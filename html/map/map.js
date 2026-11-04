// Independent sh_pauseMenu map UI. No code or assets from the reference resource.
(() => {
  'use strict';
  const el=id=>document.getElementById(id), canvas=el('world'), context=canvas.getContext('2d');
  const state={open:false,mode:'3d',player:null,waypoint:false,route:[],markers:[],places:[],shared:[],camera:null,groups:[],selection:null,group:-1,hidden:new Set(),stops:[],tiles:[],grid:{x:-4140,y:8400,size:4500},flat:{x:0,y:0,span:2500},colors:[],touring:false};
  let requestId=0, queued=false, drag=null, toastTimer, hitPoints=[], inputFrame=0, inputMove=null, lastSidebar=0, placeFilter='all';
  const pending=new Map(), images=new Map(), stamps=new Map();
  const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const finite=n=>typeof n==='number'&&Number.isFinite(n);
  const distance=(a,b)=>a&&b?Math.hypot(a.x-b.x,a.y-b.y):0;
  const range=n=>n>=1000?`${(n/1000).toFixed(1)} km`:`${Math.round(n)} m`;
  const duration=seconds=>seconds>=3600?`${Math.floor(seconds/3600)} h ${Math.floor(seconds/60)%60} min`:`${Math.max(1,Math.round(seconds/60))} min`;
  function request(name,data={}){
    const id=++requestId;
    return new Promise(resolve=>{
      const timer=setTimeout(()=>{pending.delete(id);resolve(false);},6500);
      pending.set(id,result=>{clearTimeout(timer);resolve(result);});
      parent.postMessage({type:'shMapRequest',id,name,data},location.origin);
    });
  }
  function toast(text){clearTimeout(toastTimer);el('status').textContent=text;el('status').hidden=false;toastTimer=setTimeout(()=>el('status').hidden=true,3300);}
  function image(url){
    if(!images.has(url)){const img=new Image();img.onload=draw;img.onerror=draw;img.src=url;images.set(url,img);}
    return images.get(url);
  }
  function projection(point){
    if(state.mode==='2d'){
      const scale=innerWidth/state.flat.span;
      return [innerWidth/2+(point.x-state.flat.x)*scale,innerHeight/2-(point.y-state.flat.y)*scale];
    }
    const c=state.camera;if(!c)return null;
    const p=c.pitch*Math.PI/180,y=c.yaw*Math.PI/180,sp=Math.sin(p),cp=Math.cos(p),sy=Math.sin(y),cy=Math.cos(y);
    const x=point.x-c.x,z=(point.z||0)-c.z,dy=point.y-c.y;
    const depth=x*(-sy*cp)+dy*(cy*cp)+z*sp;
    if(depth<1)return null;
    const scale=innerHeight/(2*Math.tan(c.fov*Math.PI/360)*depth);
    return [innerWidth/2+(x*cy+dy*sy)*scale,innerHeight/2-(x*sy*sp-dy*cy*sp+z*cp)*scale];
  }
  function allPlaces(){
    return [...state.markers,...state.places.map(p=>({...p,id:'p'+p.id,pid:p.id,category:'My places',color:color(p.color),z:p.z||30})),...state.shared];
  }
  function color(id){return state.colors.find(c=>c.id===id)?.hex||'#b18aff';}
  function glyph(p){
    const name=iconName(p);
    return `<img class="place-icon" src="../assets/icon-${name}.svg" alt="">`;
  }
  function iconName(p){
    if(p.pid)return 'star';
    return ({40:'home',52:'shopping-bag',60:'shield',61:'plus-square',71:'scissors',72:'tool',73:'shopping-bag',75:'anchor',108:'dollar-sign',110:'crosshair',357:'home',361:'droplet',513:'truck'})[p.sprite]
      ||({Services:'info',Shops:'shopping-bag',Jobs:'briefcase',Transport:'truck',Shared:'map-pin',Properties:'home'})[p.category]||'map-pin';
  }
  function mapIcon(name,tint,size){
    const key=`${name}:${tint}:${size}`,ready=stamps.get(key);if(ready)return ready;
    const source=image(`../assets/icon-${name}.svg`);if(!source.complete||!source.naturalWidth)return null;
    const icon=document.createElement('canvas');icon.width=icon.height=size*2;
    const pen=icon.getContext('2d');pen.drawImage(source,0,0,icon.width,icon.height);
    pen.globalCompositeOperation='source-in';pen.fillStyle=tint;pen.fillRect(0,0,icon.width,icon.height);
    stamps.set(key,icon);return icon;
  }
  function groupKey(p){return p.pid||p.category==='Shared'?p.id:`${p.category}:${p.label}:${p.sprite||0}`;}
  function toggleGroup(group){
    if(state.hidden.has(group.key))state.hidden.delete(group.key);else state.hidden.add(group.key);
    sidebar();draw();
  }
  function paint(){
    queued=false;
    const dpr=Math.min(devicePixelRatio||1,2),width=Math.round(innerWidth*dpr),height=Math.round(innerHeight*dpr);
    if(canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height;}
    context.setTransform(dpr,0,0,dpr,0,0);context.clearRect(0,0,innerWidth,innerHeight);hitPoints=[];
    if(!state.open)return;
    if(state.mode==='2d'){
      context.fillStyle='#203038';context.fillRect(0,0,innerWidth,innerHeight);
      const scale=innerWidth/state.flat.span,size=state.grid.size*scale;
      for(const tile of state.tiles){
        const texture=image(tile.url),corner=projection({x:state.grid.x+tile.col*state.grid.size,y:state.grid.y-tile.row*state.grid.size});
        if(texture.complete&&texture.naturalWidth)context.drawImage(texture,corner[0],corner[1],size,size);
      }
      if(!state.tiles.length){context.fillStyle='#c2bdca';context.font='14px Manrope, sans-serif';context.fillText('Loading game map textures…',35,innerHeight-90);}
    }
    const route=state.route;
    if(route.length>1){
      context.lineCap='round';context.lineJoin='round';context.beginPath();let pen=false;
      for(const p of route){const q=projection({...p,z:(p.z||0)+2});if(!q){pen=false;continue;}if(pen)context.lineTo(...q);else context.moveTo(...q);pen=true;}
      context.strokeStyle='#06242c';context.lineWidth=8;context.stroke();
      context.strokeStyle='#55dce3';context.lineWidth=4;context.stroke();
    }
    for(const p of allPlaces()){
      if(state.hidden.has(groupKey(p)))continue;
      const q=projection(p);if(!q||q[0]<-40||q[1]<-40||q[0]>innerWidth+40||q[1]>innerHeight+40)continue;
      const selected=state.selection?.id===p.id;
      context.beginPath();context.fillStyle=selected?'#00acb84d':'#071c26e6';context.arc(q[0],q[1],selected?23:16,0,Math.PI*2);context.fill();
      context.strokeStyle=selected?'#6ce7ed':'#d7f3f126';context.lineWidth=selected?2:1;context.stroke();
      const icon=mapIcon(iconName(p),p.color||'#e9f5f7',selected?24:20);
      if(icon)context.drawImage(icon,q[0]-(selected?12:10),q[1]-(selected?12:10),selected?24:20,selected?24:20);
      if(selected){context.font='700 12px Manrope,sans-serif';context.textAlign='left';context.textBaseline='middle';context.lineWidth=4;context.strokeStyle='#08202a';context.strokeText(p.label,q[0]+30,q[1]);context.fillStyle='#f2ffff';context.fillText(p.label,q[0]+30,q[1]);}
      hitPoints.push({p,x:q[0],y:q[1]});
    }
    if(state.waypoint){
      const q=projection(state.waypoint);if(q){
        context.save();context.beginPath();context.ellipse(q[0],q[1],10,4,0,0,Math.PI*2);context.fillStyle='#051f2bb3';context.fill();
        const pin=mapIcon('map-pin','#62edf0',42);
        if(pin){context.shadowColor='#031c26';context.shadowBlur=5;context.shadowOffsetY=2;context.drawImage(pin,q[0]-21,q[1]-38,42,42);}
        context.restore();
      }
    }
    if(state.player){
      const q=projection(state.player);if(q){
        context.save();context.translate(...q);context.rotate(((state.mode==='3d'?state.camera?.yaw||0:0)-state.player.heading)*Math.PI/180);
        context.fillStyle='#fff';context.strokeStyle='#17131c';context.lineWidth=2;context.beginPath();context.moveTo(0,-15);context.lineTo(10,11);context.lineTo(0,6);context.lineTo(-10,11);context.closePath();context.fill();context.stroke();context.restore();
      }
    }
  }
  function draw(){if(!queued){queued=true;requestAnimationFrame(paint);}}
  function routeLength(){return state.route.reduce((n,p,i)=>i?n+distance(p,state.route[i-1]):n,0);}
  function buildGroups(){
    const previous=new Map(state.groups.map(g=>[g.key,g]));const grouped=new Map();
    for(const place of allPlaces()){
      const key=groupKey(place);
      if(!grouped.has(key))grouped.set(key,{key,label:place.label,category:place.category,items:[],index:previous.get(key)?.index||0});
      grouped.get(key).items.push(place);
    }
    state.groups=[...grouped.values()].sort((a,b)=>a.category.localeCompare(b.category)||distance(a.items[0],state.player)-distance(b.items[0],state.player));
    for(const g of state.groups){g.items.sort((a,b)=>distance(a,state.player)-distance(b,state.player));g.index%=g.items.length;}
  }
  function sidebar(){
    if(!state.open)return;buildGroups();
    const p=state.player||{},wp=state.waypoint,query=el('search').value.trim().toLowerCase(),length=routeLength()||distance(p,wp);
    el('place-count').textContent=allPlaces().length;
    let html=`<button class="place you" id="me"><span class="symbol"><img src="../assets/icon-navigation.svg" alt=""></span><span><span class="title">Your location</span><span class="meta">${escape([p.zone,p.street].filter(Boolean).join(' · '))}</span></span></button>`;
    if(wp)html+=`<div class="waypoint"><h2>Your next stop</h2><p>${range(length)} · ~${duration(length/13)} drive · ${duration(length/1.5)} walk${state.route.length<2?'<br>Waiting for the game GPS route…':''}</p><div class="actions"><button id="tour" ${state.route.length<2?'disabled':''}>${state.touring?'End preview':'Preview trip'}</button><button id="share">Share GPS</button><button class="danger" id="remove">Remove</button></div></div>`;
    if(state.stops.length)html+=`<div class="waypoint"><h2>Route · ${state.stops.length} stops</h2>${state.stops.map((s,i)=>`<button data-stop="${i}">${i+1}. ${escape(s.label)} ✕</button>`).join('')}</div>`;
    let category='',count=0;
    state.groups.forEach((group,index)=>{
      const place=group.items[group.index];if(query&&!`${group.label} ${group.category}`.toLowerCase().includes(query))return;
      if(placeFilter==='saved'&&!place.pid)return;
      if(placeFilter==='nearby'&&distance(p,place)>2000)return;
      count++;if(category!==group.category){category=group.category;html+=`<div class="section-label">${escape(category)}</div>`;}
      const hidden=state.hidden.has(group.key),selected=state.selection?.id===place.id;
      html+=`<div class="group ${hidden?'hidden':''} ${selected?'selected':''}"><button class="place ${selected?'selected':''}" data-group="${index}"><span class="symbol">${glyph(place)}</span><span><span class="title">${escape(group.label)}</span><span class="meta">${range(distance(p,place))}</span></span></button><div class="cycle">${group.items.length>1?`<button data-cycle="${index}" data-dir="-1" aria-label="Previous ${escape(group.label)}">‹</button><span>${group.index+1}/${group.items.length}</span><button data-cycle="${index}" data-dir="1" aria-label="Next ${escape(group.label)}">›</button>`:''}</div><input class="visibility" type="checkbox" data-visible="${index}" ${hidden?'':'checked'} aria-label="Show ${escape(group.label)}"></div>`;
    });
    if(!count)html+=`<p class="empty">${placeFilter==='saved'?'Your saved places will appear here.':query?'No places match your search.':'No places nearby. Explore the city to find your next stop.'}</p>`;
    el('locations').innerHTML=html;el('clear').hidden=!wp;
    el('me').onclick=recenter;el('add-place').onclick=savePlace;
    if(wp){el('remove').onclick=clear;el('share').onclick=share;el('tour').onclick=()=>request('tour',{on:!state.touring});}
    el('locations').querySelectorAll('[data-group]').forEach(b=>b.onclick=()=>selectGroup(+b.dataset.group));
    el('locations').querySelectorAll('[data-cycle]').forEach(b=>b.onclick=()=>selectGroup(+b.dataset.cycle,+b.dataset.dir));
    el('locations').querySelectorAll('[data-visible]').forEach(b=>b.onchange=()=>toggleGroup(state.groups[+b.dataset.visible]));
    el('locations').querySelectorAll('[data-group]').forEach(b=>b.ondblclick=()=>setWaypoint(state.groups[+b.dataset.group].items[state.groups[+b.dataset.group].index]));
    el('locations').querySelectorAll('[data-stop]').forEach(b=>b.onclick=()=>{state.stops.splice(+b.dataset.stop,1);if(state.stops[0])setWaypoint(state.stops[0]);sidebar();});
  }
  function selectGroup(index,change=0){
    const g=state.groups[index];if(!g)return;g.index=(g.index+change+g.items.length)%g.items.length;state.group=index;select(g.items[g.index]);
  }
  function select(place,fly=true){
    state.selection=place;
    if(fly){if(state.mode==='3d')request('fly',place);else{state.flat.x=place.x;state.flat.y=place.y;}}
    const length=distance(place,state.player);
    el('card').hidden=false;el('card').innerHTML=`<div class="card-head"><small>${escape(place.category)}</small><button id="card-close" aria-label="Close place">✕</button></div><h2>${escape(place.label)}</h2><div class="facts"><div><small>Distance</small><b>${range(length)}</b></div><div><small>Car</small><b>~${duration(length/13)}</b></div><div><small>On foot</small><b>~${duration(length/1.5)}</b></div></div><div class="actions"><button id="gps" class="primary">Start GPS</button><button id="stop">+ Stop</button>${place.pid?'<button id="delete-place" class="danger">Delete</button>':''}</div>`;
    el('card-close').onclick=()=>{el('card').hidden=true;state.selection=null;draw();sidebar();};
    el('gps').onclick=()=>matchesWaypoint(place)?clear():setWaypoint(place);syncGpsButton();
    el('stop').onclick=()=>{
      if(state.stops.length>=5){toast('5 stops maximum');return;}
      if(!state.stops.some(s=>distance(s,place)<3))state.stops.push({...place});
      setWaypoint(state.stops[0]);sidebar();toast('Stop added');
    };
    if(place.pid)el('delete-place').onclick=async()=>{const r=await request('placesDelete',{id:place.pid});if(r?.ok){state.places=r.places;el('card').hidden=true;state.selection=null;sidebar();draw();}else toast('Could not delete this place.');};
    sidebar();draw();
  }
  function matchesWaypoint(point){return !!state.waypoint&&distance(point,state.waypoint)<20;}
  function syncGpsButton(){const button=el('gps');if(button&&state.selection){const active=matchesWaypoint(state.selection);button.textContent=active?'Remove waypoint':'Start GPS';button.classList.toggle('is-active',active);}}
  async function setWaypoint(point){
    const ok=await request('waypoint',{x:point.x,y:point.y});if(!ok){toast('Could not set the waypoint.');return;}
    state.waypoint={x:point.x,y:point.y,z:point.z||30};state.route=[];sidebar();syncGpsButton();draw();toast('Waypoint set');
  }
  async function clear(){await request('clear');state.waypoint=false;state.route=[];state.stops=[];state.touring=false;el('card').hidden=true;sidebar();draw();}
  function recenter(){
    state.selection=null;el('card').hidden=true;
    if(state.mode==='3d')request('recenter');else if(state.player){state.flat.x=state.player.x;state.flat.y=state.player.y;draw();}
  }
  function zoom(factor){if(state.mode==='3d')request('zoom',{factor});else{state.flat.span=Math.min(25000,Math.max(150,state.flat.span/factor));draw();}}
  async function setMode(){
    const mode=state.mode==='3d'?'2d':'3d';if(!await request('mode',{mode}))return;
    state.mode=mode;document.body.classList.toggle('flat',mode==='2d');el('mode').textContent=mode==='3d'?'2D view':'3D view';el('card').hidden=true;
    if(mode==='2d'&&state.player){state.flat.x=state.player.x;state.flat.y=state.player.y;}
    draw();
  }
  function modal(title,html,onSave){
    el('dialog-title').textContent=title;el('dialog-body').innerHTML=html;el('save').hidden=!onSave;
    el('place-form').onsubmit=e=>{e.preventDefault();onSave?.();};el('dialog').showModal();
  }
  function savePlace(){
    let selectedColor=state.colors[0]?.id||'purple',point=state.waypoint||state.player;
    modal('Save a place',`<p>Only visible to your character, on the 2D and 3D maps.</p><input id="place-name" maxlength="40" placeholder="Name (e.g. Home, Garage…)" aria-label="Place name"><div class="colors">${state.colors.map((c,i)=>`<button type="button" class="${i?'':'active'}" data-color="${escape(c.id)}" style="--swatch:${/^#[0-9a-f]{6}$/i.test(c.hex)?c.hex:'#9a6bff'}" title="${escape(c.label)}"></button>`).join('')}</div><p>Location</p><div class="spot-options"><button type="button" data-spot="me" class="${state.waypoint?'':'active'}">My position</button>${state.waypoint?'<button type="button" data-spot="gps" class="active">The waypoint</button>':''}${state.mode==='2d'?'<button type="button" data-spot="center">Map center</button>':''}</div>`,async()=>{
      const label=el('place-name').value.trim();if(!label){toast('Give this place a name');return;}
      const result=await request('placesAdd',{label,color:selectedColor,x:point.x,y:point.y});
      if(!result?.ok){toast(result?.err==='full'?'30 saved places maximum':'Could not save this place.');return;}
      state.places=result.places;el('dialog').close();sidebar();draw();toast('Place saved');
    });
    el('place-name').focus();
    el('dialog-body').querySelectorAll('[data-color]').forEach(b=>b.onclick=()=>{selectedColor=b.dataset.color;el('dialog-body').querySelectorAll('[data-color]').forEach(x=>x.classList.toggle('active',x===b));});
    el('dialog-body').querySelectorAll('[data-spot]').forEach(b=>b.onclick=()=>{point=b.dataset.spot==='me'?state.player:b.dataset.spot==='gps'?state.waypoint:state.flat;el('dialog-body').querySelectorAll('[data-spot]').forEach(x=>x.classList.toggle('active',x===b));});
  }
  function share(){
    if(!state.waypoint)return;
    modal('Share GPS','<p>Your waypoint will appear on their map for 10 minutes.</p><div class="share-actions"><button type="button" data-share="near">Nearby players (30 m)</button><button type="button" data-share="job">My coworkers on duty</button></div>',null);
    el('dialog-body').querySelectorAll('[data-share]').forEach(b=>b.onclick=async()=>{await request('shareGps',{...state.waypoint,to:b.dataset.share,label:state.selection?.label||'Waypoint'});el('dialog').close();toast('GPS shared');});
  }
  function update(frame){
    const waypointChanged='waypoint' in frame&&((state.waypoint?.x!==frame.waypoint?.x)||(state.waypoint?.y!==frame.waypoint?.y));
    for(const key of ['player','waypoint','route','markers','places','shared','camera','touring'])if(key in frame)state[key]=frame[key];
    if(state.player){el('zone').textContent=state.player.zone||'Los Santos';
      if(state.stops.length&&distance(state.player,state.stops[0])<35){state.stops.shift();if(state.stops.length)setWaypoint(state.stops[0]);else clear();}
    }
    if(frame.markers||frame.places||frame.shared||frame.route||waypointChanged||performance.now()-lastSidebar>1000){lastSidebar=performance.now();sidebar();syncGpsButton();}draw();
  }
  async function mapClick(x,y,street=false){
    const hit=hitPoints.find(h=>Math.hypot(h.x-x,h.y-y)<20);if(hit&&!street){select(hit.p);return;}
    let point;
    if(state.mode==='3d')point=await request('pick',{u:x/innerWidth,v:y/innerHeight});
    else{const scale=state.flat.span/innerWidth;point={x:state.flat.x+(x-innerWidth/2)*scale,y:state.flat.y-(y-innerHeight/2)*scale};}
    if(!point||!finite(point.x)||!finite(point.y))return;
    if(!street)setWaypoint(point);
  }
  function flushMove(){
    inputFrame=0;const move=inputMove;inputMove=null;if(move&&state.open)request(move.rotate?'rotate':'pan',{dx:move.dx,dy:move.dy,height:innerHeight});
  }
  canvas.addEventListener('pointerdown',e=>{
    if(![0,2].includes(e.button))return;canvas.setPointerCapture(e.pointerId);
    drag={id:e.pointerId,x:e.clientX,y:e.clientY,lastX:e.clientX,lastY:e.clientY,rotate:e.button===2,moved:false,center:{...state.flat}};
  });
  canvas.addEventListener('pointermove',e=>{
    if(!drag||drag.id!==e.pointerId)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;
    if(Math.hypot(dx,dy)<5&&!drag.moved)return;drag.moved=true;canvas.classList.add('dragging');
    if(state.mode==='2d'){state.flat.x=drag.center.x-dx*state.flat.span/innerWidth;state.flat.y=drag.center.y+dy*state.flat.span/innerWidth;draw();}
    else{if(!inputMove)inputMove={dx:0,dy:0,rotate:drag.rotate};inputMove.dx+=e.clientX-drag.lastX;inputMove.dy+=e.clientY-drag.lastY;if(!inputFrame)inputFrame=requestAnimationFrame(flushMove);}
    drag.lastX=e.clientX;drag.lastY=e.clientY;
  });
  canvas.addEventListener('pointerup',e=>{if(drag&&!drag.moved)mapClick(e.clientX,e.clientY,drag.rotate&&state.mode==='3d');drag=null;canvas.classList.remove('dragging');});
  canvas.addEventListener('pointercancel',()=>{drag=null;canvas.classList.remove('dragging');});canvas.addEventListener('contextmenu',e=>e.preventDefault());
  canvas.addEventListener('wheel',e=>{e.preventDefault();zoom(e.deltaY<0?1.2:1/1.2);},{passive:false});
  el('mode').onclick=setMode;el('recenter').onclick=recenter;el('clear').onclick=clear;el('zin').onclick=()=>zoom(1.4);el('zout').onclick=()=>zoom(1/1.4);
  el('native').onclick=()=>request('native');el('back').onclick=()=>request('close');el('cancel').onclick=()=>el('dialog').close();el('search').addEventListener('input',sidebar);
  document.querySelectorAll('[data-filter]').forEach(button=>button.onclick=()=>{
    placeFilter=button.dataset.filter;
    document.querySelectorAll('[data-filter]').forEach(item=>{const active=item===button;item.classList.toggle('active',active);item.setAttribute('aria-pressed',String(active));});
    sidebar();
  });
  window.addEventListener('resize',draw);
  window.addEventListener('keydown',e=>{
    if(!state.open)return;if(el('dialog').open)return;
    if(e.key==='Escape'){e.preventDefault();request('close');return;}
    if(e.key==='/'){e.preventDefault();el('search').focus();return;}
    if(/INPUT|TEXTAREA/.test(document.activeElement.tagName))return;
    if(e.key==='Delete'||e.key==='Backspace'){e.preventDefault();clear();return;}
    if(e.key==='ArrowUp'||e.key==='ArrowDown'){e.preventDefault();selectGroup(Math.max(0,Math.min(state.groups.length-1,state.group+(e.key==='ArrowDown'?1:-1))));}
    else if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();selectGroup(state.group,e.key==='ArrowRight'?1:-1);}
    else if(e.key==='Enter'&&state.selection){e.preventDefault();setWaypoint(state.selection);}
    else if(e.key.toLowerCase()==='t'&&state.selection){const group=state.groups.find(g=>g.key===groupKey(state.selection));if(group)toggleGroup(group);}
  });
  function close(){state.open=false;state.selection=null;state.stops=[];drag=null;document.body.hidden=true;el('card').hidden=true;if(el('dialog').open)el('dialog').close();draw();}
  window.addEventListener('message',async e=>{
    if(e.source!==parent||e.origin!==location.origin)return;const m=e.data;if(!m||typeof m!=='object')return;
    if(m.type==='shMapHello'){parent.postMessage({type:'shMapReady'},location.origin);return;}
    if(m.type==='shMapResponse'){const done=pending.get(m.id);if(done){pending.delete(m.id);done(m.result);}return;}
    if(m.type==='open'){
      placeFilter='all';document.querySelectorAll('[data-filter]').forEach(button=>{const active=button.dataset.filter==='all';button.classList.toggle('active',active);button.setAttribute('aria-pressed',String(active));});
      state.open=true;state.mode='3d';state.colors=m.colors||[];state.tiles=m.tiles||[];state.grid=m.tileGrid||state.grid;state.group=-1;state.hidden.clear();state.stops=[];el('search').value='';el('city').textContent=m.serverName||'ROLEPLAY';
      document.body.hidden=false;document.body.classList.remove('flat');el('mode').textContent='2D view';update(m.frame);
      const places=await request('placesList');if(places?.ok){state.places=places.places;sidebar();draw();}
    }else if(m.type==='close'||m.action==='close')close();
    else if(m.type==='frame'&&state.open)update(m);
    else if(m.type==='tiles'){state.tiles=m.tiles||[];draw();}
  });
  parent.postMessage({type:'shMapReady'},location.origin);
})();

