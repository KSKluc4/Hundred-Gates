#!/usr/bin/env python3
"""The pack reader and the zip writer of tools/export (F-017/C6, C9).

Standard library only, Python 3.9 or later. Sub-commands:

  list <exe>                    print every path in the pack embedded in the exe
  check <exe> <project_root>    checks (b), (c) and (d) of C6; one `error:` line (on
                                stderr) per failing check, exit 1 if any
  extract <exe> <out.pck>       write the embedded pack out as a standalone .pck, which
                                the editor binary takes with --main-pack (C11)
  readme <file>                 plain ASCII, no line over 78 characters
  zip <out.zip> <exe> <readme>  a deflated zip holding HundredGates.exe and README.txt

The pack is the one Godot 4.7.2 writes into a release export with
binary_format/embed_pck=true. The exe ends with: the pack, its size (8 bytes, little
endian), and the magic `GDPC` (4 bytes). The pack starts with the magic `GDPC` again:

  magic(4) format(u32) major(u32) minor(u32) patch(u32) flags(u32)
  file_base(u64) dir_offset(u64) reserved(16 x u32)

Format 4 is the only one read here. `dir_offset` counts from the start of the pack and
points at the file table: a u32 count, then per file a u32 path length (padded to a
multiple of 4, with NUL bytes), the path (without `res://`), offset u64, size u64, md5
(16 bytes) and flags u32.
"""

import os
import struct
import sys
import zipfile

MAGIC = b"GDPC"
TRAILER_SIZE = 12  # the pack's size (8 bytes) and the magic (4 bytes)
HEADER_SIZE = 4 + 4 + 12 + 4 + 8 + 8 + 64
SUPPORTED_FORMAT = 4
FLAG_ENCRYPTED = 1  # PACK_DIR_ENCRYPTED

# C6 (c): the project files that must be in the pack, as folders and one file.
REQUIRED_FOLDERS = ("src", "data")
REQUIRED_EXTENSIONS = (".gd", ".tres", ".tscn")
REQUIRED_FILES = ("scenes/main.tscn",)
# C6 (d): what the pack's top level holds, and nothing else.
TOP_LEVEL_NAMES = {".godot", "data", "scenes", "src", "project.binary"}
SCENES_ENTRIES = {"main.tscn", "main.tscn.remap"}

README_MAX_LINE = 78
SHOWN_PATHS = 8


class PackError(Exception):
    """The exe has no readable embedded pack; the message says why."""


def report(text):
    """A failed check: one `error:` line on stderr, like the shell script's own."""
    print(text, file=sys.stderr)


def read_pack(exe_path):
    """Returns the bytes of the exe's embedded pack, from its `GDPC` header to its end."""
    with open(exe_path, "rb") as exe:
        exe.seek(0, os.SEEK_END)
        length = exe.tell()
        if length < TRAILER_SIZE + HEADER_SIZE:
            raise PackError("the exe is too small to hold a pack")
        exe.seek(length - TRAILER_SIZE)
        trailer = exe.read(TRAILER_SIZE)
        if trailer[8:] != MAGIC:
            raise PackError("the exe does not end with the GDPC trailer (no embedded pack)")
        pack_size = struct.unpack("<Q", trailer[:8])[0]
        if pack_size < HEADER_SIZE or pack_size > length - TRAILER_SIZE:
            raise PackError("the size in the trailer (%d) does not fit the exe" % pack_size)
        exe.seek(length - TRAILER_SIZE - pack_size)
        return exe.read(pack_size)


def read_table(exe_path):
    """Returns the list of paths in the exe's embedded pack, in table order."""
    return _paths_in(read_pack(exe_path))


def write_pck(exe_path, pck_path):
    """Writes the embedded pack out as a standalone .pck. Returns its size."""
    pack = read_pack(exe_path)
    _paths_in(pack)  # A header and a table that read, or no file.
    with open(pck_path, "wb") as pck:
        pck.write(pack)
    return len(pack)


def _paths_in(pack):
    magic, version, _major, _minor, _patch, flags, _base, dir_offset = struct.unpack_from(
        "<4sIIIIIQQ", pack, 0
    )
    if magic != MAGIC:
        raise PackError("the pack does not start with GDPC")
    if version != SUPPORTED_FORMAT:
        raise PackError("pack format %d is not supported (only %d)" % (version, SUPPORTED_FORMAT))
    if flags & FLAG_ENCRYPTED:
        raise PackError("the pack's file table is encrypted")
    try:
        (count,) = struct.unpack_from("<I", pack, dir_offset)
        offset = dir_offset + 4
        paths = []
        for _ in range(count):
            (name_length,) = struct.unpack_from("<I", pack, offset)
            offset += 4
            raw = pack[offset : offset + name_length]
            if len(raw) != name_length:
                raise PackError("the file table is cut short")
            offset += name_length
            paths.append(raw.rstrip(b"\0").decode("utf-8"))
            offset += 8 + 8 + 16 + 4  # offset, size, md5, flags
        if offset > len(pack):
            raise PackError("the file table runs past the end of the pack")
    except struct.error:
        raise PackError("the file table is cut short") from None
    return paths


