extends Node2D

const SAVE_PATH = "user://noite-da-horda.json"
const CREAM = Color("fff1d3")
const GOLD = Color("ffc66a")
const MINT = Color("9ce4c7")
const PLUM = Color("35213f")
const CORAL = Color("ee917e")
const CAMERA_BASE_ZOOM = 1.32 / 0.95
const CAMERA_TRANSFORM_ZOOM = 1.42 / 0.95
const CAMERA_ANCHOR = Vector2(360, 610)
const CAMERA_MIN_ZOOM = 0.90 / 0.95

var art = HordeArt.new()
var actor = HordeActor.new(art)
var scenery = HordeScene.new(art, actor)
var effects = HordeEffects.new()
var last_stats: Dictionary = {}
var trail_tick = 0.0
var voice_tick = 0.0
var reward_rng = RandomNumberGenerator.new()
var run_settled = false
var run_report: Dictionary = {}
var result_time = 0.0
var result_level = 1
var ritual_view: Dictionary = {}
var ritual_time = 4.0
var ritual_particle_tick = 0.0
var ritual_reward_played = false
var coin_pulse = 0.0
var sound: HordeSound
var runner = HordeRun.new()
var data: Dictionary = MonsterCatalog.defaults()
var screen = "home"
var ui_time = 0.0
var buttons: Array[Dictionary] = []
var jump_held = false
var jump_touches: Dictionary = {}
var toast = ""
var toast_left = 0.0
var shake = 0.0
var flash = 0.0
var end_delay = -1.0
var last_save = 0.0
var run_challenges: Array[String] = []
var previous_page = "home"
var test_mode = false
var capture_mode = false
var capture_freeze = false
var pressed_button = ""
var paint_target: Node2D
var world_canvas: Node2D
var layout_origin = Vector2.ZERO
var camera_zoom = CAMERA_BASE_ZOOM
var ui_effects = HordeEffects.new()
var selected_power = 3
var home_menu = HordeHomeMenu.new()
var market = HordeMarket.new()
var settings_from = "home"
var slider_channel = ""
var camera_focus = 0.0
var camera_ground_shift = 0.0
var frozen_world_time = 0.0
var foreground_canvas: Node2D
var market_clip: Control
var market_canvas: Node2D
var views = HordeViews.new()
var gameplay_ui = HordeGameplayUI.new()
var pages = HordePages.new()
var credits_from = "help"
var result_full_flash = 0.0
var market_touch = -999
var market_touch_start = Vector2.ZERO
var market_touch_last = Vector2.ZERO
var market_touch_moved = false
var market_touch_action = ""
var lab_delay = HordeTuning.FOLLOWER_DELAY_STEP
var lab_hitboxes = false
var sprite_subject = 0
var sprite_state = 0
var sprite_npcs = false
var sprite_clock = 0.0
var sprite_paused = false
var crowd_drawn = 0
var lab_active = false
var lab_count = 36
var lab_stage = 3
var lab_kind = "bomb"
var lab_data: Dictionary = {}
var lab_context: Dictionary = {}
var lab_saved_runner: HordeRun
const LAB_KINDS = ["bomb", "air_bomb", "mixed", "gap", "collapse", "car", "helicopter", "tank", "convoy", "vehicles", "combined", "collision", "sprites", "npcs", "powers"]
const LAB_LABELS = ["BOMBAS TERRESTRES", "BOMBAS AÉREAS", "BOMBAS MISTAS", "BURACOS EM SEQUÊNCIA", "CHÃO QUE CAI", "TRÂNSITO HOSTIL", "HELICÓPTEROS", "TANQUES DO EXÉRCITO", "VEÍCULOS + HELICÓPTERO", "INFECÇÃO NOS VEÍCULOS", "DESAFIOS COMBINADOS", "COLISÕES E SUPERFÍCIES", "SPRITES DOS MONSTROS", "SPRITES DOS NPCs", "PODERES E PROTEÇÃO"]

func _ready() -> void :
	home_menu.attach(self)
	Engine.max_fps = 60
	paint_target = self
	world_canvas = Node2D.new();world_canvas.z_index = -1
	add_child(world_canvas);world_canvas.draw.connect(paint_world)
	foreground_canvas = Node2D.new();world_canvas.add_child(foreground_canvas);foreground_canvas.draw.connect(paint_foreground)
	var outline = ShaderMaterial.new();outline.shader = preload("res://scripts/foreground.gdshader");foreground_canvas.material = outline
	market_clip = Control.new();market_clip.z_index = 3;market_clip.position = Vector2(339, 179);market_clip.size = Vector2(853, 435)
	market_clip.clip_contents = true;market_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE;market_clip.visible = false;add_child(market_clip)
	market_canvas = Node2D.new();market_canvas.position = - market_clip.position;market_clip.add_child(market_canvas)
	market_canvas.draw.connect(paint_market_rows)
	configure_layout()
	reward_rng.randomize()
	test_mode = "--self-test" in OS.get_cmdline_user_args()
	capture_mode = "--sprite-preview" in OS.get_cmdline_user_args() or "--rig-preview" in OS.get_cmdline_user_args() or "--v7-preview" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--motion-preview" in OS.get_cmdline_user_args() or "--menu-preview" in OS.get_cmdline_user_args()
	if not test_mode and not capture_mode: data = read_save()
	sound = HordeSound.new()
	add_child(sound)
	sound.set_mix(data.audio_levels)
	sound.set_enabled(bool(data.audio))
	sound.set_music("moon_menu");sound.set_menu(true)
	if not test_mode and not capture_mode and int(data.active_souls) > 0:
		HordeProgress.settle(data, int(data.active_souls), reward_rng);save_game()
	if not test_mode and not capture_mode: begin_ritual()
	if test_mode: call_deferred("run_tests")
	elif "--sprite-preview" in OS.get_cmdline_user_args(): call_deferred("preview_sprite")
	elif "--rig-preview" in OS.get_cmdline_user_args(): call_deferred("preview_rig")
	elif "--v7-preview" in OS.get_cmdline_user_args(): call_deferred("preview_v7")
	elif "--menu-preview" in OS.get_cmdline_user_args(): call_deferred("capture_menu_preview")
	elif "--motion-preview" in OS.get_cmdline_user_args(): call_deferred("motion_preview")
	elif capture_mode: call_deferred("capture_preview")

func _process(dt: float) -> void :
	if screen == "sprite_lab" and not sprite_paused: sprite_clock += dt
	if screen == "run" and not capture_freeze:
		update_camera(dt)
	home_menu.set_visible(screen == "home" or (screen == "collection" and views.selected == 0))
	configure_layout()
	world_canvas.queue_redraw();foreground_canvas.queue_redraw()
	if capture_freeze:
		queue_redraw()
		return
	if not capture_freeze: ui_time += dt
	market.update(dt)
	market_clip.visible = screen == "market"
	if screen == "market": market_canvas.queue_redraw()
	toast_left = maxf(0, toast_left - dt)
	shake = maxf(0, shake - dt * 20)
	flash = maxf(0, flash - dt * 1.7)
	coin_pulse = maxf(0, coin_pulse - dt * 4)
	position = layout_origin + (Vector2(sin(ui_time * 83), cos(ui_time * 71)) * shake * 0.45 if screen == "run" else Vector2.ZERO)
	if screen == "run" and not capture_freeze: update_run_visuals(dt)
	if screen in ["home", "results"]: update_rewards(dt)
	if end_delay >= 0:
		end_delay -= dt
		if end_delay < 0: change_screen("developer" if lab_active else "results")
	queue_redraw()

func _physics_process(dt: float) -> void :
	if screen != "run" or capture_freeze: return
	runner.advance(dt, jump_held)
	consume_run_events()
	check_challenges()
	last_save += dt
	if last_save > 12:
		last_save = 0
		save_game()

func change_screen(next: String) -> void :
	market_touch = -999
	market_touch_action = ""
	if next in ["pause", "results"] and screen == "run": frozen_world_time = ui_time
	if next == "home": begin_ritual()
	if next == "results":
		result_time = 0;result_full_flash = 0;result_level = int(run_report.get("old_level", data.player_level))
		sound.set_jar(runner.souls > 0)
	else: sound.set_jar(false)
	screen = next
	home_menu.set_visible(next == "home" or (next == "collection" and views.selected == 0))
	market_clip.visible = next == "market"
	buttons.clear()
	pressed_button = ""
	jump_touches.clear()
	jump_held = false
	sound.set_music(("midnight_late" if runner.tunnel_number() >= 6 else "midnight_run") if next in ["run", "pause"] or (next == "settings" and settings_from == "pause") else "moon_menu")
	sound.set_menu(next == "home")
	sound.set_area(runner.area(), next == "run" and not runner.dead)
	sound.update_course(runner, next == "run" and not runner.dead)
	configure_layout();world_canvas.queue_redraw()
	queue_redraw()

func start_run() -> void :
	camera_focus = 0;camera_zoom = CAMERA_BASE_ZOOM;camera_ground_shift = 0
	run_settled = false;run_report = {};data.active_souls = 0
	runner.start(data.levels, 0, 0, data.areas, data.owned, data.power_owned, data.power_levels)
	runner.tutorial_enabled = not bool(data.tutorial_complete) and int(data.runs) == 0
	data.tutorial_complete = true
	save_game()
	effects.clear();ui_effects.clear()
	scenery.reset();voice_tick = 1.8
	run_challenges.clear()
	last_stats = {}
	trail_tick = 0
	end_delay = -1
	toast_left = 0
	last_save = 0
	change_screen("run")

func consume_run_events() -> void :
	for e in runner.drain_events():
		var point = Vector2(float(e.get("x", HordeRun.ANCHOR)), float(e.get("y", HordeRun.FLOOR)))
		match e.type:
			"coin":
				if not lab_active: data.wallet += int(e.amount)
				coin_pulse = 1
				sound.play("coin")
				effects.spark(point, GOLD, 5)
				ui_effects.pickup(world_to_ui(point), 1, gameplay_ui.counter_target(self, 3))
			"recruit":
				sound.play("recruit")
				if not runner.members.is_empty(): sound.play_monster(int(runner.members[-1].kind))
				effects.spark(point, MINT, 18)
				effects.ring(point, MINT)
			"capture":
				sound.play_monster(int(e.kind));effects.capture(point, int(e.kind))
			"soul":
				sound.play("soul_capture", -13);sound.play("recruit", -20);effects.ring(point, MINT)
				ui_effects.soul(world_to_ui(point), gameplay_ui.counter_target(self, 2))
				if not lab_active: data.active_souls = runner.souls
				save_game()
			"contact": sound.play("metal_push", -19);effects.dust(point, 4, 0.7)
			"glass": sound.play("glass_break", -17);effects.spark(point, MINT, 9)
			"surge_warning":
				if runner.tutorial_hints(): show_toast("A HORDA ACELERA!", 1.0)
			"power_warning": sound.play("power_warning", -8)
			"car_warning":
				sound.play("car_approach_" + str(randi_range(1, 2)), -15);sound.play("car_horn", -12)
			"air_warning":
				sound.play("ui_denied", -19)
				if runner.tutorial_hints(): show_toast("HELICÓPTERO À FRENTE", 1.2)
			"rush_crash":
				sound.play("car_crash", -10);shake = 7;effects.smash(point, "car", 0, e)
			"npc_voice": sound.play("police_stop" if e.npc == "police" else ("army_command" if e.npc == "soldier" else ("civil_female" if int(e.variant) == 1 else "civil_worker" if int(e.variant) == 2 else "civil_male")), -17)
			"transform":
				jump_touches.clear();jump_held = false;sound.play("transform_fly" if e.kind == 3 else "transform_mask", -12)
				effects.ring(point, MINT);effects.spark(point, Color("c39cf3"), 30)
			"revive":
				sound.play("revive", -12);effects.spark(point, MINT, 50);effects.ring(point, MINT);show_toast("ÚLTIMO SUSPIRO", 1.2)
			"weak_vehicle":
				if runner.tutorial_hints(): show_toast("FALTOU FORÇA: " + str(e.count) + " / " + str(e.need), 1.8)
			"tunnel_enter": sound.play("tunnel", -18)
			"tunnel_exit": sound.play("tunnel", -18)
			"jump":
				sound.play("jump")
				if point.y >= HordeRun.FLOOR - 4: effects.dust(point, 10, 1.2)
				effects.ring(point, MINT)
			"step": effects.dust(point, 2, 0.65)
			"land":
				sound.play("heavy_land" if runner.perk_kind == 2 else "land", -15)
				effects.dust(point, 8, 1.15)
			"wing": effects.spark(point, Color("c39cf3"), 8)
			"perk":
				sound.play("perk");flash = 0.25
				var color = Color("c39cf3") if e.kind == 3 else CORAL
				effects.spark(point, color, 35);effects.ring(point, color)
				effects.pickup(point, 0 if e.kind == 3 else 11, point + Vector2(25, -20))
				sound.play_monster(int(e.kind))

			"perk_end":
				sound.play("power_end", -12)
				effects.spark(point, Color("c39cf3"), 16)
				show_toast("Transformação terminou", 1.5)
			"boost":
				sound.play("perk");flash = 0.2
				effects.spark(point, GOLD, 30);effects.ring(point, GOLD)
				effects.pickup(point, 5, Vector2(HordeRun.ANCHOR, HordeRun.FLOOR - 70))
				show_toast("FRENESI! VELOCIDADE E MOEDAS EM DOBRO", 2.4)
			"guard":
				sound.play("guard")
				effects.spark(point, Color("8de5f0"), 20);effects.ring(point, Color("8de5f0"))
			"smash":
				sound.play("smash_" + str(e.get("object", "")) if MonsterCatalog.VEHICLES.has(str(e.get("object", ""))) else "smash", -12);shake = 6
				var object_kind = str(e.get("object", "crate"))
				effects.smash(point, object_kind, float(e.get("tilt", 0)), e)
				if MonsterCatalog.VEHICLES.has(object_kind):
					var rescued_count = int(e.get("rescued_count", MonsterCatalog.VEHICLES[object_kind].rescues))
					show_toast("VEÍCULO VIRADO!" + (" +" + str(rescued_count) + " ALMAS CONVERTIDAS" if rescued_count > 0 else ""), 1.7)
			"hit":
				sound.play("pit_fall" if str(e.get("cause", "")) == "fall" else "member_lost", -15)
				if str(e.get("cause", "")) not in ["fall", "camera"]: sound.play("hit", -17)
				shake = 5
				effects.death(int(e.kind), point)
			"shot": sound.play("gunshot", -17)
			"explosion": sound.play("explosion", -14);effects.explosion(point);shake = 8
			"tunnel": sound.play("tunnel", -18)
			"area":
				sound.set_area(int(e.area), true)
				show_toast(MonsterCatalog.AREAS[int(e.area)].name.to_upper(), 2.0)
			"recovery":
				if runner.tutorial_hints(): show_toast("REAGRUPE A HORDA! MAIS RECRUTAS À FRENTE", 2.2)
			"collapse_warning":
				sound.play("metal_push", -14)
				shake = maxf(shake, 2.7)
			"collapse":
				sound.play("glass_break", -12);effects.dust(point, 20, 1.5)
				shake = maxf(shake, 4.0)
			"finish": finish_run()

