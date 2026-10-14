class_name StreetParachute
extends Node3D

func _init() -> void:
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strip in range(12):
		var a=-1.2+strip*.2
		var b=a+.2
		var x0=sin(a)*3.5
		var x1=sin(b)*3.5
		var y0=2.8+cos(a)*1.6
		var y1=2.8+cos(b)*1.6
		for p in [Vector3(x0,y0,-1.5),Vector3(x1,y1,-1.5),Vector3(x0,y0,1.5),Vector3(x1,y1,-1.5),Vector3(x1,y1,1.5),Vector3(x0,y0,1.5)]:
			st.set_color(Color("f1ba64") if strip%3 else Color("48b5b2"))
			st.add_vertex(p)
	st.generate_normals()
	var canopy=MeshInstance3D.new()
	canopy.mesh=st.commit()
	var fabric=StandardMaterial3D.new()
	fabric.vertex_color_use_as_albedo=true
	fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
	fabric.roughness=.9
	canopy.material_override=fabric
	add_child(canopy)
	for x in [-2.9,-1.5,1.5,2.9]:
		for z in [-1.35,1.35]: StreetModels.segment(self,Vector3(signf(x)*.25,1.1,0),Vector3(x,3.8 if absf(x)<2 else 3.3,z),.018,Color("f7ead5"))
	visible=false
