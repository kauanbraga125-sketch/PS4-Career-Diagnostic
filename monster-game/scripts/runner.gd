class_name HordeRun
extends RefCounted

const FLOOR=574.0
const GRAVITY=1500.0
const ANCHOR=MonsterCatalog.ANCHOR
const SEGMENT=3300.0
const ZONE_LENGTH=MonsterCatalog.ZONE_LENGTH
const MAX_HORDE=MonsterCatalog.MAX_HORDE
var rng=RandomNumberGenerator.new()
var levels={}
var route: Array[int]=[0,1]
var members: Array[Dictionary]=[]
var entities: Array[Dictionary]=[]
var events: Array[Dictionary]=[]
var elapsed=0.0
var world_px=0.0
var speed=275.0
var pressure=0.0
var recovery_left=0.0
var recovery_speed=275.0
var loss_times: Array[float]=[]
var next_member_id=0
var coins=0
var recruits=0
var souls=0
var soldiers=0
var rescues=0
var groups=0
var group_captures: Dictionary={}
var next_entity_id=0
var tunnels: Array[Dictionary]=[]
var entered_tunnels=0
var completed_tunnels=0
var cars=0
var losses=0
var shots=0
var clean_jumps=0
var bonuses=0
var flights=0
var boost_px=0.0
var max_horde=1
var shields=0
var perk_kind=-1
var perk_left=0.0
var boost_left=0.0
var next_segment=0
var last_variant=-1
var dead=false
var hit_grace=0.0
var jumped=false
var clean_air=false
var last_area=0
var last_tunnel=0
var owned: Array=[0]
var power_owned: Array=[3]
var power_levels: Dictionary={}
var transform_left=0.0
var transform_kind=-1
var transform_from_kind=-1
var transform_duration=2.8
var revive_charges=0
var next_pattern_world=2400.0
var pattern_index=0
var last_gap_world=0.0
var voice_cooldown=0.0
var cruise_speed=305.0
var last_effective_speed=305.0
var time_scale=1.0
var next_power_tunnel=1
var last_three_world=-100000.0
var speech_text=""
var speech_left=0.0
var speech_npc=0
var speech_cooldown=0.0
var jump_sequence=0
var wave_holds: Dictionary={}
var npc_serial=0
var next_rush_world=8500.0

func start(upgrades: Dictionary,seed_value: int=0,skin: int=0,areas: Array=[0,1],collection: Array=[0],powers: Array=[3],power_upgrades: Dictionary={}) -> void:
	levels=upgrades.duplicate(true)
	owned=collection.duplicate();power_owned=powers.duplicate();power_levels=power_upgrades.duplicate(true)
	route.assign([0,1])
	for area in areas:
		if int(area) in [2,3] and int(area) not in route: route.append(int(area))
	rng.seed=seed_value if seed_value else Time.get_ticks_usec()
	members.clear();entities.clear();events.clear();loss_times.clear();tunnels.clear();group_captures.clear()
	elapsed=0;world_px=0;coins=0;recruits=0;cars=0;losses=0;shots=0;clean_jumps=0;bonuses=0;flights=0;boost_px=0
	shields=0;perk_kind=-1;perk_left=0;boost_left=0;next_segment=0;last_variant=-1
	dead=false;hit_grace=0;jumped=false;clean_air=false;speed=305;pressure=0;recovery_left=0;recovery_speed=275
	transform_left=0;transform_kind=-1;revive_charges=0;next_pattern_world=2400;pattern_index=0;last_gap_world=0;voice_cooldown=0
	max_horde=1;next_member_id=0;next_entity_id=0;last_area=0;last_tunnel=0
	cruise_speed=305;last_effective_speed=305;time_scale=1;next_power_tunnel=1;last_three_world=-100000
	speech_text="";speech_left=0;speech_npc=0;speech_cooldown=0
	jump_sequence=0;wave_holds.clear();npc_serial=0;next_rush_world=8500
	souls=0;soldiers=0;rescues=0;groups=0;entered_tunnels=0;completed_tunnels=0
	schedule_tunnel(1,18000.0)
	for i in range(1+int(levels.get("horde",0))): add_member(0 if i==0 else recruit_kind(),false)
	spawn_segment(0)
	next_segment=1

func slot_x(index: int) -> float:
	return ANCHOR-float(index%8)*34.0-float(int(index/8))*14.0

func member_x(index: int) -> float:
	return float(members[index].x) if index>=0 and index<members.size() else slot_x(index)

func active_count() -> int:
	var total=0
	for m in members:
		if not m.falling: total+=1
	return total

func leader_index() -> int:
	for i in range(members.size()):
		if not members[i].falling: return i
	return -1

