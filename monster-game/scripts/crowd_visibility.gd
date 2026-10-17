class_name HordeCrowdVisibility
extends RefCounted

# Keep the front silhouettes and all distinctive actions. Hidden members still
# receive every physics, collision, recruitment and jump update.
static func visible(run) -> Dictionary:
	var result: Dictionary = {}
	var cells: Dictionary = {}
	for i in range(run.members.size()):
		var m: Dictionary = run.members[i]
		var point = Vector2(m.x, m.y - run.member_depth(i))
		var cell = Vector2i(floori(point.x / 14.0), floori(point.y / 12.0))
		var hidden = false
		if run.members.size() > 36 and not m.falling and float(m.attack_left) <= 0 and float(m.arrival) <= 0:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					for other in cells.get(cell + Vector2i(dx, dy), []):
						if absf(point.x - other.x) <= 11 and absf(point.y - other.y) <= 8: hidden = true;break
		if hidden: continue
		result[i] = true
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(point)
	return result