func finish_run() -> void :
	if lab_active:
		if end_delay < 0: end_delay = 1.0;sound.play("finish")
		return
	if run_settled or end_delay >= 0 or screen not in ["run", "pause"]: return
	data.best = maxi(int(data.best), runner.distance())
	data.runs += 1
	run_settled = true
	run_report = HordeProgress.settle(data, runner.souls, reward_rng)
	end_delay = 1.0
	jump_held = false
	sound.play("finish")
	sound.set_area(0, false)
	save_game()

func check_challenges() -> void :
	if lab_active: return
	var values = runner.stats()
	var all_complete = true
	for challenge in MonsterCatalog.active_missions(int(data.mission_tier)):
		if challenge.key in data.claimed: continue
		var current = int(values.get(challenge.stat, 0))
		var progress = int(data.mission_progress.get(challenge.id, 0))
		if challenge.mode == "sum":
			progress += maxi(0, current - int(last_stats.get(challenge.stat, 0)))
		else: progress = maxi(progress, current)
		data.mission_progress[challenge.id] = mini(progress, int(challenge.target))
		if progress >= int(challenge.target):
			data.claimed.append(challenge.key)
			HordeProgress.queue_mission(data, challenge)
			data.missions_completed += 1
			run_challenges.append(challenge.title)
			sound.play("challenge")
			show_toast("MISSÃO CONCLUÍDA  +" + str(challenge.ritual) + " PARA O RITUAL", 2.5)
			save_game()
		else: all_complete = false
	last_stats = values.duplicate()
	if all_complete:
		data.mission_tier += 1
		data.claimed.clear();data.mission_progress.clear()
		show_toast("NOVAS MISSÕES! CAPÍTULO " + str(int(data.mission_tier) + 1), 2.5)
		save_game()

func buy_upgrade(index: int) -> bool:
	if index < 0 or index >= MonsterCatalog.UPGRADES.size(): return false
	var item = MonsterCatalog.UPGRADES[index]
	var level = int(data.levels[item.id])
	if level >= int(item.max): sound.play("ui_denied");show_toast("Esta melhoria já está no máximo.");return false
	var cost = MonsterCatalog.upgrade_cost(item, level)
	if int(data.wallet) < cost:
		sound.play("ui_denied");show_toast("Faltam " + str(cost - int(data.wallet)) + " moedas. Jogue mais uma corrida!")
		return false
	data.wallet -= cost
	data.levels[item.id] = level + 1
	sound.play("buy")
	show_toast("Melhoria comprada! Nível " + str(level + 1), 2)
	save_game()
	return true

func open_market(tab: int = 0) -> void :
	previous_page = "results" if screen == "results" else ("collection" if screen == "collection" else "home")
	market.open(tab);change_screen("market")

func perform_action(action: String) -> void :
	if action.begins_with("lab_kind_"):
		var kind = action.trim_prefix("lab_kind_")
		if kind in ["sprites", "npcs"]:
			sprite_npcs = kind == "npcs";sprite_clock = 0;sprite_subject = 0;sprite_state = 0;change_screen("sprite_lab")
		else: start_lab(kind)
		return
	if action == "sprite_subject": sprite_subject = (sprite_subject + 1) % (5 if sprite_npcs else 4);sprite_clock = 0;return
	if action == "sprite_state": sprite_state = (sprite_state + 1) % 7;sprite_clock = 0;return
	if action == "sprite_pause": sprite_paused = not sprite_paused;return
	if action == "back" and screen == "sprite_lab": change_screen("developer");return
	if action == "lab_delay":
		var values = [0.0, 0.004, 0.008, 0.012, 0.016];lab_delay = values[(values.find(lab_delay) + 1) % values.size()];return
	if action == "lab_hitboxes": lab_hitboxes = not lab_hitboxes;return
	if lab_active and action.begins_with("lab_power_"):
		var kind = action.trim_prefix("lab_power_")
		if kind == "upgrade": runner.levels.frenzy = 1 - int(runner.levels.get("frenzy", 0))
		elif kind == "boost": runner.perk_left = 0;runner.perk_kind = -1;runner.boost_left = HordeTuning.BOOST_SECONDS;runner.boost_warning_tick = 4
		else:
			runner.boost_left = 0;runner.activate_perk(3 if kind == "fly" else 2)
		return
	if action == "lab_count":
		var values = [1, 16, 36, 56, 88];lab_count = values[(values.find(lab_count) + 1) % values.size()];return
	if action == "lab_stage":
		var values = [0, 3, 6, 8, 12];lab_stage = values[(values.find(lab_stage) + 1) % values.size()];return
	if action == "developer": change_screen("developer");return
	if action == "back" and screen == "developer":
		leave_lab();change_screen("settings");return
	if lab_active and action == "retry": start_lab(lab_kind);return
	if lab_active and action == "home": end_delay = -1;change_screen("developer");return
	if action.begins_with("collection_select_"):
		views.selected = clampi(int(action.trim_prefix("collection_select_")), 0, 1);sound.play("ui_confirm");return
	if not action.begins_with("buy_") and not action.begins_with("skin_") and not action.begins_with("area_") and not action.begins_with("power_buy_") and not action.begins_with("power_upgrade_"):
		sound.play("ui_back" if action in ["back", "home"] else "ui_confirm")
	if action.begins_with("market_tab_"): market.open(int(action.trim_prefix("market_tab_")));return
	if action.begins_with("market_select_"): market.select(action.trim_prefix("market_select_"));return
	if action == "market_next" or action == "market_prev":
		market.page += 1 if action == "market_next" else -1;market.selected = "";market.expanded.clear();return
	if action.begins_with("mix_plus_"): adjust_mix(action.trim_prefix("mix_plus_"), 0.1);return
	if action.begins_with("mix_minus_"): adjust_mix(action.trim_prefix("mix_minus_"), - 0.1);return
	if action.begins_with("buy_"): buy_upgrade(int(action.trim_prefix("buy_")));return
	if action.begins_with("skin_"): buy_skin(int(action.trim_prefix("skin_")));return
	if action.begins_with("power_buy_"): buy_power(int(action.trim_prefix("power_buy_")));return
	if action.begins_with("power_upgrade_"): buy_power_upgrade(int(action.trim_prefix("power_upgrade_")));return
	if action.begins_with("power_tab_"): selected_power = int(action.trim_prefix("power_tab_"));open_market(2);return
	if action.begins_with("area_"): buy_area(int(action.trim_prefix("area_")));return
	match action:
		"play": start_run()
		"market", "shop": open_market(0)
		"monsters", "market_monsters": open_market(1)
		"powers": open_market(2)
		"worlds": open_market(3)
		"collection": change_screen("collection")
		"missions": change_screen("missions")
		"help": change_screen("help")
		"credits":
			credits_from = screen;change_screen("credits")
		"settings":
			settings_from = "pause" if screen in ["run", "pause"] else screen
			change_screen("settings")
		"retry":
			if screen in ["run", "pause"] and not runner.dead: runner.finish();consume_run_events()
			end_delay = -1;start_run()
		"home":
			if screen in ["run", "pause"] and not runner.dead: runner.finish();consume_run_events();end_delay = -1
			change_screen("home")
		"back": change_screen(settings_from if screen == "settings" else (credits_from if screen == "credits" else (previous_page if screen == "market" else "home")))
		"pause": if screen == "run": change_screen("pause")
		"resume": if screen == "pause": change_screen("run")
		"audio":
			data.audio = not bool(data.audio);sound.set_enabled(bool(data.audio));save_game()

func press_at(point: Vector2, touch_id: int = -1) -> void :
	for i in range(buttons.size() - 1, -1, -1):
		var button = buttons[i]
		if button.rect.has_point(point):
			pressed_button = button.action
			if str(button.action).begins_with("mix_slider_"):
				slider_channel = str(button.action).trim_prefix("mix_slider_");update_slider(point);return
			if button.action == "jump":
				jump_touches[touch_id] = true
				jump_held = true
				runner.jump()
			else: perform_action(button.action)
			return
	if screen == "run" and not runner.dead:
		jump_touches[touch_id] = true
		jump_held = true
		runner.jump()

func release_touch(id: int) -> void :
	if not slider_channel.is_empty(): slider_channel = "";save_game()
	jump_touches.erase(id)
	jump_held = not jump_touches.is_empty()
	if not jump_held: runner.release_jump()
	pressed_button = ""

func begin_market_touch(point: Vector2, id: int) -> void:
	if market_touch != -999: return
	market_touch = id
	market_touch_start = point
	market_touch_last = point
	market_touch_moved = false
	market_touch_action = market.action_at(self,point)
	pressed_button = market_touch_action

func move_market_touch(point: Vector2,id: int) -> void:
	if id != market_touch: return
	if point.distance_to(market_touch_start)>12: market_touch_moved = true
	if market_touch_moved:
		pressed_button = ""
		if market.layout(full_rect()).grid.has_point(market_touch_start):
			market.scroll_by(market_touch_last.y-point.y)
	market_touch_last = point

func end_market_touch(point: Vector2,id: int) -> void:
	if id != market_touch: return
	var action = market_touch_action
	var activate = not market_touch_moved and not action.is_empty() and market.action_at(self,point)==action
	market_touch = -999
	market_touch_action = ""
	if activate: press_at(point,id)
	release_touch(id)

