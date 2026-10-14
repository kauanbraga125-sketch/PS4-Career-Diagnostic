"""Retarget KayKit's CC0 humanoid clips; gameplay owns root motion.

Explicit rest-direction alignment handles the MakeHuman A-pose and KayKit T-pose.
Target bone lengths are retained and root translation is restricted to body bob.
"""
from pathlib import Path
import os
import bpy
from mathutils import Matrix, Quaternion, Vector
CACHE=None
BONES={'Hips':'hips','Spine':'spine','Spine1':'chest','Head':'head'}
for side,suffix in [('Left','l'),('Right','r')]:
    BONES.update({side+a:b+'.'+suffix for a,b in [('Arm','upperarm'),('ForeArm','lowerarm'),('Hand','hand'),('UpLeg','upperleg'),('Leg','lowerleg'),('Foot','foot'),('ToeBase','toes')]})
CLIPS={'MovementBasic':{'walk':'Walking_A','run':'Running_A','jump':'Jump_Start','fall':'Jump_Idle','land':'Jump_Land'},'General':{'idle':'Idle_A','death':'Death_A'},'CombatRanged':{'aim':'Ranged_2H_Aiming'}}

def source_clips():
    global CACHE
    if CACHE is not None:return CACHE
    CACHE={}
    for filename,labels in CLIPS.items():
        before=set(bpy.data.objects);old_actions=set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=str(Path(os.environ['PORTO_ASSET_CACHE'])/(filename+'.glb')))
        added=set(bpy.data.objects)-before
        rig=next(o for o in added if o.type=='ARMATURE')
        for track in rig.animation_data.nla_tracks:track.mute=True
        rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
        directions={b.name:(b.tail_local-b.head_local).normalized() for b in rig.data.bones}
        for name,source_name in labels.items():
            action=next(a for a in bpy.data.actions if a not in old_actions and (a.name==source_name or a.name.startswith(source_name+'_Rig_')))
            rig.animation_data.action=action
            start,end=action.frame_range;count=max(2,round(end-start));frames=[]
            for frame in range(count+1):
                bpy.context.scene.frame_set(int(start)+frame)
                frames.append({b.name:b.matrix.copy() for b in rig.pose.bones})
            CACHE[name]=(rest,directions,frames)
            print('RETARGET_SOURCE',name,action.name,count,flush=True)
        for obj in added:bpy.data.objects.remove(obj,do_unlink=True)
        for action in set(bpy.data.actions)-old_actions:bpy.data.actions.remove(action)
    return CACHE

def apply(rig):
    sampled=source_clips();rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:track.mute=True
    for name,(source_rest,source_dirs,frames) in sampled.items():
        for old in list(bpy.data.actions):
            if old.name==name:bpy.data.actions.remove(old)
        action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
        for frame,source_pose in enumerate(frames):
            pose_matrices={}
            for bone in rig.pose.bones:
                bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion();bone.location=(0,0,0);bone.scale=(1,1,1)
                rest=bone.bone.matrix_local
                parent_rest=bone.parent.bone.matrix_local if bone.parent else Matrix.Identity(4)
                parent_pose=pose_matrices[bone.parent.name] if bone.parent else Matrix.Identity(4)
                local_rest=parent_rest.inverted()@rest
                if bone.name in BONES and BONES[bone.name] in source_pose:
                    src=BONES[bone.name]
                    delta=source_pose[src].to_quaternion()@source_rest[src].to_quaternion().inverted()
                    align=Quaternion()
                    if bone.name.startswith(('Left','Right')):
                        direction=(bone.bone.tail_local-bone.bone.head_local).normalized()
                        align=direction.rotation_difference(source_dirs[src])
                    desired=delta@align@rest.to_quaternion()
                    bone.rotation_quaternion=local_rest.to_quaternion().inverted()@parent_pose.to_quaternion().inverted()@desired
                if bone.name=='Hips':
                    offset=source_pose['hips'].translation.z-source_rest['hips'].translation.z
                    bone.location=rest.to_quaternion().inverted()@Vector((0,0,max(-.10,min(.10,offset*1.35))))
                basis=Matrix.LocRotScale(bone.location,bone.rotation_quaternion,Vector((1,1,1)))
                pose_matrices[bone.name]=parent_pose@local_rest@basis
                bone.keyframe_insert('rotation_quaternion',frame=frame+1,group=bone.name)
                if bone.name=='Hips':bone.keyframe_insert('location',frame=frame+1,group=bone.name)
            if name in ('idle','walk','run','aim'):
                feet=[label for label in ('LeftToeBase','RightToeBase') if label in pose_matrices]
                if feet:
                    lift=min(pose_matrices[label].translation.z-rig.data.bones[label].head_local.z for label in feet)
                    hip=rig.pose.bones['Hips']
                    hip.location+=hip.bone.matrix_local.to_quaternion().inverted()@Vector((0,0,max(-.35,min(.35,-lift))))
                    hip.keyframe_insert('location',frame=frame+1,group=hip.name)
        for curve in action.fcurves:
            for key in curve.keyframe_points:key.interpolation='LINEAR'
    rig.animation_data.action=bpy.data.actions.get('idle');bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
