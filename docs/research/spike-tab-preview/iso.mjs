import {spawn} from 'node:child_process';import fs from 'node:fs';import path from 'node:path';
const S=path.dirname(new URL(import.meta.url).pathname);
const WAIT=+(process.argv[2]||60), MODE=process.argv[3]||'headless', TAG=process.argv[4]||'run';
const PROF=fs.mkdtempSync('/tmp/claude-1000/tabspike-prof-');
const args=[`--user-data-dir=${PROF}`,`--load-extension=${S}/ext`,'--no-first-run','--no-default-browser-check','--remote-debugging-port=9333','--remote-allow-origins=*','--window-size=900,600','--disable-gpu','--disable-software-rasterizer','--use-gl=disabled','--disable-crash-reporter','--whitelisted-extension-id=lapbjcmcmlacgliicmilocegkkbmknph','--disable-breakpad',
 '--silent-debugger-extension-api=false'].filter(a=>!a.includes('silent'));
if(MODE==='headless')args.push('--headless=new');
args.push('about:blank');
const ch=spawn('chromium',args,{stdio:'ignore'});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function getJSON(u){for(let i=0;i<50;i++){try{return await (await fetch(u)).json()}catch{await sleep(200)}}throw 'no cdp'}
console.log('spawned');let swurl;for(let i=0;i<60&&!swurl;i++){const l=await getJSON('http://127.0.0.1:9333/json/list');swurl=l.find(t=>t.type==='service_worker'&&t.url.includes('sw.js'))?.webSocketDebuggerUrl;if(!swurl)await sleep(300)}
const ws=new WebSocket(swurl);await new Promise(r=>ws.onopen=r);
let id=0;const pend={};ws.onmessage=m=>{const d=JSON.parse(m.data);if(d.id&&pend[d.id]){pend[d.id](d);delete pend[d.id]}};
const send=(method,params={},sessionId)=>new Promise(r=>{const i=++id;pend[i]=r;ws.send(JSON.stringify({id:i,method,params}))});
const sess=1;
const ev=async(expr)=>{const r=await Promise.race([send('Runtime.evaluate',{expression:expr,awaitPromise:true,returnByValue:true},sess),sleep(25000).then(()=>({result:{exceptionDetails:{exception:{description:'TIMEOUT 25s (call never returned)'}}}}))]);if(r.result.exceptionDetails)return {EXC:r.result.exceptionDetails.exception?.description||JSON.stringify(r.result.exceptionDetails).slice(0,300)};return r.result.result.value};
const PAL=['255,0,0','0,255,0','0,0,255','255,255,0','255,0,255','0,255,255'];
const results={};
async function trial(name,expr,tabForState){
 const b=tabForState? (await ev(`state()`)).find(t=>t.id===tabForState)?.st?.st:null;
 const r=await ev(expr);const a=tabForState? (await ev(`state()`)).find(t=>t.id===tabForState)?.st?.st:null;
 let out={name};
 if(r&&r.EXC){out.error=r.EXC.slice(0,200)}
 else if(r&&r.err&&!r.url){out.error=String(r.err).slice(0,200)}
 else if(r&&r.url){fs.writeFileSync(`${S}/out/${TAG}-${name}.png`,Buffer.from(r.url.split(',')[1],'base64'));out.ms=r.ms;out.img=await ev(`analyze(${JSON.stringify(r.url)})`);}
 else out.raw=r;
 if(b&&a){out.expectBefore=PAL[b.idx];out.expectAfter=PAL[a.idx];out.vis=b.vis;
  const c=out.img?.corner;out.match=c===PAL[b.idx]?'current(before)':c===PAL[a.idx]?'current(after)':'STALE_OR_OTHER'}
 if(r&&r.w&&!out.img)Object.assign(out,{w:r.w,h:r.h});
 console.log(JSON.stringify(out));results[name]=out;return out}
async function setup(){
 const w=await ev(`(async()=>{const w=await chrome.windows.create({url:'http://127.0.0.1:8801/plain.html',width:900,height:600});return w.id})()`);
 const B=await ev(`(async()=>{const t=await chrome.tabs.create({windowId:${w},url:'http://127.0.0.1:8801/color.html',active:false});return t.id})()`);
 await sleep(1500);return {w,B}}
const {w,B}=await setup();
console.log('mode',MODE,'win',w,'B',B);console.log('state',JSON.stringify(await ev('state()')));

async function fresh(p){const T=await ev(`(async()=>{const t=await chrome.tabs.create({windowId:${w},url:'http://127.0.0.1:8801/${p}.html',active:false});return t.id})()`);await sleep(2500);return T}
for(const p of ['csp','xorigin','csp','canvas','color']){const T=await fresh(p);await trial('iso-'+p+'-dbg',`dbg(${T})`);await ev(`chrome.tabs.remove(${T})`)}
// does it hang because hidden? same page made visible
const T2=await fresh('csp');await ev(`chrome.tabs.update(${T2},{active:true})`);await sleep(800);await trial('iso-csp-VISIBLE-dbg',`dbg(${T2})`);
ws.close();ch.kill();setTimeout(()=>process.exit(0),500);