func add_member(kind: int,count_recruit: bool=true,spawn: Vector2=Vector2(INF,INF)) -> void:
	if dead or (not members.is_empty() and active_count()==0): return
	if members.size()>=MAX_HORDE:
		coins+=2;events.append({"type":"coin","amount":2,"x":ANCHOR,"y":FLOOR-70})
		return
	var index=members.size()
	members.append({"id":next_member_id,"kind":clampi(kind,0,3),"x":slot_x(index) if is_inf(spawn.x) else spawn.x,"y":FLOOR if is_inf(spawn.y) else minf(FLOOR,spawn.y),"vy":0.0,"jump_delay":-1.0,"jump_at":-1.0,
		"air_jumps":0,"coyote":.1,"land_left":0.0,"glide_left":0.0,"arrival":.35,"step_phase":-1,"falling":false,"attack_left":0.0,"push_left":0.0,"run_phase":index*.11,"air_pose":0.0,"jump_ground_only":false,"jump_queue":[],"wave_id":-1,"air_time":0.0})
	next_member_id+=1;max_horde=maxi(max_horde,active_count())
	if count_recruit:
		recruits+=1;events.append({"type":"recruit","x":slot_x(index),"y":FLOOR-50})

func add_entity(kind: String,x: float,y: float=FLOOR,variant: int=0,width: float=70) -> Dictionary:
	# Legacy spawners now create living humans rather than collectible monsters.
	if kind=="recruit": kind="civilian"
	var entity={"id":next_entity_id,"kind":kind,"x":x,"y":y,"base_y":y,"variant":variant,"width":width,"taken":false,
		"vx":-70.0 if kind=="helicopter" else (-190.0 if kind=="bullet" else (-40.0 if kind=="air_bomb" else 0.0)),
		"timer":rng.randf_range(1.2,1.8),"flash":0.0,"bob":rng.randf_range(0,TAU),"state":"normal","age":0.0,"vy":0.0,
		"pose":"run","contacts":{},"push_age":0.0,"tilt":0.0,"passengers":[],"group":-1,"rescued":false,"speech_left":0.0,"spoke":false,"rushing":false,"warned":false,"voice_wait":rng.randf_range(.2,1.5),"speech":"","damage_stage":0}
	next_entity_id+=1
	if kind in ["civilian","soldier","police"]:
		npc_serial+=1;entity.speaker=npc_serial%15==0
		var phrases=MonsterCatalog.CIVIL_PHRASES if kind=="civilian" else (MonsterCatalog.POLICE_PHRASES if kind=="police" else MonsterCatalog.ARMY_PHRASES)
		entity.speech=phrases[rng.randi_range(0,phrases.size()-1)]
	if kind=="police":entity.vx=-135;entity.pose="police_run"
	if kind=="civilian":
		entity.variant=clampi(variant,0,2);entity.vx=rng.randf_range(-55,90)
		entity.pose=["run","hop","panic"][rng.randi_range(0,2)]
	if MonsterCatalog.VEHICLES.has(kind):
		var spec=MonsterCatalog.VEHICLES[kind];entity.width=spec.width
		for i in range(mini(int(spec.rescues),remaining_soul_slots())): entity.passengers.append(rng.randi_range(0,2))
	if kind in ["civilian","soldier","police"] and remaining_soul_slots()<=0:
		entity.taken=true;return entity
	entities.append(entity)
	return entity

func coin_arc(base: float,count: int=7,height: float=125,spacing: float=72) -> void:
	for i in range(count): add_entity("coin",base+i*spacing,FLOOR-48-sin(float(i)*PI/float(count-1))*height)

func tunnel_number() -> int:
	return entered_tunnels

func area() -> int:
	return route[posmod(completed_tunnels,route.size())]

func tunnel_phase() -> float:
	var tunnel=current_tunnel()
	return world_px-float(tunnel.entry) if not tunnel.is_empty() else -1

func inside_tunnel() -> bool:
	for t in tunnels:
		if world_px>=float(t.entry) and world_px<float(t.entry)+float(t.length): return true
	return false

func safe_world_position(x: float) -> bool:
	for t in tunnels:
		if x>=float(t.entry)+ANCHOR-550 and x<=float(t.entry)+ANCHOR+float(t.length)+850: return false
	return true

func spawn_segment(index: int) -> void:
	if index==0:
		spawn_civilians(1050-world_px,1,0)
		for i in range(8):add_entity("coin",850-world_px+i*95,FLOOR-50)
	else:HordeCourse.build(self,float(index)*SEGMENT,index)

func spawn_next_pattern() -> void:
	var absolute=next_pattern_world+ANCHOR
	if not safe_world_position(absolute):
		for t in tunnels:
			if absolute>=float(t.entry)+ANCHOR-550 and absolute<=float(t.entry)+ANCHOR+float(t.length)+850:
				next_pattern_world=float(t.entry)+float(t.length)+900
				return
	var finish_world=HordeCourse.build(self,absolute,pattern_index)
	next_pattern_world=finish_world-ANCHOR;pattern_index+=1;next_segment=pattern_index+1

