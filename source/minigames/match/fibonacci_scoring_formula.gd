class_name FibonacciScoringFormula
extends ScoringFormula
## A [ScoringFormula] that pays out along the Fibonacci sequence, so a bigger match rewards super-linearly:
## 1→1, 2→2, 3→3, 4→5, 5→8, 6→13, 7→21… A single large match is worth far more than the same tiles split
## across small ones, which makes hunting big shapes worthwhile — at the cost of a swingier economy.

## The Fibonacci-shaped reward for [param quantity] tiles, seeded so 1→1, 2→2, 3→3, 4→5, 5→8, …
func reward_for(quantity: int) -> int:
	if quantity <= 0:
		return 0
	var previous: int = 1
	var current: int = 2
	if quantity == 1:
		return previous
	for _i: int in range(2, quantity):
		var next: int = previous + current
		previous = current
		current = next
	return current
