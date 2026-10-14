class_name HordeRun
extends RefCounted

const FLOOR=574.0
const GRAVITY=1500.0
const ANCHOR=340.0
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
var shields=0
var perk_kind=-1
var perk_left=0.0
var next_segment=0
var dead=false
var hit_grace=0.0
var jumped=false

func start(upgrades: Dictionary,seed_value: int=0) -> void:
	levels=upgrades.duplicate(true)
	rng.seed=seed_value if seed_value else Time.get_ticks_usec()
	members.clear();entities.clear();events.clear()
	elapsed=0;world_px=0;coins=0;recruits=0;shields=0
	perk_kind=-1;perk_left=0;next_segment=0;dead=false;hit_grace=0;jumped=false
	for i in range(1+int(levels.get("horde",0))): add_member(0,false)
	for i in range(3): spawn_segment(i)
	next_segment=3

func add_member(kind: int,count_recruit: bool=true) -> void:
	if members.size()>=12:
		coins+=2;events.append({"type":"coin","amount":2,"x":ANCHOR,"y":FLOOR-70})
		return
	members.append({"kind":kind,"y":FLOOR,"vy":0.0,"jump_delay":-1.0,"air_jumps":0,"coyote":.1})
	if count_recruit:
		recruits+=1
		events.append({"type":"recruit","x":ANCHOR,"y":FLOOR-50})

func add_entity(kind: String,x: float,y: float=FLOOR,variant: int=0,width: float=70) -> Dictionary:
	var entity={"kind":kind,"x":x,"y":y,"variant":variant,"width":width,"taken":false}
	entities.append(entity)
	return entity

func spawn_segment(index: int) -> void:
	var base=float(index)*1700-world_px
	if index==0:
		add_entity("recruit",base+1000,FLOOR,0)
		add_entity("recruit",base+1450,FLOOR,1)
		for i in range(7): add_entity("coin",base+1050+i*82,FLOOR-50)
		return
	var variant=posmod(index-1,5)
	add_entity("recruit",base+220,FLOOR,index%2)
	match variant:
		0:
			add_entity("crate",base+750,FLOOR,0,72)
			for i in range(7): add_entity("coin",base+450+i*90,FLOOR-70-sin(i*PI/6)*75)
		1:
			add_entity("gap",base+720,FLOOR,0,145)
			for i in range(6): add_entity("coin",base+570+i*78,FLOOR-140)
		2:
			add_entity("crystal",base+350,FLOOR-70)
			add_entity("spikes",base+900,FLOOR,0,95)
			add_entity("car",base+1280,FLOOR,0,155)
			for i in range(7): add_entity("coin",base+600+i*90,FLOOR-115)
		3:
			add_entity("mask",base+320,FLOOR-55)
			add_entity("car",base+920,FLOOR,0,155)
			for i in range(7): add_entity("coin",base+470+i*100,FLOOR-55)
		4:
			add_entity("shield",base+360,FLOOR-70)
			add_entity("spikes",base+900,FLOOR,0,95)
			for i in range(8): add_entity("coin",base+440+i*92,FLOOR-90)
	if index>4 and rng.randf()<.5: add_entity("recruit",base+1430,FLOOR,index%2)

func member_x(index: int) -> float:
	return ANCHOR-float(index%6)*46.0-float(index/6)*20.0

func has_floor(x: float) -> bool:
	for e in entities:
		if e.kind=="gap" and x>e.x and x<e.x+e.width: return false
	return true

func jump() -> void:
	if dead: return
	var accepted=false
	for i in range(members.size()):
		var member=members[i]
		if member.jump_delay>=0: continue
		var may_double=int(levels.get("jump",0))>=2 and member.air_jumps<2
		if member.coyote>0 or may_double:
			# Each follower jumps at the same world position as the leader.
			# A nearly simultaneous jump makes trailing members land in a pit.
			member.jump_delay=(ANCHOR-member_x(i))/speed
			accepted=true
	if accepted:
		jumped=true
		events.append({"type":"jump","x":ANCHOR,"y":FLOOR})

