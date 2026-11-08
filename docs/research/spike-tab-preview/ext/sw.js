const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function analyze(url){
 const b=await (await fetch(url)).blob();const bm=await createImageBitmap(b);
 const c=new OffscreenCanvas(bm.width,bm.height),x=c.getContext('2d');x.drawImage(bm,0,0);
 const d=x.getImageData(0,0,bm.width,bm.height).data;const cnt={};
 for(let i=0;i<d.length;i+=16){const k=[d[i],d[i+1],d[i+2]].map(v=>Math.round(v/64)*64>255?255:Math.round(v/64)*64).join(',');cnt[k]=(cnt[k]||0)+1}
 const top=Object.entries(cnt).sort((a,b)=>b[1]-a[1]).slice(0,3).map(e=>e[0]+' x'+e[1]);
 const px=(fx,fy)=>{const o=(Math.floor(fy*(bm.height-1))*bm.width+Math.floor(fx*(bm.width-1)))*4;return d[o]+','+d[o+1]+','+d[o+2]};
 let nonwhite=0;for(let i=0;i<d.length;i+=16)if(d[i]<250||d[i+1]<250||d[i+2]<250)nonwhite++;
 return {w:bm.width,h:bm.height,top,corner:px(0.02,0.98),left:px(0.1,0.1),right:px(0.9,0.1),nonwhitePct:Math.round(100*nonwhite/(d.length/16))};
}
self.analyze=analyze;
self.state=async()=>{const ts=await chrome.tabs.query({});const out=[];
 for(const t of ts){let st=null;try{const r=await chrome.scripting.executeScript({target:{tabId:t.id},func:()=>({vis:document.visibilityState,st:window.__st||null}),world:'MAIN'});st=r[0].result}catch(e){st=String(e).slice(0,80)}
  out.push({id:t.id,win:t.windowId,active:t.active,discarded:t.discarded,frozen:t.frozen,url:t.url,st})}return out};
self.cvt=async(w)=>{const t0=performance.now();const u=await chrome.tabs.captureVisibleTab(w,{format:'png'});return {url:u,ms:Math.round(performance.now()-t0)}};
const race=(p,ms,n)=>Promise.race([p,sleep(ms).then(()=>{throw new Error('timeout '+ms+'ms in '+n)})]);
self.dbg=async(tabId)=>{const t0=performance.now();await chrome.debugger.attach({tabId},'1.3');
 try{const r=await race(chrome.debugger.sendCommand({tabId},'Page.captureScreenshot',{format:'png'}),10000,'captureScreenshot');return {url:'data:image/png;base64,'+r.data,ms:Math.round(performance.now()-t0)}}finally{try{await chrome.debugger.detach({tabId})}catch(e){}}};
self.scr=async(tabId,lib)=>{const t0=performance.now();
 await chrome.scripting.executeScript({target:{tabId},files:[lib==='h2c'?'html2canvas.min.js':'html-to-image.js']});
 const r=await race(chrome.scripting.executeScript({target:{tabId},func:async(lib)=>{try{
   if(lib==='h2c'){const c=await html2canvas(document.documentElement,{useCORS:false,logging:false,width:innerWidth,height:innerHeight,windowWidth:innerWidth,windowHeight:innerHeight});return {url:c.toDataURL('image/png')}}
   return {url:await htmlToImage.toPng(document.documentElement,{width:innerWidth,height:innerHeight,cacheBust:false})}}catch(e){return {err:String(e&&e.message||e)}}},args:[lib]}),12000,'rasterizer');
 const v=r[0].result;return {...v,ms:Math.round(performance.now()-t0)}};
self.mhtml=async(tabId)=>{const t0=performance.now();const b=await chrome.pageCapture.saveAsMHTML({tabId});const t=await b.text();
 return {bytes:b.size,ms:Math.round(performance.now()-t0),bg:(t.match(/background[^;"]*?(rgb\([^)]*\)|#[0-9a-f]{6})/i)||[])[1],txt:(t.match(/idx \d tick \d+ raf \d+ \w+/)||[])[0]}};
self.tabcap=async(tabId,wait)=>{const t0=performance.now();
 const id=await chrome.tabCapture.getMediaStreamId({targetTabId:tabId});
 const has=await chrome.offscreen.hasDocument?.();if(!has)await chrome.offscreen.createDocument({url:'offscreen.html',reasons:['USER_MEDIA'],justification:'spike'});
 const r=await chrome.runtime.sendMessage({type:'grab',id,wait});return {...r,total:Math.round(performance.now()-t0)}};
self.popup=async(url,mode)=>{const t0=performance.now();
 const w=await chrome.windows.create({url,type:'popup',width:800,height:500,focused:false,...(mode==='min'?{state:'minimized'}:{})});
 await sleep(2000);let r;try{r=await chrome.tabs.captureVisibleTab(w.id,{format:'png'})}catch(e){r=null;var err=String(e)}
 await chrome.windows.remove(w.id);return {url:r,err,ms:Math.round(performance.now()-t0)}};
self.disc=async(id)=>{const t=await chrome.tabs.discard(id);return t?{discarded:t.discarded,id:t.id}:null};
// Headful checks: click the toolbar icon on a tab to grant activeTab for that tab, then switch away and call tabcap(thatTabId).
chrome.action.onClicked.addListener(t=>{self.invoked=t.id;console.log('activeTab granted for tab',t.id)});
// show(dataUrl) renders a picture on an extension page (data: URLs cannot be opened from the console).
self.show=async(url)=>{await chrome.storage.session.set({pic:url});await chrome.tabs.create({url:chrome.runtime.getURL('result.html')})};
