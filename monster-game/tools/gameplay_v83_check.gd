extends SceneTree

var game: Node2D
var failures: Array[String] = []
var output = OS.get_environment("HORDE_GAMEPLAY_OUTPUT")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("GAMEPLAY_V83_FAIL: " + message)

func frames(count: int = 3) -> void:
	for i in range(count):
		game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	if not output.is_empty(): root.get_texture().get_image().save_png(output + "/" + name + ".png")

func action_rect(action: String) -> Rect2:
	for control in game.buttons:
		if control.action == action: return control.rect
	return Rect2()

func tap(action: String) -> void:
	var rect = action_rect(action)
	check(rect.size.x > 0, "Missing touch control " + action)
	if rect.size.x <= 0: return
	var event = InputEventScreenTouch.new()
	event.position = game.to_global(rect.get_center());event.index = 5;event.pressed = true
	game._input(event)
	await frames(4)
	event.pressed = false;game._input(event)
	await frames()

func prepare_run() -> void:
	game.data = MonsterCatalog.defaults()
	game.data.levels.jump = 3
	game.data.player_level = 8;game.data.mission_tier = 9
	game.data.mission_progress = {"cars_many": 7, "flights": 5, "boost": 190}
	var missions = MonsterCatalog.active_missions(9)
	game.data.claimed = [missions[0].key, missions[1].key]
	game.start_run()
	game.runner.entities.clear()
	game.runner.tunnels.clear()
	game.runner.next_pattern_world = 1000000000.0
	game.runner.next_segment = 99999
	game.runner.next_rush_world = 1000000000.0
	while game.runner.members.size() < 9: game.runner.add_member(0)
	for member in game.runner.members: member.arrival = 0
	game.runner.coins = 31;game.runner.souls = 7
	game.capture_freeze = true
	game.configure_layout()

func check_camera() -> void:
	var view: Rect2 = game.full_rect()
	var corner = game.world_to_ui(Vector2(game.scenery.view_left, game.scenery.view_top))
	var end = game.world_to_ui(Vector2(game.scenery.view_right, game.scenery.view_bottom))
	check(corner.distance_to(view.position) < 0.05 and end.distance_to(view.end) < 0.05, "World edges do not fill the viewport")
	var foot = game.world_to_ui(Vector2(HordeRun.ANCHOR, HordeRun.FLOOR))
	check(absf(foot.x - game.CAMERA_ANCHOR.x) < 0.02 and absf(foot.y - game.CAMERA_ANCHOR.y - game.camera_ground_shift) < 0.02, "Zoom moved the horde anchor")
	check(foot.y <= view.end.y - 40, "Walk surface left the screen")
	check(game.camera_zoom >= game.CAMERA_MIN_ZOOM - 0.001 and game.camera_zoom <= game.CAMERA_TRANSFORM_ZOOM + 0.001, "Camera zoom outside supported range")

