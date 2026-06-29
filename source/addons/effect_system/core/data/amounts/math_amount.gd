class_name MathAmount
extends Amount
## Combines two [Amount]s with an arithmetic [member operation]. Composes the other amount types into expressions
## — "base damage plus your charge stacks", "half your power" — without a bespoke subclass per formula.

enum Operation {
	ADD,
	SUBTRACT,
	MULTIPLY,
}

@export var left: Amount
@export var right: Amount
@export var operation: Operation = Operation.ADD


## Evaluates both operands against the context and combines them per [member operation]. A missing operand counts
## as zero.
func evaluate(context: ResolutionContext) -> int:
	var left_value := left.evaluate(context) if left != null else 0
	var right_value := right.evaluate(context) if right != null else 0
	match operation:
		Operation.ADD:
			return left_value + right_value
		Operation.SUBTRACT:
			return left_value - right_value
		Operation.MULTIPLY:
			return left_value * right_value
	return 0
