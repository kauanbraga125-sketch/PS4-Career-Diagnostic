extends SceneTree
var failures: Array[String] = []
var reports: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func flat(count: int = 1, stage: int = 3, seed_value: int = 89001) -> HordeRun:
	var r = HordeRun.new();r.start_developer("mixed", count, stage, seed_value)
	r.entities.clear();r.physics_surfaces.clear();r.events.clear();r.next_segment = 99999
	for m in r.members: m.arrival = 0.0
	return r
func collisions() -> void:
	for fps in [30, 60]:
		for kind in ["car", "bus", "plane", "helicopter"]:
			var r = flat();var e = r.add_entity(kind,340,400 if kind == "helicopter" else 574)
			e.vx = r.speed
			var roof = HordeBalance.surface(e).position.y
			var m = r.members[0];m.y = roof - 12;m.vy = 150
			for tick in range(fps / 3): r.advance(1.0/fps, false)
			check(r.active_count() == 1 and absf(float(m.y) - HordeBalance.surface(e).position.y) < 2.1, "roof " + kind + " " + str(fps))
		var r = flat();var heli = r.add_entity("helicopter",340,350);heli.vx = r.speed
		var m = r.members[0];m.y = 574;r.jump()
		var touched = false
		for tick in range(fps / 3):
			r.advance(1.0/fps,true)
			if float(m.vy) >= 0 and float(m.y) > 480: touched = true
		check(touched and r.active_count() == 1 and r.losses == 0,"harmless helicopter ceiling " + str(fps))
	var e = {"kind":"helicopter","x":500.0,"y":480.0,"width":256.0}
	check(HordeBalance.hazard_hits(e,{"x":400.0,"y":574.0,"vy":0.0}),"helicopter front must damage")
	check(not HordeBalance.hazard_hits(e,{"x":500.0,"y":517.0,"vy":0.0}),"helicopter middle contact is not frontal damage")
func civil() -> void:
	var total = 0
	for spec in HordeCivilSprite.metadata().values(): total += int(spec.frame_count)
	check(total == 66,"civil 66 approved frames")
	check(HordeCivilSprite.sample("susto_inicio_fuga",.55) == 5 and HordeCivilSprite.sample("susto_inicio_fuga",.67) == 6,"shock turn boundary")
	for phase in [0.0,.28,.88]:
		var r = flat(36);var e = r.add_entity("civilian",370,574,0)
		check(e.civil_key == "civil_casaco_azul_nerd" and e.civil_flip,"only blue association and idle left")
		e.civil_clip = "corrida";e.civil_time = phase;e.civil_flip = false;e.vx = 80
		r.begin_capture(e,r.members[0]);r.begin_capture(e,r.members[1])
		check(e.civil_flip and e.capture_left == .62,"capture immediate turn and original window")
		var original = int(e.capturer)
		r.update_civilians(.30);check(e.capturer == original and r.souls == 0,"stable capturer")
		r.update_civilians(.33);r.complete_capture(e)
		check(r.souls == 1 and r.active_count() == 37,"one conversion per contact phase")
	var r = flat();var e = r.add_entity("civilian",700,574,0)
	r.update_civilians(.01);check(e.civil_clip == "susto_inicio_fuga" and e.civil_flip,"threat interrupts idle left")
	r.update_civilians(.68);check(not e.civil_flip and e.vx > 0,"flight turns and moves right")
	r.update_civilians(.41);r.update_civilians(.12);check(e.civil_clip == "corrida","shock and bridge finish")
	check(not r.add_entity("civilian",800,574,1).has("civil_key") and not r.add_entity("civilian",900,574,2).has("civil_key"),"other civilians preserved")
func powers_and_budget() -> void:
	var r = flat();r.boost_left = 8
	check(not r.boost_protected(),"base frenzy no immunity")
	r.levels.frenzy = 1;check(r.boost_protected(),"upgraded frenzy immunity")
	r.add_entity("gap",250,574,0,500);check(r.has_floor(340),"frenzy pit floor")
	check(not r.damage(0,"bomb") and r.active_count() == 1,"frenzy bomb immunity")
	r = flat();r.boost_left = 8;r.levels.frenzy = 1
	var weak_car = r.add_entity("car",440)
	r.update_vehicle(weak_car,1.0/60)
	check(weak_car.taken and r.losses == 0,"upgraded frenzy cannot be trapped by a vehicle")
	r = flat();r.activate_perk(2);check(r.perk_left == 11,"power +3sec")
	var warnings = 0
	for i in range(11 * 60):
		r.advance(1.0/60,false)
		for event in r.drain_events():
			if event.type == "power_warning": warnings += 1
	check(warnings == 3,"audible warnings at 3,2,1 seconds")
	var normal = HordeRun.new();normal.start({},89002);normal.entities.clear();normal.physics_surfaces.clear();normal.entered_tunnels = 5;normal.souls = 64
	check(normal.early_soul_limit() == 65,"T5 cumulative budget")
	check(normal.add_entity("bus",3000).taken,"no empty or underfilled reward vehicle")
	var hostile = normal.add_entity("car",3300,574,-89)
	check(not hostile.taken and hostile.rushing and hostile.passengers.is_empty(),"hostile car unaffected by positive budget")
	var car = normal.add_entity("car",3500)
	check(not car.taken and car.passengers.size() == 1,"minimum proportional passenger when last slot")
	check(normal.remaining_soul_slots() == 0 and normal.add_entity("civilian",3700).taken,"no bonus souls beyond encounter budget")
	var crowd = flat(88);crowd.jump();check(float(crowd.members[-1].jump_queue[0].at) - float(crowd.members[0].jump_queue[0].at) >= crowd.speed*.119,"follower delay queued")
	var shown = HordeCrowdVisibility.visible(crowd)
	check(shown.size() < 88 and crowd.active_count() == 88,"hidden drawings preserve physical horde")
	reports.append({"horde":88,"visible_drawings":shown.size(),"delay_cap_seconds":crowd.follower_delay(87)})
func sequences() -> void:
	for count in [16,36,88]:
		for kind in ["bomb_sequence","air_sequence","mixed","gap","gap_chain","collapse","traffic_sequence","convoy","combined"]:
			var r = flat(count,3)
			var p = HordeDirector.profile(0,count,r.pressure,0,3)
			var valid = 0
			for variation in range(4):
				r.developer_iteration = variation + 1
				var plan = HordeCourse.sequence_plan(r,kind,3500,r.speed,p)
				var passed = HordeSequenceValidator.validate(r,plan.parts,plan.get("validation_commands",plan.commands),plan.start,plan.get("validation_end",plan.end),plan.get("validation_speed",r.speed))
				if passed: valid += 1
				if kind in ["traffic_sequence","convoy"]:
					for part in plan.parts:
						if part.kind == "car": check(part.rushing,"all traffic cars hostile")
			check(valid >= 2,"viable variants "+kind+" horde "+str(count)+" got "+str(valid))
			reports.append({"sequence":kind,"horde":count,"valid_variants":valid,"attempts":4})
func run() -> void:
	collisions();civil();powers_and_budget();sequences()
	var path = OS.get_environment("HORDE_V89_REPORT")
	if not path.is_empty(): FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"reports":reports},"  "))
	print("V89_RESULT "+JSON.stringify({"failures":failures,"reports":reports}))
	quit(0 if failures.is_empty() else 1)