func step() -> void:
	game._physics_process(1.0 / 60)
	game._process(1.0 / 60)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false);game.set_physics_process(false)
	game.capture_mode = true;game.sound.set_enabled(false)
	prepare_run()
	game.runner.world_px = 268 * 30.0
	game.runner.add_entity("civilian", 650, HordeRun.FLOOR)
	game.runner.coin_arc(700, 5, 115, 65)
	game.runner.add_entity("bomb", 1110, HordeRun.FLOOR)
	for size in [Vector2i(1600,720), Vector2i(1280,720), Vector2i(1280,960)]:
		root.size = size
		game.configure_layout()
		await frames()
		check_camera()
		var hud = game.gameplay_ui.hud_layout(game.full_rect())
		for i in range(4):
			check(game.full_rect().encloses(hud.counters[i]), "HUD counter outside viewport")
			check(hud.counters[i].has_point(game.gameplay_ui.counter_target(game, i)), "Pickup effects miss their counter")
			check(not hud.counters[i].intersects(hud.effect), "Active power overlaps a counter")
		check(game.full_rect().encloses(action_rect("pause")), "Pause touch outside viewport")
		capture("gameplay-" + str(size.x) + "x" + str(size.y))
		await tap("pause")
		check(game.screen == "pause", "Pause did not react to actual touch")
		var d = game.gameplay_ui.pause_layout(game.full_rect())
		check(game.full_rect().encloses(d.frame), "Pause panel clipped")
		for action in ["resume", "retry", "home", "settings"]:
			check(d.frame.encloses(action_rect(action)), "Pause action clipped: " + action)
			check(action_rect(action).size.y >= 60, "Pause action too small")
			for row in d.rows: check(not action_rect(action).intersects(row), "Pause control overlaps a mission")
		capture("pausa-" + str(size.x) + "x" + str(size.y))
		var before_world = game.runner.world_px
		var before_time = game.runner.elapsed
		var before_transform = game.world_canvas.transform
		game.capture_freeze = false
		for i in range(45): step()
		check(game.runner.world_px == before_world and game.runner.elapsed == before_time, "World continued while paused")
		check(game.world_canvas.transform == before_transform, "Camera moved while paused")
		await tap("settings")
		check(game.screen == "settings", "Pause settings failed")
		await tap("back")
		check(game.screen == "pause", "Settings returned to the wrong screen")
		await tap("resume")
		check(game.screen == "run" and not game.jump_held, "Resume left a held jump active")
		game.capture_freeze = true
	root.size = Vector2i(1600,720)
	prepare_run()
	game.capture_freeze = false
	game.runner.add_entity("gap", HordeRun.ANCHOR + 140, HordeRun.FLOOR, 0, 150)
	game.jump_held = true;game.runner.jump()
	var single_top = 10000.0
	for i in range(150):
		step()
		if i == 70: game.jump_held = false;game.runner.release_jump()
		if not game.runner.members.is_empty(): single_top = minf(single_top, game.world_to_ui(Vector2(game.runner.members[0].x, game.runner.members[0].y - 112)).y)
	check(not game.runner.dead and game.runner.losses == 0 and game.runner.active_count() == 9, "Normal jump over a gap changed or lost the horde")
	check(single_top > game.full_rect().position.y + 108, "Single jump clipped behind the HUD")
	check_camera()
	prepare_run();game.capture_freeze = false
	game.jump_held = true;game.runner.jump()
	var double_top = 10000.0
	for i in range(270):
		if i == 36: game.runner.jump()
		step()
		var head = game.world_to_ui(Vector2(game.runner.members[0].x, game.runner.members[0].y - 112))
		if head.y < double_top:
			double_top = head.y
			if not output.is_empty() and i % 4 == 0:
				await frames(1);capture("salto-duplo")
		if i == 90: game.jump_held = false;game.runner.release_jump()
	check(not game.runner.dead and game.runner.active_count() == 9, "Double jump broke the horde")
	check(double_top > game.full_rect().position.y + 132, "Double jump clipped behind the HUD")
	check(is_equal_approx(game.camera_zoom, game.CAMERA_BASE_ZOOM) and is_zero_approx(game.camera_ground_shift), "Camera did not return after landing")
	check_camera()
	print("GAMEPLAY_V83_JUMP_TOP: single=", single_top, " double=", double_top)
	prepare_run();game.capture_freeze = false
	game.runner.transform_kind = 3;game.runner.transform_from_kind = -1;game.runner.transform_left = 2.8
	var last_zoom: float = game.camera_zoom
	for i in range(75):
		game._process(1.0 / 60)
		check(absf(game.camera_zoom - last_zoom) < 0.015, "Abrupt transform camera change")
		last_zoom = game.camera_zoom
		check_camera()
	check(is_equal_approx(game.camera_zoom, game.CAMERA_TRANSFORM_ZOOM), "Transformation zoom did not settle")
	await frames();capture("camera-transformacao")
	await tap("pause")
	await tap("retry")
	check(game.screen == "run" and is_zero_approx(game.camera_focus) and is_equal_approx(game.camera_zoom, game.CAMERA_BASE_ZOOM), "Restart retained the previous transformation camera")
	for pattern in [0,2,4]:
		var run_logic = HordeRun.new()
		run_logic.start(MonsterCatalog.defaults().levels, 83)
		run_logic.entities.clear();run_logic.tunnels.clear()
		HordeCourse.build(run_logic, 1200, pattern)
		for coin in run_logic.entities:
			if coin.kind != "coin": continue
			for obstacle in run_logic.entities:
				if obstacle.kind == "bomb" or MonsterCatalog.VEHICLES.has(obstacle.kind):
					var half_width = float(MonsterCatalog.VEHICLES[obstacle.kind].width) * 0.5 if MonsterCatalog.VEHICLES.has(obstacle.kind) else 52.0
					check(absf(coin.x - obstacle.x) > half_width + 55, "Coin art overlaps obstacle " + obstacle.kind)
	game.capture_freeze = true
	await frames()
	await tap("pause");await tap("home")
	check(game.screen == "home", "Pause could not return to the menu")
	await frames()
	print("GAMEPLAY_V83_", "OK" if failures.is_empty() else "FAILED", ": HUD and pause on three aspect ratios; real touch; paused physics/camera; settings/resume/retry/menu; normal and double jumps; smooth transformation; viewport edges; collectible clearance")
	quit(0 if failures.is_empty() else 1)
