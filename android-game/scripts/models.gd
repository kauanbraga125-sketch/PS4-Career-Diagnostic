class_name StreetModels
extends RefCounted

static var materials: Dictionary = {}
static var meshes: Dictionary = {}

# Bake every articulated part into one vertex-coloured mesh. The body, two
# arms and two legs remain independently animated, without one draw per box.
static func batch_parts(root: Node3D) -> void:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	var remove: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh:
			var arrays = child.mesh.surface_get_arrays(0)
			var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normal: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var offset = vertices.size()
			var transform: Transform3D = child.transform
			var normal_basis = transform.basis.inverse().transposed()
			var color = child.material_override.albedo_color
			for i in range(source.size()):
				vertices.append(transform*source[i])
				normals.append((normal_basis*normal[i]).normalized())
				colors.append(color)
			var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if source_indices.is_empty():
				for i in range(source.size()): indices.append(offset+i)
			else:
				for i in source_indices: indices.append(offset+i)
			remove.append(child)
		elif child is Node3D:
			batch_parts(child)
	if vertices.is_empty(): return
	var data = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = vertices
	data[Mesh.ARRAY_NORMAL] = normals
	data[Mesh.ARRAY_COLOR] = colors
	data[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.78
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	for child in remove: child.free()
	root.add_child(instance)

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

static func imported(asset_name: String) -> Node3D:
	var path = "res://assets/realism/models/"+asset_name+".glb"
	if not meshes.has(path): meshes[path] = load(path)
	assert(meshes[path] is PackedScene,"Missing required realism asset: "+path)
	return meshes[path].instantiate()

static func architecture(style: int,size: Vector3) -> Node3D:
	# Scale individually licensed Kenney CC0 glTF houses to their plots.
	var id = posmod(style,8)
	var asset = "building_%d" % id
	var root = imported(asset)
	var key = asset+"_bounds"
	if not meshes.has(key):
		var parts: Array = []
		collect_meshes(root,Transform3D.IDENTITY,parts)
		var low = Vector3(1e12,1e12,1e12)
		var high = Vector3(-1e12,-1e12,-1e12)
		for part_value in parts:
			var aabb: AABB = part_value.mesh.get_aabb()
			var t: Transform3D = part_value.transform
			for corner in range(8):
				var p = t*aabb.get_endpoint(corner)
				low = low.min(p)
				high = high.max(p)
		meshes[key] = {"low":low,"high":high}
	var bounds: Dictionary = meshes[key]
	var low: Vector3 = bounds.low
	var high: Vector3 = bounds.high
	var ext = high-low
	var ratio = Vector3(size.x/maxf(ext.x,0.01),size.y/maxf(ext.y,0.01),size.z/maxf(ext.z,0.01))
	root.scale = ratio
	root.position = Vector3(-(low.x+high.x)*0.5*ratio.x,-low.y*ratio.y,-(low.z+high.z)*0.5*ratio.z)
	return root

static func tree_parts() -> Array:
	if not meshes.has("tree_parts"):
		var root = imported("tree")
		var parts: Array = []
		collect_meshes(root,Transform3D.IDENTITY,parts)
		meshes["tree_parts"] = parts
		root.free()
	return meshes["tree_parts"]

static func collect_meshes(node: Node3D,parent: Transform3D,parts: Array) -> void:
	var t = parent*node.transform
	if node is MeshInstance3D: parts.append({"mesh":node.mesh,"transform":t})
	for child in node.get_children():
		if child is Node3D: collect_meshes(child,t,parts)

static func person(style: int = 0) -> StreetActor:
	var actor = StreetActor.new()
	actor.setup(style)
	return actor

static func car(style: int = 0) -> Node3D:
	var root = imported("car")
	var paint = [Color("6f1820"),Color("dedcd2"),Color("16445c"),Color("252c32"),Color("9b6634")][posmod(style,5)]
	for part_node in root.find_children("*","MeshInstance3D",true,false):
		for index in range(part_node.mesh.get_surface_count()):
			var original = part_node.mesh.surface_get_material(index)
			if original is BaseMaterial3D and String(original.resource_name).begins_with("Paint 1"):
				var key = "car_paint_"+str(style)
				if not materials.has(key):
					var changed = original.duplicate()
					changed.albedo_color = paint
					# The source's microscopic paint flakes shimmer after mobile
					# compression. Use a smooth automotive clear coat at this scale.
					changed.normal_enabled = false
					changed.ao_enabled = false
					changed.metallic = 0.55
					changed.roughness = 0.30
					changed.clearcoat = 0.5
					materials[key] = changed
				part_node.set_surface_override_material(index,materials[key])
	return root

static func bike(_style: int = 0) -> Node3D:
	return imported("bike")

static func aircraft(plane: bool) -> Node3D:
	var root = Node3D.new()
	if plane:
		part(root,Vector3(1.9,1.05,6.1),Vector3(0,1.30,0),Color("f6e3be"),"sphere")
		part(root,Vector3(12.4,0.22,1.65),Vector3(0,1.29,0.15),Color("db764a"))
		part(root,Vector3(4.4,0.15,1.15),Vector3(0,1.87,2.37),Color("efb567"))
		part(root,Vector3(0.2,2.15,1.25),Vector3(0,2.45,2.45),Color("db764a"))
		part(root,Vector3(1.45,0.55,1.25),Vector3(0,1.83,-0.9),Color("6aa9bb"),"sphere")
		part(root,Vector3(0.24,0.9,0.24),Vector3(-1.1,0.43,0.2),Color("293641"),"cylinder")
		part(root,Vector3(0.24,0.9,0.24),Vector3(1.1,0.43,0.2),Color("293641"),"cylinder")
	else:
		part(root,Vector3(2.55,1.95,5.1),Vector3(0,1.55,0),Color("edbd68"),"sphere")
		part(root,Vector3(2.2,1.12,2.4),Vector3(0,1.70,-1.18),Color("4c879b"),"sphere")
		part(root,Vector3(0.35,0.4,5.6),Vector3(0,1.86,3.35),Color("e4aa54"))
		part(root,Vector3(1.8,0.34,1.1),Vector3(0,2.50,5.60),Color("b65d44"))
		for side in [-1,1]:
			segment(root,Vector3(side*0.9,0.44,-1.15),Vector3(side*1.6,0.43,1.5),0.085,Color("293641"))
		var rotor_root = Node3D.new()
		rotor_root.name = "Rotor"
		rotor_root.position = Vector3(0,3.0,0)
		root.add_child(rotor_root)
		part(rotor_root,Vector3(0.18,0.9,0.18),Vector3(0,0.15,0),Color("454b50"),"cylinder")
		part(rotor_root,Vector3(9.2,0.10,0.32),Vector3(0,0.62,0),Color("363d42"))
		part(rotor_root,Vector3(0.32,0.10,9.2),Vector3(0,0.62,0),Color("363d42"))
	return root


static func surface(name_value: String,tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key = name_value+str(tint)
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	var base = "res://assets/realism/textures/"+name_value
	m.albedo_texture = load(base+"_diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load(base+"_nor_gl.jpg")
	m.normal_scale = 0.65
	m.roughness_texture = load(base+"_rough.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.albedo_color = tint*Color(0.55,0.55,0.58) if name_value=="asphalt" else tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE*(0.5 if name_value in ["asphalt","grass","concrete"] else 0.8)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if name_value=="metal": m.metallic = 0.65
	materials[key] = m
	return m

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
	# Readable silhouette at third-person distance: sights, rail, grip and stock.
	part(root,Vector3(0.07,0.045,0.14),Vector3(0,0.095,-length*0.12),Color("11181e"))
	part(root,Vector3(0.10,0.075,length*0.20),Vector3(0,0.06,length*0.25),Color("4b5257"))
	if kind>0:
		part(root,Vector3(0.07,0.17,0.27),Vector3(0,-0.035,length*0.55),Color("514738"))
	if kind==3:
		part(root,Vector3(0.085,0.09,0.35),Vector3(0,0.16,-0.09),Color("202d34"))
	batch_parts(root)
	return root
