class_name HordeScene
extends RefCounted

var art: HordeArt
var actor: HordeActor
var civilians: Array[Dictionary]=[]
var events: Array[String]=[]
var clock=0.0
var district=-1
var scream_left=2.8
var crash_left=5.0
var crash_age=-1.0

func _init(source: HordeArt,rig: HordeActor) -> void:
	art=source;actor=rig
	reset()

func reset() -> void:
	clock=0;district=-1;scream_left=2.8;crash_left=5;crash_age=-1
	civilians.clear();events.clear()
	for i in range(6):
		civilians.append({"x":120.0+i*235,"y":HordeRun.FLOOR-16-float(i%3)*14,"speed":85.0+i*9,"reverse":i%3!=0,"phase":i*.21})

func update(dt: float,run: HordeRun) -> void:
	clock+=dt
	if district!=run.area():
		district=run.area();scream_left=2.8;crash_left=4.0;crash_age=-1
	if district!=1 or run.inside_tunnel(): return
	for p in civilians:
		p.x+=(-p.speed if p.reverse else p.speed)*dt-run.speed*dt*.38
		p.phase+=dt*3.9
		if p.x< -90: p.x=1400
		if p.x>1450: p.x=-70
	scream_left-=dt;crash_left-=dt
	if scream_left<=0:
		events.append("background_scream");scream_left=7.5
	if crash_left<=0:
		crash_age=0;crash_left=11.0
	if crash_age>=0:
		var before=crash_age
		crash_age+=dt
		if before<2.55 and crash_age>=2.55: events.append("background_crash")
		if crash_age>3.6: crash_age=-1

func sprite(canvas: Node2D,texture: Texture2D,centre: Vector2,height: float,tint: Color=Color.WHITE,angle: float=0,reverse: bool=false) -> void:
	var size=texture.get_size()*(height/texture.get_height())
	canvas.draw_set_transform(centre,angle,Vector2(-1 if reverse else 1,1))
	canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)

func helicopter(canvas: Node2D,centre: Vector2,height: float,time: float,angle: float=0,tint: Color=Color.WHITE) -> void:
	var texture=art.vehicles[5]
	var size=texture.get_size()*(height/texture.get_height())
	canvas.draw_set_transform(centre,angle,Vector2(-1,1))
	canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,tint)
	var hub=Vector2(4,-height*.42)
	var rotor=size.x*.43
	canvas.draw_line(hub-Vector2(rotor,0),hub+Vector2(rotor,0),Color(.12,.09,.18,tint.a*.28),7,true)
	canvas.draw_line(hub-Vector2(rotor*cos(time*65),2*sin(time*65)),hub+Vector2(rotor*cos(time*65),2*sin(time*65)),Color(.85,.80,.9,tint.a),3,true)
	canvas.draw_set_transform(Vector2.ZERO)

