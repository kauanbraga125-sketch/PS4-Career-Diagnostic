class_name StreetModels
extends RefCounted

static var materials: Dictionary = {}
static var meshes: Dictionary = {}

static func mat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var key = str(color) + str(roughness)
	if not materials.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		materials[key] = m
	return materials[key]

static func box_mesh() -> BoxMesh:
	if not meshes.has("box"):
		meshes.box = BoxMesh.new()
	return meshes.box

static func part(root: Node3D, size: Vector3, pos: Vector3, color: Color, kind: String = "box") -> MeshInstance3D:
	var n = MeshInstance3D.new()
	if kind == "box":
		n.mesh = box_mesh()
	elif kind == "sphere":
		if not meshes.has(kind):
			var s = SphereMesh.new()
			s.radial_segments = 10
			s.rings = 5
			meshes[kind] = s
		n.mesh = meshes[kind]
	else:
		if not meshes.has(kind):
			var c = CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 10
			meshes[kind] = c
		n.mesh = meshes[kind]
	n.scale = size
	n.position = pos
	n.material_override = mat(color)
	root.add_child(n)
	return n

static func segment(root: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var n = part(root, Vector3(radius, a.distance_to(b), radius), (a+b)*0.5, color, "cylinder")
	n.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	return n

static func person(style: int = 0) -> Node3D:
	var root = Node3D.new()
	var skins = [Color("ad7960"), Color("6f4838"), Color("dbad8a"), Color("825444")]
	var shirts = [Color("34606a"), Color("dfb34e"), Color("b9493c"), Color("c4c8c0"), Color("313d65"), Color("536346"), Color("d47e49"), Color("2b333a")]
	var skin = skins[style % skins.size()]
	var shirt = shirts[style % shirts.size()]
	part(root, Vector3(0.47,0.59,0.27), Vector3(0,1.19,0), shirt)
	part(root, Vector3(0.43,0.22,0.27), Vector3(0,0.84,0), Color("273039"))
	part(root, Vector3(0.12,0.12,0.12), Vector3(0,1.54,0), skin, "cylinder")
	part(root, Vector3(0.31,0.37,0.29), Vector3(0,1.74,0), skin, "sphere")
	part(root, Vector3(0.32,0.13,0.30), Vector3(0,1.89,0.015), Color("282321"))
	part(root, Vector3(0.065,0.065,0.07), Vector3(0,1.74,-0.15), skin)
	for side in [-1,1]:
		var leg = Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.position = Vector3(side*0.13,0.85,0)
		root.add_child(leg)
		part(leg, Vector3(0.17,0.68,0.20), Vector3(0,-0.34,0), Color("34434c"), "cylinder")
		part(leg, Vector3(0.19,0.12,0.33), Vector3(0,-0.76,-0.04), Color("242629"))
		var arm = Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(side*0.30,1.43,0)
		root.add_child(arm)
		part(arm, Vector3(0.16,0.29,0.17), Vector3(0,-0.14,0), shirt, "cylinder")
		part(arm, Vector3(0.12,0.27,0.13), Vector3(0,-0.41,0), skin, "cylinder")
		part(arm, Vector3(0.13,0.15,0.14), Vector3(0,-0.58,0), skin, "sphere")
	if style % 3 == 1:
		part(root, Vector3(0.35,0.11,0.34), Vector3(0,1.92,-0.015), shirt)
		part(root, Vector3(0.32,0.04,0.22), Vector3(0,1.88,-0.20), shirt)
	if style % 4 == 2:
		part(root, Vector3(0.29,0.36,0.18), Vector3(0,1.26,0.23), Color("363930"))
	return root

static func animate_person(root: Node3D, phase: float, walking: float, aiming: bool = false) -> void:
	root.get_node("LegL").rotation.x = sin(phase)*0.55*walking
	root.get_node("LegR").rotation.x = -sin(phase)*0.55*walking
	root.get_node("ArmL").rotation.x = -sin(phase)*0.43*walking if not aiming else -1.05
	root.get_node("ArmR").rotation.x = sin(phase)*0.43*walking if not aiming else -1.45

static func car(style: int = 0) -> Node3D:
	var root = Node3D.new()
	var paint = [Color("bd583e"), Color("d5cbb4"), Color("366879"), Color("353943"), Color("b6aa4d")][style%5]
	var glass = Color("29434f")
	var van = style%3 == 2
	part(root, Vector3(1.83,0.47,4.25), Vector3(0,0.69,0), paint)
	part(root, Vector3(1.73,0.17,3.95), Vector3(0,0.96,0), paint)
	part(root, Vector3(1.53,0.65,2.30 if van else 1.95), Vector3(0,1.30,0.15), glass)
	part(root, Vector3(1.55,0.13,2.38 if van else 2.03), Vector3(0,1.64,0.15), paint)
	for x in [-0.81,0.81]:
		for z in [-0.8,0.27,1.2]:
			part(root, Vector3(0.065,0.63,0.065), Vector3(x,1.30,z), paint)
		part(root, Vector3(0.04,0.39,2.23), Vector3(x*1.10,0.80,0.20), paint.darkened(0.07))
		part(root, Vector3(0.09,0.035,0.20), Vector3(x*1.13,1.03,0.60), Color("a7a7a0"))
		part(root, Vector3(0.23,0.15,0.27), Vector3(x*1.23,1.21,-0.84), paint)
	for z in [-2.16,2.16]:
		part(root, Vector3(1.82,0.15,0.12), Vector3(0,0.55,z), Color("42474a"))
		for x in [-0.60,0.60]:
			part(root, Vector3(0.44,0.17,0.07), Vector3(x,0.88,z), Color("e9dfb2") if z<0 else Color("aa2526"))
	part(root, Vector3(0.65,0.18,0.08), Vector3(0,0.75,-2.19), Color("212629"))
	for x in [-0.94,0.94]:
		for z in [-1.34,1.35]:
			var wheel = part(root, Vector3(0.67,0.22,0.67), Vector3(x,0.40,z), Color("22272a"), "cylinder")
			wheel.rotation.z = PI/2
			wheel.name = "Wheel" + str(root.get_child_count())
			var rim = part(root, Vector3(0.40,0.24,0.40), Vector3(x,0.40,z), Color("9b9d99"), "cylinder")
			rim.rotation.z = PI/2
	return root

static func bike(style: int = 0) -> Node3D:
	var root = Node3D.new()
	var paint = Color("bc6136") if style%2==0 else Color("397279")
	for z in [-0.81,0.77]:
		var wheel = part(root, Vector3(0.68,0.15,0.68), Vector3(0,0.37,z), Color("222629"), "cylinder")
		wheel.rotation.z = PI/2
		var rim = part(root, Vector3(0.49,0.16,0.49), Vector3(0,0.37,z), Color("959d9b"), "cylinder")
		rim.rotation.z = PI/2
	segment(root, Vector3(0,0.4,-0.81), Vector3(0,1.25,-0.50),0.10,Color("9a9991"))
	segment(root, Vector3(0,0.4,0.77), Vector3(0,1.1,-0.32),0.13,Color("343a3e"))
	part(root, Vector3(0.38,0.35,0.59), Vector3(0,0.91,-0.17),paint,"sphere")
	part(root, Vector3(0.30,0.12,0.66), Vector3(0,1.08,0.39),Color("29282a"))
	part(root, Vector3(0.34,0.31,0.39), Vector3(0,0.65,0),Color("737877"))
	part(root, Vector3(0.81,0.06,0.08), Vector3(0,1.28,-0.49),Color("343a3e"))
	part(root, Vector3(0.26,0.25,0.13), Vector3(0,1.16,-0.68),Color("e7dcb4"),"sphere")
	segment(root, Vector3(0.25,0.49,0.12),Vector3(0.25,0.49,0.83),0.10,Color("949a95"))
	return root

static func gun(kind: int) -> Node3D:
	var root = Node3D.new()
	var length = [0.29,0.50,0.95,0.85][kind]
	part(root, Vector3(0.085,0.10,length),Vector3(0,0,0),Color("373d41"))
	part(root, Vector3(0.07,0.22,0.10),Vector3(0,-0.14,length*0.27),Color("5b5140"))
	part(root, Vector3(0.032,0.04,0.14),Vector3(0,0.005,-length*0.5),Color("161d24"),"cylinder").rotation.x = PI/2
	if kind>0:
		part(root, Vector3(0.07,0.25,0.13),Vector3(0,-0.15,-0.03),Color("292e33"))
	if kind>1:
		part(root, Vector3(0.09,0.15,0.28),Vector3(0,0.0,length*0.5),Color("6f5f46"))
	return root
