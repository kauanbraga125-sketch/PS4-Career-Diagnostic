"""Convert CC0 source art into bounded, skinned glTF assets using Blender 4.3.

Locomotion clips are authored here; they are not motion-capture recordings.
All characters wear complete outfits before export. Helpers and covered skin
are removed, textures are capped at 1K, and only deform bones are exported.
"""
from pathlib import Path
import importlib
import json
import math
import os
import sys
import bpy
import addon_utils
from mathutils import Vector, Quaternion

CACHE = Path(os.environ['PORTO_ASSET_CACHE'])
OUT = Path(os.environ['PORTO_ASSET_OUTPUT']) / 'models'
OUT.mkdir(parents=True, exist_ok=True)
REPORT = {}


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)


def asset(filename):
    results = sorted((CACHE / 'human').rglob(filename))
    if not results:
        raise FileNotFoundError(filename)
    return results[0]


def image(path):
    value = bpy.data.images.load(str(path), check_existing=True)
    if max(value.size) > 1024:
        ratio = 1024 / max(value.size)
        value.scale(max(1, int(value.size[0] * ratio)), max(1, int(value.size[1] * ratio)))
        value.pack()
    return value


def material(name, color=(0.35, 0.35, 0.35, 1), texture=None, metallic=0.0, roughness=0.75, alpha=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if texture:
        node = mat.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = image(texture)
        mat.node_tree.links.new(node.outputs['Color'], bsdf.inputs['Base Color'])
        if alpha:
            mat.node_tree.links.new(node.outputs['Alpha'], bsdf.inputs['Alpha'])
            mat.surface_render_method = 'DITHERED'
    return mat


def mh_material(obj, path, alpha=False):
    fields = {}
    for line in Path(path).read_text(errors='replace').splitlines():
        parts = line.strip().split(maxsplit=1)
        if len(parts) == 2 and not parts[0].startswith('#'):
            fields[parts[0]] = parts[1]
    texture = Path(path).parent / fields['diffuseTexture'] if 'diffuseTexture' in fields else None
    color = tuple(float(v) for v in fields.get('diffuseColor', '0.5 0.5 0.5').split()[:3]) + (1,)
    mat = material(obj.name + '_PBR', color, texture, alpha=alpha)
    if 'normalmapTexture' in fields:
        normal_path = Path(path).parent / fields['normalmapTexture']
        if normal_path.exists():
            nodes = mat.node_tree.nodes
            tex = nodes.new('ShaderNodeTexImage')
            tex.image = image(normal_path)
            tex.image.colorspace_settings.name = 'Non-Color'
            normal = nodes.new('ShaderNodeNormalMap')
            mat.node_tree.links.new(tex.outputs['Color'], normal.inputs['Color'])
            mat.node_tree.links.new(normal.outputs['Normal'], nodes.get('Principled BSDF').inputs['Normal'])
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def glb(name, animated=False):
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    for obj in meshes:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj.type in ('MESH', 'ARMATURE', 'EMPTY'):
            obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f'{name}.glb'), export_format='GLB', use_selection=True,
        export_animations=animated, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_frame_range=False,
        export_def_bones=True, export_skins=True, export_morph=False,
        export_apply=False, export_yup=True,
    )
    REPORT[name] = {
        'vertices': sum(len(obj.data.vertices) for obj in meshes),
        'triangles': sum(sum(len(face.vertices)-2 for face in obj.data.polygons) for obj in meshes),
        'meshes': [obj.name for obj in meshes],
        'animations': [a.name for a in bpy.data.actions] if animated else [],
        'bytes': (OUT / f'{name}.glb').stat().st_size,
    }
    print('MODEL_OK', name, json.dumps(REPORT[name]), flush=True)


def bone_rotation(rig, name, angle, axis='X', pre=None):
    bone = rig.pose.bones.get(name)
    if not bone:
        return
    world = Quaternion({'X': (1, 0, 0), 'Y': (0, 1, 0), 'Z': (0, 0, 1)}[axis], angle)
    if pre is not None:
        world = world @ pre
    rest = bone.bone.matrix_local.to_quaternion()
    bone.rotation_mode = 'QUATERNION'
    bone.rotation_quaternion = rest.inverted() @ world @ rest


