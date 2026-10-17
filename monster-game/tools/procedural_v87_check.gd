extends SceneTree
var failures: Array[String] = []
var physics_cases = 0
var generated = 0
var coin_checks = 0
var patterns: Dictionary = {}
var reports: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		if failures.size() < 12: push_error("V87 " + label)
func isolated(count: int, stage: int, seed_value: int) -> HordeRun:
	var r = HordeRun.new();r.start({},seed_value)
	r.entities.clear();r.tunnels.clear();r.next_segment = 99999;r.entered_tunnels = stage
	r.speed = HordeDirector.stage_speed(stage);r.cruise_speed = r.speed;r.last_effective_speed = r.speed
	r.terrain.segments.assign([{"start":-1e12,"end":1e12,"height":0.0,"state":0}]);r.terrain.generated_to = 1e12
	while r.members.size() < count: r.add_member(0,false)
	for i in range(r.members.size()): r.members[i].x = r.slot_x(i)
	return r
func physics() -> void:
	for fps in [30,60,120]:
		for stage in [0,5,8,11]:
			for count in [1,16,36,50]:
				for kind in ["bomb","bomb_pair","bomb_sequence","mixed","gap","gap_chain"]:
					if kind == "mixed" and stage < 4: continue
					if kind == "gap_chain" and stage < 7: continue
					var r = isolated(count,stage,870000+stage*100+count)
					var p = HordeDirector.profile(0,count,0,0,stage)
					var plan = HordeCourse.sequence_plan(r,kind,HordeRun.ANCHOR+r.speed*1.25,r.speed,p)
					check(HordeSequenceValidator.validate(r,plan.parts,plan.commands,plan.start,plan.end,r.speed),"template "+str([fps,stage,count,kind]))
					for part in plan.parts:
						var e = r.add_entity(part.kind,part.x,part.y,0,part.width);e.vx = 0
					var command = 0;var held_until = -1.0
					for frame in range(ceili((float(plan.end)-HordeRun.ANCHOR+500)/r.speed*fps)):
						if command < plan.commands.size() and r.world_px+HordeRun.ANCHOR+r.speed/fps*0.25 >= float(plan.commands[command].x):
							r.jump();held_until = r.elapsed+float(plan.commands[command].hold);command += 1
						r.pressure = 0;r.advance(1.0/fps,r.elapsed<held_until);r.events.clear()
					check(r.losses == 0 and r.active_count() == count and not r.dead,"live "+str([fps,stage,count,kind,r.losses]))
					physics_cases += 1
func sweep(stage: int,count: int) -> void:
	var kinds: Dictionary = {};var helis = 0;var slots = 0;var rejected = 0
	for seed_index in range(200):
		var r = isolated(count,stage,8701000+seed_index);var absolute = 2400.0
		for chunk in range(5):
			var delta = absolute-HordeRun.ANCHOR-1500-r.world_px;r.world_px += delta
			for e in r.entities: e.x -= delta
			for i in range(r.entities.size()-1,-1,-1):
				if r.entities[i].x < -1800: r.entities.remove_at(i)
			var next = HordeCourse.build(r,absolute,chunk)
			check(next>absolute,"generation stalled")
			for e in r.entities:
				if e.taken: continue
				if e.kind == "coin":
					check(HordeCourse.coin_clear(r,Vector2(r.world_px+e.x,e.y),false),"coin intersects obstacle");coin_checks += 1
				elif e.kind == "gap": check(e.width <= r.speed*HordeTuning.GAP_LARGE_SECONDS.y+0.01,"wide gap")
				elif e.kind in ["bomb","air_bomb","helicopter"]: check(e.get("path_checked",false),"unvalidated hazard")
			if not r.generation_trace.is_empty():
				var kind = str(r.generation_trace[-1].kind)
				kinds[kind] = int(kinds.get(kind,0))+1;patterns[kind] = int(patterns.get(kind,0))+1
			absolute = next;generated += 1
		helis += r.helicopter_draws;slots += r.mobile_slots;rejected += r.sequence_rejections
	reports.append({"stage":stage,"horde":count,"seeds":200,"chunks":1000,"kinds":kinds,"helicopter_draws":helis,"mobile_slots":slots,"rejected":rejected})
	print("V87_SWEEP "+str([stage,count,rejected]))
func configuration() -> void:
	var r = HordeRun.new();r.start({},871)
	check(is_equal_approx(float(r.tunnels[0].entry)/18000.0,0.7),"first tunnel")
	var first = r.tunnels[0].duplicate();r.world_px = first.entry+first.length;r.update_tunnels()
	check(is_equal_approx((float(r.tunnels[1].entry)-float(first.entry)-float(first.length))/(18000*maxf(1,r.cruise_speed/305)),0.7),"between tunnels")
	var pickup = isolated(1,0,879);var offered = pickup.add_entity("shield",HordeRun.ANCHOR+20,HordeRun.FLOOR-65)
	pickup.bonus_director.reschedule(1000,305);pickup.advance(1.0/60,false)
	check(offered.taken and pickup.shields == 1 and pickup.bonuses == 1,"box disappears in cooldown")
	var a = isolated(36,8,874);var b = isolated(36,8,874)
	for i in range(30): check(HordeCourse.draw_pattern(a,i,true)==HordeCourse.draw_pattern(b,i,true),"seed reproducibility")
	var parts: Array[Dictionary] = [{"kind":"gap","x":1000.0,"y":HordeRun.FLOOR,"width":r.speed*2,"vx":0.0}]
	var commands: Array[Dictionary] = [{"x":1000-r.speed*0.2,"hold":HordeBalance.MAX_HOLD}]
	check(not HordeSequenceValidator.validate(pickup,parts,commands,800,2200,r.speed),"impossible gap accepted")
func run() -> void:
	configuration();physics()
	for stage in [0,1,3]: sweep(stage,16)
	for stage in [5,8,11]:
		for count in [16,25,36,50]: sweep(stage,count)
	var result = {"failures":failures,"physics_cases":physics_cases,"generated_chunks":generated,"coin_checks":coin_checks,"patterns":patterns,"reports":reports}
	FileAccess.open(OS.get_environment("HORDE_V87_REPORT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("V87_RESULT "+JSON.stringify({"failures":failures,"physics_cases":physics_cases,"generated":generated,"coin_checks":coin_checks}))
	quit(0 if failures.is_empty() else 1)
