extends SceneTree
var failures: Array[String] = []
var reports: Array[Dictionary] = []
var baseline = "--baseline" in OS.get_cmdline_user_args()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		if failures.size() < 12: push_error("DISTRIBUTION_V85: " + message)
func sweep(seed_value: int, speed: float) -> void:
	var r = HordeRun.new();r.start({}, seed_value)
	r.entities.clear();r.tunnels.clear()
	while r.members.size() < 12: r.add_member(0, false)
	var absolute = 2400.0;var old_world = 0.0
	var counts: Dictionary = {};var beats_with_hazard = 0;var platforms: Dictionary = {};var longest_delay = 0.0
	for i in range(80):
		r.world_px = maxf(0, absolute - HordeRun.ANCHOR - 1500)
		var moved = r.world_px - old_world;old_world = r.world_px
		for e in r.entities: e.x -= moved
		for j in range(r.entities.size() - 1, -1, -1):
			if r.entities[j].x < -1800: r.entities.remove_at(j)
		r.speed = speed;r.cruise_speed = speed;r.entered_tunnels = int(i / 12)
		var serial = r.next_entity_id
		var next = HordeCourse.build(r, absolute, i)
		var present = false
		for e in r.entities:
			if e.id < serial or e.taken: continue
			if e.kind in ["coin", "civilian", "crystal", "mask", "shield", "boost"]: continue
			var kind = "rush" if e.get("rushing", false) else str(e.kind)
			counts[kind] = int(counts.get(kind, 0)) + 1;present = true
			longest_delay = maxf(longest_delay, (r.world_px + float(e.x) - absolute) / speed)
		if present: beats_with_hazard += 1
		for segment in r.terrain.segments:
			if float(segment.height) > 0 and float(segment.start) < next: platforms[str(segment.start)] = float(segment.end) - float(segment.start)
		absolute = next
	var vehicles = 0
	for kind in MonsterCatalog.VEHICLES: vehicles += int(counts.get(kind, 0))
	var raised = 0.0
	for length in platforms.values(): raised += float(length)
	var result = {"seed":seed_value,"speed":speed,"beats":80,"populated":beats_with_hazard,"counts":counts,"vehicles":vehicles,"platforms":platforms.size(),"raised_fraction":raised/absolute,"max_reposition_seconds":longest_delay}
	reports.append(result)
	if not baseline:
		check(beats_with_hazard >= 72, "empty planned beats " + str(result))
		check(vehicles >= 22, "vehicles too rare " + str(result))
		for kind in ["moto","car","bus","truck","tank","plane","bomb","helicopter","air_bomb","gap","rush"]: check(int(counts.get(kind,0)) >= 2, "missing " + kind + " " + str(result))
		check(float(result.raised_fraction) <= 0.17 and platforms.size() <= 12, "elevations dominate " + str(result))
func run() -> void:
	for seed_value in range(9): sweep(4721 + seed_value,[305.0,500.0,780.0][seed_value%3])
	var result = {"baseline":baseline,"failures":failures,"reports":reports}
	var path = OS.get_environment("HORDE_DISTRIBUTION_REPORT")
	if not path.is_empty(): FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DISTRIBUTION_RESULT: " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
