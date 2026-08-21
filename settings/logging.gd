@tool
extends Object

##[codeblock]
##│ _                   _
##│| |   ___  __ _ __ _(_)_ _  __ _
##│| |__/ _ \/ _` / _` | | ' \/ _` |
##│|____\___/\__, \__, |_|_||_\__, |
##╰──────────|___/|___/───────|___/───
##[/codeblock]enetheru.gdtask logging backend selector (addon-local).
##
## Call sites inside this addon:
## [codeblock]
## const GdtLog = preload("uid://g4fxq108dmm").Backend
## GdtLog.printy("hello")
## [/codeblock]
##
## Default is the addon builtin (print). Point [member Backend] at
## [code]enetheru.log-shim/log_shim.gd[/code] (or any compatible script) when
## this project wants a richer logger. No [code]class_name[/code], no autoload
## — other addons keep their own selector so trees resolve independently.
##[br][color=goldenrod]TODO[/color]: develop an abstract base logger that can
## be used to implement the shims.

# Default: zero extra deps — ships with the addon.
const Backend = preload("uid://cexurwqu3u4tm")
