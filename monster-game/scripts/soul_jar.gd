class_name HordeSoulJar
extends RefCounted

# One generated glass frame, with 61 reproducible GPU-baked fill sprites.
const FRAME=preload("res://assets/art/soul-jar-frame-v7.png")
var sprites: Texture2D

func _init() -> void:
	if ResourceLoader.exists("res://assets/art/soul-jar-states-v7.png"):
		sprites=load("res://assets/art/soul-jar-states-v7.png")

func paint_state(c: Node2D,fill: float,phase: float=0) -> void:
	var centre=Vector2(128,179);var radius=Vector2(87,79)
	var cavity=PackedVector2Array()
	for i in range(65):cavity.append(centre+Vector2(cos(i*TAU/64)*radius.x,sin(i*TAU/64)*radius.y))
	c.draw_colored_polygon(cavity,Color(.035,.10,.16,.72))
	if fill>0:
		var top=lerpf(257,102,clampf(fill,0,1))
		var shape=PackedVector2Array()
		for y in range(int(top),259,2):
			var width=radius.x*sqrt(maxf(0,1-pow((y-centre.y)/radius.y,2)))
			shape.append(Vector2(128-width,y))
		for y in range(258,int(top)-1,-2):
			var width=radius.x*sqrt(maxf(0,1-pow((y-centre.y)/radius.y,2)))
			shape.append(Vector2(128+width,y))
		if shape.size()>3:c.draw_colored_polygon(shape,Color("34bdba"))
		var surface=radius.x*sqrt(maxf(0,1-pow((top-centre.y)/radius.y,2)))
		c.draw_set_transform(Vector2(128,top),0,Vector2(surface,3.8))
		c.draw_circle(Vector2.ZERO,1,Color("a0ffe0"));c.draw_set_transform(Vector2.ZERO)
		for i in range(int(fill*9)):
			var pos=Vector2(128+sin(i*2.39)*48,lerpf(250,top+10,float(i+1)/(int(fill*9)+1)))
			c.draw_circle(pos,3+sin(i+phase),Color(.65,1,.88,.6))
	c.draw_texture_rect(FRAME,Rect2(0,0,256,320),false)

func paint(c: Node2D,rect: Rect2,fill: float,time: float) -> void:
	if sprites!=null:
		var index=clampi(roundi(fill*60),0,60)
		c.draw_texture_rect_region(sprites,rect,Rect2((index%8)*256,(index/8)*320,256,320))
	else:
		c.draw_set_transform(rect.position,0,rect.size/Vector2(256,320));paint_state(c,fill,time);c.draw_set_transform(Vector2.ZERO)