func has_floor(x: float) -> bool:
	if inside_tunnel(): return true
	for e in entities:
		if e.kind=="gap" and x>e.x and x<e.x+e.width: return false
	return true

func grounded_strength() -> int:
	var count=0
	for m in members:
		if not m.falling and m.y>=FLOOR-12 and m.y<=FLOOR+2 and has_floor(m.x): count+=1
	return count

func jump() -> void:
	if dead or transform_left>0: return
	var lead=leader_index()
	if lead<0:return
	if perk_kind==3 and perk_left>0:
		events.append({"type":"wing","x":members[lead].x,"y":members[lead].y-50});return
	var first=members[lead]
	var grounded=first.coyote>0 or (first.y>=FLOOR-.1 and first.y<=FLOOR+1 and first.vy==0 and has_floor(first.x))
	var double=not grounded and int(levels.get("jump",0))>=2 and first.air_jumps<2 and first.y<FLOOR
	if not grounded and not double:return
	jump_sequence+=1;wave_holds[jump_sequence]=true
	for old in wave_holds.keys():
		if int(old)<jump_sequence-8:wave_holds.erase(old)
	var point=world_px+float(first.x)
	for m in members:
		if m.falling:continue
		m.jump_queue.append({"at":point,"id":jump_sequence,"double":double})
		m.jump_delay=maxf(0,point-world_px-float(m.x))/maxf(1,speed)
		m.jump_at=point-float(m.x)
	jumped=true;clean_air=true
	events.append({"type":"jump","x":first.x,"y":first.y})

func release_jump() -> void:
	wave_holds[jump_sequence]=false

func grant_perk(kind: int) -> void:
	var lead=leader_index()
	if dead or lead<0 or transform_left>0 or kind not in power_owned:return
	transform_from_kind=perk_kind if perk_left>0 else -1
	transform_kind=kind;transform_left=transform_duration
	mark_power_collected()
	bonuses+=1
	events.append({"type":"transform","kind":kind,"x":members[lead].x,"y":members[lead].y-60})

func activate_perk(kind: int) -> void:
	perk_kind=kind
	perk_left=(8.0+int(power_levels.get("fly_time",0))*3) if kind==3 else (8.0+int(power_levels.get("mask_time",0))*3)
	revive_charges=1 if kind==2 and int(power_levels.get("mask_revive",0))>0 else 0
	if kind==2 and int(power_levels.get("mask_shield",0))>0:shields=maxi(shields,3)
	if kind==3:
		flights+=1
		for m in members:
			if not m.falling:m.jump_delay=-1;m.jump_at=-1;m.vy=minf(m.vy,-180)
	events.append({"type":"perk","kind":kind})

func recruit_kind() -> int:
	return 1 if 1 in owned and rng.randf()<.30 else 0

func member_force() -> int:
	if perk_kind!=2 or perk_left<=0:return 1
	return (1+int(power_levels.get("mask_force",0)))*(2 if int(power_levels.get("mask_size",0))>0 else 1)

func rescue_from_pit() -> bool:
	if perk_kind!=2 or perk_left<=0 or revive_charges<=0 or active_count()>0 or members.is_empty():return false
	revive_charges-=1;hit_grace=1.5
	for i in range(members.size()):
		var m=members[i];m.falling=false;m.x=slot_x(i);m.y=FLOOR-160;m.vy=-90;m.glide_left=1.8;m.jump_delay=-1;m.jump_at=-1;m.coyote=0
	events.append({"type":"revive","x":ANCHOR,"y":FLOOR-75})
	return true

func register_loss() -> void:
	losses+=1;loss_times.append(elapsed)
	while not loss_times.is_empty() and loss_times[0]<elapsed-4.5: loss_times.pop_front()
	if (loss_times.size()>=3 or active_count()<=3) and recovery_left<=0 and active_count()>0:
		recovery_left=7.0;recovery_speed=maxf(275,speed*.93);pressure=maxf(0,pressure-.35)
		spawn_civilians(1400,3 if world_px+1400-last_three_world>=3000 else 1,next_entity_id+500000)
		events.append({"type":"recovery"})

func remove_member(index: int,cause: String) -> void:
	if index<0 or index>=members.size(): return
	var old=members[index]
	var shown=int(old.get("death_kind",old.kind)) if old.falling else (perk_kind if perk_left>0 else int(old.kind))
	events.append({"type":"hit","x":old.x,"y":minf(old.y-45,FLOOR-30),"kind":shown,"cause":cause})
	members.remove_at(index)
	clean_air=false;register_loss()
	if members.is_empty(): finish()

func damage(index: int,cause: String="impact") -> bool:
	if dead or index<0 or index>=members.size() or members[index].falling: return false
	if hit_grace>0 or transform_left>0: return false
	hit_grace=.36;clean_air=false
	if shields>0:
		shields-=1;events.append({"type":"guard","x":members[index].x,"y":members[index].y-60});return true
	remove_member(index,cause)
	return true

