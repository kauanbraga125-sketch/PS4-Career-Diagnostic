class_name HordeDirector
extends RefCounted

static func profile(world_px: float,count: int,pressure: float,recovery: float,stage: int=0) -> Dictionary:
	var base=minf(500,275+world_px/600.0+stage*8)
	var target_pressure=clampf(float(count-5)/16.0,0,1)
	if stage>=5 and count>=10: target_pressure=minf(1,target_pressure+.25)
	if recovery>0 or count<=3: target_pressure=0
	var difficulty=clampf(stage*.10+pressure*.42,0,1)
	var recruit_chance=clampf(.84-pressure*.55-stage*.025,.22,.92)
	var cluster=mini(5,1+int(stage/2))
	if recovery>0 or count<=3:
		recruit_chance=.97;difficulty*=.5;cluster=mini(cluster,2)
	var gap=clampf(135+stage*22+pressure*50,135,325)
	if recovery>0: gap=minf(gap,180)
	return {"stage":stage,"pressure_target":target_pressure,"difficulty":difficulty,
		"recruit_chance":recruit_chance,"gap":gap,"extra_hazard":.1+difficulty*.65,
		"speed":base+pressure*28,"bullet_period":maxf(1.2,2.2-difficulty*.8),"cluster":cluster,
		"spacing":maxf(490,(base+pressure*28)*1.15)}