def animate(rig):
    rig.animation_data_create()
    bpy.context.scene.render.fps = 30
    arm_down = {}
    for side, sign in [('Left', 1), ('Right', -1)]:
        bone = rig.data.bones[f'{side}Arm']
        arm_down[side] = (bone.tail_local - bone.head_local).normalized().rotation_difference(Vector((sign * .14, 0, -1)).normalized())
    clips = {'idle': 60, 'walk': 32, 'run': 22, 'jump': 24, 'fall': 30, 'land': 12, 'death': 36, 'riding': 30, 'aim': 30}
    for name, frames in clips.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        for frame in range(frames + 1):
            t = frame / frames
            phase = t * math.tau
            for bone in rig.pose.bones:
                bone.location = (0, 0, 0)
                bone.rotation_mode = 'QUATERNION'
                bone.rotation_quaternion = Quaternion()
                bone.scale = (1, 1, 1)
            bob = .005 * math.sin(phase)
            lean = 0.0
            for side, sign in [('Left', 1), ('Right', -1)]:
                swing = math.sin(phase) * sign
                hip, knee, foot, arm, elbow = 0., .04, 0., .015 * swing, -.12
                if name in ('walk', 'run'):
                    running = name == 'run'
                    hip = swing * (.68 if running else .40)
                    knee = -(.12 + max(0, -swing) * (1.22 if running else .65))
                    foot = -hip * .25 - knee * .25
                    arm = -swing * (.62 if running else .30)
                    elbow = -.90 if running else -.22
                    bob = (.035 if running else .015) * (1 - math.cos(phase * 2))
                    lean = .10 if running else .025
                elif name == 'jump':
                    hip = .38 * math.sin(t * math.pi) + .10
                    knee = -.70 * math.sin(t * math.pi) - .15
                    arm = -.55 * math.sin(t * math.pi)
                    elbow = -.70
                    lean = .12
                elif name == 'fall':
                    hip, knee, arm, elbow = .12 * sign, -.27, -.18, -.6
                elif name == 'land':
                    crouch = math.sin(t * math.pi)
                    hip, knee, arm, elbow = .48 * crouch, -.90 * crouch, -.3 * crouch, -.45
                    bob = -.13 * crouch
                    lean = .2 * crouch
                elif name == 'riding':
                    hip, knee, arm, elbow = 1.15, -1.45, -.92, -.38
                    lean = .14
                elif name == 'aim':
                    arm, elbow = -1.35, -.16 if side == 'Right' else -.60
                    lean = .06
                elif name == 'death':
                    ease = min(1, t * 1.4)
                    hip, knee, arm, elbow = .2 * ease, -.35 * ease, -.25 * ease, -.25
                    lean = -1.47 * ease
                    bob = -.83 * ease
                bone_rotation(rig, side + 'UpLeg', hip)
                bone_rotation(rig, side + 'Leg', knee)
                bone_rotation(rig, side + 'Foot', foot)
                bone_rotation(rig, side + 'Arm', arm, pre=arm_down[side])
                bone_rotation(rig, side + 'ForeArm', elbow)
            bone_rotation(rig, 'Spine', lean)
            if name == 'death':
                bone_rotation(rig, 'Hips', lean)
                bone_rotation(rig, 'Spine', .10)
            root = rig.pose.bones['Hips']
            root.location = root.bone.matrix_local.to_quaternion().inverted() @ Vector((0, 0, bob))
            for bone in rig.pose.bones:
                bone.keyframe_insert('rotation_quaternion', frame=frame + 1, group=bone.name)
                if bone.name == 'Hips':
                    bone.keyframe_insert('location', frame=frame + 1, group=bone.name)
        for curve in action.fcurves:
            for key in curve.keyframe_points:
                key.interpolation = 'LINEAR'
    rig.animation_data.action = bpy.data.actions.get('idle')
    bpy.context.scene.frame_set(1)


def people():
    source = os.environ['PORTO_MPFB']
    repo = bpy.context.preferences.extensions.repos.new(name='Porto Assets', module='porto_assets', custom_directory=source)
    addon_utils.modules_refresh()
    module_name = 'bl_ext.porto_assets.mpfb'
    addon_utils.enable(module_name, default_set=True)
    HumanService = importlib.import_module(module_name + '.services.humanservice').HumanService
    TargetService = importlib.import_module(module_name + '.services.targetservice').TargetService
    variants = [
        (1., 'young_african_male', 'male_casualsuit01', 'short02', 'shoes01', .56),
        (0., 'young_caucasian_female', 'female_casualsuit01', 'ponytail01', 'shoes02', .47),
        (1., 'middleage_caucasian_male', 'male_casualsuit03', 'short01', 'shoes03', .62),
        (0., 'young_african_female', 'female_casualsuit02', 'bob01', 'shoes02', .53),
    ]
    for index, (gender, skin, outfit, hair, shoes, weight) in enumerate(variants):
        clear()
        macro = TargetService.get_default_macro_info_dict()
        macro.update(gender=gender, age=.4, weight=weight, muscle=.5, height=.53 if gender else .47)
        macro['race'] = {'african': 1. if 'african' in skin else 0., 'asian': 0., 'caucasian': 0. if 'african' in skin else 1.}
        human = HumanService.create_human(macro_detail_dict=macro)
        human.name = 'Body'
        mh_material(human, asset(skin + '.mhmat'))
        rig = HumanService.add_builtin_rig(human, 'cmu_mb')
        rig.name = 'Skeleton'
        for item, kind in [(outfit, 'Clothes'), (shoes, 'Clothes'), (hair, 'Hair'), ('low-poly', 'Eyes'), ('eyebrow001', 'Eyebrows')]:
            paths = sorted((CACHE / 'human').rglob(item + '.mhclo'))
            if not paths and kind in ('Eyes', 'Eyebrows'):
                print('OPTIONAL_ASSET_MISSING', item, flush=True)
                continue
            if not paths:
                raise FileNotFoundError(item)
            path = paths[0]
            clothing = HumanService.add_mhclo_asset(str(path), human, asset_type=kind, subdiv_levels=0, material_type='NONE')
            mhmat_names = [line.split(maxsplit=1)[1].strip() for line in path.read_text().splitlines() if line.startswith('material ')]
            mhmat = path.parent / mhmat_names[0] if mhmat_names else next(path.parent.glob('*.mhmat'))
            mh_material(clothing, mhmat, alpha=kind in ('Hair', 'Eyebrows'))
        for obj in list(bpy.context.scene.objects):
            if obj.type != 'MESH':
                continue
            activate(obj)
            if obj.data.shape_keys:
                obj.shape_key_add(name='Baked', from_mix=True)
                for key in list(obj.data.shape_keys.key_blocks)[:-1]:
                    obj.shape_key_remove(key)
                obj.shape_key_clear()
            for modifier in list(obj.modifiers):
                if modifier.type == 'MASK':
                    bpy.ops.object.modifier_apply(modifier=modifier.name)
                elif modifier.type != 'ARMATURE':
                    obj.modifiers.remove(modifier)
        animate(rig)
        glb(f'person_{index}', animated=True)