def project_files(project_root):
    """What check (c) asks for: paths relative to the project, with `/`."""
    wanted = set(REQUIRED_FILES)
    for folder in REQUIRED_FOLDERS:
        for directory, _names, files in os.walk(os.path.join(project_root, folder)):
            for name in files:
                if name.endswith(REQUIRED_EXTENSIONS):
                    relative = os.path.relpath(os.path.join(directory, name), project_root)
                    wanted.add(relative.replace(os.sep, "/"))
    return wanted


def _shown(paths):
    paths = sorted(paths)
    text = ", ".join(paths[:SHOWN_PATHS])
    if len(paths) > SHOWN_PATHS:
        text += ", ... (%d more)" % (len(paths) - SHOWN_PATHS)
    return text


def check(exe_path, project_root):
    """Checks (b), (c), (d). Prints one `error:` line per failing check; returns 0 or 1."""
    try:
        paths = read_table(exe_path)
    except (PackError, OSError) as problem:
        report("error: check (b) failed: %s" % problem)
        return 1
    if not paths:
        report("error: check (b) failed: the pack's file table is empty")
        return 1
    present = set(paths)
    failed = False

    missing = [
        path
        for path in project_files(project_root)
        if path not in present and path + ".remap" not in present
    ]
    if missing:
        failed = True
        report(
            "error: check (c) failed: the pack lacks %d project file(s): %s"
            % (len(missing), _shown(missing))
        )

    extra = set()
    for path in paths:
        top, _slash, rest = path.partition("/")
        if top not in TOP_LEVEL_NAMES or (top == "scenes" and rest not in SCENES_ENTRIES):
            extra.add(path)
    absent = TOP_LEVEL_NAMES - {path.partition("/")[0] for path in paths}
    if extra or absent:
        failed = True
        parts = []
        if extra:
            parts.append("%d unexpected path(s): %s" % (len(extra), _shown(extra)))
        if absent:
            parts.append("no entry under: %s" % ", ".join(sorted(absent)))
        report("error: check (d) failed: the pack's contents are wrong: %s" % "; ".join(parts))

    if failed:
        return 1
    print("pack: %d entries, complete and nothing else (checks b, c, d)" % len(paths))
    return 0


def check_readme(readme_path):
    """C7: plain ASCII, no line over 78 characters. Returns 0 or 1."""
    with open(readme_path, "rb") as readme:
        data = readme.read()
    if not data.strip():
        report("error: README check failed: %s is empty" % readme_path)
        return 1
    for number, line in enumerate(data.split(b"\n"), 1):
        line = line.rstrip(b"\r")
        if any(byte < 0x20 or byte > 0x7E for byte in line):
            report("error: README check failed: line %d is not plain ASCII" % number)
            return 1
        if len(line) > README_MAX_LINE:
            report(
                "error: README check failed: line %d has %d characters (at most %d)"
                % (number, len(line), README_MAX_LINE)
            )
            return 1
    return 0


def write_zip(zip_path, exe_path, readme_path):
    """Writes a deflated zip with exactly HundredGates.exe and README.txt."""
    part = zip_path + ".part"
    try:
        with zipfile.ZipFile(part, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            archive.write(exe_path, "HundredGates.exe")
            archive.write(readme_path, "README.txt")
        os.replace(part, zip_path)
    finally:
        if os.path.exists(part):
            os.remove(part)


def main(argv):
    command = argv[1] if len(argv) > 1 else ""
    arguments = argv[2:]
    if command == "list" and len(arguments) == 1:
        try:
            for path in read_table(arguments[0]):
                print(path)
        except (PackError, OSError) as problem:
            report("error: %s: %s" % (arguments[0], problem))
            return 1
        return 0
    if command == "check" and len(arguments) == 2:
        return check(arguments[0], arguments[1])
    if command == "extract" and len(arguments) == 2:
        try:
            size = write_pck(arguments[0], arguments[1])
        except (PackError, OSError) as problem:
            report("error: could not cut the pack out of the exe: %s" % problem)
            return 1
        print("pack: %d bytes written to %s" % (size, arguments[1]))
        return 0
    if command == "readme" and len(arguments) == 1:
        return check_readme(arguments[0])
    if command == "zip" and len(arguments) == 3:
        try:
            write_zip(arguments[0], arguments[1], arguments[2])
        except OSError as problem:
            report("error: could not write the zip: %s" % problem)
            return 1
        return 0
    print("usage: export_pack.py list <exe> | check <exe> <project_root> |")
    print("       extract <exe> <out.pck> | readme <file> | zip <out.zip> <exe> <readme>")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