func _input(event: InputEvent) -> void :
	if screen == "market":
		if event is InputEventScreenDrag:
			move_market_touch(to_local(event.position),event.index);return
		if event is InputEventScreenTouch:
			if event.pressed: begin_market_touch(to_local(event.position),event.index)
			else: end_market_touch(to_local(event.position),event.index)
			return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: begin_market_touch(to_local(event.position),-1)
			else: end_market_touch(to_local(event.position),-1)
			return
		if event is InputEventMouseMotion and market_touch==-1:
			move_market_touch(to_local(event.position),-1);return
	if event is InputEventScreenDrag and screen == "settings" and not slider_channel.is_empty(): update_slider(to_local(event.position));return
	if event is InputEventMouseMotion and screen == "settings" and not slider_channel.is_empty(): update_slider(to_local(event.position));return
	if event is InputEventMouseButton and screen == "market" and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		market.scroll_by(92 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -92);return
	if event is InputEventScreenTouch:
		if event.pressed: press_at(to_local(event.position), event.index)
		else: release_touch(event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: press_at(to_local(event.position), -1)
		else: release_touch(-1)
	elif event is InputEventKey and not event.echo:
		if event.keycode == KEY_SPACE:
			if event.pressed and screen == "run" and runner.transform_left <= 0: jump_touches[-2] = true;jump_held = true;runner.jump()
			elif not event.pressed: release_touch(-2)
		elif event.pressed and event.keycode in [KEY_ESCAPE, KEY_BACK]:
			if screen == "run": perform_action("pause")
			elif screen == "pause": perform_action("resume")
			elif screen != "home": perform_action("back")

func burst(pos: Vector2, color: Color, count: int, glowing: bool = true) -> void :
	effects.spark(pos, color, count)

func show_toast(message: String, duration: float = 2.8) -> void :
	toast = message;toast_left = duration

func text(value: String, pos: Vector2, size: int = 22, color: Color = CREAM, heading: bool = false, center: bool = false, outline: int = 0) -> void :
	var font = art.title_font if heading else art.body_font
	var point = pos
	if center: point.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	if outline > 0: paint_target.draw_string_outline(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color("1c112b"))
	paint_target.draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func wrapped(value: String, pos: Vector2, width: float, size: int = 19, color: Color = CREAM, maximum: int = 4) -> void :
	var line = ""; var row = 0
	for word in value.split(" "):
		var candidate = line + word + " "
		if art.body_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and not line.is_empty():
			text(line, pos + Vector2(0, row * (size + 9)), size, color)
			row += 1;line = ""
			if row >= maximum: return
		line += word + " "
	if not line.is_empty(): text(line, pos + Vector2(0, row * (size + 9)), size, color)

func panel(rect: Rect2, color: Color, border: Color = Color("70496f"), radius: int = 20, border_size: int = 2, shadow: bool = true) -> void :
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(border_size)
	box.set_corner_radius_all(radius)
	if shadow:
		box.shadow_color = Color(0.04, 0.02, 0.09, 0.55)
		box.shadow_size = 4;box.shadow_offset = Vector2(0, 6)
	paint_target.draw_style_box(box, rect)

func button(rect: Rect2, label: String, action: String, color: Color = Color("825aab"), icon: int = -2, size: int = 25) -> void :
	var pressed = pressed_button == action
	var face = rect
	if pressed: face.position.y += 3
	panel(face, color.lightened(0.06) if pressed else color, color.lightened(0.28), 18, 3)
	paint_target.draw_line(face.position + Vector2(20, 8), face.position + Vector2(face.size.x - 20, 8), Color(1, 1, 1, 0.13), 3, true)
	var offset = 18.0 if icon >= 0 else 0.0
	if icon >= 0: item_sprite(icon, Vector2(face.position.x + 36, face.get_center().y), 42)
	text(label, face.get_center() + Vector2(offset, size * 0.37), size, CREAM, true, true, 2)
	buttons.append({"rect": rect.intersection(market.layout(full_rect()).grid) if paint_target == market_canvas else rect, "action": action})

func item_sprite(index: int, centre: Vector2, height: float, modulate: Color = Color.WHITE) -> void :
	var texture = art.items[clampi(index, 0, art.items.size() - 1)]
	var size = texture.get_size()
	var draw_size = size * (height / size.y)
	paint_target.draw_texture_rect(texture, Rect2(centre - draw_size * 0.5, draw_size), false, modulate)

func creature(kind: int, frame: int, foot: Vector2, height: float, shadow: bool = true, modulate: Color = Color.WHITE) -> void :
	if shadow:
		paint_target.draw_set_transform(Vector2(foot.x, HordeRun.FLOOR + 4), 0, Vector2(height * 0.22, 4))
		paint_target.draw_circle(Vector2.ZERO, 1, Color(0.02, 0.01, 0.05, 0.25))
		paint_target.draw_set_transform(Vector2.ZERO)
	var state = "idle" if frame == 0 else ("rise" if frame == 5 else "run")
	actor.paint(paint_target, kind, foot, height, ui_time * 1.35, state, ui_time, 0, modulate)

func currency() -> void :
	panel(Rect2(1000, 32, 236, 62), Color(0.14, 0.09, 0.2, 0.9), Color("976b65"), 26)
	floating_item(1, Vector2(1038, 62 + sin(ui_time * 3) * 2), 38)
	text(str(data.wallet), Vector2(1070, 77), 31, GOLD, true, false, 2)

func backdrop() -> void :
	if screen in ["run", "pause", "results"]:
		scenery.paint(paint_target, runner, ui_time)
	elif screen in ["home", "market"]:
		home_menu.backdrop(self, full_rect())
	else:
		paint_target.draw_texture_rect(art.background, full_rect().grow(12), false)
	for i in range(18):
		var x = fposmod(i * 83.0 + ui_time * (7 + i * 0.35) - runner.world_px * 0.1, 1340) - 30
		var y = 405 + sin(ui_time * 0.5 + i * 2.2) * 115
		paint_target.draw_circle(Vector2(x, y), 3.5, Color(0.75, 1, 0.85, 0.035))
		paint_target.draw_circle(Vector2(x, y), 1.3, Color(0.75, 1, 0.85, 0.2 + sin(ui_time * 2 + i) * 0.1))
	for i in range(3):
		var pos = Vector2(fposmod(ui_time * (25 + i * 6) + i * 440, 1460) - 90, 220 + sin(ui_time * 1.1 + i) * 35)
		var flap = sin(ui_time * 13 + i) * 7
		paint_target.draw_colored_polygon(PackedVector2Array([pos + Vector2(-13, flap), pos + Vector2(-6, -3), pos, pos + Vector2(6, -3), pos + Vector2(13, flap), pos + Vector2(5, 4), pos + Vector2(-5, 4)]), Color(0.11, 0.07, 0.2, 0.55))

func ground(offset: float = 0) -> void :
	gameplay_ui.ground(self, offset)

func _draw() -> void :
	paint_target = self;buttons.clear()
	if screen not in ["run", "pause", "results"]:
		backdrop();paint_target.draw_rect(full_rect(), Color(0.035, 0.012, 0.065, 0.045 if screen == "home" else (0.10 if screen == "market" else 0.18)))
	match screen:
		"home": draw_home()
		"market": market.paint(self)
		"collection": draw_collection()
		"settings": draw_settings()
		"developer": draw_developer()
		"sprite_lab": draw_sprite_lab()
		"shop": draw_shop()
		"powers": draw_powers()
		"monsters": draw_monsters()
		"worlds": draw_worlds()
		"missions": draw_missions()
		"help": draw_help()
		"credits": draw_credits()
		"run":
			draw_run_hud()
			if runner.transform_left > 0: draw_transformation_title()
		"pause": draw_pause()
		"results": draw_results()
	if flash > 0: paint_target.draw_rect(full_rect(), Color(0.62, 1, 0.83, flash * 0.25))
	ui_effects.paint(paint_target, art, actor)
	if toast_left > 0 and runner.transform_left <= 0:
		var width = clampf(art.body_font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 50, 320, 1130)
		panel(Rect2(640 - width * 0.5, 108, width, 48), Color(0.13, 0.08, 0.19, 0.96), Color("c2ab82"), 15)
		text(toast, Vector2(640, 138), 19, CREAM, false, true)

func draw_home() -> void :
	home_menu.paint(self)

func draw_shop() -> void :
	text("MELHORIAS DA HORDA", Vector2(67, 99), 39, GOLD, true, false, 5);currency()
	button(Rect2(68, 120, 218, 51), "HORDA", "shop", Color("8054a7"), -2, 21)
	button(Rect2(305, 120, 250, 51), "POWER-UPS", "powers", Color("487385"), -2, 21)
	for i in range(3):
		var item = MonsterCatalog.UPGRADES[i]; var x = 68 + i * 392; var level = int(data.levels[item.id])
		panel(Rect2(x, 197, 364, 343), Color(0.2, 0.12, 0.27, 0.94), Color("785682"), 23, 3)
		paint_target.draw_circle(Vector2(x + 182, 290), 73, Color(0.5, 0.33, 0.59, 0.32))
		if i == 0: actor.paint(paint_target, 0, Vector2(x + 180, 356), 128, ui_time * 1.3, "run", ui_time)
		else: floating_item(item.icon, Vector2(x + 182, 289), 115)
		text(item.name, Vector2(x + 182, 385), 23, CREAM, true, true, 2)
		for n in range(int(item.max)): paint_target.draw_circle(Vector2(x + 152 + n * 30, 414), 7, MINT if n < level else Color("665575"))
		wrapped(item.description, Vector2(x + 28, 459), 306, 19, Color("ded0e7"), 3)
		var full = level >= int(item.max)
		button(Rect2(x + 9, 562, 346, 67), "NO MÁXIMO" if full else str(MonsterCatalog.upgrade_cost(item, level)) + " MOEDAS", "buy_" + str(i), Color("6b7669") if full else Color("9670ba"), -2, 23)
	button(Rect2(68, 656, 218, 47), "VOLTAR", "back", Color("513c67"), -2, 20)

func draw_monsters() -> void :
	text("MONSTROS DA HORDA", Vector2(67, 99), 42, GOLD, true, false, 5);currency()
	for i in range(2):
		var x = 68 + i * 591; var owned = i in data.owned
		panel(Rect2(x, 159, 551, 454), Color(0.18, 0.11, 0.25, 0.95), MINT if owned else Color("76527d"), 22, 3)
		actor.paint(paint_target, i, Vector2(x + 145, 424), 190, ui_time * 1.25 + i * 0.4, "run" if owned else "idle", ui_time, 0, Color.WHITE if owned else Color(0.1, 0.06, 0.16, 1))
		if not owned: text("?", Vector2(x + 145, 341), 46, Color("bba4ce"), true, true, 3)
		text(MonsterCatalog.MONSTERS[i].name.to_upper(), Vector2(x + 281, 221), 29, MonsterCatalog.MONSTERS[i].color, true, true, 2)
		var note = "Seu primeiro monstro. Sempre disponível." if i == 0 else "Ao desbloquear, cada civil tem 30% de chance de virar um esqueleto."
		wrapped(note, Vector2(x + 279, 293), 240, 21, CREAM, 5)
		text("70% ZUMBI / 30% ESQUELETO" if 1 in data.owned else "CIVIS VIRAM ZUMBIS", Vector2(x + 275, 493), 19, MINT, true, true)
		button(Rect2(x + 30, 536, 491, 57), "NA HORDA" if owned else "LIBERAR • 1000 MOEDAS", "skin_" + str(i), Color("557d70") if owned else Color("8054a7"), -2, 22)
	button(Rect2(68, 647, 240, 59), "VOLTAR", "back", Color("513c67"), -2, 22)
	button(Rect2(939, 647, 270, 59), "POWER-UPS", "powers", Color("487385"), -2, 22)

func draw_help() -> void:
	pages.help(self)

func draw_run() -> void :
	ground(runner.world_px)
	effects.paint_wrecks(paint_target, art, ui_time, scenery.view_left)
	scenery.paint_front(paint_target, runner)
	effects.draw_trails(paint_target, actor, runner.elapsed)

	for e in runner.entities:
		if e.kind not in ["gap", "collapse"] or e.x + e.width < scenery.view_left or e.x > scenery.view_right: continue
		var floor_y = float(e.y)
		if e.kind == "collapse" and not e.get("collapsed", false):
			HordeTerrainArt.collapse(self, e);continue
		paint_target.draw_rect(Rect2(e.x, floor_y, e.width, scenery.view_bottom - floor_y), Color("080616"))
		HordeTerrainArt.pit_edge(self, float(e.x), floor_y, false)
		HordeTerrainArt.pit_edge(self, float(e.x) + float(e.width), floor_y, true)
		if e.kind == "collapse": HordeTerrainArt.collapse(self, e)
		if e.kind == "gap" and runner.tutorial_hints() and e.x > HordeRun.ANCHOR: text("SEGURE!" if e.get("long_jump", false) else "PULO!", Vector2(e.x + e.width * 0.5, floor_y - 28), 16, CORAL, true, true, 3)
	for e in runner.entities:
		if e.taken or e.x + float(e.width) * 0.5 < scenery.view_left - 100 or e.x - float(e.width) * 0.5 > scenery.view_right + 100: continue
		if e.kind in ["civilian", "soldier", "police"] and e.state == "capture": continue
		var bob = sin(ui_time * 4 + e.bob) * 5
		if MonsterCatalog.VEHICLES.has(e.kind):
			draw_vehicle(e)
			continue
		match e.kind:
			"coin": floating_item(1, Vector2(e.x, e.y + bob), HordeBalance.COIN_DIAMETER)
			"hump":
				var points = PackedVector2Array([Vector2(e.x - 60, HordeRun.FLOOR), Vector2(e.x - 44, HordeRun.FLOOR - 21), Vector2(e.x - 15, HordeRun.FLOOR - 61), Vector2(e.x + 20, HordeRun.FLOOR - 66), Vector2(e.x + 46, HordeRun.FLOOR - 28), Vector2(e.x + 60, HordeRun.FLOOR)])
				paint_target.draw_colored_polygon(points, Color("58465c"));paint_target.draw_polyline(points, Color("a9a38c"), 5, true)
			"civilian", "police": draw_civilian(e)
			"crystal", "mask", "shield", "boost":
				var icon = 0 if e.kind == "crystal" else (11 if e.kind == "mask" else (2 if e.kind == "shield" else 5))
				var centre = Vector2(e.x, e.y + bob)
				var color = GOLD if e.kind == "boost" else Color("c39cf3")
				paint_target.draw_circle(centre, 51 + sin(ui_time * 4) * 4, Color(color.r, color.g, color.b, 0.08))
				paint_target.draw_circle(centre, 36, Color(color.r, color.g, color.b, 0.12))
				for i in range(3):
					var angle = ui_time * 2.8 + i * TAU / 3
					paint_target.draw_circle(centre + Vector2(cos(angle) * 43, sin(angle) * 30), 3, color)
				if e.kind in ["crystal", "mask"]: scenery.sprite(paint_target, art.power(3 if e.kind == "crystal" else 2, ui_time), centre, 85, sin_color(e.kind), sin(ui_time * 2) * 0.035)
				else: floating_item(icon, centre, 70 * (1 + sin(ui_time * 3) * 0.04))
				text("FRENESI" if e.kind == "boost" else "BÔNUS", centre + Vector2(0, -57), 13, color, true, true, 2)
			"crate": item_sprite(6, Vector2(e.x, e.y - 36), 72)
			"spikes": item_sprite(8, Vector2(e.x, e.y - 24), 48)
			"bomb", "air_bomb":
				var aerial = e.kind == "air_bomb"
				var point = Vector2(e.x, e.y if aerial else e.y - HordeTuning.BOMB_HEIGHT * 0.5)
				scenery.sprite(paint_target, art.ritual[3] if aerial else art.props[0], point, 85.8 if aerial else HordeTuning.BOMB_HEIGHT, Color.WHITE, sin(ui_time * 7 + e.bob) * 0.07)
				draw_fuse(point + Vector2(9, -34 if aerial else -32), ui_time + e.bob)
				if runner.tutorial_hints() and aerial and e.get("cluster_first", true): text("PULE" if e.y > HordeRun.FLOOR - 130 else "POR BAIXO", point + Vector2(0, -52), 15, CORAL, true, true, 2)
			"soldier":
				if e.state == "capture": draw_civilian(e)
				else:
					actor.paint(paint_target, 5, Vector2(e.x, e.y), 108, 0, "aim", ui_time, 0, Color.WHITE, true)
					var muzzle = Vector2(e.x - 54, e.y - 64)
					if e.flash > 0: scenery.sprite(paint_target, art.props[5], muzzle, 28)
					if e.speech_left > 0: draw_speech(e, e.y - 128)
					if e.x > HordeRun.ANCHOR + 230:
						if runner.tutorial_hints() and e.timer < 0.65 and e.speech_left <= 0: text("TIRO!", Vector2(e.x, e.y - 130), 15, CORAL, true, true, 2)
						if e.timer < 0.65: paint_target.draw_line(muzzle, muzzle + Vector2(-120, float(e.get("aim_dy", 0))), Color(1, 0.4, 0.26, 0.18), 2, true)
			"bullet":
				paint_target.draw_line(Vector2(e.x + 31, e.y), Vector2(e.x, e.y), Color(1, 0.62, 0.22, 0.45), 4, true)
				paint_target.draw_circle(Vector2(e.x, e.y), 4, GOLD)
			"helicopter":
				scenery.helicopter(paint_target, Vector2(e.x, e.y), 185, ui_time, sin(ui_time * 2) * 0.06)
				if runner.tutorial_hints(): text("PULE!" if e.y > HordeRun.FLOOR - 180 else "POR BAIXO", Vector2(e.x, e.y - 125), 16, CORAL, true, true, 2)
	var visible = HordeCrowdVisibility.visible(runner)
	crowd_drawn = visible.size()
	for i in range(runner.members.size() - 1, -1, -1):
		if not visible.has(i): continue
		var member = runner.members[i]
		var kind = int(member.get("death_kind", member.kind)) if member.falling else (runner.perk_kind if runner.perk_left > 0 else int(member.kind))
		var state = animation_state(member)
		var foot = Vector2(runner.member_x(i), member.y - runner.member_depth(i))
		if state == "fly": foot.y += sin(runner.elapsed * 7 + i) * 3
		var height = 112.0 * (1 + sin(member.arrival / 0.35 * PI) * 0.1) * (1.4 if runner.perk_kind == 2 and runner.perk_left > 0 and int(runner.power_levels.get("mask_size", 0)) > 0 else 1)
		var phase = (0.62 - float(member.attack_left)) / 0.62 if state == "capture" else float(member.run_phase)
		if not member.falling:
			var shadow_size = clampf(1 - (runner.ground_y(member.x) - member.y) / 420, 0.25, 1)
			paint_target.draw_set_transform(Vector2(foot.x, float(member.get("surface_y", runner.ground_y(member.x))) + 4), 0, Vector2(23 * shadow_size, 4 * shadow_size))
			paint_target.draw_circle(Vector2.ZERO, 1, Color(0.02, 0.01, 0.05, 0.28 * shadow_size))
			paint_target.draw_set_transform(Vector2.ZERO)
			if runner.shields > 0: paint_target.draw_arc(foot - Vector2(0, 56), 62, 0, TAU, 32, Color(0.5, 0.9, 1, 0.4), 3, true)
		var blink = Color(1, 1, 1, 0.45) if runner.hit_grace > 0 and int(ui_time * 14) % 2 == 0 else Color.WHITE
		if runner.transform_left > 0:
			var progress = 1 - runner.transform_left / runner.transform_duration
			var blend = smoothstep(0.16 + i * 0.007, 0.84 + i * 0.006, progress)
			foot.y -= sin(progress * PI) * 22
			actor.paint(paint_target, runner.transform_from_kind if runner.transform_from_kind >= 0 else int(member.kind), foot, height, phase, "run", runner.elapsed, 0, Color(1, 1, 1, 1 - blend))
			actor.paint(paint_target, runner.transform_kind, foot, height * (0.9 + blend * 0.1), phase, "fly" if runner.transform_kind == 3 else "run", runner.elapsed, 0, Color(1, 1, 1, blend))
			scenery.sprite(paint_target, art.power(runner.transform_kind, ui_time), foot - Vector2(0, 56), height * 1.18, Color(1, 1, 1, sin(progress * PI) * 0.48), progress * 0.15)
			for j in range(3):
				var centre = foot - Vector2(0, 51)
				var a = ui_time * 6 + j * TAU / 3
				var bolt = PackedVector2Array()
				for k in range(5):
					var angle = a + k * 0.38
					bolt.append(centre + Vector2(cos(angle), sin(angle)) * (36 + (k % 2) * 15))
				paint_target.draw_polyline(bolt, Color(0.65, 1, 0.96, sin(progress * PI) * 0.9), 2.4, true)
		else: actor.paint(paint_target, kind, foot, height, phase, state, runner.elapsed + i * 0.071, float(member.land_left), blink, false, float(member.air_pose), true, float(member.air_time), float(member.vy))
	for e in runner.entities:
		if not e.taken and e.kind in ["civilian", "soldier", "police"] and e.state == "capture": draw_civilian(e)
	effects.paint(paint_target, art, actor)
	if lab_active and lab_hitboxes: draw_collision_guides()

func draw_run_hud() -> void :
	gameplay_ui.hud(self)

func draw_pause() -> void :
	views.pause(self)

func draw_results() -> void :
	views.results(self)

func saved_ids(value) -> Array[int]:
	# JSON decodes numbers as floats; array membership distinguishes 1 from 1.0.
	var ids: Array[int] = []
	if value is Array:
		for kind in value:
			if (kind is int or kind is float) and int(kind)==kind and int(kind) not in ids:
				ids.append(int(kind))
	return ids

func validate_save(value) -> Dictionary:
	if not value is Dictionary or int(value.get("version", 0)) not in [1, 2, 3, 4, 5, 6]: return MonsterCatalog.defaults()
	var result = MonsterCatalog.defaults()
	result.wallet = clampi(int(value.get("wallet", 120)), 0, 9999999)
	result.best = clampi(int(value.get("best", 0)), 0, 9999999)
	result.runs = maxi(0, int(value.get("runs", 0)))
	result.tutorial_complete = bool(value.get("tutorial_complete", result.runs > 0))
	result.audio = bool(value.get("audio", true))
	var mix = value.get("audio_levels", {})
	if mix is Dictionary:
		for channel in ["music", "effects", "voices"]: result.audio_levels[channel] = clampf(float(mix.get(channel, result.audio_levels[channel])), 0, 1)
	result.player_level = clampi(int(value.get("player_level", 1)), 1, 500)
	result.level_souls = clampi(int(value.get("level_souls", 0)), 0, HordeProgress.level_target(int(result.player_level)) - 1)
	for key in ["total_souls", "best_souls", "active_souls"]: result[key] = clampi(int(value.get(key, 0)), 0, 9999999)
	result.ritual_progress = clampi(int(value.get("ritual_progress", 0)), 0, 99)
	result.ritual_ready = bool(value.get("ritual_ready", false))
	var pending = value.get("ritual_pending", [])
	var pending_keys = {}
	if pending is Array:
		for item in pending.slice(0, 300):
			if not item is Dictionary: continue
			var key = str(item.get("key", ""))
			if key.is_empty() or key.length() > 60 or pending_keys.has(key): continue
			pending_keys[key] = true
			result.ritual_pending.append({"key": key, "title": str(item.get("title", "Missão")).left(120), "points": clampi(int(item.get("points", 0)), 1, 40)})
	var areas = value.get("areas", [])
	if areas is Array:
		for area in areas:
			if int(area) in [2, 3] and int(area) not in result.areas: result.areas.append(int(area))
	var raw_levels = value.get("levels", {})
	if raw_levels is Dictionary:
		for item in MonsterCatalog.UPGRADES: result.levels[item.id] = clampi(int(raw_levels.get(item.id, 0)), 0, int(item.max))
	var owned = saved_ids(value.get("owned", []))
	if owned is Array and 1 in owned: result.owned.append(1)
	result.skin = 0
	var power_owned = saved_ids(value.get("power_owned", []))
	if (power_owned is Array and 2 in power_owned) or (int(value.get("version", 0)) < 5 and owned is Array and 2 in owned): result.power_owned.append(2)
	var power_levels = value.get("power_levels", {})
	for item in MonsterCatalog.POWER_UPGRADES:
		var legacy = int(raw_levels.get("perk", 0)) if raw_levels is Dictionary and int(value.get("version", 0)) < 5 and item.id in ["fly_time", "mask_time"] else 0
		var extra = 1 if item.kind == 3 and owned is Array and 3 in owned and int(value.get("version", 0)) < 5 else 0
		result.power_levels[item.id] = clampi(int(power_levels.get(item.id, legacy + extra)) if power_levels is Dictionary else legacy + extra, 0, int(item.max))
	result.mission_tier = clampi(int(value.get("mission_tier", 0)), 0, 9999)
	result.missions_completed = clampi(int(value.get("missions_completed", 0)), 0, 99999)
	var claimed = value.get("claimed", [])
	if int(value.get("version", 0)) == 1:
		if claimed is Array:
			for challenge in MonsterCatalog.CHALLENGES:
				if challenge.id in claimed: result.claimed.append("0:" + str(challenge.id))
			result.missions_completed = result.claimed.size()
			if result.claimed.size() == 3: result.mission_tier = 1;result.claimed.clear()
	else:
		var progress = value.get("mission_progress", {})
		for challenge in MonsterCatalog.active_missions(result.mission_tier):
			if claimed is Array and challenge.key in claimed: result.claimed.append(challenge.key)
			if progress is Dictionary: result.mission_progress[challenge.id] = clampi(int(progress.get(challenge.id, 0)), 0, int(challenge.target))
			if challenge.key in result.claimed: result.mission_progress[challenge.id] = int(challenge.target)
	return result

func read_save(path: String = SAVE_PATH) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary and int(parsed.get("version", 0)) in [1, 2, 3, 4, 5, 6]: return validate_save(parsed)
	return MonsterCatalog.defaults()

func save_game(path: String = SAVE_PATH) -> bool:
	if lab_active: return true
	if (test_mode or capture_mode) and path == SAVE_PATH: return true
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data));file.flush();file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		if DirAccess.rename_absolute(path, path + ".bak") != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func _notification(what: int) -> void :
	if what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(sound):
		if screen == "run": change_screen("pause")
		save_game()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(sound):
		if screen == "run": perform_action("pause")
		elif screen == "pause": perform_action("resume")
		elif screen != "home": perform_action("back")
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(sound): save_game()

