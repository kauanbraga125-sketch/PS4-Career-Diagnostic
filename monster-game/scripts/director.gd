class_name HordeDirector
extends RefCounted

static func profile(world_px: float,count: int,pressure: float,recovery: float) -> Dictionary:
	var stage=int((world_px+MonsterCatalog.ANCHOR)/MonsterCatalog.ZONE_LENGTH)
	var base=minf(500,275+world_px/240.0)
	var target_pressure=clampf(float(count-5)/16.0,0,1)
	if stage>=5 and count>=10: target_pressure=minf(1,target_pressure+.25)
	if recovery>0 or count<=3: target_pressure=0
	var difficulty=clampf(float(stage)*.075+pressure*.50,0,1)
	var recruit_chance=clampf(.88-pressure*.66-float(stage)*.015,.20,.94)
	if recovery>0 or count<=3: recruit_chance=.98;difficulty*=.55
	var gap=clampf(130+stage*15+pressure*60,130,325)
	if recovery>0: gap=minf(gap,180)
	return {"stage":stage,"pressure_target":target_pressure,"difficulty":difficulty,
		"recruit_chance":recruit_chance,"gap":gap,"extra_hazard":.12+difficulty*.68,
		"speed":base+pressure*28,"bullet_period":maxf(1.15,2.1-difficulty*.8)}
