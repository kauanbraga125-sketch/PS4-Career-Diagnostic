extends SceneTree
var game: Node2D
var failures: Array[String] = []
var reports: Array[Dictionary] = []
var shots: Dictionary = {}
var output = OS.get_environment("HORDE_LIVE_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		if failures.size() < 15: push_error("LIVE_COURSE_V85: " + message)
func frames() -> void:
	game.configure_layout();game.ui_time = game.runner.elapsed
	for i in range(3):
		game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
func observe(seed_value: int) -> void:
	var r = HordeRun.new();r.start({}, seed_value)
	while r.members.size() < 12: r.add_member(0, false)
	game.runner = r;game.scenery.reset();game.change_screen("run")
	var seen: Dictionary = {};var counts: Dictionary = {};var first: Dictionary = {}
	var elevated = 0.0;var platforms = 0;var last_height = 0.0;var idle = 0.0;var longest_idle = 0.0
	var coin_checks = 0;var rush_started: Dictionary = {}
	for frame in range(180 * 30):
		# An observer keeps actors alive to measure the advancing generator, not a gameplay bot.
		# Jump/landing playability is separately tested with the unmodified physical simulation.
		r.dead = false;r.hit_grace = 1000
		for i in range(r.members.size()):
			var m = r.members[i];m.x = r.slot_x(i);m.y = r.ground_y(m.x);m.vy = 0;m.falling = false;m.jump_queue.clear();m.attack_left = 0
		r.advance(1.0 / 30, false)
		var height = HordeRun.FLOOR - r.ground_y(HordeRun.ANCHOR)
		if height > 0: elevated += 1.0 / 30
		if height > last_height: platforms += 1
		last_height = height
		var upcoming = false
		for e in r.entities:
			if e.taken: continue
			if e.get("rushing", false) and not e.get("rush_waiting", false): rush_started[e.id] = true
			if frame % 15 == 0 and e.kind == "coin":
				check(HordeCourse.coin_clear(r, Vector2(r.world_px + e.x, e.y), false), "live coin overlap")
				coin_checks += 1
			if e.kind not in ["gap", "bomb", "air_bomb", "helicopter", "soldier", "police"] and not MonsterCatalog.VEHICLES.has(e.kind): continue
			if e.x > HordeRun.ANCHOR + 80 and e.x < 1350: upcoming = true
			if e.x < HordeRun.ANCHOR + 100 or e.x > 1100 or seen.has(e.id): continue
			var kind = "rush" if e.get("rushing", false) else str(e.kind)
			seen[e.id] = true;counts[kind] = int(counts.get(kind, 0)) + 1
			if not first.has(kind): first[kind] = snappedf(r.elapsed, 0.1)
			if MonsterCatalog.VEHICLES.has(e.kind): check(absf(e.y - r.ground_y(e.x)) < 0.1, "vehicle left the road")
			if not output.is_empty() and kind in ["moto", "bomb", "helicopter", "rush", "tank", "plane"] and not shots.has(kind):
				shots[kind] = true
				r.hit_grace = 0
				await frames()
				root.get_texture().get_image().save_png(output + "/" + kind + ".png")
		if r.elapsed > 12 and not r.inside_tunnel() and not upcoming: idle += 1.0 / 30
		else: longest_idle = maxf(longest_idle, idle);idle = 0
		r.events.clear()
	for kind in ["moto", "car", "bus", "truck", "tank", "plane", "bomb", "air_bomb", "helicopter", "gap", "rush"]: check(int(counts.get(kind, 0)) >= 1, "never visible " + kind + " seed " + str(seed_value))
	check(rush_started.size() >= 2, "incoming cars never started")
	check(elevated / r.elapsed < 0.17 and platforms <= 7, "elevated terrain dominates live run")
	check(longest_idle < 13, "long empty stretch " + str(longest_idle))
	reports.append({"seed":seed_value,"seconds":r.elapsed,"counts_visible":counts,"first_visible_seconds":first,"platforms":platforms,"raised_fraction":elevated/r.elapsed,"longest_idle_seconds":longest_idle,"coin_checks":coin_checks,"rushing_cars_started":rush_started.size(),"tunnels":r.completed_tunnels})
func run() -> void:
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.capture_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.set_process(false);game.sound.set_enabled(false)
	for seed_value in [5101, 5102, 5103]: await observe(seed_value)
	var result = {"failures":failures,"reports":reports,"screenshots":shots.keys()}
	var path = OS.get_environment("HORDE_LIVE_REPORT")
	if not path.is_empty(): FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("LIVE_COURSE_V85_RESULT: " + JSON.stringify(result))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
