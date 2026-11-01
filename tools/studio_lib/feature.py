"""Feature files, the board and DECISIONS.md: parsing and content lanes (F-002 C6, C9, C13).

Pure functions on strings, no I/O, so every rule can be tested on plain text.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

STATUSES = (
    "DRAFT",
    "PLAN_REVIEW",
    "PLAN_CHANGES",
    "APPROVED",
    "IN_PROGRESS",
    "CODE_REVIEW",
    "CODE_CHANGES",
    "DONE",
    "PARKED",
)
OWNERS = ("Planner", "Auditor", "Builder", "Lucas")
CHANGES_REQUESTED = "CHANGES_REQUESTED"
APPROVING = ("APPROVE", "APPROVE_WITH_NOTES")

PLAN_SECTION = 7
LOG_SECTION = 8
CODE_SECTION = 9
QUESTIONS_SECTION = 10
NOTES_SECTION = 11

# F-002/C13: what each role may do to each section. Sections left out must stay identical.
SECTION_RULES = {
    "auditor-plan": {PLAN_SECTION: "append", QUESTIONS_SECTION: "rows"},
    "auditor-code": {CODE_SECTION: "append", QUESTIONS_SECTION: "rows"},
    "planner": {
        **{number: "free" for number in range(1, 7)},
        PLAN_SECTION: "append",
        QUESTIONS_SECTION: "rows+answers",
    },
    "builder": {LOG_SECTION: "free", CODE_SECTION: "append", QUESTIONS_SECTION: "rows"},
}
FRONTMATTER_FREE_FIELDS = ("status", "owner_now", "updated")

_FIELD_RE = re.compile(r"^([a-z_]+):\s*(.*?)(\s+#.*)?$")
_SECTION_RE = re.compile(r"^## (\d+)\. ")
_ROUND_RE = re.compile(r"^<!-- review-round: (\d+) verdict: ([A-Z_]+) -->\s*$")
_REVIEWED_COMMIT_RE = re.compile(r"\*\*Reviewed commit:\*\*\s*`?([0-9a-fA-F]{7,40})\b")
_READINESS_RE = re.compile(r"<!-- readiness-fail: (\d+) sha: ([0-9a-f]+) -->")
_AFTER_ROUND_RE = re.compile(r"<!-- after-code-round: (\d+) -->")
_QUESTION_ID_RE = re.compile(r"^\s*Q(\d+)\s*$")
_DECISION_RE = re.compile(r"^## (D-\d+)\b")
_PROPOSED_RE = re.compile(r"^\W*Status:\W*PROPOSED\b", re.MULTILINE)
_CELL_SPLIT_RE = re.compile(r"(?<!\\)\|")


class FormatError(ValueError):
    """The file doesn't have the structure the studio formats define."""


@dataclass(frozen=True)
class Round:
    number: int
    verdict: str
    line: int


@dataclass(frozen=True)
class Question:
    raw: str
    question_id: str
    blocking: bool
    answer: str


@dataclass(frozen=True)
class ReadinessFailure:
    number: int
    sha: str
    after_round: int