def normalize_vehicle(length):
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for obj in list(bpy.context.scene.objects):
        if obj.type not in ('MESH', 'EMPTY'):
            bpy.data.objects.remove(obj, do_unlink=True)
    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
    for obj in list(bpy.context.scene.objects):
        if obj.type == 'EMPTY':
            bpy.data.objects.remove(obj, do_unlink=True)
    points = [o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
    sizes = [max(p[i] for p in points) - min(p[i] for p in points) for i in range(3)]
    if sizes[0] > sizes[1]:
        for obj in meshes:
            obj.rotation_euler.z += math.pi / 2
        bpy.context.view_layer.update()
    points = [o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    factor = length / (hi.y - lo.y)
    center = Vector(((lo.x + hi.x)/2, (lo.y + hi.y)/2, lo.z))
    for obj in meshes:
        obj.location = (obj.location - center) * factor
        obj.scale *= factor
        activate(obj)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    print('VEHICLE_BOUNDS', list((hi - lo) * factor), flush=True)


def vehicles():
    clear()
    bpy.ops.import_scene.fbx(filepath=str(next((CACHE / 'car').glob('*.fbx'))))
    print('CAR_MATERIALS', [m.name for m in bpy.data.materials], flush=True)
    body_texture = next((CACHE / 'car').glob('*Texture*.png'))
    tyre_texture = next((CACHE / 'car').glob('*Tyres*.png'))
    for obj in [o for o in bpy.context.scene.objects if o.type == 'MESH']:
        for slot in obj.material_slots:
            old = slot.material.name.lower() if slot.material else obj.name.lower()
            if 'glass' in old:
                slot.material = material('Glass', (.10, .16, .19, 1), metallic=.55, roughness=.16)
            else:
                tyre = 'tyre' in old or 'tire' in old or 'wheel' in old
                slot.material = material('Tyres' if tyre else 'Paint', texture=tyre_texture if tyre else body_texture, metallic=.0 if tyre else .55, roughness=.82 if tyre else .28)
    normalize_vehicle(4.3)
    glb('car')
    clear()
    with bpy.data.libraries.load(str(CACHE / 'bike.blend'), link=False) as (source, target):
        target.objects = source.objects
    for obj in target.objects:
        if obj and obj.type == 'MESH':
            bpy.context.collection.objects.link(obj)
    print('BIKE_PARTS', [(o.name, [s.material.name if s.material else '' for s in o.material_slots]) for o in bpy.context.scene.objects], flush=True)
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        if not obj.material_slots:
            obj.data.materials.append(material('Bike metal', (.15, .18, .21, 1), metallic=.75, roughness=.32))
        for slot in obj.material_slots:
            old = slot.material
            color = tuple(old.diffuse_color) if old else (.2, .22, .25, 1)
            name = old.name.lower() if old else obj.name.lower()
            rubber = any(s in name for s in ('rubber', 'tire', 'tyre', 'seat')) or max(color[:3]) < .08
            slot.material = material('Bike_' + name, color, metallic=0 if rubber else .65, roughness=.85 if rubber else .32)
    normalize_vehicle(2.15)
    glb('bike')


people()
vehicles()
(OUT / 'report.json').write_text(json.dumps(REPORT, indent=2) + '\n')
