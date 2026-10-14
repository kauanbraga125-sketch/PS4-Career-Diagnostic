class_name HordeRun
extends RefCounted

const FLOOR=574.0
const GRAVITY=1500.0
const ANCHOR=MonsterCatalog.ANCHOR
const SEGMENT=1700.0
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

func start(upgrades: Dictionary,seed_value: int=0,skin: int=0,areas: Array=[0,1]) -> void:
	levels=upgrades.duplicate(true)
	route.assign([0,1])
	for area in areas:
		if int(area) in [2,3] and int(area) not in route: route.append(int(area))
	rng.seed=seed_value if seed_value else Time.get_ticks_usec()
	members.clear();entities.clear();events.clear();loss_times.clear()
	elapsed=0;world_px=0;coins=0;recruits=0;cars=0;losses=0;shots=0;clean_jumps=0;bonuses=0;flights=0;boost_px=0
	shields=0;perk_kind=-1;perk_left=0;boost_left=0;next_segment=0;last_variant=-1
	dead=false;hit_grace=0;jumped=false;clean_air=false;speed=275;pressure=0;recovery_left=0;recovery_speed=275
	max_horde=1;next_member_id=0;last_area=0;last_tunnel=0
	for i in range(1+int(levels.get("horde",0))): add_member(skin,false)
	for i in range(3): spawn_segment(i)
	next_segment=3

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

func add_member(kind: int,count_recruit: bool=true) -> void:
	if dead or (not members.is_empty() and active_count()==0): return
	if members.size()>=MAX_HORDE:
		coins+=2;events.append({"type":"coin","amount":2,"x":ANCHOR,"y":FLOOR-70})
		return
	var index=members.size()
	members.append({"id":next_member_id,"kind":clampi(kind,0,3),"x":slot_x(index),"y":FLOOR,"vy":0.0,"jump_delay":-1.0,"jump_at":-1.0,
		"air_jumps":0,"coyote":.1,"land_left":0.0,"glide_left":0.0,"arrival":.35,"step_phase":-1,"falling":false})
	next_member_id+=1;max_horde=maxi(max_horde,active_count())
	if count_recruit:
		recruits+=1;events.append({"type":"recruit","x":slot_x(index),"y":FLOOR-50})

func add_entity(kind: String,x: float,y: float=FLOOR,variant: int=0,width: float=70) -> Dictionary:
	var entity={"kind":kind,"x":x,"y":y,"variant":variant,"width":width,"taken":false,
		"vx":-105.0 if kind=="helicopter" else (-190.0 if kind=="bullet" else 0.0),
		"timer":rng.randf_range(1.3,2.0),"flash":0.0,"bob":rng.randf_range(0,TAU)}
	if MonsterCatalog.VEHICLES.has(kind): entity.width=MonsterCatalog.VEHICLES[kind].width
	entities.append(entity)
	return entity

func coin_arc(base: float,count: int=7,height: float=125,spacing: float=72) -> void:
	for i in range(count): add_entity("coin",base+i*spacing,FLOOR-48-sin(float(i)*PI/float(count-1))*height)

func tunnel_number() -> int:
	return int((world_px+ANCHOR)/ZONE_LENGTH)

func area() -> int:
	return route[posmod(tunnel_number(),route.size())]

func tunnel_phase() -> float:
	return fposmod(world_px+ANCHOR,ZONE_LENGTH)

func inside_tunnel() -> bool:
	var phase=tunnel_phase()
	return phase>ZONE_LENGTH-650 or (tunnel_number()>0 and phase<220)

func safe_world_position(x: float) -> bool:
	var phase=fposmod(x,ZONE_LENGTH)
	return phase<ZONE_LENGTH-650 and (x<ZONE_LENGTH or phase>220)

