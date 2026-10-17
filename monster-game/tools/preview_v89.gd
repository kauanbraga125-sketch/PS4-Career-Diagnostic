extends SceneTree
var game: Node2D
var output = OS.get_environment("HORDE_PREVIEW_OUTPUT")
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	game.toast_left = 0;game.flash = 0;game.shake = 0
	await game.capture_frame(output + "/" + name + ".png")
func reset_course(count: int = 36) -> void:
	game.start_lab("combined");game.runner.entities.clear();game.runner.physics_surfaces.clear()
	game.runner.next_segment = 99999;game.effects.clear();game.ui_effects.clear()
	for m in game.runner.members: m.arrival = 0.0;m.y = 574.0;m.vy = 0.0
	game.runner.elapsed = 4;game.ui_time = 4.2;game.lab_hitboxes = false
func run() -> void:
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.capture_mode = true;game.capture_freeze = true;game.test_mode = true
	game.set_physics_process(false);game.set_process(false);game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 99999
	game.change_screen("developer");await capture("01-developer")
	game.perform_action("lab_kind_npcs");await capture("02-civil-idle")
	game.sprite_state = 1;game.sprite_clock = .48;await capture("03-civil-run")
	game.sprite_state = 4;game.sprite_clock = .7;await capture("04-civil-capture")
	game.perform_action("back")
	game.start_run();game.change_screen("pause");game.settings_from = "pause"
	var original = game.runner;var before = game.data.duplicate(true)
	game.start_lab("mixed");game.runner.add_entity("coin",340,526)
	game.runner.advance(1.0/60,false);game.consume_run_events();game.check_challenges()
	assert(game.data == before,"developer changed progression")
	var path = output + "/must-not-save.json";game.save_game(path)
	assert(not FileAccess.file_exists(path),"developer saved progression")
	game.leave_lab();assert(game.runner == original and game.data == before,"restored paused game")
	reset_course()
	var civil = game.runner.add_entity("civilian",640,574,0);civil.civil_clip = "corrida";civil.civil_time = .48;civil.civil_flip = false
	game.runner.add_entity("civilian",850,574,1);game.runner.add_entity("civilian",960,574,2)
	game.runner.speech_text = "NÃO ME TRANSFORMEM!";game.runner.speech_left = 2;game.runner.speech_npc = 4
	await capture("05-civil-gameplay-dialogue")
	reset_course()
	var slab = game.runner.add_entity("collapse",510,574,0,220);slab.armed = true;slab.collapse_left = .25
	game.runner.add_entity("gap",790,574,0,290)
	await capture("06-collapse-warning-pit")
	slab.collapsed = true;slab.collapse_at = game.runner.elapsed - .3
	await capture("07-collapse-debris")
	reset_course()
	var heli = game.runner.add_entity("helicopter",560,390);heli.vx = 0
	var bus = game.runner.add_entity("bus",960,574)
	var m = game.runner.members[0];m.x = heli.x;m.y = HordeBalance.surface(heli).position.y;m.surface_y = m.y;m.roof_id = heli.id
	game.lab_hitboxes = true
	await capture("08-roof-guides")
	reset_course()
	for x in [580.0,644.0,708.0]:
		game.runner.add_entity("bomb",x,574,0,HordeTuning.BOMB_WIDTH)
		game.runner.add_entity("air_bomb",x,289,0,HordeTuning.BOMB_WIDTH)
	game.runner.add_entity("car",1010,574,-89)
	game.runner.generation_started = false
	HordeCourse.create_formation(game.runner,820,game.runner.speed,0,8)
	await capture("09-bombs-coins-traffic")
	reset_course()
	game.runner.generation_started = false
	HordeCourse.create_formation(game.runner,520,305,7,7)
	HordeCourse.create_formation(game.runner,900,305,8,8)
	await capture("13-coin-formations")
	reset_course()
	var plane = game.runner.add_entity("plane",780,574)
	var top = game.runner.members[0];top.x = 780;top.y = HordeBalance.surface(plane).position.y;top.surface_y = top.y;top.roof_id = plane.id
	game.lab_hitboxes = true;await capture("14-plane-roof")
	reset_course()
	game.runner.terrain.segments.assign([{"start":-100000.0,"end":610.0,"height":0.0,"state":0},{"start":610.0,"end":870.0,"height":80.0,"state":1},{"start":870.0,"end":100000.0,"height":0.0,"state":2}])
	await capture("15-raised-ground")
	game.leave_lab();game.data = MonsterCatalog.defaults();game.data.wallet = 99999
	game.open_market(0);game.market.scroll = 400
	await capture("10-frenzy-upgrade")
	assert(game.buy_upgrade(4) and game.data.levels.frenzy == 1,"frenzy upgrade purchase")
	var restored = game.validate_save(game.data.duplicate(true));assert(restored.levels.frenzy == 1,"frenzy save migration")
	game.start_lab("powers");game.perform_action("lab_power_boost");await capture("11-power-lab")
	game.change_screen("developer");root.size = Vector2i(1600,720);game.configure_layout();await capture("12-developer-wide")
	print("V89_UI_OK: rendered gameplay, blue sprite states, debris, roof guides, upgrade purchase/save and isolated lab")
	game.queue_free();await process_frame;quit()
