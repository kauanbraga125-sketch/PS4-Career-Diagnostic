"""Build a signed resource update using an existing Godot 4.5.1 APK template.

Native Android/Godot libraries and the original package ID remain unchanged.
Game resources come from Godot's --export-pack Android output. The signing key
is supplied separately and never belongs in the repository.
"""
import argparse
import fnmatch
import copy
import json
import os
import struct
import subprocess
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_STORED, ZIP_DEFLATED

def string_pool(data, offset):
    header=struct.unpack_from('<H',data,offset+2)[0]
    count,_,flags,start,_=struct.unpack_from('<5I',data,offset+8)
    strings=[];locations=[]
    for i in range(count):
        p=offset+start+struct.unpack_from('<I',data,offset+header+4*i)[0]
        if flags&0x100:
            def length(pos):
                value=data[pos]
                return (((value&127)<<8)|data[pos+1],pos+2) if value&128 else (value,pos+1)
            _,p=length(p);size,p=length(p);raw=data[p:p+size]
            strings.append(raw.decode('utf8'));locations.append((p,size,'utf8'))
        else:
            size=struct.unpack_from('<H',data,p)[0];p+=2
            if size&0x8000:size=((size&0x7fff)<<16)|struct.unpack_from('<H',data,p)[0];p+=2
            strings.append(data[p:p+size*2].decode('utf-16le'));locations.append((p,size*2,'utf-16le'))
    return strings,locations

