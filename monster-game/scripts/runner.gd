class_name HordeRun
extends RefCounted

const FLOOR=574.0
const GRAVITY=1500.0
const ANCHOR=340.0
const SEGMENT=1450.0
var rng=RandomNumberGenerator.new()
var levels={}
var members: Array[Dictionary]=[]
var entities: Array[Dictionary]=[]
var events: Array[Dictionary]=[]
var elapsed=0.0
var world_px=0.0
var speed=285.0
var coins=0
var recruits=0
var cars=0
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

func start(upgrades: Dictionary,seed_value: int=0,skin: int=0) -> void:
	levels=upgrades.duplicate(true)
	rng.seed=seed_value if seed_value else Time.get_ticks_usec()
	members.clear();entities.clear();events.clear()
	elapsed=0;world_px=0;coins=0;recruits=0;cars=0;clean_jumps=0;bonuses=0;flights=0;boost_px=0
	shields=0;perk_kind=-1;perk_left=0;boost_left=0;next_segment=0;last_variant=-1
	dead=false;hit_grace=0;jumped=false;clean_air=false;speed=285;max_horde=1
	for i in range(1+int(levels.get("horde",0))): add_member(skin,false)
	for i in range(3): spawn_segment(i)
	next_segment=3

func add_member(kind: int,count_recruit: bool=true) -> void:
	if members.size()>=12:
		coins+=2;events.append({"type":"coin","amount":2,"x":ANCHOR,"y":FLOOR-70})
		return
	members.append({"kind":clampi(kind,0,3),"y":FLOOR,"vy":0.0,"jump_delay":-1.0,"jump_at":-1.0,
		"air_jumps":0,"coyote":.1,"land_left":0.0,"glide_left":0.0,"arrival":.35,"step_phase":-1})
	max_horde=maxi(max_horde,members.size())
	if count_recruit:
		recruits+=1
		events.append({"type":"recruit","x":ANCHOR,"y":FLOOR-50})

func add_entity(kind: String,x: float,y: float=FLOOR,variant: int=0,width: float=70) -> Dictionary:
	var entity={"kind":kind,"x":x,"y":y,"variant":variant,"width":width,"taken":false}
	entities.append(entity)
	return entity

func coin_arc(base: float,count: int=7,height: float=125,spacing: float=72) -> void:
	for i in range(count):
		add_entity("coin",base+i*spacing,FLOOR-48-sin(float(i)*PI/float(count-1))*height)

func spawn_segment(index: int) -> void:
	var base=float(index)*SEGMENT-world_px
	if index==0:
		add_entity("recruit",base+830,FLOOR,0)
		add_entity("recruit",base+1190,FLOOR,1)
		for i in range(6): add_entity("coin",base+880+i*72,FLOOR-50)
		return
	var variant=index-1 if index<6 else rng.randi_range(0,8)
	if variant==last_variant: variant=(variant+3)%9
	last_variant=variant
	add_entity("recruit",base+200,FLOOR,index%2)
	match variant:
		0:
			add_entity("crate",base+740,FLOOR,0,72)
			coin_arc(base+520)
		1:
			add_entity("gap",base+720,FLOOR,0,150)
			coin_arc(base+550,7,120,70)
		2:
			add_entity("crystal",base+340,FLOOR-70)
			add_entity("gap",base+760,FLOOR,0,230)
			for i in range(8): add_entity("coin",base+590+i*78,FLOOR-145)
		3:
			add_entity("mask",base+300,FLOOR-65)
			add_entity("car",base+850,FLOOR,0,155)
			coin_arc(base+550,7,50)
		4:
			add_entity("boost",base+330,FLOOR-60)
			add_entity("crate",base+970,FLOOR,0,72)
			coin_arc(base+670,8,110,70)
		5:
			add_entity("shield",base+300,FLOOR-65)
			add_entity("spikes",base+850,FLOOR,0,100)
			coin_arc(base+640,7,105,72)
		6:
			add_entity("gap",base+830,FLOOR,0,185)
			coin_arc(base+650,7,135,70)
		7:
			add_entity("recruit",base+450,FLOOR,0)
			add_entity("car",base+950,FLOOR,0,155)
			for i in range(7): add_entity("coin",base+510+i*60,FLOOR-55)
		8:
			add_entity("crate",base+780,FLOOR,0,72)
			add_entity("boost",base+360,FLOOR-70)
			coin_arc(base+580,7,160,70)
	if index>3 and rng.randf()<.65: add_entity("recruit",base+1290,FLOOR,index%2)

