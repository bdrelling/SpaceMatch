class_name ReplaceStackRule
extends StackRule
## Overwrites the existing stacks with the incoming count, rather than summing them ([StackStackRule]) or keeping
## the larger ([KeepHighestStackRule]). The refresh policy — a re-application resets the count to whatever was
## just applied.
