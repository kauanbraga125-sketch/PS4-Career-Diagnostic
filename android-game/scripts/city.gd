class_name CityWorld
extends Node3D

const BLOCK = 120.0
const HALF = 720.0
const PALETTE = [Color("a89b83"),Color("aeb3ad"),Color("9d806a"),Color("c7bda4"),Color("8c9b9a"),Color("b49e87")]
var game
var chunks: Dictionary = {}
var queue: Array[Vector2i] = []
var radius = 1
var center = Vector2i(999,999)
var batches: Dictionary
var current_body: StaticBody3D
var current_root: Node3D
var rng = RandomNumberGenerator.new()

static func elevation(x: float) -> float:
	return maxf(-x-240.0,0.0)*0.075

static func ground(p: Vector3, extra: float = 0.0) -> Vector3:
	return Vector3(p.x,elevation(p.x)+extra,p.z)

static func district(p: Vector3) -> String:
	if p.x < -240: return "SERRA VERDE" if p.z < 0 else "CAMPUS E PARQUE"
	if p.x > 240: return "DISTRITO INDUSTRIAL" if p.z < 0 else "PORTO E ORLA"
	return "CENTRO FINANCEIRO" if p.z < 0 else "VILA ANTIGA"

func setup(owner_game) -> void:
	game = owner_game
	var water = StreetModels.part(self,Vector3(2300,2,2300),Vector3(0,-4,0),Color("377f88"))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	add_child(floor_body)
	for edge in [-1,1]:
		for axis in [0,1]:
			var shape = CollisionShape3D.new()
			var box = BoxShape3D.new()
			box.size = Vector3(4,110,1440) if axis==0 else Vector3(1440,110,4)
			shape.shape = box
			shape.position = Vector3(edge*719,45,0) if axis==0 else Vector3(0,45,edge*719)
			floor_body.add_child(shape)
	for i in range(12):
		var hill = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 12
		cone.bottom_radius = 130 + i%3*30
		cone.height = 160+i%4*40
		cone.radial_segments = 9
		hill.mesh = cone
		hill.position = Vector3(-940-i%2*80,40,-900+i*170)
		hill.material_override = StreetModels.mat(Color("657c77"))
		add_child(hill)
	refresh(Vector3(60,0,6),true)

func refresh(pos: Vector3, immediate: bool = false) -> void:
	var c = Vector2i(int(floor(pos.x/BLOCK)),int(floor(pos.z/BLOCK)))
	if c == center and not immediate: return
	center = c
	queue.clear()
	var wanted: Dictionary = {}
	for x in range(c.x-radius,c.x+radius+1):
		for z in range(c.y-radius,c.y+radius+1):
			if x < -6 or x >= 6 or z < -6 or z >= 6: continue
			var key = Vector2i(x,z)
			wanted[key] = true
			if not chunks.has(key): queue.append(key)
	queue.sort_custom(func(a,b): return (a-c).length_squared() < (b-c).length_squared())
	for key in chunks.keys():
		if not wanted.has(key):
			chunks[key].queue_free()
			chunks.erase(key)
	if immediate:
		while not queue.is_empty(): build_chunk(queue.pop_front())

func _process(_dt: float) -> void:
	if game and game.running:
		refresh(game.focus_position())
		# One district block per frame avoids a large allocation spike while driving.
		if not queue.is_empty(): build_chunk(queue.pop_front())

func set_quality(q: int) -> void:
	radius = [1,2,3][q]
	center = Vector2i(999,999)

func is_loaded(pos: Vector3) -> bool:
	return chunks.has(Vector2i(floori(pos.x/BLOCK),floori(pos.z/BLOCK)))

func box(p: Vector3,size: Vector3,color: Color,solid: bool=false,rot: Vector3=Vector3.ZERO,kind: String="box") -> void:
	var key = str(color)+kind
	if not batches.has(key): batches[key] = {"color":color,"kind":kind,"transforms":[]}
	batches[key].transforms.append(Transform3D(Basis.from_euler(rot).scaled(size),p))
	if solid:
		var s = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		s.shape = shape
		s.position = p
		s.rotation = rot
		current_body.add_child(s)

