// Asset preparation only. Runtime uses the resulting PNG and JSON, not Node.
const fs=require('fs'),path=require('path'),sharp=require('sharp'),{PNG}=require('pngjs');
const input=process.argv[2],dest=process.argv[3];
if(!input||!dest)throw Error('Usage: node normalize_menu_sprites.cjs INPUT.png OUTPUT.png');
const src=PNG.sync.read(fs.readFileSync(input));
if(src.width!==4096||src.height!==3072)throw Error('Expected approved 8x6 sheet with 512px cells');
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
function material(r,g,b,y){
 const max=Math.max(r,g,b),min=Math.min(r,g,b),d=max-min;if(max<34||d<18)return null;
 const s=d/max;let h=max===r?60*((g-b)/d%6):max===g?60*((b-r)/d+2):60*((r-g)/d+4);if(h<0)h+=360;
 const t=(y-30)/458;
 if(h>47&&h<108&&s>.24)return 'skin';
 if(h>260&&h<334&&s>.28){if(t<.43)return 'hair';if(t>.46&&t<.78)return 'shirt';}
 if(h>10&&h<46&&s>.3&&t>.59)return 'shorts';
 return null;
}
function pixels(index){const d=Buffer.alloc(512*512*4),cx=index%8,cy=Math.floor(index/8);for(let y=0;y<512;y++)src.data.copy(d,y*2048,((cy*512+y)*src.width+cx*512)*4,((cy*512+y)*src.width+(cx+1)*512)*4);return d;}
function stats(d){const bins={};for(let y=0;y<512;y++)for(let x=0;x<512;x++){const i=(y*512+x)*4;if(d[i+3]<235)continue;const m=material(d[i],d[i+1],d[i+2],y);if(!m)continue;if(!bins[m])bins[m]=[new Uint32Array(256),new Uint32Array(256),new Uint32Array(256),0];for(let c=0;c<3;c++)bins[m][c][d[i+c]]++;bins[m][3]++;}const out={};for(const [m,a]of Object.entries(bins)){out[m]=a.slice(0,3).map(h=>{let sum=0;for(let i=0;i<256;i++){sum+=h[i];if(sum>=a[3]/2)return i;}return 0;});}return out;}
const reference=stats(pixels(0));
(async()=>{const comp=[],report=[];for(let n=0;n<48;n++){
 const d=pixels(n),before=stats(d),gains={};for(const m of Object.keys(reference))gains[m]=reference[m].map((v,c)=>clamp(v/(before[m]?.[c]||v),.72,1.36));
 let x0=512,y0=512,x1=0,y1=0;
 for(let y=0;y<512;y++)for(let x=0;x<512;x++){const i=(y*512+x)*4;if(d[i+3]===0){d[i]=d[i+1]=d[i+2]=0;continue;}x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);const m=material(d[i],d[i+1],d[i+2],y);if(m&&gains[m])for(let c=0;c<3;c++)d[i+c]=Math.round(clamp(d[i+c]*gains[m][c],0,255));}
 const bh=y1-y0+1,bw=x1-x0+1,scale=458/bh,rw=Math.round(bw*scale);
 let fx0=512,fx1=0;for(let y=y1-17;y<=y1;y++)for(let x=0;x<512;x++)if(d[(y*512+x)*4+3]>128){fx0=Math.min(fx0,x);fx1=Math.max(fx1,x);}
 const fx=(fx0+fx1)/2,left=Math.round(256-(fx-x0)*scale);
 const png=await sharp(d,{raw:{width:512,height:512,channels:4}}).extract({left:x0,top:y0,width:bw,height:bh}).resize(rw,458,{kernel:'lanczos3'}).png().toBuffer();
 const frame=await sharp({create:{width:512,height:512,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:png,left,top:31}]).png().toBuffer();
 comp.push({input:frame,left:n%8*512,top:Math.floor(n/8)*512});report.push({frame:n,row:Math.floor(n/8),sourceHeight:bh,normalizedHeight:458,uniformScale:scale,materialGains:gains});
 }
 await sharp({create:{width:4096,height:3072,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(comp).png({compressionLevel:9}).toFile(dest);
 const actions=['breathe','blink','look_left','look_right','smile','annoyed'];
 const duration=[[.26,.3,.34,.4,.34,.3,.26,.26],[.16,.045,.04,.065,.04,.045,.08,.2],[.25,.10,.12,.20,.4,.14,.12,.25],[.25,.10,.12,.20,.4,.14,.12,.25],[.25,.12,.14,.2,.35,.16,.14,.25],[.25,.12,.14,.20,.25,.20,.16,.3]];
 const meta={version:'0.7.9',image:path.basename(dest),columns:8,rows:6,cell:[512,512],anchor:[256,488],visibleHeight:458,referencePalette:reference,actions:actions.map((name,row)=>({name,row,durations:duration[row]})),preparation:'Material-specific color matching to approved frame 1; uniform scaling, fixed foot anchor; no anatomical stretching or body-part animation.',frames:report};
 fs.writeFileSync(dest.replace(/\.png$/,'.json'),JSON.stringify(meta,null,2));console.log(JSON.stringify({frames:48,referencePalette:reference,size:[4096,3072],visibleHeight:458}));
})().catch(e=>{console.error(e);process.exit(1)});
