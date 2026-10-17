extends SceneTree

var game: Node2D
var output = OS.get_environment("HORDE_PREVIEW_OUTPUT")

func _initialize() -> void: call_deferred("run")

func capture(name: String) -> void:
	game.toast_left = 0;game.flash = 0;game.shake = 0
	await game.capture_frame(output + "/" + name + ".png")

func reset_scene(count: int = 36) -> void:
	game.data.tutorial_complete = true;game.start_run()
	var r = game.runner
	r.entities.clear();r.physics_surfaces.clear();r.tunnels.clear();r.events.clear()
	r.next_segment = 99999;r.elapsed = 10;r.speed = 305;r.cruise_speed = 305
	while r.members.size() < count: r.add_member(0, false)
	for i in range(r.members.size()):
		var m = r.members[i];m.x = r.slot_x(i);m.arrival = 0.0;m.y = 574.0;m.vy = 0.0
	game.ui_time = 4.2;game.effects.clear();game.ui_effects.clear()

func run() -> void:
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.capture_mode = true;game.capture_freeze = true;game.test_mode = true
	game.set_physics_process(false);game.set_process(false);game.sound.set_enabled(false)
	var legacy = game.validate_save({"version": 6, "runs": 4, "wallet": 987, "best": 42})
	assert(legacy.tutorial_complete and legacy.wallet == 987 and legacy.runs == 4)
	game.data = MonsterCatalog.defaults();game.start_run()
	assert(game.runner.tutorial_hints() and game.data.tutorial_complete)
	var saved = output + "/tutorial-save.json"
	assert(game.save_game(saved));game.data = game.read_save(saved);game.start_run()
	assert(not game.runner.tutorial_hints())
	reset_scene()
	var r = game.runner
	var slab = r.add_entity("collapse", 540, 574, 0, 225);slab.armed = true;slab.collapse_left = .25
	r.add_entity("gap", 840, 574, 0, 235)
	r.add_entity("air_bomb", 1135, 430, 0, HordeTuning.BOMB_WIDTH)
	r.tutorial_enabled = true;r.elapsed = 2
	await capture("01-first-play-tutorial")
	r.tutorial_enabled = false;r.elapsed = 10
	await capture("02-normal-no-instructions")
	slab.collapsed = true;slab.collapse_at = r.elapsed - .25
	r.speech_text = "NÃO ME TRANSFORMEM!";r.speech_left = 2;r.speech_npc = 0
	await capture("03-falling-floor-dialogue")
	reset_scene(46);r = game.runner
	var car = r.add_entity("car", 850, 574)
	car.reinforced = true;car.required_count = 55
	r.add_entity("helicopter", 1085, 300)
	r.jump()
	for i in range(18): r.advance(1.0 / 60, true)
	await capture("04-jump-wave-armored-vehicle")
	game.change_screen("developer")
	await capture("05-developer-controls")
	game.start_lab("collapse");assert(not game.runner.tutorial_hints())
	print("V810_UI_OK: first-play save/migration, normal warning removal, falling debris, dialogue, jump wave and developer controls")
	game.queue_free();await process_frame;quit()
