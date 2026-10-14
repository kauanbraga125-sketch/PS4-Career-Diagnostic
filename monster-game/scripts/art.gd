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

func _init() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/layout.json"))
	for row in data.creatures:
		var frames: Array[AtlasTexture]=[]
		for region in row.frames: frames.append(atlas(creature_sheet,region))
		creatures.append(frames)
		baselines.append(float(row.baseline))
	for region in data.items: items.append(atlas(item_sheet,region))

static func atlas(sheet: Texture2D,region: Array) -> AtlasTexture:
	var texture=AtlasTexture.new()
	texture.atlas=sheet
	texture.region=Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
	texture.filter_clip=true
	return texture

func actor(kind: int,frame: int) -> AtlasTexture:
	return creatures[clampi(kind,0,3)][clampi(frame,0,5)]