func spawn_segment(index: int) -> void:
	var absolute=float(index)*SEGMENT
	var base=absolute-world_px
	if index==0:
		add_entity("recruit",base+800,FLOOR,0)
		add_entity("recruit",base+1170,FLOOR,1)
		for i in range(7): add_entity("coin",base+870+i*72,FLOOR-50)
		return
	var p=HordeDirector.profile(world_px,active_count(),pressure,recovery_left)
	var variant=index-1 if index<6 else rng.randi_range(0,14)
	if float(p.difficulty)>.65 and rng.randf()<.55: variant=rng.randi_range(8,14)
	if variant==last_variant: variant=(variant+3)%15
	last_variant=variant
	if rng.randf()<float(p.recruit_chance):
		add_entity("recruit",base+220,FLOOR,index%2)
		if recovery_left>0 or active_count()<4: add_entity("recruit",base+405,FLOOR,(index+1)%2)
	var hazard="crate"
	var gap_width=float(p.gap)
	match variant:
		0: hazard="crate";coin_arc(base+500)
		1: hazard="gap";coin_arc(base+620,7,140,(gap_width+170)/6)
		2: hazard="moto";coin_arc(base+530,7,70)
		3:
			hazard="gap";add_entity("crystal",base+330,FLOOR-65)
			for i in range(8): add_entity("coin",base+550+i*76,FLOOR-190)
		4: hazard="car";coin_arc(base+520,7,85)
		5:
			hazard="bus";add_entity("mask",base+300,FLOOR-65);coin_arc(base+530,7,60)
		6:
			hazard="bomb";add_entity("shield",base+310,FLOOR-70);coin_arc(base+510,7,100)
		7:
			hazard="crate";add_entity("boost",base+320,FLOOR-60);coin_arc(base+570,7,120)
		8: hazard="soldier" if int(p.stage)>=1 else "spikes";coin_arc(base+540)
		9: hazard="helicopter" if int(p.stage)>=1 else "bomb";coin_arc(base+540,7,140)
		10: hazard="bus";coin_arc(base+530,7,145)
		11: hazard="tank" if int(p.stage)>=3 or area()==2 else "truck";coin_arc(base+530,7,140)
		12: hazard="plane" if int(p.stage)>=4 or area()==3 else "car";coin_arc(base+520,7,160)
		13: hazard="bomb";coin_arc(base+530,7,100)
		14: hazard="gap";coin_arc(base+620,7,150,(gap_width+170)/6)
	if safe_world_position(absolute+800):
		add_entity(hazard,base+800,FLOOR-65 if hazard=="helicopter" else FLOOR,0,gap_width if hazard=="gap" else 85)
	if index>=5 and rng.randf()<float(p.extra_hazard) and safe_world_position(absolute+1580):
		var extra="bomb" if rng.randf()<.65 else ("soldier" if int(p.stage)>=2 else "crate")
		add_entity(extra,base+1580,FLOOR,0,72)
	if rng.randf()<float(p.recruit_chance)*.65: add_entity("recruit",base+1420,FLOOR,index%2)

func has_floor(x: float) -> bool:
	for e in entities:
		if e.kind=="gap" and x>e.x and x<e.x+e.width: return false
	return true

func grounded_strength() -> int:
	var count=0
	for m in members:
		if not m.falling and m.y>=FLOOR-12 and m.y<=FLOOR+2 and has_floor(m.x): count+=1
	return count

func jump() -> void:
	if dead: return
	var lead=leader_index()
	if lead<0: return
	if perk_kind==3 and perk_left>0:
		events.append({"type":"wing","x":members[lead].x,"y":members[lead].y-50})
		return
	var accepted=false
	for m in members:
		if m.falling or m.jump_delay>=0: continue
		var may_double=int(levels.get("jump",0))>=2 and m.air_jumps<2 and m.y<=FLOOR+8
		if m.coyote>0 or may_double:
			m.jump_at=world_px+maxf(0,members[lead].x-m.x)
			m.jump_delay=maxf(0,members[lead].x-m.x)/speed
			accepted=true
	if accepted:
		jumped=true;clean_air=true
		events.append({"type":"jump","x":members[lead].x,"y":members[lead].y})

func grant_perk(kind: int) -> void:
	var lead=leader_index()
	if dead or lead<0: return
	perk_kind=kind
	perk_left=(7.0 if kind==3 else 9.0)+int(levels.get("perk",0))*2.0
	bonuses+=1
	if kind==3:
		flights+=1
		for m in members:
			if m.falling: continue
			m.jump_delay=-1.0;m.jump_at=-1.0;m.vy=minf(m.vy,-180)
	events.append({"type":"perk","kind":kind,"x":members[lead].x,"y":members[lead].y-65})

func register_loss() -> void:
	losses+=1;loss_times.append(elapsed)
	while not loss_times.is_empty() and loss_times[0]<elapsed-4.5: loss_times.pop_front()
	if (loss_times.size()>=3 or active_count()<=3) and recovery_left<=0 and active_count()>0:
		recovery_left=7.0;recovery_speed=maxf(275,speed*.93);pressure=maxf(0,pressure-.35)
		add_entity("recruit",1340,FLOOR,0)
		add_entity("recruit",1560,FLOOR,1)
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
	if hit_grace>0 or (perk_kind==2 and perk_left>0): return false
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
	var p=HordeDirector.profile(world_px,active_count(),pressure,recovery_left)
	for e in entities:
		if e.taken: continue
		e.flash=maxf(0,e.flash-dt)
		if e.kind=="soldier" and e.x>ANCHOR+230 and e.x<1390:
			e.timer-=dt
			if e.timer<=0:
				e.timer=float(p.bullet_period);e.flash=.16;shots+=1
				pending.append({"x":e.x-56,"y":FLOOR-64})
				events.append({"type":"shot","x":e.x-56,"y":FLOOR-64})
	for bullet in pending: add_entity("bullet",bullet.x,bullet.y,0,18)