class Feature:
    """A parsed feature file. Sections keep their heading and trailing lines."""

    def __init__(self, text: str) -> None:
        self.text = text
        self.frontmatter, self.preamble, self.sections = _split(text)
        self.meta = _parse_meta(self.frontmatter)

    @property
    def fid(self) -> str:
        return self.meta.get("id", "")

    @property
    def title(self) -> str:
        return self.meta.get("title", "")

    @property
    def status(self) -> str:
        return self.meta.get("status", "")

    @property
    def owner(self) -> str:
        return self.meta.get("owner_now", "")

    @property
    def department(self) -> str:
        return self.meta.get("department", "")

    @property
    def plan_rounds(self) -> list[Round]:
        return review_rounds(self.sections.get(PLAN_SECTION, []))

    @property
    def code_rounds(self) -> list[Round]:
        return review_rounds(self.sections.get(CODE_SECTION, []))

    @property
    def reviewed_commit(self) -> str | None:
        """The "Reviewed commit" inside the latest §9 round, ignoring placeholders above it."""
        lines = self.sections.get(CODE_SECTION, [])
        rounds = review_rounds(lines)
        if not rounds:
            return None
        for line in lines[rounds[-1].line :]:
            match = _REVIEWED_COMMIT_RE.search(line)
            if match:
                return match.group(1).lower()
        return None

    @property
    def questions(self) -> list[Question]:
        return question_rows(self.sections.get(QUESTIONS_SECTION, []))

    @property
    def unanswered_blocking(self) -> list[Question]:
        return [q for q in self.questions if q.blocking and not q.answer]

    @property
    def readiness_failures(self) -> list[ReadinessFailure]:
        failures = []
        for question in self.questions:
            fail = _READINESS_RE.search(question.raw)
            after = _AFTER_ROUND_RE.search(question.raw)
            if fail:
                failures.append(
                    ReadinessFailure(
                        int(fail.group(1)), fail.group(2), int(after.group(1)) if after else 0
                    )
                )
        return failures

    @property
    def consecutive_readiness_failures(self) -> int:
        """F-002/C10(b): failures since the last completed code review round."""
        completed = len(self.code_rounds)
        return sum(1 for fail in self.readiness_failures if fail.after_round == completed)


def _split(text: str) -> tuple[list[str], list[str], dict[int, list[str]]]:
    lines = text.split("\n")
    if not lines or lines[0] != "---" or "---" not in lines[1:]:
        raise FormatError("missing frontmatter")
    end = lines.index("---", 1)
    preamble: list[str] = []
    sections: dict[int, list[str]] = {}
    current = preamble
    fenced = False
    for line in lines[end + 1 :]:
        if line.startswith("```"):
            fenced = not fenced
        match = None if fenced else _SECTION_RE.match(line)
        if match:
            number = int(match.group(1))
            if number in sections:
                raise FormatError(f"duplicate section {number}")
            current = sections.setdefault(number, [])
        current.append(line)
    return lines[1:end], preamble, sections


def _parse_meta(frontmatter: list[str]) -> dict[str, str]:
    meta = {}
    for line in frontmatter:
        match = _FIELD_RE.match(line)
        if match:
            meta[match.group(1)] = match.group(2).strip()
    return meta


def review_rounds(section_lines: list[str]) -> list[Round]:
    """F-002/C9: only machine markers count. `PENDING` and `**Round:**` text doesn't."""
    rounds = []
    fenced = False
    for index, line in enumerate(section_lines):
        if line.startswith("```"):
            fenced = not fenced
        match = None if fenced else _ROUND_RE.match(line)
        if match:
            rounds.append(Round(int(match.group(1)), match.group(2), index))
    return rounds


def _cells(line: str) -> list[str]:
    return [cell.strip() for cell in _CELL_SPLIT_RE.split(line.strip().strip("|"))]


def _is_row(line: str) -> bool:
    stripped = line.strip()
    return stripped.startswith("|") and stripped.endswith("|") and len(_cells(line)) >= 5


def question_rows(section_lines: list[str]) -> list[Question]:
    questions = []
    for line in section_lines:
        if not _is_row(line):
            continue
        cells = _cells(line)
        if not _QUESTION_ID_RE.match(cells[0]):
            continue
        questions.append(Question(line, cells[0], cells[-2].lower() == "yes", cells[-1]))
    return questions


def set_field(text: str, key: str, value: str) -> str:
    """Sets a frontmatter field, keeping the trailing comment in its column."""
    lines = text.split("\n")
    end = lines.index("---", 1)
    for index in range(1, end):
        match = _FIELD_RE.match(lines[index])
        if match and match.group(1) == key:
            line = lines[index]
            comment = match.group(3)
            new_line = f"{key}: {value}"
            if comment:
                column = len(line) - len(comment.lstrip())
                new_line = new_line.ljust(column - 1) + " " + comment.lstrip()
            lines[index] = new_line
            return "\n".join(lines)
    raise FormatError(f"no frontmatter field {key}")