func run_tests() -> void :
	var suite = load("res://tests/self_test.gd").new()
	add_child(suite)
	await suite.run(self)

func capture_frame(path: String) -> void :
	configure_layout();world_canvas.queue_redraw();foreground_canvas.queue_redraw();queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	if not path.contains("/frame-"): print("HORDE_CAPTURE " + path)

func preview_course(world: float = 0, count: int = 4, kind: int = 0) -> void :
	data.levels.horde = 0;data.skin = kind
	start_run();capture_freeze = true
	runner.entities.clear();runner.events.clear();runner.next_segment = 99999
	runner.world_px = world;runner.speed = 350;runner.rng.seed = 4014
	while runner.active_count() < count: runner.add_member(runner.recruit_kind(), false)
	if kind != 0:
		for member in runner.members: member.kind = kind
	runner.update_tunnels();runner.events.clear()
	scenery.update(0.1, runner)

func preview_ticks(count: int, held: bool = false) -> void :
	for i in range(count):
		runner.advance(1.0 / 60, held);consume_run_events();update_run_visuals(1.0 / 60)
		check_challenges();ui_time += 1.0 / 60
	toast_left = 0;flash = 0;shake = 0

func preview_collect_souls(count: int) -> void :
	for i in range(count):
		var person = runner.add_entity("civilian", HordeRun.ANCHOR, HordeRun.FLOOR, i % 3)
		person.vx = 0;person.pose = "run";person.group = 999
		preview_ticks(45)
	for i in range(40): runner.add_entity("coin", HordeRun.ANCHOR, HordeRun.FLOOR - 48)
	preview_ticks(2)

