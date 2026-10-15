"""Verify that native engine capture covers all 40 scenarios and three shapes."""
from pathlib import Path
import struct,hashlib,sys
folder=Path(sys.argv[1] if len(sys.argv)>1 else "monster-game/build")
names="menu shop monsters worlds powers-fly powers-locked powers-mask run pause pause-animated capture-zombie capture-skeleton capture-masked capture-fly police vehicle-count passengers pickups transform-early transform-fly perk tunnel-entry tunnel tunnel-exit city late-holes industrial airport gameover ritual credits wide wide-pause tablet".split()
names += ["burning-"+n for n in ["moto","car","bus","truck","tank","plane"]]
assert len(names)==40
for name in names:
    p=folder/("NoiteDaHorda-"+name+".png");raw=p.read_bytes()
    assert raw[:8]==b"\x89PNG\r\n\x1a\n",name
    size=struct.unpack(">II",raw[16:24])
    expected=(1600,720) if name in ["wide","wide-pause"] else (1280,960) if name=="tablet" else (1280,720)
    assert size==expected,(name,size,expected)
    assert len(raw)>15000,(name,"blank or incomplete PNG")
pause=[hashlib.sha256((folder/("NoiteDaHorda-"+n+".png")).read_bytes()).hexdigest() for n in ["pause","pause-animated"]]
assert pause[0]!=pause[1],"Paused UI must keep animating"
print("HORDE_PREVIEW_OK: 40 native screenshots, 1600x720 wide phone, 1280x960 tablet, animated paused UI")