def set_state(text: str, status: str, owner: str, today: str) -> str:
    text = set_field(text, "status", status)
    text = set_field(text, "owner_now", owner)
    return set_field(text, "updated", today)


def append_question(text: str, raised_by: str, question: str, blocking: bool) -> str:
    """Adds a §10 row after the table's last row (F-002 C10, C14)."""
    feature = Feature(text)
    numbers = [0]
    for row in feature.questions:
        numbers.append(int(_QUESTION_ID_RE.match(_cells(row.raw)[0]).group(1)))
    safe_question = question.replace("|", "\\|")
    flag = "yes" if blocking else "no"
    row = f"| Q{max(numbers) + 1} | {raised_by} | {safe_question} | {flag} | |"
    section = feature.sections.get(QUESTIONS_SECTION)
    if section is None:
        raise FormatError("no §10")
    last_row = max((i for i, line in enumerate(section) if _is_row(line)), default=None)
    if last_row is None:
        raise FormatError("no §10 table")
    updated = section[: last_row + 1] + [row] + section[last_row + 1 :]
    return _replace_section(text, QUESTIONS_SECTION, updated)


def readiness_row(number: int, sha: str, failed: list[str], log: str, after_round: int) -> str:
    names = ", ".join(failed)
    return (
        f"Readiness checks failed at `{sha[:7]}`: {names}. Log: `{log}`. "
        f"<!-- readiness-fail: {number} sha: {sha} --> <!-- after-code-round: {after_round} -->"
    )


def add_director_note(text: str, note: str, label: str, today: str) -> str:
    """Only gate commands call this (F-002/C2)."""
    section = Feature(text).sections.get(NOTES_SECTION)
    if section is None:
        raise FormatError("no §11")
    body = list(section)
    while body and not body[-1].strip():
        body.pop()
    trailing = len(section) - len(body)
    body.append(f"- **{today} ({label}):** {note}")
    return _replace_section(text, NOTES_SECTION, body + [""] * max(trailing, 1))


def _replace_section(text: str, number: int, new_lines: list[str]) -> str:
    feature = Feature(text)
    lines = text.split("\n")
    old = feature.sections[number]
    for start in range(len(lines) - len(old) + 1):
        if lines[start : start + len(old)] == old and _SECTION_RE.match(lines[start]):
            return "\n".join(lines[:start] + new_lines + lines[start + len(old) :])
    raise FormatError(f"section {number} not found")


# --- Board ---


def _board_columns(lines: list[str]) -> dict[str, int]:
    for line in lines:
        cells = _cells(line) if line.strip().startswith("|") else []
        if "Status" in cells and "Next actor" in cells:
            return {name: index for index, name in enumerate(cells)}
    raise FormatError("no board table")


def board_row(board_text: str, fid: str) -> dict[str, str] | None:
    lines = board_text.split("\n")
    columns = _board_columns(lines)
    for line in lines:
        if line.strip().startswith("|"):
            cells = _cells(line)
            if cells and cells[0] == fid:
                return {name: cells[index] for name, index in columns.items()}
    return None


def next_actor_for(status: str, owner: str) -> str:
    return "—" if status == "DONE" else owner


def set_board_row(board_text: str, fid: str, status: str, owner: str) -> str:
    lines = board_text.split("\n")
    columns = _board_columns(lines)
    for index, line in enumerate(lines):
        if line.strip().startswith("|"):
            cells = _cells(line)
            if cells and cells[0] == fid:
                cells[columns["Status"]] = status
                cells[columns["Next actor"]] = next_actor_for(status, owner)
                lines[index] = "| " + " | ".join(cells) + " |"
                return "\n".join(lines)
    raise FormatError(f"no board row for {fid}")


