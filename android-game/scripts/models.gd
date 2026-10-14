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
	if size.y>=14: asset="town/shops/building-skyscraper-"+String.chr(97+posmod(style,5))
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
			elif original is BaseMaterial3D:
				var key="car_clean_"+str(original.get_instance_id())
				if not materials.has(key):
					var changed=original.duplicate()
					changed.normal_enabled=false
					changed.ao_enabled=false
					changed.emission_enabled=false
					if String(original.resource_name).to_lower().contains("tire") or String(original.resource_name).to_lower().contains("tyre"):
						changed.albedo_texture=null
						changed.albedo_color=Color("161e26")
						changed.metallic=0
						changed.roughness=.86
					materials[key]=changed
				part_node.set_surface_override_material(index,materials[key])
	return root

static func bike(_style: int = 0) -> Node3D:
	return imported("bike")

static func aircraft(plane: bool) -> Node3D:
	return imported("plane" if plane else "helicopter")

static func surface(name_value: String,tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key = name_value+str(tint)
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	var base = "res://assets/realism/textures/"+name_value
	m.albedo_texture = load(base+"_diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load(base+"_nor_gl.jpg")
	m.normal_scale = 0.22
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
	return imported("gun_%d" % clampi(kind,0,3))
