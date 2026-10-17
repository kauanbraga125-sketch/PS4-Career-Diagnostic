extends SceneTree
func _initialize() -> void:
	var failed = 0;var checked = 0
	for stage in [0,3,8,14]:
		for level in [0,1,2,3]:
			for kind in ["bomb_sequence","air_sequence","mixed","gap_chain","collapse","convoy"]:
				for variation in range(6):
					var r = HordeRun.new();r.start_developer(kind,36,stage,8800+variation)
					r.levels.jump = level;r.developer_iteration = variation+1
					var p = HordeDirector.profile(0,36,r.pressure,0,stage)
					var plan = HordeCourse.sequence_plan(r,kind,3000,r.speed,p)
					checked += 1
					if not HordeSequenceValidator.validate(r,plan.parts,plan.commands,plan.start,plan.end,r.speed):
						failed += 1
						if failed < 12:print("UPGRADE_BAD "+str([stage,level,kind,variation]))
	print("UPGRADE_RESULT "+str([checked,failed]));quit(0 if failed==0 else 1)
