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
		civilians.append({"x":120.0+i*235,"y":HordeRun.FLOOR-16-float(i%3)*14,"speed":85.0+i*9,"reverse":i%3!=0,"phase":i*.21,"variant":i%3})

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
	var texture=art.helicopter
	var size=texture.get_size()*(height/texture.get_height())
	canvas.draw_set_transform(centre,angle,Vector2(-1,1))
	canvas.draw_texture_rect(texture,Rect2(-size*.5,size),false,tint)
	var hub=Vector2(4,-height*.42)
	var rotor=size.x*.43
	canvas.draw_line(hub-Vector2(rotor,0),hub+Vector2(rotor,0),Color(.12,.09,.18,tint.a*.28),7,true)
	canvas.draw_line(hub-Vector2(rotor*cos(time*65),2*sin(time*65)),hub+Vector2(rotor*cos(time*65),2*sin(time*65)),Color(.85,.80,.9,tint.a),3,true)
	canvas.draw_set_transform(Vector2.ZERO)

func paint_outside(canvas: Node2D,run: HordeRun,time: float,area: int,left: float=0,right: float=1280) -> void:
	canvas.draw_rect(Rect2(left,0,right-left,720),Color("342049"))
	clip_texture(canvas,art.sky,Rect2(0,0,1280,448),left,right)
	for i in range(20):
		canvas.draw_rect(Rect2(left,380+i*10,right-left,11),Color(.24,.14,.31,float(i)/20*.26))
	for layer in range(3):
		var height=[224.0,274.0,254.0][layer]
		var texture=art.world_layers[area][layer]
		var width=texture.get_width()*height/texture.get_height()
		var bottom=HordeRun.FLOOR-[80.0,5.0,-5.0][layer]
		var offset=fposmod(run.world_px*[.055,.19,.48][layer],width)
		for tile in range(-1,3):
			clip_texture(canvas,texture,Rect2(tile*width-offset,bottom-height,width+1,height),left,right)
	if area==0:
		for i in range(2):
			var point=Vector2(fposmod(i*770-run.world_px*.52,1540)-140,HordeRun.FLOOR-111)
			canvas.draw_circle(point,42,Color(1,.65,.23,.05+.018*sin(time*7+i)))
			sprite(canvas,art.items[10],point+Vector2(0,35),135,Color(.9,.92,1,1),sin(time*2+i)*.035)
	elif area==1:
		for i in range(5):
			var x=fposmod(i*313-run.world_px*.48,1565)-90
			if x>left and x<right: flame(canvas,Vector2(x,HordeRun.FLOOR-26),time+i,26)
		for p in civilians:
			if p.x>left and p.x<right: actor.paint(canvas,int(MonsterCatalog.CIVILIANS[int(p.variant)].rig),Vector2(p.x,p.y-absf(sin(time*3+p.variant))*6),66,p.phase,"panic_run",time,0,Color(.78,.76,.85,.86),p.reverse)
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


func flame(canvas: Node2D,pos: Vector2,time: float,height: float) -> void:
	canvas.draw_circle(pos-Vector2(0,height*.4),height*1.2,Color(1,.48,.12,.07))
	for i in range(3):
		var sway=sin(time*12+i*2)*height*.10
		canvas.draw_set_transform(pos+Vector2((i-1)*height*.22,0),sway*.013,Vector2(.55,.9+sin(time*9+i)*.18))
		canvas.draw_circle(Vector2(0,-height*.4),height*.45,Color("f29148") if i!=1 else Color("ffdc87"))
	canvas.draw_set_transform(Vector2.ZERO)


func clip_texture(canvas: Node2D,texture: Texture2D,dest: Rect2,left: float,right: float) -> void:
	var x0=maxf(left,dest.position.x);var x1=minf(right,dest.end.x)
	if x1<=x0: return
	var width=texture.get_width();var height=texture.get_height()
	var source=Rect2((x0-dest.position.x)/dest.size.x*width,0,(x1-x0)/dest.size.x*width,height)
	canvas.draw_texture_rect_region(texture,Rect2(x0,dest.position.y,x1-x0,dest.size.y),source)

func paint(canvas: Node2D,run: HordeRun,time: float) -> void:
	paint_outside(canvas,run,time,run.area())
	for t in run.tunnels:
		var entrance=HordeRun.ANCHOR+float(t.entry)-run.world_px
		var exit=entrance+float(t.length)
		if entrance>=1280 or exit<=0: continue
		var left=maxf(0,entrance);var right=minf(1280,exit)
		if right>left:
			var width=art.tunnel.get_width()*720.0/art.tunnel.get_height()
			var offset=fposmod(run.world_px,width)
			for tile in range(-1,3): clip_texture(canvas,art.tunnel,Rect2(tile*width-offset,0,width+1,720),left,right)
			for i in range(8):
				var x=fposmod(i*197-run.world_px*.7,1576)-80
				if x>left+25 and x<right-25:
					var drip=fposmod(time*.5+i*.17,1)
					canvas.draw_line(Vector2(x,255+drip*150),Vector2(x,261+drip*150),Color(.55,.90,1,.28*(1-drip)),2,true)
					canvas.draw_circle(Vector2(x,HordeRun.FLOOR-8),21,Color(.30,.80,.85,.04+.015*sin(time*4+i)))
			for i in range(5):
				var x=fposmod(i*302-run.world_px,1510)-40
				if x>left+15 and x<right-15:
					canvas.draw_circle(Vector2(x,300),80,Color(1,.58,.22,.025+.015*sin(time*9+i)))
					canvas.draw_circle(Vector2(x+sin(time*2+i)*13,280+fposmod(time*26+i*40,80)),2,Color(1,.76,.38,.35))
		if exit<1280: paint_outside(canvas,run,time,int(t.to),maxf(0,exit),1280)

func paint_front(canvas: Node2D,run: HordeRun) -> void:
	for t in run.tunnels:
		for side in range(2):
			var boundary=HordeRun.ANCHOR+float(t.entry)+float(t.length)*side-run.world_px
			if boundary< -680 or boundary>1960: continue
			var texture=art.tunnel_mouths[side]
			var height=430.0
			var width=texture.get_width()*height/texture.get_height()
			# A cutaway rock facade surrounds a continuous horizontal corridor.
			sprite(canvas,texture,Vector2(boundary-30,HordeRun.FLOOR-height*.5),height)
			if side==0:
				var box=StyleBoxFlat.new();box.bg_color=Color("2a2037");box.border_color=Color("c9a35c")
				box.set_border_width_all(3);box.set_corner_radius_all(11)
				var point=Vector2(boundary-40,HordeRun.FLOOR-345)
				canvas.draw_style_box(box,Rect2(point-Vector2(65,35),Vector2(130,70)))
				canvas.draw_string(art.title_font,point+Vector2(-45,-8),"TÚNEL",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("ffe7ba"))
				var value=str(t.number)
				canvas.draw_string(art.title_font,point+Vector2(-art.title_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x*.5,23),value,HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("ffc66a"))
