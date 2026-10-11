class_name StreetAtmosphere
extends Node3D

# Layered cloud billows: inexpensive volumetric silhouette, not GPU raymarching.
# One material/mesh and one draw call per cloud tint via MultiMesh.
func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 991452
	var mesh = SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	for layer in range(3):
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = [Color("fff8e9"),Color("e8f2f2"),Color("bfd6dd")][layer]
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = 108
		for i in range(108):
			var group = i/3
			var x = rng.randf_range(-1250.0,1250.0)
			var z = rng.randf_range(-1250.0,1250.0)
			var center_height = rng.randf_range(190.0,265.0)
			var puff = Vector3(x+(i%3-1)*15.0,center_height+layer*4.0+sin(float(i))*3.0,z+(i%3-1)*10.0)
			var scale_value = Vector3(rng.randf_range(20.0,52.0),rng.randf_range(6.0,13.0),rng.randf_range(12.0,32.0))
			mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(scale_value),puff))
		var cloud = MultiMeshInstance3D.new()
		cloud.multimesh = mm
		cloud.material_override = material
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cloud)