func member_x(index: int) -> float:
	return ANCHOR-float(index%6)*45.0-float(index/6)*23.0

func has_floor(x: float) -> bool:
	for e in entities:
		if e.kind=="gap" and x>e.x and x<e.x+e.width: return false
	return true

func grounded_strength() -> int:
	var count=0
	for i in range(members.size()):
		if members[i].y>FLOOR-12 and has_floor(member_x(i)): count+=1
	return count

func jump() -> void:
	if dead: return
	if perk_kind==3 and perk_left>0:
		events.append({"type":"wing","x":ANCHOR,"y":members[0].y-50})
		return
	var accepted=false
	for i in range(members.size()):
		var member=members[i]
		if member.jump_delay>=0: continue
		var may_double=int(levels.get("jump",0))>=2 and member.air_jumps<2
		if member.coyote>0 or may_double:
			# World positions remain correct even if a speed bonus starts midway.
			member.jump_at=world_px+ANCHOR-member_x(i)
			member.jump_delay=(ANCHOR-member_x(i))/speed
			accepted=true
	if accepted:
		jumped=true;clean_air=true
		events.append({"type":"jump","x":ANCHOR,"y":members[0].y})

func grant_perk(kind: int) -> void:
	perk_kind=kind
	perk_left=(7.0 if kind==3 else 9.0)+int(levels.get("perk",0))*2.0
	bonuses+=1
	if kind==3:
		flights+=1
		for m in members:
			m.jump_delay=-1.0;m.jump_at=-1.0
			m.vy=minf(m.vy,-180)
	events.append({"type":"perk","kind":kind,"x":ANCHOR,"y":members[0].y-65})

func damage(index: int) -> void:
	if hit_grace>0 or perk_left>0: return
	hit_grace=.65;clean_air=false
	if shields>0:
		shields-=1
		events.append({"type":"guard","x":member_x(index),"y":FLOOR-65})
		return
	if index>=members.size(): return
	var old=members[index]
	events.append({"type":"hit","x":member_x(index),"y":old.y-45,"kind":old.kind})
	members.remove_at(index)
	if members.is_empty(): finish()

func finish() -> void:
	if dead: return
	dead=true
	events.append({"type":"finish"})