func capture_preview() -> void :
	capture_freeze = true
	await get_tree().create_timer(0.4).timeout
	var path = OS.get_environment("HORDE_CAPTURE_PATH")
	if path.is_empty(): path = "user://NoiteDaHorda-menu.png"
	var base = path.get_basename().trim_suffix("-menu")
	await capture_frame(base + "-menu.png")
	perform_action("shop"); await capture_frame(base + "-shop.png")
	perform_action("monsters"); await capture_frame(base + "-monsters.png")
	perform_action("worlds"); await capture_frame(base + "-worlds.png")
	selected_power = 3;perform_action("powers"); await capture_frame(base + "-powers-fly.png")
	selected_power = 2; await capture_frame(base + "-powers-locked.png")
	data.wallet = 15000;buy_power(2)
	for i in range(1, 6): buy_power_upgrade(i)
	toast_left = 0
	await capture_frame(base + "-powers-mask.png")
	data = MonsterCatalog.defaults()
	preview_course(1100, 4)
	for i in range(3): runner.add_entity("civilian", 620 + i * 110, HordeRun.FLOOR, i)
	runner.add_entity("bomb", 970);runner.add_entity("air_bomb", 1140, HordeRun.FLOOR - 190)
	for i in range(6): runner.add_entity("coin", 540 + i * 76, HordeRun.FLOOR - 155)
	runner.jump();preview_ticks(11, true)
	await capture_frame(base + "-run.png")
	perform_action("pause"); await capture_frame(base + "-pause.png")
	ui_time += 0.16; await capture_frame(base + "-pause-animated.png");perform_action("resume")
	for kind in range(4):
		preview_course(0, 1, kind)
		var npc = runner.add_entity("civilian", HordeRun.ANCHOR + 7, HordeRun.FLOOR, kind % 3);npc.vx = 0;npc.pose = "run"
		preview_ticks(14)
		await capture_frame(base + "-capture-" + ["zombie", "skeleton", "masked", "fly"][kind] + ".png")
	preview_course(22300, 4)
	runner.add_entity("police", 660);runner.add_entity("civilian", 850, HordeRun.FLOOR, 1)
	await capture_frame(base + "-police.png")
	preview_course(2000, 4)
	var car = runner.add_entity("car", HordeRun.ANCHOR + float(MonsterCatalog.VEHICLES.car.width) * 0.5 + 12)
	while car.contacts.size() < 2 and not car.taken: preview_ticks(1)
	await capture_frame(base + "-vehicle-count.png")
	preview_ticks(45); await capture_frame(base + "-passengers.png")
	for name in MonsterCatalog.VEHICLES:
		preview_course(22300, 4)
		effects.smash(Vector2(730, HordeRun.FLOOR - float(MonsterCatalog.VEHICLES[name].height) * 0.5), name, 0.62)
		effects.update(1.7, 0)
		await capture_frame(base + "-burning-" + name + ".png")
	preview_course(1100, 4)
	runner.add_entity("crystal", 660, HordeRun.FLOOR - 65);runner.add_entity("mask", 930, HordeRun.FLOOR - 65)
	await capture_frame(base + "-pickups.png")
	runner.grant_perk(3);preview_ticks(45); await capture_frame(base + "-transform-early.png")
	preview_ticks(60); await capture_frame(base + "-transform-fly.png")
	preview_ticks(125);runner.add_entity("gap", 520, HordeRun.FLOOR, 0, 310);runner.add_entity("bomb", 950)
	await capture_frame(base + "-perk.png")
	preview_course(17850, 8); await capture_frame(base + "-tunnel-entry.png")
	preview_course(19050, 8); await capture_frame(base + "-tunnel.png")
	var tunnel = runner.tunnels[0];preview_course(float(tunnel.entry) + float(tunnel.length) - 160, 8)
	await capture_frame(base + "-tunnel-exit.png")
	preview_course(22300, 8)
	runner.add_entity("bus", 970);runner.add_entity("bomb", 600)
	runner.add_entity("soldier", 760);runner.add_entity("helicopter", 770, HordeRun.FLOOR - 280)
	runner.add_entity("air_bomb", 1130, HordeRun.FLOOR - 180);scenery.crash_age = 1.45
	await capture_frame(base + "-city.png")
	preview_course(210000, 12);runner.tunnels.clear();runner.entered_tunnels = 7;runner.completed_tunnels = 7;runner.pressure = 1;runner.speed = 780
	HordeCourse.build(runner, runner.world_px + 650, 40)
	await capture_frame(base + "-late-holes.png")
	preview_course(22000, 12);runner.route.assign([0, 1, 2, 3]);runner.completed_tunnels = 2;runner.entered_tunnels = 2
	scenery.update(0.1, runner);runner.add_entity("tank", 710);runner.add_entity("truck", 1100)
	await capture_frame(base + "-industrial.png")
	preview_course(22000, 16);runner.route.assign([0, 1, 2, 3]);runner.completed_tunnels = 3;runner.entered_tunnels = 3
	scenery.update(0.1, runner);runner.add_entity("plane", 895);runner.add_entity("moto", 470)
	await capture_frame(base + "-airport.png")

	data = MonsterCatalog.defaults();data.ritual_progress = 70
	preview_course(22300, 4);preview_collect_souls(24)
	runner.entities.clear();runner.add_entity("gap", HordeRun.ANCHOR - 290, HordeRun.FLOOR, 0, 850)
	preview_ticks(90);end_delay = -1;change_screen("results")
	for i in range(135): update_rewards(1.0 / 60);ui_time += 1.0 / 60
	await capture_frame(base + "-gameover.png")
	perform_action("home")
	for i in range(108): update_rewards(1.0 / 60);ui_time += 1.0 / 60
	await capture_frame(base + "-ritual.png")
	perform_action("credits"); await capture_frame(base + "-credits.png")
	preview_course(22300, 5);runner.add_entity("police", 820);runner.add_entity("bus", 1120)
	get_window().size = Vector2i(1600, 720)
	await get_tree().create_timer(0.15).timeout
	print("HORDE_LAYOUT_WIDE window=", get_window().size, " viewport=", get_viewport_rect(), " aspect=", get_window().content_scale_aspect)
	await capture_frame(base + "-wide.png")
	var touch = InputEventScreenTouch.new();touch.index = 7;touch.pressed = true;touch.position = layout_origin + Vector2(1202, 51)
	_input(touch)
	if screen != "pause": push_error("HORDE_CAPTURE_FAIL: wide-screen touch did not hit pause");get_tree().quit(1);return
	touch.pressed = false;_input(touch)
	await capture_frame(base + "-wide-pause.png")
	get_window().size = Vector2i(1280, 960)
	await get_tree().create_timer(0.15).timeout
	print("HORDE_LAYOUT_TABLET window=", get_window().size, " viewport=", get_viewport_rect(), " aspect=", get_window().content_scale_aspect)
	perform_action("resume"); await capture_frame(base + "-tablet.png")
	print("HORDE_CAPTURE_OK: 40 real screens; close camera at 16:9, wide phone and 4:3 tablet, animated HUD/souls, power store/transformations, police, occupied/damaged/burning vehicles, chained terrain, tunnels/results/ritual")
	get_tree().quit()

func animation_state(member: Dictionary) -> String:
	if member.falling: return "fall"
	if member.attack_left > 0: return "capture"
	if member.push_left > 0 and member.y >= runner.ground_y(member.x) - 12: return "push"
	if runner.perk_kind == 3 and runner.perk_left > 0: return "fly"
	if member.get("roof_id", -1) >= 0 and absf(float(member.vy)) < 0.1: return "run"
	if member.y < runner.ground_y(member.x) - 4: return "rise" if member.vy < 0 else "fall"
	return "run"

func update_run_visuals(dt: float) -> void :
	effects.update(dt, 0 if runner.dead else runner.speed);ui_effects.update(dt, 0)
	sound.update_course(runner, screen == "run" and not runner.dead, not effects.wrecks.is_empty())
	if not runner.dead:
		scenery.update(dt, runner)
		for event in scenery.events:
			sound.play("city_scream" if event == "background_scream" else "explosion", -23)
		scenery.events.clear()
		voice_tick -= dt
		if voice_tick <= 0 and runner.active_count() > 0:
			var lead = runner.leader_index()
			sound.play_monster(runner.perk_kind if runner.perk_left > 0 else int(runner.members[lead].kind))
			voice_tick = 4.5
	trail_tick += dt
	if not runner.members.is_empty() and not runner.dead and trail_tick >= 0.09:
		trail_tick = 0
		var index = runner.members.size() - 1
		var m = runner.members[index]
		if not m.falling and (runner.boost_left > 0 or runner.speed >= 380):
			var foot = Vector2(runner.member_x(index), m.y - runner.member_depth(index))
			effects.ghost(runner.perk_kind if runner.perk_left > 0 else int(m.kind), foot, float(m.run_phase), animation_state(m), m.land_left)
			for i in range(2):
				effects.add("speed", foot + Vector2(-22, randf_range(-75, -15)), Vector2(-100, 0), MINT, randf_range(20, 43), 0.22)

func floating_item(index: int, centre: Vector2, height: float, modulate: Color = Color.WHITE, lantern: bool = false) -> void :
	var texture = art.items[index]
	var size = texture.get_size() * (height / texture.get_height())
	var squash = maxf(0.624, absf(cos(ui_time * 3.8 + centre.x * 0.003))) if index == 1 else 1.0
	paint_target.draw_set_transform(centre, sin(ui_time * 2.5 + centre.x * 0.003) * (0.035 if lantern else 0.09), Vector2(squash * 1.10 if index == 1 else squash, 1))
	paint_target.draw_texture_rect(texture, Rect2( - size * 0.5, size), false, modulate)
	paint_target.draw_set_transform(Vector2.ZERO)

