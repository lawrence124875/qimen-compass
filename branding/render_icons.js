const {chromium}=require('playwright');const fs=require('fs'),path=require('path');const R=process.argv[2];
(async()=>{const b=await chromium.launch();const p=await b.newPage();
const shot=async(svg,size,out,radius='0')=>{const s=fs.readFileSync(R+'/branding/'+svg).toString('base64');
 await p.setViewportSize({width:Math.max(size,100),height:Math.max(size,100)});
 await p.setContent(`<html><body style="margin:0;background:transparent"><img id="i" src="data:image/svg+xml;base64,${s}" style="display:block;width:${size}px;height:${size}px;border-radius:${radius}"></body></html>`);
 await p.waitForFunction(()=>document.getElementById('i').complete);
 fs.mkdirSync(path.dirname(out),{recursive:true});await p.screenshot({path:out,omitBackground:true,clip:{x:0,y:0,width:size,height:size}});};
const D={mdpi:1,hdpi:1.5,xhdpi:2,xxhdpi:3,xxxhdpi:4};const res=R+'/branding/android/res';
for(const [k,m] of Object.entries(D)){
 for(const n of ['foreground','background','monochrome']) await shot('icon_'+n+'.svg',108*m,`${res}/mipmap-${k}/ic_launcher_${n}.png`);
 await shot('icon_legacy.svg',48*m,`${res}/mipmap-${k}/ic_launcher.png`,'22%');
 await shot('icon_legacy.svg',48*m,`${res}/mipmap-${k}/ic_launcher_round.png`,'50%');}
await shot('icon_legacy.svg',512,R+'/branding/play_icon_512.png');
await b.close()})();