func grant_perk(kind: int) -> void:
	perk_kind=kind
	perk_left=(7.0 if kind==3 else 9.0)+int(levels.get("perk",0))*2.0
	events.append({"type":"perk","kind":kind,"x":ANCHOR,"y":FLOOR-80})

func damage(index: int) -> void:
	if hit_grace>0 or perk_left>0: return
	hit_grace=.65
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
	speed=minf(425,285+world_px/2600)
	var step=speed*dt
	world_px+=step
	hit_grace=maxf(0,hit_grace-dt)
	if perk_left>0:
		perk_left=maxf(0,perk_left-dt)
		if perk_left<=0:
			perk_kind=-1
			events.append({"type":"perk_end"})
	for entity in entities: entity.x-=step
	while next_segment*1700-world_px<2300:
		spawn_segment(next_segment)
		next_segment+=1
	for i in range(members.size()-1,-1,-1):
		var m=members[i]
		var floor_here=has_floor(member_x(i))
		if m.y>=FLOOR-.1 and floor_here:
			m.coyote=.10
			m.air_jumps=0
		else: m.coyote=maxf(0,m.coyote-dt)
		if m.jump_delay>=0:
			m.jump_delay-=dt
			if m.jump_delay<0:
				m.vy=-560.0-int(levels.get("jump",0))*24.0
				m.air_jumps+=1
				m.coyote=0.0
		var gravity=GRAVITY*(.65 if jump_held and m.vy<0 else 1.0)
		m.vy+=gravity*dt
		m.y+=m.vy*dt
		if perk_kind==3 and perk_left>0 and m.y>FLOOR-18:
			m.y=FLOOR-18;m.vy=0
		elif floor_here and m.y>FLOOR and m.vy>=0:
			if m.vy>250: events.append({"type":"land","x":member_x(i),"y":FLOOR})
			m.y=FLOOR;m.vy=0
		if m.y>800:
			events.append({"type":"hit","x":member_x(i),"y":735,"kind":m.kind})
			members.remove_at(i)
	if members.is_empty(): finish(); return
	for e in entities:
		if e.taken: continue
		var body=members[0]
		var centre=Vector2(ANCHOR,body.y-48)
		if e.kind=="coin":
			var radius=46.0+int(levels.get("magnet",0))*65.0
			if centre.distance_to(Vector2(e.x,e.y))<radius:
				e.taken=true;coins+=1
				events.append({"type":"coin","amount":1,"x":e.x,"y":e.y})
			continue
		if e.kind in ["recruit","crystal","mask","shield"]:
			var target=Vector2(e.x,e.y-48) if e.kind=="recruit" else Vector2(e.x,e.y)
			if centre.distance_to(target)<72:
				e.taken=true
				match e.kind:
					"recruit": add_member(e.variant)
					"crystal": grant_perk(3)
					"mask": grant_perk(2)
					"shield":
						shields=1
						events.append({"type":"guard","x":e.x,"y":e.y})
			continue
		if e.kind not in ["crate","car","spikes"]: continue
		for i in range(members.size()):
			var m=members[i]
			var obstacle_height=70.0 if e.kind!="spikes" else 40.0
			var overlapping=absf(member_x(i)-e.x)<e.width*.5+16 and m.y>FLOOR-obstacle_height+10 and m.y<FLOOR+70
			if overlapping:
				if perk_left>0 or (e.kind=="car" and members.size()>=5):
					e.taken=true
					coins+=3
					events.append({"type":"smash","x":e.x,"y":FLOOR-35})
					events.append({"type":"coin","amount":3,"x":e.x,"y":FLOOR-60})
				else:
					damage(i)
				break
	for i in range(entities.size()-1,-1,-1):
		if entities[i].x< -250: entities.remove_at(i)

func distance() -> int:
	return int(world_px/30.0)

func drain_events() -> Array[Dictionary]:
	var result=events.duplicate()
	events.clear()
	return result