func buy_skin(index: int) -> bool:
	if index not in [0, 1]: return false
	if index in data.owned: return true
	var cost = int(MonsterCatalog.SKIN_PRICES[index])
	if int(data.wallet) < cost: sound.play("ui_denied");show_toast("Faltam " + str(cost - int(data.wallet)) + " moedas.");return false
	data.wallet -= cost;data.owned.append(index);data.skin = 0;sound.play("buy")
	show_toast("ESQUELETO LIBERADO PARA A HORDA", 2);save_game();return true

func draw_missions() -> void :
	views.missions(self)

func motion_preview() -> void :
	capture_freeze = true
	await get_tree().create_timer(0.3).timeout
	var folder = OS.get_environment("HORDE_MOTION_PATH")
	if folder.is_empty(): folder = "user://motion"
	DirAccess.make_dir_recursive_absolute(folder)
	var first_frame = maxi(0, int(OS.get_environment("HORDE_MOTION_START")))
	data = MonsterCatalog.defaults();data.ritual_progress = 70
	preview_course(22300, 4)
	for i in range(3): runner.add_entity("civilian", 460 + i * 80, HordeRun.FLOOR, i)
	runner.add_entity("car", 800)
	for frame in range(720):
		ui_time = float(frame) / 30.0
		if frame == 90:
			preview_course(22300, 5);runner.grant_perk(3)
			runner.add_entity("gap", 530, HordeRun.FLOOR, 0, 320);runner.add_entity("bomb", 960)
		if frame == 260: perform_action("pause")
		if frame == 290:
			data.power_owned = [3, 2];data.power_levels = {"mask_time": 1, "mask_force": 1, "mask_size": 1, "mask_shield": 1}
			preview_course(22300, 4);runner.grant_perk(2)
			runner.add_entity("bus", 930);runner.add_entity("police", 600)
		if frame == 450:
			preview_course(17920, 8);runner.speed = 440
		if frame == 535:
			data = MonsterCatalog.defaults();data.ritual_progress = 70
			preview_course(22300, 4);preview_collect_souls(24)
			runner.entities.clear();runner.add_entity("gap", HordeRun.ANCHOR - 250, HordeRun.FLOOR, 0, 850)
		if frame == 650: perform_action("home")
		var held = frame >= 200 and frame < 235
		if screen == "run":
			runner.advance(1.0 / 60, held);runner.advance(1.0 / 60, held)
			consume_run_events();check_challenges();update_run_visuals(1.0 / 30)
			if end_delay >= 0:
				end_delay -= 1.0 / 30
				if end_delay < 0: change_screen("developer" if lab_active else "results")
		elif screen in ["results", "home"]: update_rewards(1.0 / 30)
		toast_left = maxf(0, toast_left - 1.0 / 30)
		flash = maxf(0, flash - 1.0 / 30 * 1.7);shake = maxf(0, shake - 1.0 / 30 * 20)
		if frame >= first_frame: await capture_frame(folder + "/frame-%04d.png" % frame)
	print("HORDE_MOTION_OK: 720 real rendered frames; prepared courses and simulated touch; fluid running/capture, occupied physical vehicle flip/fire, 2.8s Fly/mask transformations, dive, animated pause missions, stronger masked bus flip, running police, tunnel, fatal pit, souls and ritual")
	get_tree().quit()

func draw_vehicle(entity: Dictionary) -> void :
	var spec = MonsterCatalog.VEHICLES[entity.kind]
	var height = float(entity.height); var width = float(entity.width)
	var angle = float(entity.tilt) + sin(ui_time * 3 + entity.bob) * 0.006
	var point = Vector2(entity.x, entity.y - height * 0.5 - sin(angle) * height * 0.15)
	paint_target.draw_set_transform(point, angle, Vector2(-1 if spec.reverse else 1, 1))
	paint_target.draw_texture_rect(art.vehicle(entity.kind), Rect2( - width * 0.5, - height * 0.5, width, height), false)
	var deform = clampf(float(entity.damage_stage) * 0.4 + sin(ui_time * 16) * 0.03 if entity.state == "pushing" else 0, 0, 0.9)
	paint_target.draw_texture_rect(art.damaged_vehicles[int(spec.icon)], Rect2( - width * 0.5, - height * 0.5, width, height), false, Color(1, 1, 1, deform))
	paint_target.draw_set_transform(Vector2.ZERO)
	if entity.kind == "moto" and not entity.passengers.is_empty():
		var pose = posmod(int(ui_time * 4 + entity.bob), 4)
		var rider = art.passenger_frames[8 + pose]
		paint_target.draw_set_transform(point + Vector2(15, -53).rotated(angle) * float(entity.scale), angle)
		paint_target.draw_texture_rect(rider, Rect2(Vector2(-65, -80) * float(entity.scale), Vector2(130, 130) * float(entity.scale)), false)
		paint_target.draw_set_transform(Vector2.ZERO)
	elif entity.kind != "moto":
		# Clip the head/torso to each native window; doors and waving hands cannot cover the vehicle.
		paint_target.draw_set_transform(point, angle)
		for i in range(mini(spec.windows.size(), entity.passengers.size())):
			var row = 1 if int(entity.passengers[i]) == 1 else 0
			var frame = row * 4 + posmod(int(ui_time * 3.5 + i * 1.3), 4)
			var crop = Rect2(70, 35, 220, 235) if row == 1 else Rect2(95, 30, 190, 245)
			paint_target.draw_texture_rect_region(art.passenger_frames[frame], HordeBalance.passenger_rect(spec, i), crop)
		paint_target.draw_set_transform(Vector2.ZERO)

	if entity.kind == "plane":
		for x in [ - width * 0.14, width * 0.22]:
			var start = point + Vector2(x, -10 - sin(ui_time * 60) * height * 0.11).rotated(angle)
			var end = point + Vector2(x, -10 + sin(ui_time * 60) * height * 0.11).rotated(angle)
			paint_target.draw_line(start, end, Color(0.9, 0.94, 1, 0.72), 3, true)
	var need = int(entity.get("required_count", spec.need))
	var count = entity.contacts.size()
	var color = MINT if count >= need else (GOLD if count > 0 else CORAL)
	var effort = 0
	for value in entity.contacts.values(): effort += int(value)
	if entity.rushing and not runner.tutorial_hints(): return
	var label = "PULE!" if entity.rushing else ((str(effort) + " / " + str(need)) if count > 0 else ("BLINDADO: " if entity.get("reinforced", false) else "VIRAR: ") + str(need))
	panel(Rect2(entity.x - 70, entity.y - height - (133 if entity.kind == "moto" else 51), 140, 37), Color(0.13, 0.08, 0.19, 0.96), color, 12, 2, false)
	text(label, Vector2(entity.x, entity.y - height - (107 if entity.kind == "moto" else 25)), 19, color, true, true, 1)
	if count > 0: progress_bar(Rect2(entity.x - 63, entity.y - height - 10, 126, 6), float(effort) / float(need), color)

func buy_area(index: int) -> bool:
	if index < 0 or index >= MonsterCatalog.AREAS.size(): return false
	if index in data.areas:
		show_toast("Este cenário já está na sua rota.", 1.7);return true
	var cost = int(MonsterCatalog.AREAS[index].price)
	if int(data.wallet) < cost:
		sound.play("ui_denied");show_toast("Faltam " + str(cost - int(data.wallet)) + " moedas para este cenário.");return false
	data.wallet -= cost;data.areas.append(index);sound.play("buy")
	show_toast(MonsterCatalog.AREAS[index].name + " entra na próxima fuga!", 2.3)
	save_game();return true

func draw_worlds() -> void :
	text("CENÁRIOS DA FUGA", Vector2(67, 101), 42, GOLD, true, false, 5)
	text("Cada túnel leva à próxima região. Dois cenários já vêm liberados!", Vector2(70, 144), 20, CREAM)
	currency()
	var notes = ["Névoa, lanternas e criaturas à espera.", "Fogo, civis fugindo e helicópteros caindo.", "Fábricas, fumaça e máquinas de guerra.", "Pista iluminada, hangares e aviões."]
	for i in range(4):
		var x = 64 + i * 291
		var area = MonsterCatalog.AREAS[i]
		var owned = i in data.areas
		panel(Rect2(x, 186, 278, 430), Color(0.18, 0.11, 0.25, 0.94), area.color if owned else Color("76527d"), 22, 3)
		paint_target.draw_rect(Rect2(x + 12, 202, 254, 191), Color("38264c"))
		paint_target.draw_texture_rect(art.world_thumbnails[i], Rect2(x + 12, 205, 254, 188), false, Color.WHITE if owned else Color(0.55, 0.49, 0.63, 1))
		text(area.name.to_upper(), Vector2(x + 139, 434), 18, area.color, true, true, 2)
		wrapped(notes[i], Vector2(x + 24, 474), 230, 17, Color("ded0e7"), 3)
		button(Rect2(x + 16, 551, 246, 52), "NA SUA ROTA" if owned else str(area.price) + " MOEDAS", "area_" + str(i), Color("557d70") if owned else Color("8054a7"), -2, 19)
	button(Rect2(68, 650, 218, 49), "VOLTAR", "back", Color("513c67"), -2, 20)
	text("A rota começa no cemitério. Novas regiões entram após a cidade.", Vector2(319, 682), 17, MINT)

func progress_bar(rect: Rect2, value: float, color: Color) -> void :
	panel(rect, Color("21152f"), Color("463154"), int(rect.size.y * 0.5), 1, false)
	if value > 0: panel(Rect2(rect.position, Vector2(maxf(5, rect.size.x * clampf(value, 0, 1)), rect.size.y)), color, color.lightened(0.12), int(rect.size.y * 0.5), 0, false)

func draw_fuse(point: Vector2, time: float) -> void :
	paint_target.draw_circle(point - Vector2(0, 11), 26, Color(1, 0.5, 0.13, 0.1 + 0.025 * sin(time * 12)))
	var texture = art.vfx[posmod(int(time * 11), 3)]
	var size = texture.get_size() * (26.0 / texture.get_height())
	paint_target.draw_texture_rect(texture, Rect2(point - Vector2(size.x * 0.5, size.y), size), false)
	for i in range(3):
		var age = fposmod(time * 1.7 + i * 0.33, 1)
		paint_target.draw_circle(point + Vector2(sin(time * 7 + i) * 11 * age, - age * 33), 1.7 * (1 - age), Color(1, 0.81, 0.3, 0.8 * (1 - age)))

func draw_civilian(entity: Dictionary) -> void :
	if entity.get("civil_key", "") == "civil_casaco_azul_nerd":
		art.civil.paint(paint_target, entity, Vector2(entity.x, entity.y), 112.0)
		return
	var spec = MonsterCatalog.CIVILIANS[clampi(int(entity.variant), 0, 2)]
	var rig = 5 if entity.kind == "soldier" else (8 if entity.kind == "police" else int(spec.rig))
	var state = "police_run" if entity.kind == "police" else ("panic_run" if entity.pose == "panic" else "run")
	var height = float(spec.height)
	var foot = Vector2(entity.x, entity.y)
	var tint = Color.WHITE
	if entity.state == "capture":
		var progress = 1 - float(entity.capture_left) / 0.62
		state = "panic";foot.x -= progress * 16;foot.y -= sin(progress * PI) * 12
		height *= 1 - maxf(0, progress - 0.6) * 1.5;tint.a = 1 - maxf(0, progress - 0.72) * 2.5
		if progress > 0.35:
			var texture = art.vfx[3 + mini(2, int(progress * 3))]
			var size = texture.get_size() * (80.0 / texture.get_height())
			paint_target.draw_texture_rect(texture, Rect2(foot - Vector2(size.x * 0.5, 73), size), false, Color(1, 1, 1, progress * 0.8))
	elif entity.pose == "hop" and entity.y < runner.ground_y(entity.x) - 10: state = "rise"
	actor.paint(paint_target, rig, foot, height, entity.age * 1.45 + entity.bob, state, ui_time, 0, tint, entity.vx < 0)
	if entity.state == "normal" and entity.speech_left > 0 and entity.x > HordeRun.ANCHOR + 50: draw_speech(entity, foot.y - height - 20)

func begin_ritual() -> void :
	if not data.ritual_ready: return
	ritual_view = HordeProgress.ritual(data, reward_rng);ritual_time = 0;ritual_particle_tick = 0;ritual_reward_played = false
	save_game()
	if int(ritual_view.points) > 0:
		effects.clear();sound.play("ritual_fill", -13)