def replace_pool_string(data, offset, index, value):
    """Grow an AXML string without changing any of the manifest's string IDs."""
    header=struct.unpack_from('<H',data,offset+2)[0]
    size=struct.unpack_from('<I',data,offset+4)[0]
    count,styles,flags,start,style_start=struct.unpack_from('<5I',data,offset+8)
    pool=bytearray(data[offset:offset+size])
    relative=struct.unpack_from('<I',pool,header+index*4)[0]
    position=start+relative
    def len8(n):
        return bytes([n]) if n<128 else bytes([(n>>8)|0x80,n&255])
    def len16(n):
        return struct.pack('<H',n) if n<32768 else struct.pack('<HH',(n>>16)|0x8000,n&65535)
    if flags&0x100:
        def read8(p):
            first=pool[p]
            return ((((first&127)<<8)|pool[p+1]),p+2) if first&128 else (first,p+1)
        _,p=read8(position);old_bytes,p=read8(p)
        end=p+old_bytes+1
        raw=value.encode('utf8')
        replacement=len8(len(value.encode('utf-16le'))//2)+len8(len(raw))+raw+b'\0'
    else:
        old_chars=struct.unpack_from('<H',pool,position)[0];p=position+2
        if old_chars&0x8000:
            old_chars=((old_chars&0x7fff)<<16)|struct.unpack_from('<H',pool,p)[0];p+=2
        end=p+old_chars*2+2
        raw=value.encode('utf-16le');replacement=len16(len(raw)//2)+raw+b'\0\0'
    delta=len(replacement)-(end-position)
    pool[position:end]=replacement
    for i in range(count):
        old=struct.unpack_from('<I',pool,header+i*4)[0]
        if old>relative:struct.pack_into('<I',pool,header+i*4,old+delta)
    if style_start:
        shifted=style_start+delta;pad=(-shifted)%4
        pool[shifted:shifted]=bytes(pad)
        struct.pack_into('<I',pool,24,shifted+pad)
    pool.extend(bytes((-len(pool))%4))
    struct.pack_into('<I',pool,4,len(pool))
    data[offset:offset+size]=pool
    struct.pack_into('<I',data,4,len(data))
    return data

def patch_manifest(raw,version,code):
    data=bytearray(raw);strings=[];locations=[];metadata={};offset=8;pool_offset=None;version_index=None
    while offset<len(data):
        kind,header,size=struct.unpack_from('<HHI',data,offset)
        if kind==1:strings,locations=string_pool(data,offset);pool_offset=offset
        elif kind==0x102:
            tag=struct.unpack_from('<I',data,offset+20)[0]
            attr_start,attr_size,count=struct.unpack_from('<HHH',data,offset+24)
            if strings[tag]=='manifest':
                for i in range(count):
                    a=offset+16+attr_start+i*attr_size
                    _,name,raw_value=struct.unpack_from('<III',data,a)
                    dtype=data[a+15];value=struct.unpack_from('<I',data,a+16)[0];key=strings[name]
                    if key=='versionCode':
                        metadata['previousVersionCode']=value
                        code=max(code,value+1)
                        struct.pack_into('<I',data,a+16,code)
                    elif key=='versionName':
                        index=value if dtype==3 else raw_value
                        metadata['previousVersionName']=strings[index]
                        version_index=index
                    elif key=='package':metadata['package']=strings[value if dtype==3 else raw_value]
        if size<8:raise ValueError('Invalid Android manifest chunk')
        offset+=size
    metadata.update(versionName=version,versionCode=code)
    if 'previousVersionCode' not in metadata:raise ValueError('Template has no manifest versionCode')
    if version_index is None or pool_offset is None:raise ValueError('Template has no manifest versionName')
    data=replace_pool_string(data,pool_offset,version_index,version)
    return bytes(data),metadata

def write_entry(archive,info,data):
    info=copy.copy(info);info.extra=b''
    if info.compress_type==ZIP_STORED:
        alignment=16384 if info.filename.endswith('.so') else 4
        offset=archive.fp.tell()+30+len(info.filename.encode('utf8'))
        padding=(-offset)%alignment
        if padding:
            if padding<4:padding+=alignment
            info.extra=struct.pack('<HH',0xd935,padding-4)+bytes(padding-4)
    archive.writestr(info,data)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--template',required=True,type=Path)
    parser.add_argument('--resources',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--keystore',required=True,type=Path)
    parser.add_argument('--signer-classpath',required=True)
    parser.add_argument('--alias',default='androiddebugkey')
    parser.add_argument('--version',default='0.8.6')
    parser.add_argument('--version-code',type=int,default=24)
    parser.add_argument('--resource-overlay',action='append',default=[],help='Replace only matching resource paths and preserve all other assets from the template')
    args=parser.parse_args()
    password_env='GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD'
    if not os.environ.get(password_env):raise ValueError('Signing password environment variable is required')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    unsigned=args.output.with_name(args.output.stem+'-unsigned.apk')
    with ZipFile(args.template) as template,ZipFile(args.resources) as resources,ZipFile(unsigned,'w') as target:
        manifest,metadata=patch_manifest(template.read('AndroidManifest.xml'),args.version,args.version_code)
        replacements={i.filename for i in resources.infolist() if not i.is_dir() and (not args.resource_overlay or any(fnmatch.fnmatchcase(i.filename,p) for p in args.resource_overlay))}
        for pattern in args.resource_overlay:
            if not any(fnmatch.fnmatchcase(name,pattern) for name in replacements):raise ValueError('No exported resource matches '+pattern)
        preserved=0
        for info in template.infolist():
            if info.filename.startswith('assets/'):
                if not args.resource_overlay or info.filename[7:] in replacements:continue
                preserved+=1
            if info.filename.startswith('META-INF/') and (info.filename.endswith(('.RSA','.SF','.DSA','.EC')) or info.filename=='META-INF/MANIFEST.MF'):continue
            write_entry(target,info,manifest if info.filename=='AndroidManifest.xml' else template.read(info))
        for info in resources.infolist():
            if info.is_dir() or info.filename not in replacements:continue
            dest=ZipInfo('assets/'+info.filename,date_time=info.date_time)
            dest.compress_type=ZIP_DEFLATED
            write_entry(target,dest,resources.read(info))
    command=['java','-cp',args.signer_classpath,'com.android.apksigner.ApkSignerTool']
    subprocess.run(command+['sign','--ks',str(args.keystore),'--ks-key-alias',args.alias,'--ks-pass','env:'+password_env,'--key-pass','env:'+password_env,'--out',str(args.output),str(unsigned)],check=True)
    subprocess.run(command+['verify','--verbose',str(args.output)],check=True)
    with ZipFile(args.output) as built:
        if built.testzip() is not None:raise ValueError('APK ZIP integrity verification failed')
        if 'assets/assets/art/menu-zombie-animation.json' not in built.namelist():raise ValueError('Menu animation metadata was not exported')
        if 'assets/scripts/menu_zombie.gdc' not in built.namelist():raise ValueError('Menu animation script was not compiled')
    print(json.dumps({'apk':str(args.output),'size':args.output.stat().st_size,'updated_resources':len(replacements),'preserved_resources':preserved,**metadata}))

if __name__=='__main__':main()
