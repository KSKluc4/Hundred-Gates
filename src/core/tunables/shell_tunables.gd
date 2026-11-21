class_name ShellTunables
extends Resource
## What a player's settings start as (F-015/C11, G2). Read by GameSettings; the shipped file is
## data/tunables/shell.tres.

## F-015/C11: whether the placeholder camera shake is on before the player chooses.
@export var default_screen_shake_enabled: bool = true
## F-015/C11: whether the window starts fullscreen before the player chooses.
@export var default_fullscreen: bool = false
