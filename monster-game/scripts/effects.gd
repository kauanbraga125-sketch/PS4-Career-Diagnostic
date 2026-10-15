class_name HordeEffects
extends RefCounted

const LIMIT=240
var particles: Array[Dictionary]=[]
var trails: Array[Dictionary]=[]
var flashes: Array[Dictionary]=[]
var deaths: Array[Dictionary]=[]
var wrecks: Array[Dictionary]=[]

func clear() -> void:
	particles.clear();trails.clear();flashes.clear();deaths.clear();wrecks.clear()

func add(kind: String,pos: Vector2,velocity: Vector2,color: Color,size: float,life: float,gravity: float=0,drift: bool=true) -> Dictionary:
	if particles.size()>=LIMIT: particles.pop_front()
	var p={"kind":kind,"pos":pos,"velocity":velocity,"color":color,"size":size,"life":life,"duration":life,"gravity":gravity,"drift":drift,"spin":randf_range(-6,6),"rotation":randf_range(-PI,PI)}
	particles.append(p)
	return p

func dust(pos: Vector2,count: int=6,force: float=1) -> void:
	for i in range(count):
		add("dust",pos+Vector2(randf_range(-10,10),-2),Vector2(randf_range(-50,50),randf_range(-55,-12))*force,Color("baafc2"),randf_range(4,9)*force,randf_range(.28,.55),-10)

func spark(pos: Vector2,color: Color,count: int=12) -> void:
	for i in range(count):
		add("spark",pos,Vector2(randf_range(-170,170),randf_range(-200,45)),color,randf_range(2,5),randf_range(.30,.70),190)

func ring(pos: Vector2,color: Color) -> void:
	add("ring",pos,Vector2.ZERO,color,22,.55)

func pickup(pos: Vector2,icon: int,target: Vector2) -> void:
	var p=add("pickup",pos,Vector2.ZERO,Color.WHITE,26,.48,0,false)
	p.origin=pos;p.target=target;p.icon=icon

func smash(pos: Vector2,object_kind: String,start_angle: float=0) -> void:
	dust(Vector2(pos.x,HordeRun.FLOOR),13,1.4)
	spark(pos,Color("ffc66a"),22)
	ring(pos,Color("ee917e"))
	for i in range(8): add("chip",pos,Vector2(randf_range(-190,170),randf_range(-260,-100)),Color("99705f"),randf_range(3,8),.9,750)
	if MonsterCatalog.VEHICLES.has(object_kind):
		if wrecks.size()>=12:wrecks.pop_front()
		wrecks.append({"object":object_kind,"pos":pos,"origin_y":pos.y,"age":0.0,"start_angle":start_angle})
	elif object_kind in ["bomb","helicopter","air_bomb"]: explosion(pos)

func capture(pos: Vector2,kind: int) -> void:
	var p=add("capture",pos,Vector2.ZERO,Color.WHITE,110,.55)
	p.monster=kind
	spark(pos,[Color("9ce4c7"),Color("fff1d3"),Color("ee917e"),Color("c39cf3")][clampi(kind,0,3)],12)

func soul(pos: Vector2,target: Vector2,life: float=.75) -> void:
	var p=add("soul",pos,Vector2.ZERO,Color.WHITE,36,life,0,false)
	p.origin=pos;p.target=target

func explosion(pos: Vector2) -> void:
	add("explosion",pos,Vector2.ZERO,Color.WHITE,140,.62)
	spark(pos,Color("ffc66a"),25);dust(pos,10,1.4)

func death(kind: int,pos: Vector2) -> void:
	if deaths.size()>=24: deaths.pop_front()
	deaths.append({"kind":kind,"pos":Vector2(pos.x,HordeRun.FLOOR),"life":.85,"duration":.85})
	if kind==1:
		for index in [0,1,2,3,4,5,6,7,5,6,7]:
			var p=add("bone",pos+Vector2(randf_range(-12,12),randf_range(-45,18)),Vector2(randf_range(-140,140),randf_range(-250,-70)),Color.WHITE,35 if index==0 else 20,.80,850)
			p.part=index
	elif kind==2:
		var p=add("mask",pos-Vector2(0,28),Vector2(80,-180),Color.WHITE,43,.80,700)
		for i in range(14): add("dust",pos+Vector2(0,-30),Vector2(randf_range(-60,60),randf_range(-80,-20)),Color("ae8bca"),randf_range(8,16),.55)
	elif kind==3:
		add("fly",pos-Vector2(0,20),Vector2(60,-70),Color.WHITE,48,.80,450)
		for i in range(4):
			var wing=add("wing",pos,Vector2(randf_range(-100,100),randf_range(-130,-50)),Color(.85,.75,1,.9),30,.75,320)
			wing.spin=12
	else: dust(Vector2(pos.x,HordeRun.FLOOR),12,1.2)