# --- F-002/C6 consistency ---


def verdict_errors(feature: Feature) -> list[str]:
    """Does the latest review round match the status? Files with no markers pass unless the
    state itself claims a verdict (F-002 C5, C9)."""
    state = (feature.status, feature.owner)
    plan = feature.plan_rounds
    code = feature.code_rounds
    latest_plan = plan[-1].verdict if plan else None
    latest_code = code[-1].verdict if code else None
    errors = []
    if feature.status == "PLAN_CHANGES" and latest_plan != CHANGES_REQUESTED:
        errors.append(f"PLAN_CHANGES but the latest §7 verdict is {latest_plan}")
    if state == ("PLAN_REVIEW", "Lucas") and latest_plan not in APPROVING:
        errors.append(f"waiting for Gate A but the latest §7 verdict is {latest_plan}")
    if feature.status == "APPROVED" and plan and latest_plan not in APPROVING:
        errors.append(f"APPROVED but the latest §7 verdict is {latest_plan}")
    if (
        feature.status == "CODE_CHANGES"
        and latest_code != CHANGES_REQUESTED
        and not feature.consecutive_readiness_failures
    ):
        errors.append(f"CODE_CHANGES but the latest §9 verdict is {latest_code}")
    if state == ("CODE_REVIEW", "Lucas") and latest_code not in APPROVING:
        errors.append(f"waiting for Gate B but the latest §9 verdict is {latest_code}")
    return errors


def board_errors_for(feature: Feature, board_text: str) -> list[str]:
    try:
        row = board_row(board_text, feature.fid)
    except FormatError as error:
        return [f"board unreadable: {error}"]
    if row is None:
        return [f"no STATUS.md row for {feature.fid}"]
    errors = []
    if row.get("Status") != feature.status:
        errors.append(f"status is {feature.status}, board says {row.get('Status')}")
    if row.get("Next actor") not in (feature.owner, next_actor_for(feature.status, feature.owner)):
        errors.append(f"owner is {feature.owner}, board says {row.get('Next actor')}")
    return errors


def consistency_errors(feature: Feature, board_text: str) -> list[str]:
    return board_errors_for(feature, board_text) + verdict_errors(feature)


# --- F-002/C13 content lanes ---


def preserved(before: list[str], after: list[str]) -> bool:
    """Every earlier line is still present, in order."""
    remaining = iter(after)
    return all(line in remaining for line in before)


def _frontmatter_errors(before: Feature, after: Feature) -> list[str]:
    def fixed(lines: list[str]) -> list[str]:
        kept = []
        for line in lines:
            match = _FIELD_RE.match(line)
            free = match and match.group(1) in FRONTMATTER_FREE_FIELDS
            kept.append(match.group(1) if free else line)  # Free values, but one line each.
        return kept

    if fixed(before.frontmatter) != fixed(after.frontmatter):
        return ["frontmatter: only status, owner_now and updated may change"]
    return []


def _answer_filled(before: str, after: str) -> bool:
    if not (_is_row(before) and _is_row(after)):
        return False
    old, new = _cells(before), _cells(after)
    return old[:-1] == new[:-1] and not old[-1] and bool(new[-1])


def _questions_errors(before: list[str], after: list[str], may_answer: bool) -> list[str]:
    errors = []
    added = []
    cursor = 0
    for line in before:
        match = None
        for index in range(cursor, len(after)):
            if after[index] == line or (may_answer and _answer_filled(line, after[index])):
                match = index
                break
        if match is None:
            return [f"§10: an earlier line changed or was removed: {line.strip()[:70]}"]
        added.extend(after[cursor:match])
        cursor = match + 1
    added.extend(after[cursor:])
    for line in added:
        if not line.strip():
            continue
        if not _is_row(line):
            errors.append(f"§10: only new table rows may be added: {line.strip()[:70]}")
        elif _READINESS_RE.search(line):
            errors.append("§10: readiness markers belong to the tool")
    return errors