func paint(canvas: Node2D,run: HordeRun,time: float) -> void:
	var area=run.area()
	canvas.draw_rect(Rect2(0,0,1280,720),Color("342049"))
	canvas.draw_texture_rect(art.sky,Rect2(0,0,1280,448),false)
	for i in range(20):
		canvas.draw_rect(Rect2(0,380+i*10,1280,11),Color(.24,.14,.31,float(i)/20*.26))
	for layer in range(3):
		var height=[224.0,274.0,254.0][layer]
		var texture=art.world_layers[area][layer]
		var width=texture.get_width()*height/texture.get_height()
		var bottom=HordeRun.FLOOR-[80.0,5.0,-5.0][layer]
		var offset=fposmod(run.world_px*[.055,.19,.48][layer],width)
		for tile in range(-1,3):
			canvas.draw_texture_rect(texture,Rect2(tile*width-offset,bottom-height,width+1,height),false)
	if area==0:
		for i in range(2):
			var point=Vector2(fposmod(i*770-run.world_px*.52,1540)-140,HordeRun.FLOOR-111)
			canvas.draw_circle(point,42,Color(1,.65,.23,.05+.018*sin(time*7+i)))
			sprite(canvas,art.items[10],point+Vector2(0,35),135,Color(.9,.92,1,1),sin(time*2+i)*.035)
	elif area==1:
		for i in range(5):
			var x=fposmod(i*313-run.world_px*.48,1565)-90
			flame(canvas,Vector2(x,HordeRun.FLOOR-26),time+i,26)
		for p in civilians:
			actor.paint(canvas,4,Vector2(p.x,p.y),66,p.phase,"run",time,0,Color(.78,.76,.85,.86),p.reverse)
		if crash_age>=0:
			var t=crash_age
			var point=Vector2(1040-t*135,210+minf(t,2.55)*minf(t,2.55)*43)
			for i in range(9):
				var smoke=point+Vector2(17+i*17,-12-i*13)
				canvas.draw_circle(smoke,7+i*1.6,Color(.22,.13,.26,.30-float(i)*.024))
			if t<2.55:
				helicopter(canvas,point,66,time,.12+t*.25,Color(.70,.69,.78,.88))
				flame(canvas,point+Vector2(30,7),time,12)
			else:
				sprite(canvas,art.props[5],Vector2(point.x,HordeRun.FLOOR-53),105*(1+(t-2.55)*.2),Color(1,1,1,1-(t-2.55)/1.05))
	elif area==2:
		for i in range(6):
			var x=fposmod(i*280-run.world_px*.19,1680)-80
			for puff in range(4):
				var age=fposmod(time*.35+puff*.25+i*.12,1)
				canvas.draw_circle(Vector2(x+age*26,265-age*100),12+age*24,Color(.35,.28,.44,.16*(1-age)))
	elif area==3:
		for i in range(12):
			var point=Vector2(fposmod(i*142-run.world_px*.48,1704)-60,HordeRun.FLOOR-25)
			var glow=.16+.10*sin(time*5-i*.55)
			canvas.draw_circle(point,14,Color(.54,.90,1,glow));canvas.draw_circle(point,3,Color(.70,.94,1,.9))
		var beacon=Vector2(fposmod(1020-run.world_px*.19,1530),244)
		canvas.draw_colored_polygon(PackedVector2Array([beacon,beacon+Vector2(220*cos(time*.75),-75),beacon+Vector2(240*cos(time*.75),55)]),Color(1,.9,.65,.035))
	paint_tunnel_back(canvas,run,time)

func flame(canvas: Node2D,pos: Vector2,time: float,height: float) -> void:
	canvas.draw_circle(pos-Vector2(0,height*.4),height*1.2,Color(1,.48,.12,.07))
	for i in range(3):
		var sway=sin(time*12+i*2)*height*.10
		canvas.draw_set_transform(pos+Vector2((i-1)*height*.22,0),sway*.013,Vector2(.55,.9+sin(time*9+i)*.18))
		canvas.draw_circle(Vector2(0,-height*.4),height*.45,Color("f29148") if i!=1 else Color("ffdc87"))
	canvas.draw_set_transform(Vector2.ZERO)

func tunnel_opacity(run: HordeRun) -> float:
	var phase=run.tunnel_phase()
	if phase>HordeRun.ZONE_LENGTH-650: return minf(1,(phase-(HordeRun.ZONE_LENGTH-650))/180)
	if run.tunnel_number()>0 and phase<220: return clampf((220-phase)/150,0,1)
	return 0

func paint_tunnel_back(canvas: Node2D,run: HordeRun,time: float) -> void:
	var opacity=tunnel_opacity(run)
	if opacity<=0: return
	canvas.draw_rect(Rect2(0,0,1280,HordeRun.FLOOR),Color(.075,.045,.13,opacity*.94))
	var brick=tunnel_brick(opacity)
	for row in range(3):
		for col in range(10):
			var x=fposmod(col*156-run.world_px*.7+row*77,1560)-156
			canvas.draw_style_box(brick,Rect2(x,218+row*70,148,62))
	for i in range(5):
		var point=Vector2(fposmod(i*300-run.world_px*.8,1500)-90,310)
		canvas.draw_line(point-Vector2(0,95),point-Vector2(0,20),Color(.2,.14,.28,opacity),3,true)
		canvas.draw_circle(point,68,Color(1,.68,.28,opacity*(.06+.01*sin(time*7+i))))
		sprite(canvas,art.items[10],point,70,Color(1,1,1,opacity),sin(time*2+i)*.04)

func tunnel_brick(opacity: float) -> StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=Color(.16,.11,.23,.4*opacity);box.border_color=Color(.24,.18,.32,.45*opacity)
	box.set_border_width_all(2);box.set_corner_radius_all(8)
	return box

func paint_front(canvas: Node2D,run: HordeRun) -> void:
	var boundary=(run.tunnel_number()+1)*HordeRun.ZONE_LENGTH
	for absolute in [boundary-650,boundary+220,boundary-HordeRun.ZONE_LENGTH+220]:
		if absolute<HordeRun.ZONE_LENGTH-650: continue
		var x=absolute-run.world_px
		if x< -330 or x>1600: continue
		sprite(canvas,art.props[3],Vector2(x,HordeRun.FLOOR-208),416)