func finish() -> void:
	if dead: return
	dead=true;events.append({"type":"finish"})

func update_enemies(dt: float) -> void:
	var pending: Array[Dictionary]=[]
	var p=HordeDirector.profile(world_px,active_count(),pressure,recovery_left,tunnel_number())
	for e in entities:
		if e.taken or e.state=="capture": continue
		e.flash=maxf(0,e.flash-dt);e.speech_left=maxf(0,e.speech_left-dt)
		if e.kind in ["civilian","soldier","police"] and e.get("speaker",false) and not e.spoke and e.x>ANCHOR+35 and e.x<ANCHOR+maxf(1000,speed*3.2) and speech_cooldown<=0:
			e.spoke=true;e.speech_left=2.0;speech_text=e.speech;speech_left=clampf(1.5+speech_text.length()/10.0,3.0,4.2)
			speech_cooldown=speech_left+.35;speech_npc=5 if e.kind=="soldier" else (8 if e.kind=="police" else MonsterCatalog.CIVILIANS[e.variant].rig)
			if voice_cooldown<=0:
				voice_cooldown=2.2;events.append({"type":"npc_voice","npc":e.kind,"variant":e.variant})
		if e.kind=="car" and e.rushing and not e.warned and e.x>ANCHOR and e.x-ANCHOR<(speed-e.vx)*2.7+180:
			e.warned=true;events.append({"type":"car_warning","x":e.x,"y":FLOOR-90})
		if e.kind=="soldier" and e.x>ANCHOR+230 and e.x<1390:
			e.timer-=dt
			if e.timer<=0:
				e.timer=float(p.bullet_period);e.flash=.16;shots+=1
				pending.append({"x":e.x-56,"y":FLOOR-64})
				events.append({"type":"shot","x":e.x-56,"y":FLOOR-64})
	for bullet in pending: add_entity("bullet",bullet.x,bullet.y,0,18)