func update_rewards(dt: float) -> void :
	effects.update(dt, 0)
	if screen == "home":
		ritual_time += dt;ritual_particle_tick += dt
		if not ritual_view.is_empty() and ritual_time < 2.6 and int(ritual_view.points) > 0 and ritual_particle_tick > 0.1:
			ritual_particle_tick = 0
			var target = home_menu.ritual_target(full_rect())
			effects.soul(target + Vector2(-270 + sin(ritual_time * 8) * 80, 140), target, 0.85)
		if not ritual_view.is_empty() and ritual_time > 1.75 and int(ritual_view.bonuses) > 0 and not ritual_reward_played:
			ritual_reward_played = true;sound.celebrate();effects.spark(home_menu.ritual_target(full_rect()), GOLD, 30)
	else:
		if result_full_flash <= 0: result_time += dt
		result_full_flash = maxf(0, result_full_flash - dt)
		sound.set_jar(result_full_flash <= 0 and animated_result_souls() < runner.souls)
		var animated = animated_result_souls()
		var view = HordeProgress.board(int(run_report.get("old_level", data.player_level)), int(run_report.get("old_progress", data.level_souls)), animated)
		if int(view.level) > result_level:
			result_level = int(view.level);result_full_flash = 0.34;sound.set_jar(false);sound.play("jar_full", -12);sound.celebrate();effects.spark(Vector2(331, 380), MINT, 24)

func draw_ritual_panel() -> void :
	panel(Rect2(78, 349, 650, 146), Color(0.12, 0.07, 0.2, 0.96), Color("8da690"), 22, 2)
	scenery.sprite(paint_target, art.ritual[1], Vector2(173, 431), 114, Color.WHITE, sin(ui_time * 2) * 0.014)
	for i in range(3):
		var angle = ui_time * 1.6 + i * TAU / 3
		animated_soul(Vector2(173 + cos(angle) * 43, 390 + sin(angle) * 16), 28, ui_time + i * 0.3, Color(1, 1, 1, 0.8))
	text("RITUAL DA MADRUGADA", Vector2(272, 385), 20, MINT, true)
	var amount = float(data.ritual_progress)
	if not ritual_view.is_empty() and ritual_time < 2.5:
		var value = float(ritual_view.old_progress) + float(ritual_view.points) * clampf(ritual_time / 2.1, 0, 1)
		amount = fposmod(value, 100)
	progress_bar(Rect2(272, 410, 427, 15), amount / 100, MINT)
	text(str(int(amount)) + " / 100", Vector2(272, 451), 18, CREAM, true)
	if not ritual_view.is_empty() and int(ritual_view.coins) > 0 and ritual_time > 1.7:
		text("BÔNUS: +" + str(ritual_view.coins) + " MOEDAS", Vector2(416, 451), 18, GOLD, true, false, 2)

func draw_soul_grid(rect: Rect2, progress: int, target: int) -> void :
	var cells = mini(120, target)
	var cols = 5 if cells <= 25 else (6 if cells <= 42 else (10 if cells <= 60 else 12))
	var rows = ceili(float(cells) / cols)
	var cell = Vector2((rect.size.x - (cols - 1) * 6) / cols, (rect.size.y - (rows - 1) * 6) / rows)
	var filled = float(progress) / maxi(1, target) * cells
	for i in range(cells):
		var point = rect.position + Vector2(i % cols, int(i / cols)) * (cell + Vector2(6, 6))
		var active = float(i) < filled
		panel(Rect2(point, cell), Color("31444c") if active else Color("251a32"), Color("7ac5b3") if active else Color("4b355e"), 8, 1, false)
		var centre = point + cell * 0.5 + Vector2(0, sin(ui_time * 3 + i) * (0.8 if active else 0))
		var size = minf(cell.y * 0.76, cell.x * 0.73)
		animated_soul(centre, size, ui_time + i * 0.11, Color.WHITE if active else Color(0.17, 0.13, 0.24, 0.8))

func draw_credits() -> void :
	text("CRÉDITOS E FONTES", Vector2(69, 107), 42, GOLD, true, false, 5)
	panel(Rect2(69, 158, 1142, 452), Color(0.16, 0.1, 0.23, 0.96), Color("785682"), 24, 2)
	var lines = ["Arte gerada com imagegen integrado; animações, música e efeitos adicionais criados para Noite da Horda.", "Ki Ki Ki Ma Ma Ma: alexander / Orange Free Sounds — CC BY 4.0. Conversão e normalização.", "orangefreesounds.com/ki-ki-ki-ma-ma-ma/ • creativecommons.org/licenses/by/4.0/", "Zumbis/ossos/gritos: artisticdude, congusbongus/blukotek, pauliuw, qubodup — CC0, OpenGameArt.", "Colisões: qubodup; helicóptero: WuxiaScrub; hélice: Mish7913 — CC0, OpenGameArt.", "Gritos civis: JohnsonBrandEditing e tcrocker68 — CC0, via congusbongus / OpenGameArt.", "Vozes policiais/militares sintetizadas com flite. Fontes: Luckiest Guy (Apache 2.0), Lilita One e Bungee (OFL), DejaVu Sans. Godot (MIT).", "URLs, licenças, modificações e prompts: repositório, monster-game/ASSETS.md e assets/audio/."]
	for i in range(lines.size()): wrapped(lines[i], Vector2(94, 190 + i * 51), 1092, 17, CREAM, 2)
	button(Rect2(69, 641, 240, 61), "VOLTAR", "back", Color("513c67"), -2, 23)

func update_camera(dt: float) -> void:
	camera_focus = move_toward(camera_focus, 1.0 if runner.transform_left > 0 else 0.0, dt * (1.8 if runner.transform_left > 0 else 1.2))
	var desired = lerpf(CAMERA_BASE_ZOOM, CAMERA_TRANSFORM_ZOOM, smoothstep(0, 1, camera_focus))
	var extent = 124.0
	for i in range(runner.members.size()):
		var member = runner.members[i]
		if member.falling: continue
		var height = 124.0 * (1.4 if runner.perk_kind == 2 and runner.perk_left > 0 and int(runner.power_levels.get("mask_size", 0)) > 0 else 1.0)
		var anticipation = maxf(0, -float(member.vy)) * 0.10
		extent = maxf(extent, HordeRun.FLOOR - float(member.y) + height + runner.member_depth(i) + anticipation)
	# Single jumps retain the normal framing. Tall double jumps get headroom
	# beneath the HUD, while the walk surface stays on screen and x stays fixed.
	var safe_top = -(get_viewport_rect().size.y - 720) * 0.5 + 140
	var lift = clampf(safe_top + extent * desired - CAMERA_ANCHOR.y, 0, 48)
	var fit_zoom = (CAMERA_ANCHOR.y + 48 - safe_top) / extent
	var target_zoom = clampf(minf(desired, fit_zoom), CAMERA_MIN_ZOOM, CAMERA_TRANSFORM_ZOOM)
	camera_zoom = move_toward(camera_zoom, target_zoom, dt * (0.85 if target_zoom < camera_zoom else 0.35))
	camera_ground_shift = move_toward(camera_ground_shift, lift, dt * (180 if lift > camera_ground_shift else 120))

func configure_layout() -> void :
	if not is_instance_valid(world_canvas): return
	var size = get_viewport_rect().size
	layout_origin = (size - Vector2(1280, 720)) * 0.5
	position = layout_origin
	if is_instance_valid(market_clip):
		var grid: Rect2 = market.layout(full_rect()).grid
		market_clip.position = grid.position
		market_clip.size = grid.size
		market_canvas.position = -grid.position
	world_canvas.scale = Vector2.ONE * camera_zoom
	world_canvas.position = CAMERA_ANCHOR + Vector2(0, camera_ground_shift) - Vector2(HordeRun.ANCHOR, HordeRun.FLOOR) * camera_zoom
	world_canvas.visible = screen in ["run", "pause", "results"]
	scenery.view_left = ( - layout_origin.x - world_canvas.position.x) / camera_zoom
	scenery.view_right = (1280 + layout_origin.x - world_canvas.position.x) / camera_zoom
	scenery.view_top = ( - layout_origin.y - world_canvas.position.y) / camera_zoom
	scenery.view_bottom = (720 + layout_origin.y - world_canvas.position.y) / camera_zoom
	runner.view_left = scenery.view_left
	runner.view_right = scenery.view_right
	runner.planning_right = maxf(scenery.view_right, HordeRun.ANCHOR + (1280 + layout_origin.x - CAMERA_ANCHOR.x) / CAMERA_MIN_ZOOM)

func full_rect() -> Rect2:
	return Rect2( - layout_origin, Vector2(1280, 720) + layout_origin * 2)

func world_to_ui(point: Vector2) -> Vector2:
	return world_canvas.transform * point

func paint_world() -> void :
	var interface_time = ui_time
	if screen in ["pause", "results"]: ui_time = frozen_world_time
	paint_target = world_canvas
	backdrop()
	world_canvas.draw_rect(Rect2(scenery.view_left, scenery.view_top, scenery.view_right - scenery.view_left, scenery.view_bottom - scenery.view_top), Color(0.045, 0.018, 0.09, 0.12))
	paint_target = self;ui_time = interface_time

func paint_foreground() -> void :
	var interface_time = ui_time
	if screen in ["pause", "results"]: ui_time = frozen_world_time
	paint_target = foreground_canvas;draw_run();paint_target = self;ui_time = interface_time

func animated_soul(point: Vector2, height: float, time: float, tint: Color = Color.WHITE) -> void :
	var frame = fposmod(time * 8, 6)
	var texture = art.soul_frames[int(frame)]
	var next = art.soul_frames[(int(frame) + 1) % 6]
	var size = Vector2.ONE * height
	var blend = smoothstep(0, 1, frame - floor(frame))
	paint_target.draw_set_transform(point, sin(time * 2) * 0.035)
	paint_target.draw_texture_rect(texture, Rect2( - size * 0.5, size), false, tint * Color(1, 1, 1, 1 - blend))
	paint_target.draw_texture_rect(next, Rect2( - size * 0.5, size), false, tint * Color(1, 1, 1, blend))
	paint_target.draw_set_transform(Vector2.ZERO)

func sin_color(kind: String) -> Color:
	return Color.WHITE

func draw_speech(_entity: Dictionary, _y: float) -> void:
	pass

func draw_transformation_title() -> void :
	var progress = 1 - runner.transform_left / runner.transform_duration
	var alpha = smoothstep(0, 0.2, progress) * (1 - smoothstep(0.88, 1, progress))
	var title = "SUPER FLY" if runner.transform_kind == 3 else "MASCARADO"
	var color = MINT if runner.transform_kind == 3 else CORAL
	for i in range(9):
		var point = Vector2(640, 242)
		var a = i * TAU / 9 + ui_time * 0.35
		paint_target.draw_colored_polygon(PackedVector2Array([point, point + Vector2(cos(a), sin(a)) * 260, point + Vector2(cos(a + 0.13), sin(a + 0.13)) * 280]), Color(color.r, color.g, color.b, 0.045 * alpha))
	panel(Rect2(353, 169, 574, 119), Color(0.08, 0.035, 0.13, 0.88 * alpha), Color(color.r, color.g, color.b, alpha), 29, 3)
	text(title, Vector2(640, 246 + sin(progress * PI) * 5), 53, Color(color.r, color.g, color.b, alpha), true, true, 8)

func buy_power(kind: int) -> bool:
	if kind not in [2, 3]: return false
	if kind in data.power_owned: return true
	var cost = 2800 if kind == 2 else 0
	if int(data.wallet) < cost: sound.play("ui_denied");show_toast("Faltam " + str(cost - int(data.wallet)) + " moedas.");return false
	data.wallet -= cost;data.power_owned.append(kind);sound.play("buy");save_game();show_toast("MASCARADO LIBERADO!", 2);return true

func buy_power_upgrade(index: int) -> bool:
	if index < 0 or index >= MonsterCatalog.POWER_UPGRADES.size(): return false
	var item = MonsterCatalog.POWER_UPGRADES[index]
	if item.kind not in data.power_owned: show_toast("Libere o Mascarado primeiro.", 1.7);return false
	var level = int(data.power_levels[item.id])
	if level >= int(item.max): return false
	var cost = MonsterCatalog.upgrade_cost(item, level)
	if int(data.wallet) < cost: sound.play("ui_denied");show_toast("Faltam " + str(cost - int(data.wallet)) + " moedas.");return false
	data.wallet -= cost;data.power_levels[item.id] = level + 1;sound.play("buy");save_game();return true