func tree(p: Vector3,variant: int = 0) -> void:
	box(p+Vector3(0,2.1,0),Vector3(0.36,4.2,0.36),Color("796752"),false,Vector3.ZERO,"cylinder")
	if variant==0:
		box(p+Vector3(0,5,0),Vector3(4.1,5.5,4.1),Color("54745a"),false,Vector3.ZERO,"sphere")
	else:
		for a in range(5):
			box(p+Vector3(0,4.6,0),Vector3(5.2,0.10,0.65),Color("567960"),false,Vector3(0,a*PI/5,0.12))

func build_chunk(key: Vector2i) -> void:
	var ox = key.x*BLOCK
	var oz = key.y*BLOCK
	rng.seed = (key.x+7)*73241+(key.y+7)*8329
	current_root = Node3D.new()
	current_root.name = "Block_%s_%s" % [key.x,key.y]
	add_child(current_root)
	chunks[key] = current_root
	current_body = StaticBody3D.new()
	current_body.collision_layer = 1
	current_root.add_child(current_body)
	batches = {}
	var slope = -0.075 if ox < -240 else 0.0
	var rot = Vector3(0,0,atan(slope))
	box(Vector3(ox+60,elevation(ox+60)-0.8,oz+60),Vector3(120.4,1.6,120.4),Color("ada791"),true,rot)
	box(Vector3(ox+60,elevation(ox+60)+0.016,oz+5),Vector3(120,0.024,20),Color("50565a"),false,rot)
	box(Vector3(ox+5,elevation(ox+5)+0.017,oz+60),Vector3(20,0.025,120),Color("50565a"),false,rot)
	# Flush curbs are driveable and do not snag the motorcycle collision capsule.
	box(Vector3(ox+60,elevation(ox+60)+0.04,oz+18),Vector3(120,0.06,6),Color("b9b5a7"),false,rot)
	box(Vector3(ox+18,elevation(ox+18)+0.04,oz+60),Vector3(6,0.06,120),Color("b9b5a7"),false,rot)
	for n in range(6):
		box(ground(Vector3(ox+22+n*17,0,oz+5),0.042),Vector3(6,0.012,0.18),Color("e2c773"),false,rot)
		box(ground(Vector3(ox+5,0,oz+22+n*17),0.043),Vector3(0.18,0.012,6),Color("e2c773"))
	for i in range(5):
		box(ground(Vector3(ox+22+i*1.8,0,oz+5),0.05),Vector3(0.7,0.016,13),Color("d3d1c2"),false,rot)
	var region = district(Vector3(ox+60,0,oz+60))
	var park = (key==Vector2i(-2,-2) or (key.x < -2 and key.y >= 0) or key==Vector2i(0,0))
	var port = key.x>=3 and key.y>=0
	if park:
		box(ground(Vector3(ox+68,0,oz+69),0.08),Vector3(91,0.10,90),Color("798760"),false,rot)
		box(ground(Vector3(ox+65,0,oz+65),0.15),Vector3(7,0.10,94),Color("c1b29a"),false,rot)
		for i in range(9):
			tree(ground(Vector3(ox+30+rng.randf()*77,0,oz+30+rng.randf()*77)),1 if key==Vector2i(0,0) else 0)
		box(ground(Vector3(ox+50,0,oz+43),0.55),Vector3(4,0.18,0.60),Color("6a5443"))
		box(ground(Vector3(ox+50,0,oz+43),0.25),Vector3(3.5,0.5,0.35),Color("606661"))
		if key==Vector2i(0,0):
			building(Vector3(ox+62,0,oz+92),Vector3(27,7,15),3,true)
			sign_at("OFICINA  /  PORTO LIVRE",ground(Vector3(ox+62,0,oz+83),4),0)
		if key.x==-4 and key.y==2:
			building(Vector3(ox+70,0,oz+73),Vector3(42,16,30),1,true)
			box(ground(Vector3(ox+70,0,oz+73),23),Vector3(10,17,10),Color("c7bda4"),true)
			sign_at("UNIVERSIDADE DO PORTO",ground(Vector3(ox+70,0,oz+55),7),0)
	elif port:
		box(ground(Vector3(ox+68,0,oz+68),0.08),Vector3(88,0.10,88),Color("969d98"))
		for i in range(5):
			var p = ground(Vector3(ox+40+(i%2)*28,0,oz+37+floori(i/2.0)*24))
			box(p+Vector3(0,1.5,0),Vector3(12,3,5),PALETTE[i],true)
			for rib in range(9):
				box(p+Vector3(-5+rib*1.25,1.5,-2.52),Vector3(0.08,2.8,0.06),Color("576b71"))
		if key==Vector2i(5,5):
			box(ground(Vector3(ox+65,0,oz+60),14),Vector3(7,28,7),Color("d6d0bd"),true,Vector3.ZERO,"cylinder")
			box(ground(Vector3(ox+65,0,oz+60),28),Vector3(9,1,9),Color("bd583e"),false,Vector3.ZERO,"cylinder")
			box(ground(Vector3(ox+65,0,oz+60),31),Vector3(5,5,5),Color("465f63"))
			sign_at("FAROL DA BARRA",ground(Vector3(ox+63,0,oz+51),3),0)
	else:
		for x in [42,88]:
			for z in [42,89]:
				var h = rng.randf_range(5,13)
				if region=="CENTRO FINANCEIRO": h = rng.randf_range(17,42)
				if region=="DISTRITO INDUSTRIAL": h = 8
				building(Vector3(ox+x,0,oz+z),Vector3(rng.randf_range(20,28),h,rng.randf_range(20,29)),rng.randi_range(0,5),region!="DISTRITO INDUSTRIAL")
		for t in [32,90]: tree(ground(Vector3(ox+t,0,oz+18)),1)
	for lx in [30,100]:
		var lp = ground(Vector3(ox+lx,0,oz+15))
		box(lp+Vector3(0,3.5,0),Vector3(0.13,7,0.13),Color("606661"))
		box(lp+Vector3(0,7,-1),Vector3(0.18,0.12,2),Color("606661"))
		box(lp+Vector3(0,6.9,-1.8),Vector3(0.45,0.12,0.7),Color("ded3ad"))
	for b in batches.values():
		var mesh: Mesh = StreetModels.box_mesh()
		if b.kind!="box":
			if b.kind=="sphere":
				var s = SphereMesh.new()
				s.radial_segments = 8
				s.rings = 4
				mesh = s
			else:
				var c = CylinderMesh.new()
				c.top_radius = 0.5
				c.bottom_radius = 0.5
				c.height = 1
				c.radial_segments = 8
				mesh = c
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = b.transforms.size()
		for i in range(mm.instance_count): mm.set_instance_transform(i,b.transforms[i])
		var instance = MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.material_override = StreetModels.mat(b.color)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if game.quality==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		current_root.add_child(instance)
	batches.clear()