func advance(dt: float,jump_held: bool=false) -> void:
	if dead: return
	if not jump_held:release_jump()
	elapsed+=dt;voice_cooldown=maxf(0,voice_cooldown-dt)
	speech_left=maxf(0,speech_left-dt);speech_cooldown=maxf(0,speech_cooldown-dt)
	if absf(speed-last_effective_speed)>2:cruise_speed=speed/maxf(.20,time_scale)
	if transform_left>0:
		transform_left=maxf(0,transform_left-dt)
		time_scale=move_toward(time_scale,.22,dt*2.2)
		speed=cruise_speed*time_scale;last_effective_speed=speed
		world_px+=speed*dt;update_tunnels()
		for e in entities:e.x+=(-speed+float(e.vx)*time_scale)*dt
		update_civilians(dt*time_scale);update_enemies(dt*time_scale)
		while next_segment<99999 and next_pattern_world-world_px<1550:spawn_next_pattern()
		for member in members:member.run_phase+=dt*.75
		if transform_left<=0:
			activate_perk(transform_kind);transform_kind=-1
			for member in members:member.glide_left=maxf(member.glide_left,1.1)
		return
	boost_left=maxf(0,boost_left-dt);recovery_left=maxf(0,recovery_left-dt)
	var p=HordeDirector.profile(world_px,active_count(),pressure,recovery_left,tunnel_number())
	pressure=move_toward(pressure,float(p.pressure_target),dt*.17)
	var target_speed=float(p.speed)
	if recovery_left>0: target_speed=minf(target_speed,recovery_speed)
	target_speed*=1.18 if boost_left>0 else 1.0
	cruise_speed=move_toward(cruise_speed,target_speed,dt*58)
	time_scale=move_toward(time_scale,.86 if perk_kind==3 and perk_left>0 else 1.0,dt*.72)
	speed=cruise_speed*time_scale;last_effective_speed=speed
	var step=speed*dt;world_px+=step
	update_tunnels()
	if next_segment<99999 and world_px>=next_rush_world and not inside_tunnel():
		var spawn_x=ANCHOR+maxf(1350,(speed+240)*2.6)
		if civilian_floor_safe(spawn_x,700) and safe_world_position(world_px+spawn_x):
			spawn_rushing_car(spawn_x,-500);next_rush_world=world_px+rng.randf_range(8500,12500)
		else:next_rush_world+=450
	if boost_left>0: boost_px+=step
	hit_grace=maxf(0,hit_grace-dt)
	if tunnel_number()!=last_tunnel:
		last_tunnel=tunnel_number()
		events.append({"type":"tunnel","area":area(),"number":last_tunnel})
	if area()!=last_area:
		last_area=area();events.append({"type":"area","area":last_area})
	if perk_left>0:
		perk_left=maxf(0,perk_left-dt)
		if perk_left<=0:
			if perk_kind==3:
				for m in members:
					if not m.falling: m.glide_left=.30
			perk_kind=-1;events.append({"type":"perk_end"})
	for entity in entities: entity.x+=(-speed+float(entity.vx))*dt
	update_civilians(dt)
	update_enemies(dt)
	while next_segment<99999 and next_pattern_world-world_px<1550:
		spawn_next_pattern()
	for i in range(members.size()-1,-1,-1):
		var m=members[i]
		if m.falling:
			m.x-=step
		else: m.x=move_toward(m.x,slot_x(i),dt*80)
		if not m.falling and m.x< -90:
			remove_member(i,"camera");continue
		m.run_phase+=dt*clampf(speed/240.0,1.15,2.65)
		m.air_pose=move_toward(float(m.air_pose),1.0 if m.y<FLOOR-4 else 0.0,dt*7)
		m.attack_left=maxf(0,m.attack_left-dt);m.push_left=maxf(0,m.push_left-dt)
		m.land_left=maxf(0,m.land_left-dt);m.arrival=maxf(0,m.arrival-dt);m.glide_left=maxf(0,m.glide_left-dt)
		var floor_here=has_floor(m.x)
		var previous_y=float(m.y)
		var was_grounded=not m.falling and m.y>=FLOOR-.1 and m.y<=FLOOR+2 and floor_here
		if was_grounded: m.coyote=.10;m.air_jumps=0
		else: m.coyote=maxf(0,m.coyote-dt)
		if not m.falling and not m.jump_queue.is_empty():
			var command=m.jump_queue[0]
			m.jump_delay=maxf(0,(float(command.at)-world_px-float(m.x))/maxf(1,speed))
			var can_launch=was_grounded or m.coyote>0 or (command.double and m.air_jumps<2)
			if world_px+float(m.x)+.01>=float(command.at) and can_launch:
				m.jump_queue.pop_front();m.wave_id=int(command.id);m.air_time=0
				m.vy=-560.0-int(levels.get("jump",0))*24.0;m.air_jumps+=1;m.coyote=0.0
				m.jump_delay=-1.0 if m.jump_queue.is_empty() else 0.0;m.jump_at=-1.0

		var flying=not m.falling and perk_kind==3 and perk_left>0
		if flying:
			# Balloon-style control: automatic ascent; held touch makes it dive.
			var target_y=FLOOR if jump_held else FLOOR-175
			var target_vy=clampf((target_y-m.y)*4.0,-220,260)
			m.vy=move_toward(m.vy,target_vy,dt*1250);m.y+=m.vy*dt
			m.y=clampf(m.y,FLOOR-210,FLOOR)
			if m.y==FLOOR and previous_y<FLOOR-2:
				m.land_left=.20;events.append({"type":"land","x":m.x,"y":FLOOR,"leader":i==0})
		else:
			m.air_time+=dt
			var held=jump_held and bool(wave_holds.get(int(m.wave_id),false)) and not m.falling
			var gravity=GRAVITY*(.65 if held and m.vy<0 and m.air_time<.60 else 1.0)
			m.vy+=gravity*dt;m.y+=m.vy*dt
			if not m.falling and m.glide_left>0 and not floor_here and m.y>FLOOR-60:
				m.y=FLOOR-60;m.vy=0.0
			# Landing is possible only when crossing the floor FROM ABOVE.
			elif not m.falling and floor_here and previous_y<=FLOOR+.01 and m.y>=FLOOR and m.vy>=0:
				if m.vy>250:
					m.land_left=.20;events.append({"type":"land","x":m.x,"y":FLOOR,"leader":i==0})
					if i==0 and clean_air: clean_jumps+=1;clean_air=false
				m.y=FLOOR;m.vy=0;m.air_jumps=0
			if m.y>FLOOR+12:
				if not m.falling: m.death_kind=perk_kind if perk_left>0 else int(m.kind)
				m.falling=true;m.jump_queue.clear();m.jump_delay=-1.0;m.jump_at=-1.0;m.coyote=0.0;m.glide_left=0.0
		if m.y>FLOOR+145 and active_count()==0:rescue_from_pit()
		if m.y>FLOOR+170:
			remove_member(i,"fall")
		elif i<3 and not m.falling and m.y>=FLOOR-.1 and m.y<=FLOOR+.1 and floor_here and m.jump_delay<0:
			var phase=int(float(m.run_phase)*2)
			if phase!=m.step_phase:
				m.step_phase=phase;events.append({"type":"step","x":m.x-6,"y":FLOOR})
	if members.is_empty(): finish(); return
	var lead=leader_index()
	if lead<0: return
	for e in entities:
		if e.taken: continue
		if dead or members.is_empty(): break
		lead=leader_index()
		if lead<0: break
		var body=members[lead]
		var centre=Vector2(body.x,body.y-48)
		if e.kind=="coin":
			var radius=46.0+int(levels.get("magnet",0))*65.0+(30 if boost_left>0 else 0)
			if centre.distance_to(Vector2(e.x,e.y))<radius:
				var amount=2 if boost_left>0 else 1
				e.taken=true;coins+=amount;events.append({"type":"coin","amount":amount,"x":e.x,"y":e.y})
			continue
		if e.kind in ["civilian","soldier","police"]:
			if e.state=="normal":
				for i in range(members.size()):
					var m=members[i]
					if m.falling or m.attack_left>0: continue
					if Vector2(m.x,m.y-52).distance_to(Vector2(e.x,e.y-50))<62:
						begin_capture(e,m);break
			continue
		if e.kind in ["crystal","mask","shield","boost"]:
			if e.kind=="mask" and 2 not in power_owned:continue
			if not power_eligible():e.taken=true;continue
			if centre.distance_to(Vector2(e.x,e.y))<72:
				e.taken=true
				match e.kind:
					"crystal": grant_perk(3)
					"mask": grant_perk(2)
					"shield": mark_power_collected();shields=1;bonuses+=1;events.append({"type":"guard","x":e.x,"y":e.y})
					"boost": mark_power_collected();boost_left=5.0;bonuses+=1;events.append({"type":"boost","x":e.x,"y":e.y})
			continue
		if MonsterCatalog.VEHICLES.has(e.kind):
			update_vehicle(e,dt);continue
		if e.kind not in ["crate","spikes","hump","bomb","bullet","helicopter","air_bomb"]: continue
		for i in range(members.size()):
			var m=members[i]
			if m.falling: continue
			var overlapping=false
			if e.kind in ["bullet","helicopter","air_bomb"]:
				var rx=16.0 if e.kind=="bullet" else (65.0 if e.kind=="helicopter" else 50.0)
				var ry=5.0 if e.kind=="bullet" else 28.0
				# The fuselage hurts; transparent rotor/tail space does not.
				var hit_y=e.y+(16 if e.kind=="helicopter" else 0)
				overlapping=helicopter_front_hit(e,m) if e.kind=="helicopter" else (absf(m.x-e.x)<rx+18 and m.y-101<hit_y+ry and m.y-6>hit_y-ry)
			else:
				var height=40.0 if e.kind=="spikes" else (64.0 if e.kind=="hump" else (86.0 if e.kind=="bomb" else 70.0))
				overlapping=absf(m.x-e.x)<e.width*.5+14 and m.y>FLOOR-height+10 and m.y<FLOOR+4
			if not overlapping: continue
			if perk_kind==2 and perk_left>0 and e.kind in ["crate","spikes","bomb","air_bomb"]:
				e.taken=true
				events.append({"type":"smash","object":e.kind,"x":e.x,"y":e.y-35 if e.y==FLOOR else e.y})
			else:
				var applied=damage(i,e.kind)
				if e.kind in ["bomb","bullet","helicopter","air_bomb"] and applied:
					e.taken=true
					if e.kind!="bullet": events.append({"type":"explosion","x":e.x,"y":e.y-35 if e.y==FLOOR else e.y})
			break
	for i in range(entities.size()-1,-1,-1):
		if entities[i].x< -850 and entities[i].state!="capture": entities.remove_at(i)

