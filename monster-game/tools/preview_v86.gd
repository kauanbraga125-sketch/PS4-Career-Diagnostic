extends SceneTree

var game: Node2D
var output = OS.get_environment("HORDE_PREVIEW_OUTPUT")

func _initialize() -> void: call_deferred("run")

func scene(count: int) -> void:
	game.data = MonsterCatalog.defaults()
	game.preview_course(0, count)
	game.runner.tunnels.clear()
	game.runner.terrain.segments.assign([{"start": -1e12, "end": 1e12, "height": 0.0, "state": 0}])
	for i in range(game.runner.members.size()): game.runner.members[i].x = game.runner.slot_x(i)
	game.camera_zoom = game.CAMERA_BASE_ZOOM;game.camera_ground_shift = 0
	game.scenery.reset();game.scenery.update(0.1, game.runner)
	game.ui_time = 3.1;game.toast_left = 0;game.flash = 0;game.shake = 0

func vehicle(kind: String, x: float) -> Dictionary:
	var e = game.runner.add_entity(kind, x)
	e.passengers.clear()
	for i in range(int(MonsterCatalog.VEHICLES[kind].rescues)): e.passengers.append(i % 3)
	return e

func capture(name: String) -> void:
	await game.capture_frame(output + "/" + name + ".png")

func run() -> void:
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.capture_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.set_process(false);game.sound.set_enabled(false)
	scene(6);vehicle("moto", 560);vehicle("car", 900)
	await capture("01-moto-carro")
	scene(12);vehicle("bus", 600);vehicle("truck", 1090)
	await capture("02-onibus-caminhao")
	scene(20);vehicle("plane", 850)
	await capture("03-aviao")
	scene(20);vehicle("tank", 780)
	await capture("04-tanque")
	scene(60);game.runner.speed = 360
	for i in range(7): game.runner.add_entity("coin", 630 + i * 68, HordeRun.FLOOR - 48)
	for tick in range(90): game.update_camera(1.0 / 60)
	assert(is_equal_approx(game.camera_zoom, game.CAMERA_BASE_ZOOM), "large horde changed grounded camera zoom")
	assert(game.camera_ground_shift == 0, "large horde shifted ground")
	await capture("05-horda-60")
	game.runner.entities.clear()
	game.runner.jump()
	for tick in range(40): game.runner.advance(1.0 / 60, true);game.update_camera(1.0 / 60)
	await capture("06-pulo-longo")
	game.change_screen("pause");await capture("07-pausa")
	print("PREVIEW_V86_OK: real Godot renderer; 6 vehicles with passengers, 60-member camera, held jump, pause")
	game.queue_free();await process_frame;quit()
