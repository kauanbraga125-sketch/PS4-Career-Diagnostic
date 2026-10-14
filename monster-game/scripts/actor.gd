class_name HordeActor
extends RefCounted

# Cutout art plus two-bone leg poses. A grounded support foot stays on the
# baseline while the body moves; every stride really alternates both legs.
var art: HordeArt

func _init(source: HordeArt) -> void:
	art=source

static func stride_foot(phase: float) -> Vector2:
	var t=fposmod(phase,1.0)
	if t<.62: return Vector2(26.0-52.0*t/.62,-4)
	var swing=(t-.62)/.38
	return Vector2(-26.0+52.0*swing,-4.0-19.0*sin(swing*PI))

static func knee(hip: Vector2,ankle: Vector2) -> Vector2:
	var delta=ankle-hip
	var distance=clampf(delta.length(),.1,45.9)
	var direction=delta.normalized()
	var along=(24.0*24.0-22.0*22.0+distance*distance)/(2.0*distance)
	var bend=sqrt(maxf(0,24.0*24.0-along*along))
	return hip+direction*along+Vector2(direction.y,-direction.x)*bend

func part(canvas: Node2D,kind: int,index: int,position: Vector2,size: Vector2,angle: float,tint: Color,root: Vector2,scale: float,pivot: Vector2=Vector2(.5,.5)) -> void:
	canvas.draw_set_transform(root+position*scale,angle,Vector2.ONE*scale)
	canvas.draw_texture_rect(art.rigs[kind][index],Rect2(-size*pivot,size),false,tint)

func bone(canvas: Node2D,kind: int,index: int,from: Vector2,to: Vector2,width: float,tint: Color,root: Vector2,scale: float) -> void:
	var delta=to-from
	part(canvas,kind,index,from,Vector2(width,delta.length()+4),delta.angle()-PI*.5,tint,root,scale,Vector2(.5,.08))

func leg(canvas: Node2D,kind: int,hip: Vector2,ankle: Vector2,tint: Color,root: Vector2,scale: float,angle: float=0) -> void:
	var joint=knee(hip,ankle)
	bone(canvas,kind,5,hip,joint,12 if kind!=1 else 8,tint,root,scale)
	bone(canvas,kind,6,joint,ankle,10 if kind!=1 else 7,tint,root,scale)
	part(canvas,kind,7,ankle+Vector2(5,1),Vector2(20,10),angle,tint,root,scale,Vector2(.35,.6))

func arm(canvas: Node2D,kind: int,shoulder: Vector2,swing: float,tint: Color,root: Vector2,scale: float,weapon: bool=false) -> void:
	var elbow=shoulder+Vector2(0,17).rotated(swing)
	var hand=elbow+Vector2(0,16).rotated(swing-1.3)
	bone(canvas,kind,2,shoulder,elbow,11 if kind!=1 else 7,tint,root,scale)
	bone(canvas,kind,3,elbow,hand,10 if kind!=1 else 6,tint,root,scale)
	if weapon: part(canvas,kind,8,hand+Vector2(4,-9),Vector2(11,36),.55+swing*.2,tint,root,scale,Vector2(.5,.88))
	part(canvas,kind,4,hand,Vector2(12,13),swing-.7,tint,root,scale,Vector2(.5,.2))

func paint(canvas: Node2D,kind: int,foot: Vector2,height: float,phase: float,state: String="run",time: float=0,landing: float=0,tint: Color=Color.WHITE) -> void:
	kind=clampi(kind,0,3)
	var scale=height/112.0
	var run=state=="run"
	var wave=sin(phase*TAU)
	var bob=absf(sin(phase*TAU))*2.5 if run else sin(time*2.8)*1.2
	var compression=sin(clampf(landing/.20,0,1)*PI)*6
	var hip=Vector2(-2,-37+bob+compression)
	var near_foot=stride_foot(phase) if run else Vector2(13,-4)
	var far_foot=stride_foot(phase+.5) if run else Vector2(-12,-4)
	if state in ["rise","fly"]:
		near_foot=Vector2(19,-22);far_foot=Vector2(-24,-18)
		hip.y=-37
	elif state=="fall":
		near_foot=Vector2(14,-8);far_foot=Vector2(-13,-5)
	var shade=tint*Color(.70,.72,.82,1)
	if kind==1:
		part(canvas,kind,8,hip+Vector2(-5,-27),Vector2(31,34),-.55+sin(time*7)*.11,shade,foot,scale,Vector2(.75,.1))
	elif kind==3:
		var flap=sin(time*35.0)
		for wing in range(2):
			part(canvas,kind,8,hip+Vector2(-7,-23),Vector2(25,40-absf(flap)*14),-.95-wing*.55+flap*.3,tint*Color(1,1,1,.85),foot,scale,Vector2(.5,1))
	var arm_swing=-.30+wave*.85 if run else -.25+sin(time*3)*.10
	if state in ["rise","fly"]: arm_swing=-1.35
	elif state=="fall": arm_swing=-.85
	arm(canvas,kind,hip+Vector2(-7,-24),-arm_swing-.3,shade,foot,scale)
	leg(canvas,kind,hip+Vector2(-4,0),far_foot,shade,foot,scale)
	leg(canvas,kind,hip+Vector2(3,0),near_foot,tint,foot,scale,-.20 if state=="rise" else 0)
	var lean=.12 if run else .02
	if state=="rise": lean=.22
	part(canvas,kind,1,hip+Vector2(3,-16),Vector2(29,36),lean,tint,foot,scale)
	arm(canvas,kind,hip+Vector2(10,-24),arm_swing,tint,foot,scale,kind==2)
	part(canvas,kind,0,hip+Vector2(9,-32),Vector2(52,50),lean*.3+sin(time*5)*.014,tint,foot,scale,Vector2(.5,1))
	canvas.draw_set_transform(Vector2.ZERO)