func building(p: Vector3,size: Vector3,style: int,windows: bool) -> void:
	var base = ground(p)
	box(base+Vector3(0,size.y*0.5,0),size,PALETTE[style],true)
	box(base+Vector3(0,size.y+0.15,0),Vector3(size.x+0.6,0.4,size.z+0.6),Color("697475"))
	box(base+Vector3(0,1.6,-size.z*0.5-0.05),Vector3(2.1,3.2,0.12),Color("394b50"))
	if not windows: return
	for h in range(3,int(size.y)-1,4):
		for offset in range(-int(size.x/2)+3,int(size.x/2)-1,4):
			for side in [-1,1]:
				box(base+Vector3(offset,h,side*(size.z*0.5+0.035)),Vector3(1.5,1.8,0.055),Color("526871"))
		for offset in range(-int(size.z/2)+3,int(size.z/2)-1,4):
			for side in [-1,1]:
				box(base+Vector3(side*(size.x*0.5+0.035),h,offset),Vector3(0.055,1.8,1.5),Color("526871"))
	if size.y < 14:
		box(base+Vector3(0,3.5,-size.z*0.5-1.1),Vector3(size.x*0.75,0.25,2.5),Color("677b71"))

func sign_at(text_value: String,pos: Vector3,angle: float) -> void:
	var label = Label3D.new()
	label.text = text_value
	label.font_size = 42
	label.pixel_size = 0.023
	label.position = pos
	label.rotation.y = angle
	label.modulate = Color("ede2c6")
	label.outline_modulate = Color("25353b")
	label.visibility_range_end = 85
	current_root.add_child(label)