func draw_powers() -> void :
	text("POWER-UPS", Vector2(68, 99), 44, GOLD, true, false, 5);currency()
	button(Rect2(68, 120, 230, 51), "SUPER FLY", "power_tab_3", Color("617e78") if selected_power == 3 else Color("513c67"), -2, 22)
	button(Rect2(317, 120, 250, 51), "MASCARADO", "power_tab_2", Color("965d65") if selected_power == 2 else Color("513c67"), -2, 22)
	var unlocked = selected_power in data.power_owned
	panel(Rect2(68, 201, 301, 414), Color(0.16, 0.1, 0.23, 0.96), Color("9576b0"), 24, 3)
	actor.paint(paint_target, selected_power, Vector2(218, 416 + sin(ui_time * 2) * 5), 166, ui_time * 1.3, "fly" if selected_power == 3 else "run", ui_time, 0, Color.WHITE if unlocked else Color(0.12, 0.08, 0.19, 1))
	scenery.sprite(paint_target, art.power(selected_power, ui_time), Vector2(215, 486), 88)
	if unlocked: text("LIBERADO", Vector2(218, 575), 24, MINT, true, true, 2)
	else: button(Rect2(83, 553, 271, 48), "LIBERAR • 2800", "power_buy_2", Color("965d65"), -2, 20)
	var row = 0
	for i in range(MonsterCatalog.POWER_UPGRADES.size()):
		var item = MonsterCatalog.POWER_UPGRADES[i]
		if item.kind != selected_power: continue
		var col = row % 2; var line = int(row / 2);row += 1
		var rect = Rect2(395 + col * 409, 201 + line * 142, 383, 128)
		panel(rect, Color(0.18, 0.11, 0.26, 0.97), MINT if unlocked else Color("61516c"), 18, 2)
		text(item.name, rect.position + Vector2(17, 30), 18, GOLD, true, false, 2)
		wrapped(item.description, rect.position + Vector2(17, 59), 347, 15, CREAM, 2)
		var level = int(data.power_levels[item.id]); var cost = MonsterCatalog.upgrade_cost(item, level)
		var full = level >= int(item.max)
		text(str(level) + " / " + str(item.max), rect.position + Vector2(18, 111), 17, MINT, true)
		button(Rect2(rect.position + Vector2(107, 90), Vector2(258, 30)), "BLOQUEADO" if not unlocked else ("NO MÁXIMO" if full else str(cost) + " MOEDAS"), "power_upgrade_" + str(i), Color("5c4d69") if not unlocked else Color("8054a7"), -2, 15)
	if selected_power == 3:
		text("VOE POR CIMA. MERGULHE PARA COLETAR.", Vector2(406, 430), 24, MINT, true)
		wrapped("Segure a tela para descer. Solte para subir. O tempo do bônus começa depois da transformação.", Vector2(407, 483), 747, 22, CREAM, 3)
	button(Rect2(68, 648, 240, 59), "VOLTAR", "back", Color("513c67"), -2, 22)
	button(Rect2(957, 648, 247, 59), "MELHORIAS", "shop", Color("487385"), -2, 21)

func capture_menu_preview() -> void :
	var suite = load("res://tests/menu_ui_test.gd").new()
	add_child(suite)
	await suite.run(self)

func adjust_mix(channel: String, delta: float) -> void :
	if not data.audio_levels.has(channel): return
	data.audio_levels[channel] = clampf(float(data.audio_levels[channel]) + delta, 0, 1)
	data.audio = true;sound.set_enabled(true);sound.set_mix(data.audio_levels);save_game()
	if channel == "voices": sound.play("zombie_chuckle_1", -17)
	elif channel == "effects": sound.play("coin", -12)

func update_slider(point: Vector2) -> void :
	if slider_channel.is_empty(): return
	var value = clampf((point.x - 411) / 492.0, 0, 1)
	data.audio_levels[slider_channel] = value;data.audio = true
	sound.set_enabled(true);sound.set_mix(data.audio_levels)

func draw_settings() -> void :
	home_menu.label(self, "CONFIGURAÇÕES", Vector2(69, 109), 45, GOLD, false, -1, true, 5)
	home_menu.gear(self, Vector2(1162, 87), 30, ui_time * 0.4)
	var channels = ["music", "effects", "voices"]
	var titles = ["MÚSICA", "EFEITOS", "VOZES"]
	for i in range(3):
		var y = 185 + i * 137
		var channel = channels[i]
		panel(Rect2(146, y, 989, 113), Color("2b203c"), Color("826b87"), 23, 2)
		home_menu.label(self, titles[i], Vector2(179, y + 41), 26, GOLD, false)
		home_menu.label(self, str(roundi(float(data.audio_levels[channel]) * 100)) + "%", Vector2(1033, y + 69), 28, MINT, true)
		button(Rect2(326, y + 32, 55, 51), "−", "mix_minus_" + channel, Color("513c67"), -2, 27)
		button(Rect2(929, y + 32, 55, 51), "+", "mix_plus_" + channel, Color("513c67"), -2, 27)
		var bar = Rect2(411, y + 49, 492, 17)
		progress_bar(bar, float(data.audio_levels[channel]), MINT)
		draw_circle(Vector2(bar.position.x + bar.size.x * float(data.audio_levels[channel]), bar.get_center().y), 14, GOLD)
		buttons.append({"rect": Rect2(394, y + 22, 527, 73), "action": "mix_slider_" + channel})
	button(Rect2(69, 642, 245, 57), "VOLTAR", "back", Color("513c67"), -2, 23)
	button(Rect2(340, 642, 500, 57), "DESENVOLVEDOR TESTE", "developer", Color("4c786a"), -2, 23)
	if not data.audio: button(Rect2(878, 642, 258, 57), "ATIVAR SOM", "audio", Color("4c786a"), -2, 23)

func draw_collection() -> void :
	views.collection(self)

func animated_result_souls() -> int:
	var duration = clampf(float(runner.souls) * 0.055, 1.4, 4.2)
	return mini(runner.souls, int(float(runner.souls) * clampf((result_time - 0.25) / duration, 0, 1)))

func paint_market_rows() -> void :
	if screen != "market": return
	paint_target = market_canvas
	market.paint_rows(self)
	paint_target = self

func preview_v7() -> void :
	var suite = load("res://tests/visual_v7.gd").new();add_child(suite)
	await suite.run(self)

func preview_rig() -> void :
	var suite = load("res://tests/rig_game_preview.gd").new()
	add_child(suite)
	await suite.run(self)

func preview_sprite() -> void :
	var suite = load("res://tests/whole_sprite_preview.gd").new()
	add_child(suite)
	await suite.run(self)

func start_lab(kind: String) -> void:
	if not lab_active:
		lab_saved_runner = runner;lab_data = data.duplicate(true);lab_active = true
		lab_context = {"settings_from": settings_from, "stats": last_stats.duplicate(true), "challenges": run_challenges.duplicate(), "settled": run_settled, "report": run_report.duplicate(true)}
	lab_kind = kind;runner = HordeRun.new()
	runner.start_developer(kind, lab_count, lab_stage)
	runner.jump_delay_step = lab_delay;lab_hitboxes = kind == "collision"
	if kind == "powers": runner.power_owned = [2, 3];runner.levels.frenzy = 1
	camera_focus = 0;camera_zoom = CAMERA_BASE_ZOOM;camera_ground_shift = 0
	effects.clear();ui_effects.clear();scenery.reset();end_delay = -1
	last_save = 0;last_stats.clear();run_challenges.clear();trail_tick = 0
	change_screen("run")
	show_toast("TESTE: " + LAB_LABELS[LAB_KINDS.find(kind)], 2.5)

func leave_lab() -> void:
	if not lab_active: return
	data = lab_data;runner = lab_saved_runner;lab_active = false
	settings_from = lab_context.settings_from;last_stats = lab_context.stats;run_challenges.assign(lab_context.challenges)
	run_settled = lab_context.settled;run_report = lab_context.report
	end_delay = -1;effects.clear();ui_effects.clear();scenery.reset()

func draw_developer() -> void:
	home_menu.label(self, "DESENVOLVEDOR TESTE", Vector2(69, 102), 38, GOLD, false, -1, true, 4)
	text("Escolha uma família para testar suas variações.", Vector2(70, 143), 20, CREAM)
	for i in range(LAB_KINDS.size()):
		button(Rect2(70 + (i % 3) * 386, 175 + int(i / 3) * 70, 369, 58), LAB_LABELS[i], "lab_kind_" + LAB_KINDS[i], Color("513c67"), -2, 20)
	button(Rect2(70, 548, 369, 49), "HORDA: " + str(lab_count), "lab_count", Color("4c786a"), -2, 21)
	button(Rect2(456, 548, 369, 49), "TÚNEL: " + str(lab_stage), "lab_stage", Color("4c786a"), -2, 21)
	button(Rect2(842, 548, 369, 49), "ATRASO: " + str(snappedf(lab_delay * 1000, 0.1)) + " ms / zumbi", "lab_delay", Color("4c786a"), -2, 19)
	button(Rect2(70, 642, 245, 57), "VOLTAR", "back", Color("513c67"), -2, 23)
	text("Testes não alteram moedas, missões ou progresso.", Vector2(650, 678), 19, MINT, false, true)

func draw_collision_guides() -> void:
	for e in runner.entities:
		if e.taken: continue
		if MonsterCatalog.VEHICLES.has(e.kind) or e.kind == "helicopter":
			var body = HordeBalance.surface(e)
			paint_target.draw_rect(body, Color(0.5, 1, 0.8, 0.13))
			paint_target.draw_line(body.position, Vector2(body.end.x, body.position.y), MINT, 3, true)
			if e.kind == "helicopter":
				paint_target.draw_line(Vector2(body.position.x, body.end.y), body.end, GOLD, 3, true)
				paint_target.draw_rect(Rect2(e.x - 121, body.position.y, 60, body.size.y), Color(1, 0.2, 0.3, 0.3))
		elif e.kind in ["gap", "collapse"]:
			paint_target.draw_rect(Rect2(e.x, e.y, e.width, 100), Color(1, 0.3, 0.2, 0.18), false, 2)

func draw_sprite_lab() -> void:
	var names = ["Civil de casaco azul", "Civil mulher", "Trabalhador", "Policial", "Soldado"] if sprite_npcs else ["Zumbi", "Esqueleto", "Mascarado", "Mosca Mutante"]
	var states = ["idle", "run", "rise", "fall", "capture", "push", "panic"]
	home_menu.label(self, "TESTE DE SPRITES", Vector2(70, 102), 38, GOLD, false, -1, true, 4)
	text(names[sprite_subject] + "  •  " + states[sprite_state], Vector2(70, 146), 23, CREAM)
	panel(Rect2(70, 180, 1140, 375), Color("20182f"), Color("785b83"))
	var foot = Vector2(640, 520)
	paint_target.draw_line(Vector2(300, 521), Vector2(980, 521), MINT, 2, true)
	if sprite_npcs and sprite_subject == 0:
		var clips = ["parado_nervoso", "corrida", "susto_inicio_fuga", "transicao_susto_corrida", "captura", "transicao_corrida_captura", "parado_nervoso"]
		var clip: String = clips[sprite_state]
		var length = 3.2 if clip == "parado_nervoso" else (0.96 if clip == "corrida" else (1.08 if clip == "susto_inicio_fuga" else (1.7 if clip == "captura" else 0.12)))
		var clock = fposmod(sprite_clock, length + (0.3 if clip not in ["parado_nervoso", "corrida"] else 0.0))
		var flipped = clip in ["parado_nervoso", "captura", "transicao_corrida_captura"] or (clip == "susto_inicio_fuga" and HordeCivilSprite.sample(clip, clock) < 6)
		art.civil.paint(paint_target, {"state": "normal", "civil_clip": clip, "civil_time": clock, "civil_flip": flipped}, foot, 300)
		text(clip + "  •  quadro " + str(HordeCivilSprite.sample(clip, clock) + 1), Vector2(640, 222), 18, GOLD, false, true)
	else:
		var kind = [4, 6, 7, 8, 5][sprite_subject] if sprite_npcs else sprite_subject
		actor.paint(paint_target, kind, foot, 300, sprite_clock * 1.4, states[sprite_state], sprite_clock)
	button(Rect2(70, 580, 365, 54), "PRÓXIMO PERSONAGEM", "sprite_subject", Color("513c67"), -2, 20)
	button(Rect2(457, 580, 365, 54), "PRÓXIMA ANIMAÇÃO", "sprite_state", Color("513c67"), -2, 20)
	button(Rect2(844, 580, 365, 54), "CONTINUAR" if sprite_paused else "PAUSAR", "sprite_pause", Color("4c786a"), -2, 20)
	button(Rect2(70, 652, 245, 49), "VOLTAR", "back", Color("513c67"), -2, 22)

