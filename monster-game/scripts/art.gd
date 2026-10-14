class_name HordeArt
extends RefCounted

var background: Texture2D=preload("res://assets/art/background.png")
var creature_sheet: Texture2D=preload("res://assets/art/creatures.png")
var item_sheet: Texture2D=preload("res://assets/art/items.png")
var title_font: Font=preload("res://assets/fonts/Bungee-Regular.ttf")
var body_font: Font=preload("res://assets/fonts/DejaVuSans.ttf")
var creatures: Array=[]
var items: Array[AtlasTexture]=[]
var baselines: Array[float]=[]
var rigs: Array=[]
var layers: Array[AtlasTexture]=[]
var sky: AtlasTexture
var world_layers: Array=[]
var world_thumbnails: Array[AtlasTexture]=[]
var vehicles: Array[AtlasTexture]=[]
var props: Array[AtlasTexture]=[]
var helicopter: Texture2D
var tunnel: Texture2D=preload("res://assets/art/tunnel-interior-v4.png")
var tunnel_mouths: Array[AtlasTexture]=[]
var ritual: Array[AtlasTexture]=[]
var vfx: Array[AtlasTexture]=[]

func _init() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/layout.json"))
	for row in data.creatures:
		var frames: Array[AtlasTexture]=[]
		for region in row.frames: frames.append(atlas(creature_sheet,region))
		creatures.append(frames)
		baselines.append(float(row.baseline))
	for region in data.items: items.append(atlas(item_sheet,region))
	var rig_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/rig-layout.json"))
	for rig in rig_data.rigs:
		var sheet=load("res://assets/art/"+str(rig.file)) as Texture2D
		var parts: Array[AtlasTexture]=[]
		for region in rig.parts: parts.append(atlas(sheet,region))
		rigs.append(parts)
	var scenery=preload("res://assets/art/parallax-v2.png")
	for region in rig_data.layers: layers.append(atlas(scenery,region))
	sky=atlas(background,[285,0,1251,465])
	world_layers.append(layers)
	var extra=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/world-layout.json"))
	for rig in extra.rigs:
		var sheet=load("res://assets/art/"+str(rig.file)) as Texture2D
		var parts: Array[AtlasTexture]=[]
		for region in rig.parts: parts.append(atlas(sheet,region))
		rigs.append(parts)
	for world in extra.worlds:
		var sheet=load("res://assets/art/"+str(world.file)) as Texture2D
		var world_parts: Array[AtlasTexture]=[]
		for region in world.layers: world_parts.append(atlas(sheet,region))
		world_layers.append(world_parts)
	for group in world_layers:
		var region=group[1].region
		world_thumbnails.append(atlas(group[1].atlas,[region.position.x+500,region.position.y,510,region.size.y]))
	var vehicle_sheet=preload("res://assets/art/vehicles-v3.png")
	for region in extra.vehicles: vehicles.append(atlas(vehicle_sheet,region))
	var prop_sheet=preload("res://assets/art/props-v3.png")
	for region in extra.props: props.append(atlas(prop_sheet,region))
	helicopter=vehicles[5]
	var newest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/atlas-v4.json"))
	for rig in newest.rigs:
		var sheet=load("res://assets/art/"+str(rig.file)) as Texture2D
		var parts: Array[AtlasTexture]=[]
		for region in rig.parts: parts.append(atlas(sheet,region))
		rigs.append(parts)
	vehicles.clear()
	for region in newest.vehicles: vehicles.append(atlas(preload("res://assets/art/vehicles-v4.png"),region))
	for region in newest.mouths: tunnel_mouths.append(atlas(preload("res://assets/art/tunnel-mouths-v4.png"),region))
	for region in newest.ritual: ritual.append(atlas(preload("res://assets/art/ritual-v4.png"),region))
	for region in newest.vfx: vfx.append(atlas(preload("res://assets/art/vfx-v4.png"),region))

func vehicle(kind: String) -> Texture2D:
	var index=int(MonsterCatalog.VEHICLES.get(kind,{"icon":-1}).icon)
	return items[7] if index<0 else vehicles[index]

static func atlas(sheet: Texture2D,region: Array) -> AtlasTexture:
	var texture=AtlasTexture.new()
	texture.atlas=sheet
	texture.region=Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
	texture.filter_clip=true
	return texture

func actor(kind: int,frame: int) -> AtlasTexture:
	return creatures[clampi(kind,0,3)][clampi(frame,0,5)]
