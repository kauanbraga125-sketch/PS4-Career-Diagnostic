"""Convert CC0 Quaternius guns and OpenGameArt aircraft into bounded mobile GLB."""
from pathlib import Path
import bpy,json,math,os
from mathutils import Matrix,Vector
CACHE=Path(os.environ['PORTO_ASSET_CACHE']);OUT=Path(os.environ['PORTO_ASSET_OUTPUT'])/'models';REPORT={}
def clear():
    for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
def load_blend(path):
    clear()
    with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.objects=src.objects
    for o in dst.objects:
        if o and o.type in ('MESH','EMPTY','ARMATURE'):bpy.context.collection.objects.link(o)
    bpy.context.view_layer.update()
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH':
            bpy.context.view_layer.objects.active=o
            for mod in list(o.modifiers):
                if mod.type!='ARMATURE':bpy.ops.object.modifier_apply(modifier=mod.name)
def meshes():return [o for o in bpy.context.scene.objects if o.type=='MESH']
def bounds():
    points=[o.matrix_world@v.co for o in meshes() for v in o.data.vertices]
    return Vector([min(p[i] for p in points) for i in range(3)]),Vector([max(p[i] for p in points) for i in range(3)])
def bake():
    bpy.context.view_layer.update()
    world={o:o.matrix_world.copy() for o in meshes()}
    for o,m in world.items():
        o.parent=None
        # matrix_world assignment does not clear Blender delta transforms.
        # The biplane propeller retained a second 90-degree rotation in glTF.
        o.delta_location=(0,0,0);o.delta_rotation_euler=(0,0,0)
        o.delta_rotation_quaternion=(1,0,0,0);o.delta_scale=(1,1,1)
        o.animation_data_clear()
        o.matrix_world=Matrix.Identity(4);o.data.transform(m)
    bpy.context.view_layer.update()
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
def paint(name,color,rough=.55,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value=(*color,1);b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal;return m
def export(name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes():o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_apply=True)
    lo,hi=bounds();REPORT[name]={'bounds':[list(lo),list(hi)],'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes())}
    print('STYLE_ASSET',name,json.dumps(REPORT[name]),flush=True)
for i,(name,length) in enumerate([('Pistol_1',.34),('SubmachineGun_2',.55),('Shotgun_1',.95),('AssaultRifle_1',.90)]):
    load_blend(next((CACHE/'guns').rglob(name+'.blend')));bake();lo,hi=bounds();factor=length/(hi.x-lo.x)
    rot=Matrix.Rotation(math.pi/2,4,'Z');center=Vector((lo.x+(hi.x-lo.x)*.24,(hi.y+lo.y)/2,(lo.z+hi.z)/2-.04/factor))
    for o in meshes():
        for v in o.data.vertices:v.co=rot@((v.co-center)*factor)
        for p in o.data.polygons:p.use_smooth=False
    export('gun_'+str(i))
load_blend(next((CACHE/'helicopter').rglob('heli.blend')));bake()
# Nose is at source -X; Blender +Y exports as Godot -Z.
for o in meshes():o.data.transform(Matrix.Rotation(-math.pi/2,4,'Z'))
lo,hi=bounds();factor=7.2/(hi.y-lo.y);center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
mat=paint('Helicopter painted body',(.22,.58,.82),.5,.18);tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(next((CACHE/'helicopter').rglob('heli.png'))));tex.image.pack();mat.node_tree.links.new(tex.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
for o in meshes():
    for v in o.data.vertices:v.co=(v.co-center)*factor
    o.data.materials.clear();o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
# Extract the rotor from the textured source rather than spinning the cabin.
import bmesh
for o in list(meshes()):
    bm=bmesh.new();bm.from_mesh(o.data)
    top=max(v.co.z for v in bm.verts)
    blades=[f for f in bm.faces if min(v.co.z for v in f.verts)>top-.30]
    if not blades:bm.free();continue
    selected=set(v.index for f in blades for v in f.verts)
    coords=[tuple(o.data.vertices[i].co) for i in sorted(selected)];lookup={old:i for i,old in enumerate(sorted(selected))}
    faces=[tuple(lookup[v.index] for v in f.verts) for f in blades]
    mesh=bpy.data.meshes.new('Rotor');mesh.from_pydata(coords,[],faces);mesh.materials.append(paint('Rotor dark metal',(.06,.09,.12)))
    rotor=bpy.data.objects.new('Rotor',mesh);bpy.context.collection.objects.link(rotor)
    bmesh.ops.delete(bm,geom=blades,context='FACES');bm.to_mesh(o.data);bm.free()
    bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=rotor;rotor.select_set(True);bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS');rotor.select_set(False)
export('helicopter')
load_blend(CACHE/'plane.blend');bake()
for o in meshes():o.data.transform(Matrix.Rotation(math.pi,4,'Z'))
lo,hi=bounds();factor=8.8/max(hi.x-lo.x,hi.y-lo.y);center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
palette={'base':(.86,.12,.06),'front':(.95,.68,.19),'mid':(.92,.81,.49),'black':(.028,.041,.055)}
for o in meshes():
    for v in o.data.vertices:v.co=(v.co-center)*factor
    for slot in o.material_slots:
        name=slot.material.name.split('.')[0] if slot.material else 'base';slot.material=paint('Biplane '+name,palette.get(name,(.35,.42,.48)),.5,.15)
    for p in o.data.polygons:p.use_smooth=True
export('plane');(OUT/'style-report.json').write_text(json.dumps(REPORT,indent=2)+'\n')
