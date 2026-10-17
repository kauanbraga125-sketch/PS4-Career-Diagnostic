extends SceneTree
var failures: Array[String] = []
var physics_cases = 0
var generated = 0
var reports: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		if failures.size() <= 20: push_error("V88 " + label)
func isolated(count: int, stage: int, seed_value: int = 8801) -> HordeRun:
	var r = HordeRun.new();r.start_developer("verification", count, stage, seed_value)
	r.next_segment = 99999;r.pressure = 0
	for i in range(r.members.size()): r.members[i].x = r.slot_x(i)
	return r
func vehicle_checks() -> void:
	for kind in MonsterCatalog.VEHICLES:
		for seed_value in range(20):
			var r = isolated(20, 3, 88000 + seed_value)
			var e = r.add_entity(kind, 600)
			var n = e.passengers.size();var spec = MonsterCatalog.VEHICLES[kind]
			check(n >= spec.rescue_min and n <= spec.rescues, "passengers " + kind)
			r.flip_vehicle(e);r.flip_vehicle(e)
			check(r.active_count() == 20+n and r.rescues == n and r.souls == n, "guaranteed rescue " + kind)
	var roof = isolated(1, 0)
	var car = roof.add_entity("car", 620)
	roof.jump();var supported = 0;var fell_after = false
	for frame in range(240):
		roof.advance(1.0/60, frame < 60)
		if roof.dead: break
		var m = roof.members[0]
		if m.roof_id == car.id and absf(m.y-(car.y-car.collision)) < 0.2 and m.vy == 0: supported += 1
		if supported > 0 and m.roof_id < 0 and m.y > car.y-car.collision+8: fell_after = true
	check(supported >= 4 and fell_after and roof.losses == 0, "roof support and edge drop " + str([supported, fell_after, roof.losses]))
	print("V88_VEHICLES_DONE")
func physics() -> void:
	for fps in [30,60]:
		for stage in [0,3,8]:
			for count in [1,36,88]:
				for kind in ["bomb_sequence","air_sequence","mixed","gap_chain","collapse","convoy"]:
					if kind == "convoy" and count < 8: continue
					var r = isolated(count,stage,880000+stage*100+count)
					var p = HordeDirector.profile(0,count,0,0,stage)
					var plan = HordeCourse.sequence_plan(r,kind,HordeRun.ANCHOR+r.speed*2,r.speed,p)
					var valid = HordeSequenceValidator.validate(r,plan.parts,plan.commands,plan.start,plan.end,r.speed)
					check(valid,"template " + str([fps,stage,count,kind]))
					if not valid:
						if failures.size()<6: print("BAD_PLAN "+JSON.stringify(plan))
						continue
					for part in plan.parts:
						var e = r.add_entity(part.kind,part.x,part.y,0,float(part.get("width",70)));e.vx = 0
					var command = 0;var held_until = -1.0
					for frame in range(ceili((float(plan.end)-HordeRun.ANCHOR+350)/r.speed*fps)):
						var lead = r.leader_index()
						if lead < 0: break
						if command < plan.commands.size() and r.world_px+float(r.members[lead].x)+r.speed/fps*0.20 >= float(plan.commands[command].x):
							r.jump();held_until = r.elapsed+float(plan.commands[command].hold);command += 1
						r.pressure = 0;r.advance(1.0/fps,r.elapsed<held_until);r.events.clear()
					check(r.losses == 0 and not r.dead,"live " + str([fps,stage,count,kind,r.losses]))
					physics_cases += 1
			print("V88_PHYSICS "+str([fps,stage,physics_cases,failures.size()]))