func ghost(kind: int,foot: Vector2,phase: float,state: String,landing: float) -> void:
	if trails.size()>=8: trails.pop_front()
	trails.append({"kind":kind,"foot":foot,"phase":phase,"state":state,"landing":landing,"life":.32})

func update(dt: float,speed: float) -> void:
	for w in wrecks:
		w.age+=dt;w.pos.x-=speed*dt
		var height=float(MonsterCatalog.VEHICLES[w.object].height)
		w.pos.y=HordeRun.FLOOR-height*.44-sin(minf(1,w.age/.7)*PI)*46
	for i in range(wrecks.size()-1,-1,-1):
		if wrecks[i].pos.x+float(MonsterCatalog.VEHICLES[wrecks[i].object].width)*.5< -650:wrecks.remove_at(i)
	for i in range(particles.size()-1,-1,-1):
		var p=particles[i]
		p.life-=dt
		p.pos+=p.velocity*dt
		if p.drift: p.pos.x-=speed*dt
		p.velocity.y+=p.gravity*dt
		p.rotation+=p.spin*dt
		if p.kind=="vehicle" and p.pos.y>HordeRun.FLOOR-p.size*.45:
			p.pos.y=HordeRun.FLOOR-p.size*.45;p.velocity.y=0
		if p.life<=0: particles.remove_at(i)
	for i in range(trails.size()-1,-1,-1):
		trails[i].life-=dt;trails[i].foot.x-=speed*dt*.85
		if trails[i].life<=0: trails.remove_at(i)
	for i in range(deaths.size()-1,-1,-1):
		deaths[i].life-=dt;deaths[i].pos.x-=speed*dt
		if deaths[i].life<=0: deaths.remove_at(i)

func draw_trails(canvas: Node2D,actor: HordeActor,time: float) -> void:
	for p in trails:
		actor.paint(canvas,p.kind,p.foot,112,p.phase,p.state,time,p.landing,Color(.65,1,.9,.18*p.life/.32))

func paint(canvas: Node2D,art: HordeArt,actor: HordeActor=null) -> void:
	for d in deaths:
		if d.kind!=0: continue
		var t=1-d.life/d.duration
		var point=d.pos+Vector2(0,maxf(0,t-.63)*140)
		var alpha=minf(1,d.life/.18)
		if actor!=null and t<.5: actor.paint(canvas,0,point-Vector2(0,20-t*80),90*(1-t*.7),t,"fall",t,0,Color(1,1,1,alpha))
		var size=art.props[1].get_size()*(112/art.props[1].get_height())
		canvas.draw_set_transform(point-Vector2(0,48),-.3,Vector2(1,1))
		canvas.draw_texture_rect(art.props[1],Rect2(-size*.5,size),false,Color(1,1,1,alpha))
		if t>.25:
			var closing=clampf((t-.25)/.25,0,1)
			var lid_size=art.props[2].get_size()*(108/art.props[2].get_height())
			canvas.draw_set_transform(point+Vector2((1-closing)*55,-50),-.3-(1-closing)*.8)
			canvas.draw_texture_rect(art.props[2],Rect2(-lid_size*.5,lid_size),false,Color(1,1,1,alpha))
		canvas.draw_set_transform(Vector2.ZERO)
	for p in particles:
		var progress=1.0-p.life/p.duration
		var color=p.color
		color.a*=minf(1,p.life/p.duration*1.6)
		match p.kind:
			"speed":
				canvas.draw_set_transform(p.pos)
				canvas.draw_line(Vector2.ZERO,Vector2(-p.size,0),color,2,true)
			"dust":
				canvas.draw_set_transform(p.pos,0,Vector2(1.3,.7))
				color.a*=.35
				var size=p.size*(.6+progress*1.3)
				canvas.draw_circle(Vector2.ZERO,size,color)
				canvas.draw_circle(Vector2(-size*.5,-size*.4),size*.7,color)
				canvas.draw_circle(Vector2(size*.6,-size*.2),size*.6,color)
			"ring":
				canvas.draw_set_transform(p.pos,0,Vector2(1,.7))
				canvas.draw_arc(Vector2.ZERO,p.size+progress*68,0,TAU,30,color,3,true)
			"spark":
				canvas.draw_set_transform(p.pos,p.rotation)
				canvas.draw_circle(Vector2.ZERO,p.size*2,Color(color.r,color.g,color.b,color.a*.12))
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(0,-p.size),Vector2(p.size*.3,-p.size*.3),Vector2(p.size,0),Vector2(p.size*.3,p.size*.3),Vector2(0,p.size),Vector2(-p.size*.3,p.size*.3),Vector2(-p.size,0),Vector2(-p.size*.3,-p.size*.3)]),color)
			"chip":
				canvas.draw_set_transform(p.pos,p.rotation)
				canvas.draw_rect(Rect2(-p.size*.5,-p.size*.5,p.size,p.size),color)
			"vehicle":
				canvas.draw_set_transform(p.pos,minf(PI,p.get("start_angle",0)+(PI-p.get("start_angle",0))*progress*1.65),Vector2(-1 if MonsterCatalog.VEHICLES[p.object].reverse else 1,1))
				var texture=art.vehicle(p.object)
				var size=Vector2(MonsterCatalog.VEHICLES[p.object].width,p.size)
				canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,color)
			"capture":
				var texture=art.vfx[3+mini(2,int(progress*3))]
				var size=texture.get_size()*(p.size/texture.get_height())
				canvas.draw_set_transform(p.pos,progress*.3)
				canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,color)
			"soul":
				var t=1-pow(1-progress,2)
				var pos=p.origin.lerp(p.target,t)+Vector2(sin(progress*TAU)*18,-sin(progress*PI)*80)
				canvas.draw_set_transform(pos,sin(progress*TAU)*.1)
				canvas.draw_circle(Vector2.ZERO,23,Color(.3,1,.8,color.a*.08))
				var texture=art.soul(progress*1.2)
				var size=texture.get_size()*(p.size/texture.get_height())*(1-progress*.4)
				canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,color)
			"bone","mask","fly","wing","explosion":
				var texture: Texture2D=art.props[5]
				match p.kind:
					"bone": texture=art.rigs[1][p.part]
					"mask": texture=art.rigs[2][0]
					"fly": texture=art.rigs[3][0]
					"wing": texture=art.rigs[3][8]
				var size=texture.get_size()*(p.size/texture.get_height())
				if p.kind=="explosion": size*=.7+progress*.7
				canvas.draw_set_transform(p.pos,0 if p.kind=="explosion" else p.rotation)
				canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,color)
			"pickup":
				var t=1-pow(1-progress,3)
				var pos=p.origin.lerp(p.target,t)+Vector2(0,-sin(progress*PI)*65)
				var texture=art.items[p.icon]
				var size=texture.get_size()*(p.size/texture.get_height())*(1-progress*.55)
				canvas.draw_set_transform(pos,progress*TAU)
				canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,color)
		canvas.draw_set_transform(Vector2.ZERO)

