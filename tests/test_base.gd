extends RefCounted

var failures: Array[String] = []

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
