extends SceneTree
var game: Node2D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.capture_mode = true;game.capture_freeze = true;game.test_mode = true
	game.set_physics_process(false);game.set_process(false);game.sound.set_enabled(false)
	game.start_lab("collision");game.runner.entities.clear();game.runner.physics_surfaces.clear();game.runner.physics_gaps.clear();game.effects.clear();game.ui_effects.clear();game.toast_left = 0
	for m in game.runner.members:m.arrival = 0.0
	var plane = game.runner.add_entity("plane",780,574)
	var top = game.runner.members[0];top.x = 780;top.y = HordeBalance.surface(plane).position.y;top.surface_y = top.y;top.roof_id = plane.id
	await game.capture_frame(OS.get_environment("HORDE_PREVIEW_OUTPUT") + "/14-plane-roof.png")
	game.runner.entities.clear();game.runner.physics_surfaces.clear();top.x = 340;top.y = 574;top.vy = 0;top.roof_id = -1
	var civil = game.runner.add_entity("civilian",380,574,0);civil.civil_clip = "corrida";civil.civil_time = .02;civil.civil_flip = false
	game.runner.begin_capture(civil,top);game.runner.update_civilians(.24)
	game.lab_hitboxes = false;game.toast_left = 0
	await game.capture_frame(OS.get_environment("HORDE_PREVIEW_OUTPUT") + "/16-civil-runtime-capture.png")
	print("V89_ROOF_CAPTURE_OK")
	game.queue_free();await process_frame;quit()
