extends SceneTree
var game: Node2D
var output = OS.get_environment("HORDE_PREVIEW_OUTPUT")
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await game.capture_frame(output + "/" + name + ".png")
func run() -> void:
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.capture_mode = true;game.capture_freeze = true;game.test_mode = true
	game.set_physics_process(false);game.set_process(false);game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 1234;game.data.mission_progress = {"coins":5}
	game.start_run();game.last_stats = {"coins":12,"souls":3};game.change_screen("pause")
	var original = game.runner;var original_stats = game.last_stats.duplicate(true)
	game.settings_from = "pause";game.change_screen("settings");await capture("01-settings")
	game.perform_action("developer");await capture("02-developer")
	var before = game.data.duplicate(true)
	game.start_lab("mixed");game.runner.add_entity("coin",340,HordeRun.FLOOR-48)
	game.runner.advance(1.0/60,false);game.consume_run_events();game.check_challenges()
	var vehicle = game.runner.add_entity("tank",700);game.runner.flip_vehicle(vehicle)
	game.consume_run_events();game.check_challenges()
	assert(game.data == before,"developer changed progression")
	var save = output + "/must-not-save.json"
	game.save_game(save);assert(not FileAccess.file_exists(save),"developer wrote save")
	game.runner.entities.clear();game.effects.clear();game.ui_effects.clear();game.runner.next_segment = 99999;game.toast_left = 0
	for x in [620.0,684.0,748.0]:
		var e = game.runner.add_entity("bomb",x);e.width = HordeTuning.BOMB_WIDTH
		var a = game.runner.add_entity("air_bomb",x,HordeRun.FLOOR-285,0,HordeTuning.BOMB_WIDTH);a.vx=0;a.cluster_first=x==620
	game.ui_time = 3.2;await capture("03-mixed-bombs")
	game.runner.entities.clear()
	for mode in [7,8]:
		game.runner.generation_started=false
		HordeCourse.create_formation(game.runner,470 if mode==7 else 900,305,mode,mode)
	game.ui_time = 1.1;await capture("04-coin-geometries")
	game.runner.entities.clear();var collapse = game.runner.add_entity("collapse",650,574,0,210)
	collapse.armed=true;collapse.collapse_left=.3
	await capture("05-collapse-warning")
	collapse.collapsed=true;await capture("06-collapse-open")
	game.runner.entities.clear();var car=game.runner.add_entity("car",430)
	var m = game.runner.members[0];m.y=car.y-car.collision;m.roof_id=car.id;m.surface_y=m.y;m.vy=0;m.air_pose=0
	await capture("07-car-roof")
	game.change_screen("developer");game.perform_action("back")
	assert(not game.lab_active and game.runner == original and game.data==before and game.last_stats==original_stats,"developer failed to restore paused run")
	assert(game.settings_from=="pause","developer lost return destination")
	root.size=Vector2i(1600,720);game.change_screen("developer");await capture("08-developer-wide")
	root.size=Vector2i(1280,960);game.change_screen("developer");await capture("09-developer-tablet")
	print("V88_UI_OK: developer no wallet/mission/save writes; paused run restored; real renderer at 16:9, wide and tablet")
	game.queue_free();await process_frame;quit()
