chrome.runtime.onMessage.addListener((m,s,send)=>{
 if(m.type!=='grab')return;
 (async()=>{
  const t0=performance.now();
  const st=await navigator.mediaDevices.getUserMedia({video:{mandatory:{chromeMediaSource:'tab',chromeMediaSourceId:m.id}}});
  const v=document.createElement('video');v.srcObject=st;v.muted=true;await v.play();
  const got=await Promise.race([new Promise(r=>v.requestVideoFrameCallback(()=>r(true))),new Promise(r=>setTimeout(()=>r(false),3000))]);await new Promise(r=>setTimeout(r,m.wait||500));
  const c=document.createElement('canvas');c.width=v.videoWidth;c.height=v.videoHeight;c.getContext('2d').drawImage(v,0,0);
  const url=c.toDataURL('image/png');st.getTracks().forEach(t=>t.stop());
  send({ok:true,gotFrame:got,url,ms:Math.round(performance.now()-t0),w:c.width,h:c.height});
 })().catch(e=>send({ok:false,err:String(e)}));
 return true;
});
