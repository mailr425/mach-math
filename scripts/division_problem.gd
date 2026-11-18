class_name DivisionProblem
extends RefCounted
## Makes one division-with-remainder problem plus two "trap" answers
## built from the mistakes 4th graders actually make.

var dividend: int
var divisor: int
var quotient: int
var remainder: int
var choices: Array = []   # Each choice: {"q": int, "r": int, "kind": String, "text": String}
var correct_index: int = 0


## level 0 = quick "escape" problems, 1 = easy, 2 = medium, 3 = 3-digit dividends
static func make(level: int) -> DivisionProblem:
	var p := DivisionProblem.new()
	match level:
		0:
			p.divisor = randi_range(2, 9)
			p.dividend = randi_range(p.divisor + 1, p.divisor * 10 - 1)
		1:
			p.divisor = randi_range(2, 5)
			p.dividend = randi_range(10, 49)
		2:
			p.divisor = randi_range(2, 9)
			p.dividend = randi_range(20, 99)
		_:
			p.divisor = randi_range(3, 9)
			p.dividend = randi_range(100, 999)
	p._solve()
	# Most problems should have a remainder, since that's what he's practicing.
	if p.remainder == 0 and randf() < 0.75:
		p.dividend += randi_range(1, p.divisor - 1)
		p._solve()
	p._build_choices()
	return p


func _solve() -> void:
	@warning_ignore("integer_division")
	quotient = dividend / divisor
	remainder = dividend % divisor


func _build_choices() -> void:
	var pool: Array = []
	# The big one: a remainder that's bigger than the divisor (means another group fits).
	if quotient > 1:
		pool.append({"q": quotient - 1, "r": remainder + divisor, "kind": "remainder_too_big"})
		pool.append({"q": quotient - 1, "r": remainder, "kind": "off_by_one"})
	pool.append({"q": quotient + 1, "r": remainder, "kind": "off_by_one"})
	if remainder != 0:
		pool.append({"q": quotient, "r": 0, "kind": "forgot_remainder"})
	var wrong_r := (remainder + randi_range(1, divisor - 1)) % divisor
	if wrong_r != remainder:
		pool.append({"q": quotient, "r": wrong_r, "kind": "wrong_remainder"})
	pool.shuffle()

	choices = [{"q": quotient, "r": remainder, "kind": "correct"}]
	for c in pool:
		if choices.size() >= 3:
			break
		if not _has_choice(c["q"], c["r"]):
			choices.append(c)
	choices.shuffle()
	for i in choices.size():
		choices[i]["text"] = format_answer(choices[i]["q"], choices[i]["r"])
		if choices[i]["kind"] == "correct":
			correct_index = i


func _has_choice(q: int, r: int) -> bool:
	for c in choices:
		if c["q"] == q and c["r"] == r:
			return true
	return false


static func format_answer(q: int, r: int) -> String:
	return "%d r%d" % [q, r]


func question_text() -> String:
	return "%d ÷ %d = ?" % [dividend, divisor]


func answer_text() -> String:
	return "%d ÷ %d = %s" % [dividend, divisor, format_answer(quotient, remainder)]


## Shows the work, the way he'd check it on paper.
func work_text() -> String:
	var product := divisor * quotient
	return "%d × %d = %d, and %d - %d = %d left over.  So %s" % [
		divisor, quotient, product, dividend, product, remainder, answer_text()]


func hint_for(kind: String) -> String:
	match kind:
		"remainder_too_big":
			return "The remainder has to be SMALLER than %d. If it's bigger, another %d fits!" % [divisor, divisor]
		"forgot_remainder":
			return "Don't forget the leftovers! That's the remainder."
		"off_by_one":
			return "So close! How many groups of %d fit into %d?" % [divisor, dividend]
		"wrong_remainder":
			return "Right number of groups! Recheck the leftovers."
	return ""
