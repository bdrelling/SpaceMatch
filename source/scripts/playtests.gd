class_name Playtests
## Single source of truth for the repo-root `.playtests/` capture directory.
##
## Resolves one level above `res://` (the `source/` project root), so output
## never drifts into `source/.playtests/` — which is what `res://.playtests/`
## or a bare relative `.playtests/` written from `source/` produces. Every
## screenshot run and test artifact destination resolves through here.

## Absolute path to the repo-root `.playtests/` directory.
static func directory() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../.playtests").simplify_path()

## A named bucket under `.playtests/`, e.g. [code]Playtests.subdirectory("dc-167")[/code].
static func subdirectory(name: String) -> String:
	return directory().path_join(name)
