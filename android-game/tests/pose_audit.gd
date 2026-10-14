extends SceneTree

var failures: Array[String]=[]

func _init(): call_deferred("audit")

func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error("POSE_AUDIT_FAIL: "+message)

func audit() -> void:
	var scene=Node3D.new()
	root.add_child(scene)
	for kind in range(4):
		var gun=StreetModels.gun(kind)
		scene.add_child(gun)
		var parts: Array=[]
		StreetModels.collect_meshes(gun,Transform3D.IDENTITY,parts)
		for part in parts:
			var bounds=part.transform*part.mesh.get_aabb()
			print("GUN_AXIS ",kind," root=",gun.transform," bound=",bounds)
			check(bounds.size.z>bounds.size.x*3 and bounds.position.z<0,"Imported gun points along forward -Z: "+str(kind))
		gun.queue_free()
	var plane=StreetModels.imported("plane")
	scene.add_child(plane)
	var found_propeller=false
	for instance in plane.find_children("*","MeshInstance3D",true,false):
		if String(instance.name)!="Plane": continue
		found_propeller=true
		var bounds=(plane.global_transform.affine_inverse()*instance.global_transform)*instance.mesh.get_aabb()
		print("AIRCRAFT_PROPELLER center=",bounds.get_center()," size=",bounds.size)
		check(bounds.get_center().z<-3 and bounds.get_center().y>1 and bounds.get_center().y<3,"Biplane propeller stays at the nose")
		check(bounds.size.z<.4 and bounds.size.x>1,"Biplane propeller lies in its correct rotation plane")
	check(found_propeller,"Imported biplane has a propeller")
	plane.queue_free()
	var floor_body=StaticBody3D.new()
	scene.add_child(floor_body)
	floor_body.collision_layer=1
	floor_body.position=Vector3(3000,0,3000)
	var shape=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(30,.3,30)
	shape.shape=box
	shape.position.y=-.15
	floor_body.add_child(shape)
	var actors: Array[StreetActor]=[]
	for style in range(4):
		var actor=StreetModels.person(style)
		scene.add_child(actor)
		actors.append(actor)
	# Test varied animation poses, impact impulses, and the same rigs after
	# respawn. A free-fall-only check misses unstable constraints on impact.
	for attempt in range(2):
		for style in range(4):
			var actor=actors[style]
			if attempt>0: actor.recover()
			actor.position=Vector3(2994+style*4,3+attempt,3000)
			var clip=["idle","walk","run","jump"][posmod(style+attempt,4)]
			actor.animator.play(actor.clips[clip],0)
			actor.animator.advance(0)
			actor.animator.seek(.25,true)
			actor.animator.advance(0)
			actor.animator.pause()
		await physics_frame
		for style in range(4): actors[style].death_pose(Vector3(1+style*.5,0,.3*attempt))
		for frame in range(240): await physics_frame
		for style in range(4):
			var actor=actors[style]
			var hips=actor.simulator.get_node("Body_Hips") as PhysicalBone3D
			print("RAGDOLL_SETTLED style=",style," attempt=",attempt," hips=",hips.global_position," speed=",hips.linear_velocity.length())
			check(hips.global_position.y>-.15 and hips.global_position.y<.85,"Ragdoll reaches the floor and stays there: "+str(style))
			check(hips.linear_velocity.length()<2.5,"Ragdoll settles after ground impact: "+str(style))
			for body in actor.simulator.get_children():
				check(body.global_position.distance_to(hips.global_position)<1.8,"Ragdoll limb remains attached: "+str(style)+" "+body.get("bone_name"))
				check(body.global_position.y>-.3,"Ragdoll limb collides with ground: "+str(style)+" "+body.get("bone_name"))
			actor.recover()
			check(not actor.simulator.is_simulating_physics() and not actor.dead,"Physical rig recovers for play: "+str(style))
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("POSE_AUDIT_OK: imported weapon axes, four physical rigs, ground impact, repeated deaths and recovery")
		quit(0)
	else: quit(1)