func advance(dt: float,jump_held: bool=false) -> void:
	if dead: return
	elapsed+=dt;boost_left=maxf(0,boost_left-dt);recovery_left=maxf(0,recovery_left-dt)
	var p=HordeDirector.profile(world_px,active_count(),pressure,recovery_left)
	pressure=move_toward(pressure,float(p.pressure_target),dt*.17)
	var target_speed=float(p.speed)
	if recovery_left>0: target_speed=minf(target_speed,recovery_speed)
	target_speed*=1.18 if boost_left>0 else 1.0
	speed=move_toward(speed,target_speed,dt*42)
	var step=speed*dt;world_px+=step
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
	update_enemies(dt)
	while next_segment*SEGMENT-world_px<1900:
		spawn_segment(next_segment);next_segment+=1
	for i in range(members.size()-1,-1,-1):
		var m=members[i]
		if m.falling:
			m.x-=step
		else: m.x=move_toward(m.x,slot_x(i),dt*80)
		m.land_left=maxf(0,m.land_left-dt);m.arrival=maxf(0,m.arrival-dt);m.glide_left=maxf(0,m.glide_left-dt)
		var floor_here=has_floor(m.x)
		var previous_y=float(m.y)
		var was_grounded=not m.falling and m.y>=FLOOR-.1 and m.y<=FLOOR+2 and floor_here
		if was_grounded: m.coyote=.10;m.air_jumps=0
		else: m.coyote=maxf(0,m.coyote-dt)
		if not m.falling and m.jump_delay>=0:
			m.jump_delay=(m.jump_at-world_px)/speed
			if m.jump_delay<=0:
				m.jump_delay=-1.0;m.jump_at=-1.0;m.vy=-560.0-int(levels.get("jump",0))*24.0;m.air_jumps+=1;m.coyote=0.0
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
			var gravity=GRAVITY*(.65 if jump_held and m.vy<0 and not m.falling else 1.0)
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
				m.falling=true;m.jump_delay=-1.0;m.jump_at=-1.0;m.coyote=0.0;m.glide_left=0.0
		if m.y>FLOOR+170:
			remove_member(i,"fall")
		elif i<3 and not m.falling and m.y>=FLOOR-.1 and m.y<=FLOOR+.1 and floor_here and m.jump_delay<0:
			var phase=int(world_px/42.0+float(i)*.18)
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
		if e.kind in ["recruit","crystal","mask","shield","boost"]:
			var target=Vector2(e.x,e.y-48) if e.kind=="recruit" else Vector2(e.x,e.y)
			if centre.distance_to(target)<72:
				e.taken=true
				match e.kind:
					"recruit": add_member(e.variant)
					"crystal": grant_perk(3)
					"mask": grant_perk(2)
					"shield":
						shields=1;bonuses+=1;events.append({"type":"guard","x":e.x,"y":e.y})
					"boost":
						boost_left=5.0;bonuses+=1;events.append({"type":"boost","x":e.x,"y":e.y})
			continue
		var vehicle=MonsterCatalog.VEHICLES.get(e.kind,{})
		if vehicle.is_empty() and e.kind not in ["crate","spikes","bomb","bullet","soldier","helicopter"]: continue
		for i in range(members.size()):
			var m=members[i]
			if m.falling: continue
			var overlapping=false
			if e.kind in ["bullet","helicopter"]:
				var radius=32 if e.kind=="bullet" else 54
				overlapping=Vector2(m.x,m.y-54).distance_to(Vector2(e.x,e.y))<radius
			else:
				var height=float(vehicle.get("collision",70.0))
				if e.kind=="spikes": height=40
				if e.kind=="bomb": height=54
				if e.kind=="soldier": height=95
				overlapping=absf(m.x-e.x)<e.width*.5+14 and m.y>FLOOR-height+10 and m.y<FLOOR+4
			if not overlapping: continue
			var masked=perk_kind==2 and perk_left>0
			var can_flip=not vehicle.is_empty() and grounded_strength()>=int(vehicle.need)
			if masked or can_flip:
				e.taken=true
				var reward=int(vehicle.get("reward",3))
				coins+=reward
				events.append({"type":"smash","object":e.kind,"x":e.x,"y":FLOOR-float(vehicle.get("height",80))*.5})
				events.append({"type":"coin","amount":reward,"x":e.x,"y":FLOOR-100})
				if not vehicle.is_empty():
					cars+=1
					for extra in range(int(vehicle.rescues)): add_member(extra%2)
				elif e.kind=="soldier": add_member(0)
			else:
				var applied=damage(i,e.kind)
				if e.kind in ["bomb","bullet","helicopter","soldier"] and applied:
					e.taken=true
					if e.kind in ["bomb","helicopter"]: events.append({"type":"explosion","x":e.x,"y":e.y if e.kind=="helicopter" else FLOOR-30})
			break
	for i in range(entities.size()-1,-1,-1):
		if entities[i].x< -350: entities.remove_at(i)

func distance() -> int:
	return int(world_px/30.0)

func stats() -> Dictionary:
	return {"distance":distance(),"coins":coins,"recruits":recruits,"cars":cars,
		"jumps":clean_jumps,"bonuses":bonuses,"horde":max_horde,"flights":flights,"boost":int(boost_px/30),"tunnels":tunnel_number(),"losses":losses}

func drain_events() -> Array[Dictionary]:
	var result=events.duplicate();events.clear();return result
