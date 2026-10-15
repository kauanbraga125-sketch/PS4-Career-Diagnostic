class_name HordeCourse
extends RefCounted

static func build(run,absolute: float,index: int) -> float:
	var p=HordeDirector.profile(run.world_px,run.active_count(),run.pressure,run.recovery_left,run.tunnel_number())
	var stage=int(p.stage)
	var course_speed=minf(float(p.speed),maxf(200,run.speed))
	var base=absolute-run.world_px
	var force_gap=absolute-run.last_gap_world>float(p.max_gap_interval)
	var pattern=["car","gap","moto","rest","bomb","police"][index] if index<6 else ["gap","bomb","soldier","helicopter","car","bus","air_bomb","truck","police","rush"][run.rng.randi_range(0,9)]
	if force_gap:pattern="gap"
	if pattern=="rush" and (stage<2 or run.recovery_left>0 or run.active_count()<3):pattern="bomb"
	if stage>=4 and pattern=="truck":pattern="tank" if index%2==0 else "plane"
	if MonsterCatalog.VEHICLES.has(pattern) and run.remaining_soul_slots()<int(MonsterCatalog.VEHICLES[pattern].rescues):pattern="bomb"
	var start=absolute
	var end=absolute
	if pattern=="rush":
		var count=mini(3,1+int((stage-4)/2)) if stage>=6 and run.active_count()>=8 else 1
		var separation=maxf(1100,(float(p.speed)+290)*1.65)
		for i in range(count):
			var at=absolute+i*separation
			if run.safe_world_position(at) and run.civilian_floor_safe(at-run.world_px,700):run.spawn_rushing_car(at-run.world_px,index)
			end=at+220
	elif pattern=="rest":
		run.coin_arc(base,8,80,65);end=absolute+520
	elif pattern in ["gap","fly"]:
		var count=1 if pattern=="fly" else mini(3,1+int(stage/2))
		var long_jump=pattern=="gap" and stage>=1 and run.rng.randf()<.34
		var pad=maxf(190,course_speed*.58)
		for i in range(count):
			var width=course_speed*.87 if long_jump and i==0 else run.rng.randf_range(float(p.gap)*.78,float(p.gap))
			width=minf(width,course_speed*.88 if long_jump and i==0 else course_speed*.70)
			end=start+width
			if run.safe_world_position(start) and run.safe_world_position(end):
				var gap=run.add_entity("gap",start-run.world_px,HordeRun.FLOOR,0,width)
				gap.group=index;gap.double_jump=false;gap.long_jump=long_jump and i==0
				run.last_gap_world=start
				run.coin_arc(start-run.world_px+25,6,150,width/5)
				if i<count-1 and run.rng.randf()<float(p.recruit_chance)*.5:run.spawn_civilians(end-run.world_px+pad*.6,1,index+900000)
			start=end+pad

	else:
		var count=1 if MonsterCatalog.VEHICLES.has(pattern) or pattern=="police" else mini(4,int(p.cluster))
		for i in range(count):
			var at=absolute+i*float(p.spacing)
			var kind=pattern if i==0 or pattern=="bomb" else ["bomb","soldier","air_bomb","helicopter"][posmod(index+i,4)]
			if kind=="bomb" and stage>=1 and (index+i)%4==0:kind="hump"
			if stage==0 and kind in ["soldier","helicopter","air_bomb"]:kind="bomb"
			end=at+(float(MonsterCatalog.VEHICLES[kind].width)*.5 if MonsterCatalog.VEHICLES.has(kind) else 100)
			if not run.safe_world_position(at):continue
			var y=HordeRun.FLOOR
			if kind=="helicopter":y-=95 if (index+i)%2==0 else 280
			if kind=="air_bomb":y-=[105,185,260][posmod(index+i,3)]
			var entity=run.add_entity(kind,at-run.world_px,y);entity.group=index
		if run.safe_world_position(absolute-230):run.coin_arc(base-250,5,90,65)
	if run.rng.randf()<float(p.recruit_chance) and run.safe_world_position(end+220):
		var group_chance=clampf(.40-stage*.045-run.pressure*.17,.08,.40)
		var triple=run.rng.randf()<group_chance and end+350-run.last_three_world>=3000
		run.spawn_civilians(end+350-run.world_px,3 if triple else 1,index+100000)
	run.try_spawn_power(end+160-run.world_px)
	# Enough road to complete a landing or flip; no 100-metre empty blocks.
	return end+run.rng.randf_range(float(p.pattern_pause)*.88,float(p.pattern_pause)*1.08)+340