func distance() -> int:
	return int(world_px/30.0)

func stats() -> Dictionary:
	return {"distance":distance(),"coins":coins,"recruits":recruits,"souls":souls,"soldiers":soldiers,"rescues":rescues,"groups":groups,"cars":cars,
		"jumps":clean_jumps,"bonuses":bonuses,"horde":max_horde,"flights":flights,"boost":int(boost_px/30),"tunnels":completed_tunnels,"losses":losses}

func drain_events() -> Array[Dictionary]:
	var result=events.duplicate();events.clear();return result

func schedule_tunnel(number: int,entry: float) -> void:
	var predicted=minf(780,305+entry/230.0+maxi(0,number-1)*13)
	tunnels.append({"number":number,"entry":entry,"length":clampf(predicted*5.5,2100,4200),"from":route[(number-1)%route.size()],"to":route[number%route.size()],"entered":false,"completed":false})

func current_tunnel() -> Dictionary:
	for t in tunnels:
		if world_px<float(t.entry)+float(t.length): return t
	return {}

func update_tunnels() -> void:
	for t in tunnels:
		if not t.entered and world_px>=float(t.entry):
			t.entered=true;entered_tunnels=int(t.number)
			events.append({"type":"tunnel_enter","number":entered_tunnels})
		if not t.completed and world_px>=float(t.entry)+float(t.length):
			t.completed=true;completed_tunnels=int(t.number)
			var interval=18000.0*maxf(1,cruise_speed/305.0)
			schedule_tunnel(completed_tunnels+1,float(t.entry)+float(t.length)+interval)
			events.append({"type":"tunnel_exit","number":completed_tunnels,"area":area()})
			break

