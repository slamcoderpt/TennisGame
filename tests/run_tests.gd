extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/test_smoke.gd",
	"res://tests/test_sim.gd",
	"res://tests/test_projection.gd",
	"res://tests/test_ai.gd",
	"res://tests/test_score.gd",
	"res://tests/test_rules.gd",
	"res://tests/test_charge.gd",
	"res://tests/test_shots.gd",
	"res://tests/test_meter.gd",
	"res://tests/test_feel.gd",
	"res://tests/test_sprite.gd",
	"res://tests/test_serve.gd",
	"res://tests/test_stats.gd",
	"res://tests/test_roster.gd",
	"res://tests/test_surface.gd",
]

func _init() -> void:
	var passed := 0
	var failed := 0
	for path in TEST_SCRIPTS:
		var script = load(path)
		if script == null:
			print("FAIL could not load %s" % path)
			failed += 1
			continue
		var test = script.new()
		for m in test.get_method_list():
			if not m.name.begins_with("test_"):
				continue
			test.failures.clear()
			test.call(m.name)
			if test.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for msg in test.failures:
					print("FAIL %s.%s: %s" % [path.get_file(), m.name, msg])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