func generation() -> void:
	for stage in [0,3,8,14]:
		for count in [1,16,36,88]:
			var kinds: Dictionary = {};var rejected = 0
			for seed_value in range(8):
				var r = isolated(count,stage,882000+seed_value)
				r.developer_kind = "";r.entered_tunnels = stage;r.completed_tunnels = stage
				r.pressure = float(HordeDirector.profile(0,count,0,0,stage).pressure_target)
				r.planning_right = 2400;r.view_right = 1800
				var at = 3300.0
				for chunk in range(12):
					var delta = at - r.planning_right - 800 - r.world_px;r.world_px += delta
					for e in r.entities: e.x -= delta
					for i in range(r.entities.size()-1,-1,-1):
						if r.entities[i].x < -1600: r.entities.remove_at(i)
					var first_id = r.next_entity_id
					var next = HordeCourse.build(r,at,chunk)
					check(next>at,"generator stalled")
					for e in r.entities:
						if e.id < first_id or e.taken: continue
						var half = float(e.width)*0.5 if MonsterCatalog.VEHICLES.has(e.kind) else 40.0
						check(float(e.created_x)-half > r.planning_right, "visible creation " + str([e.kind,e.created_x,r.planning_right]))
						if e.kind == "coin": check(HordeCourse.coin_clear(r,Vector2(r.world_px+e.x,e.y),false), "coin overlap")
					if not r.generation_trace.is_empty():
						var kind = r.generation_trace[-1].kind;kinds[kind] = int(kinds.get(kind,0))+1
					at = next;r.next_pattern_world = at-HordeRun.ANCHOR;generated += 1
				rejected += r.sequence_rejections
			reports.append({"stage":stage,"horde":count,"kinds":kinds,"rejections":rejected})
			print("V88_GENERATION "+JSON.stringify(reports[-1]))
func configuration() -> void:
	check(is_equal_approx(HordeTuning.TUNNEL_DISTANCE,12600*1.20), "tunnel +20 percent")
	check(is_equal_approx(HordeTuning.COIN_CHANCE,0.70*0.70), "coin opportunity rate")
	check(is_equal_approx(HordeTuning.COINS_PER_ROAD_SECOND,1.8*0.7),"physical coin budget -30 percent")
	for stage in [1,3,8,14]:
		var old_increment = mini(stage,5)*11+clampi(stage-5,0,5)*17+235*(1.0-exp(-maxi(0,stage-10)/14.0))
		check(is_equal_approx(HordeDirector.stage_speed(stage)-305,old_increment*1.1), "speed increment")
	check(float(HordeDirector.profile(0,36,0,0,3).pressure_target) >= .99, "early horde pressure")
	var r = HordeRun.new();r.start({},880)
	r.terrain.reserve(r,300000,400)
	for t in r.tunnels:
		for seg in r.terrain.segments:
			if seg.height == 0: continue
			check(not (seg.start < t.entry+HordeRun.ANCHOR+t.length+1500 and seg.end > t.entry+HordeRun.ANCHOR-1300),"elevation near tunnel")
	for mode in [7,8,9]:
		var coins = isolated(1,0)
		check(HordeCourse.create_formation(coins,3400,305,0,mode),"coin geometry " + str(mode))
	var invalid = isolated(1,0)
	var parts: Array[Dictionary] = [{"kind":"gap","x":1000.0,"y":574.0,"width":900.0,"vx":0.0}]
	var commands: Array[Dictionary] = [{"x":940.0,"hold":1.05}]
	check(not HordeSequenceValidator.validate(invalid,parts,commands,800,2300,305),"impossible gap accepted")
	print("V88_CONFIGURATION_DONE")
func developer_filters() -> void:
	for family in ["bomb","air_bomb","mixed","gap","collapse","car","helicopter","tank","convoy","vehicles"]:
		var r = isolated(36,3,8899);r.developer_kind = family
		var at = 3300.0
		for i in range(8):
			var first = r.next_entity_id;var next = HordeCourse.build(r,at,i)
			for e in r.entities:
				if e.id < first or e.taken: continue
				var allowed: Array = [family]
				if family == "mixed": allowed = ["bomb","air_bomb"]
				if family == "vehicles": allowed = MonsterCatalog.VEHICLES.keys()
				if family == "convoy": allowed = ["car","helicopter"]
				check(e.kind in allowed,"developer filter "+str([family,e.kind]))
			at = next
		check(r.entities.size()>0,"developer empty "+family)
	print("V88_DEVELOPER_DONE")
func run() -> void:
	configuration();vehicle_checks();physics();generation();developer_filters()
	var result = {"version":"0.8.8","failures":failures,"physics_cases":physics_cases,"generated_chunks":generated,"reports":reports}
	FileAccess.open(OS.get_environment("HORDE_V88_REPORT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("V88_RESULT "+JSON.stringify({"failures":failures,"physics_cases":physics_cases,"generated":generated}))
	quit(0 if failures.is_empty() else 1)
