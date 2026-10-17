extends SceneTree
var game: Node2D
var failures: Array[String] = []
var output = OS.get_environment("HORDE_PAGES_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message);push_error("PAGES_V84: " + message)
func frames(count: int = 4) -> void:
	for i in range(count):
		game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
func rect(action: String) -> Rect2:
	for control in game.buttons:
		if control.action == action: return control.rect
	return Rect2()
func tap(action: String) -> void:
	var box = rect(action)
	check(box.size.x > 0, "missing " + action)
	if box.size.x <= 0: return
	var event = InputEventScreenTouch.new();event.position = game.to_global(box.get_center());event.index = 9;event.pressed = true
	game._input(event);await frames(3);event.pressed = false;game._input(event);await frames()
func capture(name: String) -> void:
	if not output.is_empty(): root.get_texture().get_image().save_png(output + "/" + name + ".png")
func run() -> void:
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.capture_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 370;game.data.mission_tier = 9;game.data.player_level = 8
	game.data.mission_progress = {"cars_many": 7, "flights": 5, "boost": 190}
	var missions = MonsterCatalog.active_missions(9);game.data.claimed = [missions[0].key, missions[1].key]
	for size in [Vector2i(1600, 720), Vector2i(1280, 720), Vector2i(1280, 960)]:
		root.size = size;await frames()
		for page in ["missions", "help", "collection"]:
			game.views.selected = 1 if page == "collection" else 0;game.change_screen(page);await frames(8)
			check(game.buttons.size() == {"missions": 2, "help": 3, "collection": 6}[page], "control count " + page)
			for i in range(game.buttons.size()):
				check(game.full_rect().encloses(game.buttons[i].rect), "outside viewport " + page)
				for j in range(i): check(not game.buttons[i].rect.intersects(game.buttons[j].rect), "overlapping controls " + page)
			capture(page + "-" + str(size.x) + "x" + str(size.y))
			await tap("back");check(game.screen == "home", "Back " + page)
	check(game.pages.done_count(game.data) == 2 and int(game.data.mission_progress.boost) == 190, "live mission values")
	root.size = Vector2i(1600, 720);game.change_screen("collection");await frames()
	var before = game.data.duplicate(true)
	await tap("collection_select_0")
	check(game.home_menu.menu_zombie.sprites[0].visible, "animated zombie missing")
	var material = game.home_menu.menu_zombie.materials[0]
	game.ui_time = 6.3;await frames();var a = material.get_shader_parameter("face_origin_a")
	game.ui_time = 15.3;await frames();check(a != material.get_shader_parameter("face_origin_a"), "face animation stopped")
	await tap("collection_select_1")
	for sprite in game.home_menu.menu_zombie.sprites: check(not sprite.visible, "zombie overlay on skeleton")
	check(game.data == before, "preview mutated purchase/save")
	await tap("market_monsters");check(game.market.category == 1, "wrong market category")
	await tap("skin_1");check(int(game.data.wallet) == 370 and 1 not in game.data.owned, "insufficient funds charged")
	await tap("back");check(game.screen == "collection" and game.views.selected == 1, "selection lost on Back")
	game.data.wallet = 1000;await tap("market_monsters");await tap("skin_1")
	check(int(game.data.wallet) == 0 and 1 in game.data.owned, "skin purchase failed")
	await tap("back");await tap("powers");check(game.market.category == 2, "power link")
	await tap("back");check(game.screen == "collection", "power Back")
	game.change_screen("help");await frames();await tap("credits");await tap("back");check(game.screen == "help", "credits return")
	await tap("play");check(game.screen == "run" and game.runner.active_count() > 0, "Play")
	check(game.camera_zoom == game.CAMERA_BASE_ZOOM, "camera reset")
	for sprite in game.home_menu.menu_zombie.sprites: check(not sprite.visible, "menu zombie leaked to gameplay")
	# Actual elevated road and HUD preview, without changing the camera implementation.
	game.runner.entities.clear();game.runner.tunnels.clear();game.runner.next_segment = 99999;game.runner.world_px = 2000
	game.runner.terrain.segments.assign([{"start": -10000.0, "end": 2750.0, "height": 0.0, "state": 0}, {"start": 2750.0, "end": 4400.0, "height": 80.0, "state": 1}, {"start": 4400.0, "end": 100000.0, "height": 0.0, "state": 2}])
	while game.runner.members.size() < 5: game.runner.add_member(0, false)
	for m in game.runner.members: m.arrival = 0
	var car = game.runner.add_entity("bus", 1350, 494);car.plan_speed = 305
	for i in range(5): game.runner.add_entity("coin", 850 + i * 68, 446)
	game.runner.add_entity("civilian", 1000, 494, 1)
	game.runner.coins = 31;game.runner.souls = 7;game.ui_time = 4.5
	game.configure_layout();await frames(8);capture("gameplay-platform")
	game.change_screen("pause");await frames(8);capture("pausa")
	await tap("resume");check(game.screen == "run", "resume failed")
	print("PAGES_V84_RESULT: " + JSON.stringify({"failures": failures, "viewports": 3, "pages": 3, "touch": true, "purchases": true, "camera_base": game.camera_zoom}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