func spawn_civilians(x: float,count: int,group_id: int) -> void:
	if souls>=early_soul_limit():return
	count=3 if count>=3 else 1
	if count==3 and world_px+x-last_three_world<3000:count=1
	# Reserve the entire group footprint, including a margin at each pit edge.
	var clear=false
	for attempt in range(24):
		clear=true
		for i in range(count):
			if not civilian_floor_safe(x+i*92,85) or not safe_world_position(world_px+x+i*92):clear=false;break
		if clear:break
		x+=160
	if not clear:return
	var added=0
	for i in range(count):
		var at=x+i*92
		var e=add_entity("civilian",at,FLOOR,posmod(group_id+i,3));e.group=group_id;added+=1
	if added==3:last_three_world=world_px+x

func member_by_id(id: int) -> Dictionary:
	for m in members:
		if int(m.id)==id and not m.falling: return m
	return {}

func begin_capture(entity: Dictionary,member: Dictionary) -> void:
	if dead or member.falling or entity.state!="normal": return
	entity.state="capture";entity.capture_left=.62;entity.capturer=member.id
	entity.capture_kind=perk_kind if perk_left>0 else int(member.kind)
	entity.capture_offset=Vector2(32+int(entity.id)%3*9,-6)
	member.attack_left=.62
	events.append({"type":"capture","kind":entity.capture_kind,"x":entity.x,"y":entity.y-50})

func update_civilians(dt: float) -> void:
	for e in entities:
		if e.taken: continue
		e.age+=dt
		if e.kind in ["helicopter","air_bomb"]:
			e.y=e.base_y+sin(elapsed*3+e.bob)*6
		if e.kind not in ["civilian","soldier","police"]: continue
		if e.state=="capture":
			var m=member_by_id(int(e.capturer))
			if m.is_empty():
				e.state="normal";e.pose="panic";e.vy=-120
				continue
			e.x=m.x+e.capture_offset.x;e.y=m.y+e.capture_offset.y
			e.capture_left-=dt
			if e.capture_left<=0 and active_count()>0 and not dead: complete_capture(e)
		elif e.kind in ["civilian","police"]:
			protect_civilian_path(e)
			if e.vy!=0:
				e.vy+=GRAVITY*dt;e.y+=e.vy*dt
				if e.y>=FLOOR and e.vy>0:e.y=FLOOR;e.vy=0
			else:
				e.y=FLOOR-absf(sin(e.age*(3.0 if e.pose=="hop" else 4.5)+e.bob))*(42 if e.pose=="hop" else (9 if e.pose=="panic" else 0))

func complete_capture(entity: Dictionary) -> void:
	if entity.taken or dead or active_count()==0: return
	entity.taken=true;entity.state="converted"
	souls+=1;recruits+=1
	if entity.kind in ["soldier","police"]: soldiers+=1
	if entity.rescued: rescues+=1
	if int(entity.group)>=0:
		var count=int(group_captures.get(entity.group,0))+1;group_captures[entity.group]=count
		if count==3: groups+=1
	var kind=recruit_kind()
	add_member(kind,false,Vector2(entity.x,entity.y))
	events.append({"type":"soul","kind":kind,"x":entity.x,"y":entity.y-58,"soldier":entity.kind in ["soldier","police"]})

func update_vehicle(entity: Dictionary,dt: float) -> void:
	if entity.rushing:update_rushing_car(entity);return
	var spec=MonsterCatalog.VEHICLES[entity.kind]

	var alive={}
	for m in members:
		if not m.falling: alive[m.id]=true
	for id in entity.contacts.keys():
		var member=member_by_id(int(id))
		if not alive.has(id) or member.is_empty() or member.y<FLOOR-12 or absf(float(member.x)-(float(entity.x)-float(spec.width)*.5-18))>70:entity.contacts.erase(id)
	for m in members:
		if m.falling or m.y<FLOOR-float(spec.collision)-6 or m.y>FLOOR+2 or not has_floor(m.x): continue
		var edge=float(entity.x)-float(spec.width)*.5
		if m.x<edge-16 or m.x>float(entity.x)+float(spec.width)*.5+14: continue
		if not entity.contacts.has(m.id):
			if m.y>=FLOOR-12:entity.contacts[m.id]=member_force();entity.state="pushing"
			events.append({"type":"contact","x":edge,"y":FLOOR-30,"count":entity.contacts.size(),"need":spec.need})
		m.push_left=.15
		m.x=minf(m.x,edge-18)
	var count=entity.contacts.size()
	var effort=0
	for value in entity.contacts.values():effort+=int(value)
	var damage_stage=mini(2,int(float(effort)/float(spec.need)*3))
	if damage_stage>int(entity.damage_stage):
		entity.damage_stage=damage_stage;events.append({"type":"glass","x":entity.x,"y":FLOOR-float(spec.height)*.7})
	entity.tilt=move_toward(entity.tilt,minf(.62,float(effort)/float(spec.need)*.72),dt*2.5)
	if entity.state=="pushing":
		entity.push_age+=dt
		if effort>=int(spec.need):
			flip_vehicle(entity)
		elif entity.push_age>1.35 and not entity.get("weak_warned",false):
			entity.weak_warned=true
			events.append({"type":"weak_vehicle","x":entity.x,"y":FLOOR-120,"count":count,"need":spec.need})