func paint_wrecks(canvas: Node2D,art: HordeArt,time: float,left: float) -> void:
	for w in wrecks:
		var spec=MonsterCatalog.VEHICLES[w.object]
		var size=Vector2(spec.width,spec.height)
		if w.pos.x+size.x*.5<left-90:continue
		var turn=clampf(w.age/.7,0,1)
		var angle=lerpf(float(w.start_angle),PI,smoothstep(0,1,turn))
		var mix=smoothstep(.65,1.0,turn)
		canvas.draw_set_transform(w.pos,angle,Vector2(-1 if spec.reverse else 1,1))
		canvas.draw_texture_rect(art.damaged_vehicles[int(spec.icon)],Rect2(-size*.5,size),false,Color(1,1,1,1-mix))
		canvas.draw_set_transform(w.pos,0,Vector2(1 if spec.reverse else -1,1))
		canvas.draw_texture_rect(art.wreck_vehicles[int(spec.icon)],Rect2(-size*Vector2(.5,.44),size*Vector2(1,.88)),false,Color(1,1,1,mix))
		canvas.draw_set_transform(Vector2.ZERO)
		if w.age<.55:continue
		var places={"moto":[-.08],"car":[-.30,.16],"bus":[-.34,-.12,.12,.34],"truck":[-.34,.18],"tank":[-.12,.23],"plane":[-.24,.02,.29]}[w.object]
		var height={"moto":65,"car":92,"bus":128,"truck":148,"tank":165,"plane":168}[w.object]
		for i in range(places.size()):
			var at=Vector2(w.pos.x+float(places[i])*size.x,HordeRun.FLOOR-size.y*.27)
			var grow=smoothstep(.55,1.5,w.age)
			var frame=(3 if w.object in ["truck","tank","plane"] else 0)+posmod(int(time*10+i),3)
			var h=float(height)*grow*(1+sin(time*7+i)*.07)
			var texture=art.fire_frames[frame]
			var flame_size=texture.get_size()*(h/texture.get_height())
			canvas.draw_circle(at-Vector2(0,h*.3),h*.65,Color(1,.36,.06,.045*grow))
			canvas.draw_texture_rect(texture,Rect2(at-Vector2(flame_size.x*.5,h),flame_size),false)
			for spark in range(2):
				var phase=fposmod(time*.8+i*.4+spark*.5,1)
				canvas.draw_circle(at+Vector2(sin(time*3+i+spark)*h*.18,-phase*h),1.7,Color(1,.67,.19,1-phase))