def _section_errors(number: int, rule: str, before: list[str], after: list[str]) -> list[str]:
    if rule == "free":
        return []
    if rule == "append":
        return [] if preserved(before, after) else [f"§{number}: an earlier line was changed"]
    if rule in ("rows", "rows+answers"):
        return _questions_errors(before, after, rule == "rows+answers")
    return [] if before == after else [f"§{number} must stay identical"]


def content_lane_errors(role: str, before_text: str, after_text: str) -> list[str]:
    try:
        before = Feature(before_text)
        after = Feature(after_text)
    except FormatError as error:
        return [f"feature file unreadable: {error}"]
    errors = _frontmatter_errors(before, after)
    if before.preamble != after.preamble:
        errors.append("the text above §1 must stay identical")
    if set(before.sections) != set(after.sections):
        errors.append("feature sections were added or removed")
        return errors
    rules = SECTION_RULES[role]
    for number in sorted(before.sections):
        rule = rules.get(number, "identical")
        errors.extend(_section_errors(number, rule, before.sections[number], after.sections[number]))
    return errors


def board_lane_errors(fid: str, before_text: str, after_text: str) -> list[str]:
    """Only this feature's row, only its Status and Next actor columns."""
    before = before_text.split("\n")
    after = after_text.split("\n")
    if len(before) != len(after):
        return ["STATUS.md: lines were added or removed"]
    try:
        columns = _board_columns(before)
    except FormatError as error:
        return [f"STATUS.md: {error}"]
    free = {columns["Status"], columns["Next actor"]}
    errors = []
    for old, new in zip(before, after):
        if old == new:
            continue
        old_cells = _cells(old) if old.strip().startswith("|") else []
        new_cells = _cells(new) if new.strip().startswith("|") else []
        is_own_row = bool(old_cells) and old_cells[0] == fid and len(old_cells) == len(new_cells)
        same_fixed = is_own_row and all(
            old_cells[i] == new_cells[i] for i in range(len(old_cells)) if i not in free
        )
        if not same_fixed:
            errors.append(f"STATUS.md: only {fid}'s Status and Next actor may change")
            break
    return errors


def _decision_entries(text: str) -> tuple[str, list[tuple[str, str]]]:
    lines = text.splitlines(keepends=True)
    starts = []
    fenced = False
    for index, line in enumerate(lines):
        if line.startswith("```"):
            fenced = not fenced
        match = None if fenced else _DECISION_RE.match(line)
        if match:
            starts.append((index, match.group(1)))
    if not starts:
        return text, []
    preamble = "".join(lines[: starts[0][0]])
    entries = []
    for position, (start, entry_id) in enumerate(starts):
        end = starts[position + 1][0] if position + 1 < len(starts) else len(lines)
        entries.append((entry_id, "".join(lines[start:end])))
    return preamble, entries


def decisions_lane_errors(before_text: str, after_text: str) -> list[str]:
    """Existing entries byte-identical, new ones only as PROPOSED (F-002/C13)."""
    old_preamble, old_entries = _decision_entries(before_text)
    new_preamble, new_entries = _decision_entries(after_text)
    errors = []
    if old_preamble != new_preamble:
        errors.append("DECISIONS.md: the text above the entries must stay identical")
    new_by_id: dict[str, str] = {}
    for entry_id, body in new_entries:
        if entry_id in new_by_id:
            errors.append(f"DECISIONS.md: duplicate entry {entry_id}")
        new_by_id[entry_id] = body
    old_by_id = dict(old_entries)
    for entry_id, body in old_by_id.items():
        if new_by_id.get(entry_id) != body:
            errors.append(f"DECISIONS.md: existing entry {entry_id} changed")
    for entry_id, body in new_by_id.items():
        if entry_id not in old_by_id and not _PROPOSED_RE.search(body):
            errors.append(f"DECISIONS.md: new entry {entry_id} must have Status: PROPOSED")
    return errors