func flip_vehicle(entity: Dictionary) -> void:
	if entity.taken: return
	var spec=MonsterCatalog.VEHICLES[entity.kind]
	entity.taken=true;cars+=1
	coins+=int(spec.reward)
	events.append({"type":"smash","object":entity.kind,"x":entity.x,"y":FLOOR-float(spec.height)*.5,"tilt":entity.tilt})
	events.append({"type":"coin","amount":spec.reward,"x":entity.x,"y":FLOOR-120})
	for i in range(entity.passengers.size()):
		var human=add_entity("civilian",entity.x-float(spec.width)*.3+i*43,FLOOR-40-i%2*20,int(entity.passengers[i]))
		human.vy=-230-float(i%3)*40;human.vx=-70;human.pose="panic";human.rescued=true;human.group=entity.id+2000000

func helicopter_front_hit(entity: Dictionary,member: Dictionary) -> bool:
	var head=member.y-101
	# Only the nose/cockpit leading edge can hurt. Belly, tail and rotor are safe.
	if head>entity.y+3:return false
	if member.vy<-40 and head>=entity.y-5:return false
	return member.x+18>entity.x-121 and member.x-18<entity.x-61 and head<entity.y+18 and member.y-30>entity.y-28

func civilian_floor_safe(x: float,margin: float=34) -> bool:
	for e in entities:
		if e.kind=="gap" and x>e.x-margin and x<e.x+e.width+margin:return false
	return true

func protect_civilian_path(e: Dictionary) -> void:
	for gap in entities:
		if gap.kind!="gap":continue
		var left=float(gap.x)-38
		var right=float(gap.x)+float(gap.width)+38
		if e.x>left and e.x<right:
			if e.x<(left+right)*.5:e.x=left;e.vx=-maxf(45,absf(e.vx))
			else:e.x=right;e.vx=maxf(45,absf(e.vx))
		elif e.x<=left and e.vx>0 and e.x+e.vx*.5>left:e.vx=-maxf(45,e.vx);e.pose="panic"
		elif e.x>=right and e.vx<0 and e.x+e.vx*.5<right:e.vx=maxf(45,-e.vx);e.pose="panic"

func power_eligible() -> bool:
	return maxi(1,tunnel_number())>=next_power_tunnel and transform_left<=0 and perk_left<=0

func mark_power_collected() -> void:
	next_power_tunnel=maxi(1,tunnel_number())+3
	for entity in entities:
		if entity.kind in ["crystal","mask","shield","boost"]:entity.taken=true

func try_spawn_power(x: float) -> bool:
	if not power_eligible() or not safe_world_position(world_px+x) or not civilian_floor_safe(x,60):return false
	for e in entities:
		if not e.taken and e.kind in ["crystal","mask","shield","boost"]:return false
	if rng.randf()>=.22:return false
	var choices=["crystal","shield","boost"]
	if 2 in power_owned:choices.append("mask")
	add_entity(choices[rng.randi_range(0,choices.size()-1)],x,FLOOR-65)
	return true

func spawn_rushing_car(x: float,group_id: int) -> Dictionary:
	var car=add_entity("car",x);car.rushing=true;car.vx=-clampf(cruise_speed*.42,180,290)
	car.passengers.clear();car.group=group_id
	return car

func update_rushing_car(car: Dictionary) -> void:
	if car.taken:return
	for i in range(members.size()):
		var m=members[i]
		if m.falling or m.y<FLOOR-86 or m.y>FLOOR+4:continue
		# The approaching bumper is the contact surface; its rear cannot hit twice.
		if absf(m.x-(float(car.x)-float(car.width)*.5))>30:continue
		# Consume this car on its first contact, including a shield/grace contact.
		car.taken=true
		damage(i,"rushing_car")
		events.append({"type":"rush_crash","x":car.x,"y":FLOOR-61,"object":"car"})
		return

func early_soul_limit() -> int:
	if tunnel_number()<=2:return 30+(4 if int(rng.seed)%29==0 else 0)
	return 999999

func remaining_soul_slots() -> int:
	var pending=0
	for entity in entities:
		if entity.taken:continue
		if entity.kind in ["civilian","soldier","police"]:pending+=1
		elif MonsterCatalog.VEHICLES.has(entity.kind):pending+=entity.passengers.size()
	return maxi(0,early_soul_limit()-souls-pending)
