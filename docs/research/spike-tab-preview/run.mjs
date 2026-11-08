import {spawn} from 'node:child_process';import fs from 'node:fs';import path from 'node:path';
const S=path.dirname(new URL(import.meta.url).pathname);
const WAIT=+(process.argv[2]||60), MODE=process.argv[3]||'headless', TAG=process.argv[4]||'run';
const PROF=fs.mkdtempSync('/tmp/tabspike-prof-');
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
async function suite(label,full){
 console.log('=== suite',label);
 await trial(label+'-cvt',`cvt(${w})`,B);
 await trial(label+'-dbg',`dbg(${B})`,B);
 await trial(label+'-h2c',`scr(${B},'h2c')`,B);
 if(full)await trial(label+'-h2i',`scr(${B},'h2i')`,B);
 await trial(label+'-mhtml',`mhtml(${B})`,B);
 if(full)await trial(label+'-tabcap',`tabcap(${B},700)`,B);
 console.log('state',JSON.stringify((await ev('state()')).filter(t=>t.id===B)));
}
await suite('t0',true);
// control: rasterizers on the visible tab A
const A=(await ev('state()')).find(t=>t.win===w&&t.active).id;
await trial('ctrl-visible-h2c',`scr(${A},'h2c')`);await trial('ctrl-visible-h2i',`scr(${A},'h2i')`);await trial('ctrl-visible-dbg',`dbg(${A})`);
// fidelity pages, each in a fresh background tab
for(const p of ['canvas','video','xorigin','csp']){
 const T=await ev(`(async()=>{const t=await chrome.tabs.create({windowId:${w},url:'http://127.0.0.1:8801/${p}.html',active:false});return t.id})()`);await sleep(2500);
 for(const [m,e] of [['dbg',`dbg(${T})`],['h2c',`scr(${T},'h2c')`],['h2i',`scr(${T},'h2i')`]])await trial(`fid-${p}-${m}`,e);
 await ev(`chrome.tabs.remove(${T})`);
}
// hidden window reload
const before=await (await fetch('http://127.0.0.1:8801/_log')).json();
for(const mode of ['normal','min']){const r=await ev(`popup('http://127.0.0.1:8801/color.html','${mode}')`);
 const o={name:'popup-'+mode,ms:r.ms,err:r.err};if(r.url){fs.writeFileSync(`${S}/out/${TAG}-popup-${mode}.png`,Buffer.from(r.url.split(',')[1],'base64'));o.img=await ev(`analyze(${JSON.stringify(r.url)})`)}console.log(JSON.stringify(o))}
const after=await (await fetch('http://127.0.0.1:8801/_log')).json();
console.log('color.html requests before/after popups',before['/color.html'],after['/color.html']);
// background aging
console.log('waiting',WAIT,'s');
const st=Date.now();
const marks=WAIT>=300?[60,WAIT]:[WAIT];
for(const m of marks){await sleep(Math.max(0,m*1000-(Date.now()-st)));await suite('t'+m,false)}
// discard
const dr=await ev(`disc(${B})`);console.log('discard result',JSON.stringify(dr));const B2=dr.id;await sleep(500);
console.log('state after discard',JSON.stringify((await ev('state()')).filter(t=>t.win===w)));
await trial('discarded-mhtml',`mhtml(${B2})`);
console.log('state after mhtml',JSON.stringify((await ev('tabs=chrome.tabs.query({windowId:'+w+'}).then(x=>x.map(t=>({id:t.id,disc:t.discarded,active:t.active,title:t.title})))')))); 
await trial('discarded-dbg',`dbg(${B2})`);
console.log('state after dbg',JSON.stringify(await ev('chrome.tabs.query({windowId:'+w+'}).then(x=>x.map(t=>({id:t.id,disc:t.discarded,status:t.status})))')));
fs.writeFileSync(`${S}/out/${TAG}-results.json`,JSON.stringify(results,null,1));
ws.close();ch.kill();setTimeout(()=>process.exit(0),500);
