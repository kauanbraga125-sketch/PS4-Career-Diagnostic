extends SceneTree

# Focused, independently terminating CI smoke suite for the corrected 0.8.12 source.
# The older full self_test.gd remains available for migration; it assumes the
# original, unscaled motorcycle width and crashes when no contact is recorded.
var failures: Array[String] = []
var checks: int = 0

func verify(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error("HORDE_CI_SMOKE_FAIL: " + description)

func _initialize() -> void:
	call_deferred("_run_ci")

func _run_ci() -> void:
	var tests: Node = load("res://tests/vehicle_survivors_test.gd").new()
	root.add_child(tests)
	tests.run_checks()
	checks += tests.checks
	failures.append_array(tests.failures)

	var latest: Node = load("res://tests/v0812_regressions_test.gd").new()
	root.add_child(latest)
	latest.run_checks()
	checks += latest.checks
	failures.append_array(latest.failures)

	# A real unmodified HordeRun must start, advance, and respond to a jump.
	var run := HordeRun.new()
	run.start(MonsterCatalog.defaults().levels, 812)
	run.entities.clear()
	run.events.clear()
	run.next_segment = 99999
	verify(not run.dead and run.members.size() >= 1, "Base run starts with a living player")
	var distance_before: float = run.world_px
	run.advance(1.0 / 60.0)
	verify(run.world_px > distance_before, "World advances during a live run")
	if not run.members.is_empty():
		var y_before: float = float(run.members[0].y)
		run.jump()
		for i in range(4):
			run.advance(1.0 / 60.0, true)
		verify(float(run.members[0].y) < y_before, "Held jump lifts the lead runner")
	verify(not run.dead, "Basic running and jump leave the player alive")

	if failures.is_empty():
		print("HORDE_CI_SMOKE_OK: ", checks, " assertions, including truck/plane survivor regression")
		quit(0)
	else:
		print("HORDE_CI_SMOKE_FAIL: ", failures.size(), " failures out of ", checks)
		quit(1)
