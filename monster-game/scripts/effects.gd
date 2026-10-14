class_name HordeEffects
extends RefCounted

const LIMIT=240
var particles: Array[Dictionary]=[]
var trails: Array[Dictionary]=[]
var flashes: Array[Dictionary]=[]

func clear() -> void:
	particles.clear();trails.clear();flashes.clear()

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

func smash(pos: Vector2,car: bool) -> void:
	dust(Vector2(pos.x,HordeRun.FLOOR),13,1.4)
	spark(pos,Color("ffc66a"),22)
	ring(pos,Color("ee917e"))
	for i in range(8): add("chip",pos,Vector2(randf_range(-190,170),randf_range(-260,-100)),Color("99705f"),randf_range(3,8),.9,750)
	if car:
		var p=add("car",pos,Vector2(125,-340),Color.WHITE,91,1.12,880)
		p.rotation=0

func ghost(kind: int,foot: Vector2,phase: float,state: String,landing: float) -> void:
	if trails.size()>=8: trails.pop_front()
	trails.append({"kind":kind,"foot":foot,"phase":phase,"state":state,"landing":landing,"life":.32})

func update(dt: float,speed: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p=particles[i]
		p.life-=dt
		p.pos+=p.velocity*dt
		if p.drift: p.pos.x-=speed*dt
		p.velocity.y+=p.gravity*dt
		p.rotation+=p.spin*dt
		if p.kind=="car" and p.pos.y>HordeRun.FLOOR-40:
			p.pos.y=HordeRun.FLOOR-40;p.velocity.y=0
		if p.life<=0: particles.remove_at(i)
	for i in range(trails.size()-1,-1,-1):
		trails[i].life-=dt;trails[i].foot.x-=speed*dt*.85
		if trails[i].life<=0: trails.remove_at(i)

func draw_trails(canvas: Node2D,actor: HordeActor,time: float) -> void:
	for p in trails:
		actor.paint(canvas,p.kind,p.foot,112,p.phase,p.state,time,p.landing,Color(.65,1,.9,.18*p.life/.32))

func paint(canvas: Node2D,art: HordeArt) -> void:
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
			"car":
				canvas.draw_set_transform(p.pos,minf(PI,progress*PI*1.65))
				var texture=art.items[7]
				var size=texture.get_size()*(p.size/texture.get_height())
				canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,color)
			"pickup":
				var t=1-pow(1-progress,3)
				var pos=p.origin.lerp(p.target,t)+Vector2(0,-sin(progress*PI)*65)
				var texture=art.items[p.icon]
				var size=texture.get_size()*(p.size/texture.get_height())*(1-progress*.55)
				canvas.draw_set_transform(pos,progress*TAU)
				canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,color)
		canvas.draw_set_transform(Vector2.ZERO)