func advance(dt: float,jump_held: bool=false) -> void:
	if dead: return
	elapsed+=dt
	boost_left=maxf(0,boost_left-dt)
	var target_speed=minf(425,285+world_px/2400)*(1.18 if boost_left>0 else 1.0)
	speed=move_toward(speed,target_speed,dt*280)
	var step=speed*dt
	world_px+=step
	if boost_left>0: boost_px+=step
	hit_grace=maxf(0,hit_grace-dt)
	if perk_left>0:
		perk_left=maxf(0,perk_left-dt)
		if perk_left<=0:
			if perk_kind==3:
				for m in members: m.glide_left=.9;m.coyote=.10;m.air_jumps=0
			perk_kind=-1
			events.append({"type":"perk_end"})
	for entity in entities: entity.x-=step
	while next_segment*SEGMENT-world_px<2300:
		spawn_segment(next_segment);next_segment+=1
	for i in range(members.size()-1,-1,-1):
		var m=members[i]
		m.land_left=maxf(0,m.land_left-dt)
		m.arrival=maxf(0,m.arrival-dt)
		m.glide_left=maxf(0,m.glide_left-dt)
		var floor_here=has_floor(member_x(i))
		var was_grounded=m.y>=FLOOR-.1 and floor_here
		if was_grounded:
			m.coyote=.10;m.air_jumps=0
		else: m.coyote=maxf(0,m.coyote-dt)
		if m.jump_delay>=0:
			m.jump_delay=(m.jump_at-world_px)/speed
			if m.jump_delay<=0:
				m.jump_delay=-1.0;m.jump_at=-1.0
				m.vy=-560.0-int(levels.get("jump",0))*24.0
				m.air_jumps+=1;m.coyote=0.0
		if perk_kind==3 and perk_left>0:
			# Flight responds to the same touch without requiring ground contact.
			var target_vy=-205.0 if jump_held or m.y>FLOOR-72 else 145.0
			m.vy=move_toward(m.vy,target_vy,dt*1100)
			m.y+=m.vy*dt
			m.y=maxf(m.y,FLOOR-300)
			if m.y==FLOOR-300: m.vy=0.0
			if target_vy>0 and m.y>FLOOR-72: m.y=FLOOR-72;m.vy=0.0
		else:
			var gravity=GRAVITY*(.65 if jump_held and m.vy<0 else 1.0)
			m.vy+=gravity*dt;m.y+=m.vy*dt
			if m.glide_left>0 and not floor_here and m.y>FLOOR-72:
				m.y=FLOOR-72;m.vy=0.0
			elif floor_here and m.y>FLOOR and m.vy>=0:
				if m.vy>250:
					m.land_left=.20
					events.append({"type":"land","x":member_x(i),"y":FLOOR,"leader":i==0})
					if i==0 and clean_air:
						clean_jumps+=1;clean_air=false
				m.y=FLOOR;m.vy=0
		if m.y>800:
			clean_air=false
			events.append({"type":"hit","x":member_x(i),"y":735,"kind":m.kind})
			members.remove_at(i)
		elif i<3 and m.y>=FLOOR-.1 and floor_here and m.jump_delay<0:
			var phase=int(world_px/42.0+float(i)*.18)
			if phase!=m.step_phase:
				m.step_phase=phase
				events.append({"type":"step","x":member_x(i)-6,"y":FLOOR})
	if members.is_empty(): finish(); return
	for e in entities:
		if e.taken: continue
		var body=members[0]
		var centre=Vector2(ANCHOR,body.y-48)
		if e.kind=="coin":
			var radius=46.0+int(levels.get("magnet",0))*65.0+(30 if boost_left>0 else 0)
			if centre.distance_to(Vector2(e.x,e.y))<radius:
				var amount=2 if boost_left>0 else 1
				e.taken=true;coins+=amount
				events.append({"type":"coin","amount":amount,"x":e.x,"y":e.y})
			continue
		if e.kind in ["recruit","crystal","mask","shield","boost"]:
			var target=Vector2(e.x,e.y-48) if e.kind=="recruit" else Vector2(e.x,e.y)
			# Flying can recruit from the ground without lowering into hazards.
			var reach=130 if perk_kind==3 and e.kind=="recruit" else 72
			if centre.distance_to(target)<reach:
				e.taken=true
				match e.kind:
					"recruit": add_member(e.variant)
					"crystal": grant_perk(3)
					"mask": grant_perk(2)
					"shield":
						shields=1;bonuses+=1
						events.append({"type":"guard","x":e.x,"y":e.y})
					"boost":
						boost_left=5.0;bonuses+=1
						events.append({"type":"boost","x":e.x,"y":e.y})
			continue
		if e.kind not in ["crate","car","spikes"]: continue
		for i in range(members.size()):
			var m=members[i]
			var obstacle_height=70.0 if e.kind!="spikes" else 40.0
			var overlapping=absf(member_x(i)-e.x)<e.width*.5+16 and m.y>FLOOR-obstacle_height+10 and m.y<FLOOR+70
			if overlapping:
				if perk_kind==3 and perk_left>0: break
				if (perk_kind==2 and perk_left>0) or (e.kind=="car" and grounded_strength()>=4):
					e.taken=true
					var reward=8 if e.kind=="car" else 3
					coins+=reward
					events.append({"type":"smash","object":e.kind,"x":e.x,"y":FLOOR-40})
					events.append({"type":"coin","amount":reward,"x":e.x,"y":FLOOR-85})
					if e.kind=="car":
						cars+=1;add_member(0)
				else: damage(i)
				break
	for i in range(entities.size()-1,-1,-1):
		if entities[i].x< -250: entities.remove_at(i)

func distance() -> int:
	return int(world_px/30.0)

func stats() -> Dictionary:
	return {"distance":distance(),"coins":coins,"recruits":recruits,"cars":cars,
		"jumps":clean_jumps,"bonuses":bonuses,"horde":max_horde,"flights":flights,"boost":int(boost_px/30)}

func drain_events() -> Array[Dictionary]:
	var result=events.duplicate()
	events.clear()
	return result
