extends "res://tests/test_base.gd"

func test_harness_runs() -> void:
	check(1 + 1 == 2, "math is broken")
