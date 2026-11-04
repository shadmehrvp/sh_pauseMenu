(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const inGame = typeof window.GetParentResourceName === 'function';
  const root = $('pause');
  const catalog = {
    en: {
      paused:'PAUSED', overview:'Overview', map:'Map', settings:'Settings', keybinds:'Keybinds', serverInfo:'Server Info', disconnect:'Disconnect', openMap:'Open map', job:'Job', cash:'Cash', bank:'Bank', online:'online', rules:'Server rules', discord:'Join Discord', resume:'Resume game',
      welcome:(name)=>`Welcome back, ${name}.`, overviewSub:'Everything you need. One place.', settingsSub:'Make yourself comfortable.', keybindsSub:'Know your controls. Own your city.', serverSub:'A little more about your city.', sessionId:'Session ID', citizenId:'Citizen ID', mapPreview:'LOS SANTOS · CITY MAP', sessionNote:'The city keeps moving while you’re here.',
      gameSettings:'Game settings', graphicsAudio:'Graphics, audio & controls', nativeSettingsHint:'Adjust the game’s settings in the original menu.', openSettings:'Open settings', menuPreferences:'Menu preferences', opacity:'Background darkness', opacityHint:'Keep your menu comfortable to read.', blur:'Background blur', blurHint:'Soften the city behind your menu.', sound:'Menu sounds', soundHint:'Play a subtle sound when opening and closing.', motion:'Reduce motion', motionHint:'Skip menu transitions and animations.', saved:'Saved', saving:'Saving…',
      editKeybinds:'Edit game keybinds', searchKeys:'Search controls…', keysHint:'A quick reference for your server. View or change actual bindings in the game’s keybind editor.', noResults:'No controls match your search.', yourCity:'YOUR CITY, YOUR STORY', playersOnline:'Players online', connection:'Your connection', currentLocation:'Current location', website:'Website',
      close:'Close', cancel:'Cancel', confirmDisconnect:'Leave the city?', disconnectBody:'This will disconnect you from the server. You can reconnect from FiveM whenever you’re ready.', leave:'Disconnect', unavailable:'Not available', linkMissing:'The server owner has not added this link yet.', rulesMissing:'The server owner has not added any rules yet.', refresh:'Refresh player data', refreshing:'Refreshing…', refreshed:'Player information updated.', loadFailed:'Player data is taking longer than expected. Use refresh to try again.', offlineProfile:'Your framework does not provide these character details.', loading:'Loading character information…', callbackFailed:'The game did not respond. Please try again.', nativeFailed:'The game menu could not be opened. Check the native menu configuration for your game build.', nativePreview:'Available inside FiveM', nativePreviewBody:'In the installed resource, this button opens the game’s original menu. The browser preview cannot run GTA V.', copied:'Link copied.', copy:'Copy link', openLink:'Open link', externalTitle:'Community link', copyFailed:'Copy the link from the field below.', previewDisconnect:'Preview only: your session has not been disconnected.', preferencesFailed:'Could not save preferences. Please try again.'
    }
  };
  const language='en';
  let page='overview', data=null, visible=false, pending=false, dialogFocus=null;
  let toastTimer, loadTimer, saveTimer, saveVersion=0, requestPending=false;
  let preferences={opacity:64,blur:true,sound:true,reducedMotion:false};
  const text = (key) => catalog[language][key] || catalog.en[key] || key;
  const set = (id, value) => { $(id).textContent = value == null || value === false ? '—' : String(value); };
  const icon = (name) => { const image=document.createElement('img'); image.src=`assets/icon-${name}.svg`; image.alt=''; return image; };

  function resize() {
    const scale=Math.min(window.innerWidth/1920,window.innerHeight/1024);
    document.documentElement.style.setProperty('--scale',String(scale));
  }
  window.addEventListener('resize',resize); resize();

  async function nui(endpoint, payload={}) {
    if (!inGame) return {ok:true};
    const controller=new AbortController();
    const timer=setTimeout(()=>controller.abort(),6000);
    try {
      const response=await fetch(`https://${window.GetParentResourceName()}/${endpoint}`,{method:'POST',headers:{'Content-Type':'application/json; charset=UTF-8'},body:JSON.stringify(payload),signal:controller.signal});
      if (!response.ok) throw new Error('NUI request failed');
      return await response.json();
    } finally {clearTimeout(timer);}
  }
  let mapMode=false, frameLoaded=false;
  const mapView=$('map-view');
  const sendMap=message=>mapView.contentWindow.postMessage(message,location.origin);
  const mapCallbacks=new Set(['mode','waypoint','clear','pick','pan','rotate','zoom','recenter','fly','street','tour','placesList','placesAdd','placesDelete','shareGps']);
  async function enterMap() {
    if(mapMode||pending)return;
    if(!inGame){modal('City map','The live city map is available inside FiveM.');return;}
    pending=true;
    try {
      if(!frameLoaded) await new Promise((resolve,reject)=>{
        const started=Date.now();
        sendMap({type:'shMapHello'});
        const poll=setInterval(()=>{if(frameLoaded){clearInterval(poll);resolve();}else if(Date.now()-started>6000){clearInterval(poll);reject(new Error('Map frame did not load'));}else sendMap({type:'shMapHello'});},100);
      });
      const result=await nui('mapOpen');if(!result.ok)throw new Error();
      mapMode=true;root.classList.add('map-mode');mapView.hidden=false;
      sendMap(result.message);mapView.focus();
    }catch(error){console.error('[sh_pauseMenu] Map open:',error.message);notify('The city map could not be opened. Please try again.');}
    finally{pending=false;}
  }
  function resetMapView() {
    sendMap({type:'close'});mapMode=false;
    root.classList.remove('map-mode');mapView.hidden=true;
  }
  async function leaveMap() {
    if(!mapMode||pending)return;
    pending=true;
    try{await nui('mapClose');resetMapView();document.querySelector('[data-page="overview"]').focus({preventScroll:true});}
    catch{notify(text('callbackFailed'));}finally{pending=false;}
  }
  window.addEventListener('message',async event=>{
    if(event.source!==mapView.contentWindow||event.origin!==location.origin)return;
    const m=event.data;if(!m||typeof m!=='object')return;
    if(m.type==='shMapReady'){frameLoaded=true;return;}
    if(m.type!=='shMapRequest'||!mapMode)return;
    let result=false;
    try{
      if(m.name==='close'){await leaveMap();result=true;}
      else if(m.name==='native'){await native('map');result=true;}
      else if(mapCallbacks.has(m.name))result=await nui('mapAction',{name:m.name,data:m.data});
    }catch{notify(text('callbackFailed'));}
    mapView.contentWindow.postMessage({type:'shMapResponse',id:m.id,result},location.origin);
  });

  function notify(message) {
    clearTimeout(toastTimer); set('toast',message); $('toast').hidden=false;
    toastTimer=setTimeout(()=>$('toast').hidden=true,4200);
  }
  function translate() {
    document.documentElement.lang=language;
    document.querySelectorAll('[data-i18n]').forEach(el=>el.textContent=text(el.dataset.i18n));
    $('key-search').placeholder=text('searchKeys'); $('key-search').setAttribute('aria-label',text('searchKeys'));
    $('dialog-close').setAttribute('aria-label',text('close'));
    document.querySelector('[data-action="refresh"]').setAttribute('aria-label',text('refresh'));
    updateHeading(); renderKeys();
  }
  function updateHeading() {
    const name=data?.player?.name || 'friend';
    set('page-title',page==='overview'?text('welcome')(name.split(' ')[0]):text(page==='server'?'serverInfo':page));
    set('page-subtitle',text(page==='server'?'serverSub':`${page}Sub`));
  }
  function navigate(next) {
    if (!['overview','settings','keybinds','server'].includes(next)) return;
    page=next;
    document.querySelectorAll('.page').forEach(el=>el.hidden=el.id!==`page-${next}`);
    document.querySelectorAll('[data-page]').forEach(el=>{
      const active=el.dataset.page===next; el.classList.toggle('active',active);
      if(active)el.setAttribute('aria-current','page');else el.removeAttribute('aria-current');
    });
    updateHeading();
  }
  function applyPreferences() {
    preferences.opacity=Math.min(90,Math.max(45,Number(preferences.opacity)||64));
    document.documentElement.style.setProperty('--shade',String(preferences.opacity/100));
    document.body.classList.toggle('reduced-motion',preferences.reducedMotion===true);
    document.body.classList.toggle('no-blur',preferences.blur===false);
    for(const key of ['opacity','blur','sound','reducedMotion']) {
      if(key==='opacity')$(key).value=String(preferences.opacity);else $(key).checked=preferences[key]===true;
    }
    set('opacity-value',`${preferences.opacity}%`);
  }
  function show(options={}) {
    clearTimeout(loadTimer); visible=true; pending=false;
    $('preview-reopen').hidden=true;
    if(options.preferences)preferences={...preferences,...options.preferences};
    // Never show another character’s old balances while a new open is loading.
    data=null;
    set('player-name',options.name||'—'); set('player-id','—');
    for(const id of ['player-job','player-cash','player-bank','online-count','server-online','server-ping','server-location','location'])set(id,'—');
    $('avatar').src=inGame?'assets/icon-user.svg':'assets/icon-user.svg';
    $('avatar').classList.toggle('fallback',inGame);
    set('profile-status',text('loading'));
    navigate('overview'); translate(); applyPreferences();
    root.hidden=false;
    resetMapView();
    document.querySelector('[data-page="overview"]').focus({preventScroll:true});
    loadTimer=setTimeout(()=>{if(visible&&!data)set('profile-status',text('loadFailed'));},10000);
  }
  function hide() {
    clearTimeout(loadTimer); visible=false; root.hidden=true;
    resetMapView();
    if($('dialog').open)$('dialog').close();
    $('toast').hidden=true;
    if(!inGame)$('preview-reopen').hidden=false;
  }
  function amount(value) {
    if(value===null||value===false||value===undefined||!Number.isFinite(Number(value)))return '—';
    return `${data?.config?.currency||'$'}${new Intl.NumberFormat('en-US',{maximumFractionDigits:0}).format(Number(value))}`;
  }
  function render(next) {
    if(!next||typeof next!=='object')return;
    clearTimeout(loadTimer); data=next;
    const config=next.config||{},player=next.player||{};
    translate();
    for(const token of ['accent','muted','neutral']) {
      const value=config.theme?.[token];
      if(typeof value==='string'&&/^#[0-9a-f]{6}$/i.test(value))document.documentElement.style.setProperty(`--${token}`,value);
    }
    set('brand',config.serverName||'ROLEPLAY');set('server-title',config.serverName||'ROLEPLAY');set('server-description',config.description||'');
    set('player-name',player.name);set('player-id',player.characterId);set('id-label',text(player.idLabel==='citizen'?'citizenId':'sessionId'));
    set('player-job',player.job);set('player-cash',amount(player.cash));set('player-bank',amount(player.bank));
    const online=Number.isFinite(Number(next.online))?Number(next.online):'—';
    const max=Number.isFinite(Number(next.maxPlayers))?Number(next.maxPlayers):'—';
    set('online-count',`${online} / ${max}`);set('server-online',`${online} / ${max}`);
    set('server-ping',Number.isFinite(Number(next.ping))?`${Math.max(0,Number(next.ping))} ms`:'—');
    const location=[next.location?.street,next.location?.zone].filter(Boolean).join(' · ');
    set('location',next.location?.zone||'Los Santos');set('server-location',location||'—');
    set('profile-status',(player.cash===false&&player.bank===false)||next.framework==='standalone'?text('offlineProfile'):'');
    $('website-action').hidden=!validUrl(config.website);
    renderKeys();updateHeading();
    if(requestPending){requestPending=false;notify(text('refreshed'));}
  }
  function renderKeys() {
    const target=$('key-table');target.replaceChildren();
    const query=$('key-search').value.trim().toLocaleLowerCase();
    const keys=Array.isArray(data?.config?.keybinds)?data.config.keybinds:[];
    const filtered=keys.filter(k=>`${k.action} ${k.category} ${k.key}`.toLocaleLowerCase().includes(query));
    if(!filtered.length){const e=document.createElement('p');e.className='empty';e.textContent=text('noResults');target.append(e);return;}
    for(const k of filtered){
      const row=document.createElement('div');row.className='key-row';
      for(const [tag,cls,value] of [['span','key-category',k.category],['span','key-action',k.action],['kbd','',k.key]]){
        const e=document.createElement(tag);e.className=cls;e.textContent=String(value||'');row.append(e);
      }
      target.append(row);
    }
  }
  $('key-search').addEventListener('input',renderKeys);

  function modal(title, build, actions=[]) {
    const dialog=$('dialog');
    if(dialog.open)dialog.close();
    dialogFocus=document.activeElement;
    set('dialog-title',title);$('dialog-body').replaceChildren();$('dialog-actions').replaceChildren();
    if(typeof build==='function')build($('dialog-body'));else {const p=document.createElement('p');p.textContent=build;$('dialog-body').append(p);}
    for(const item of actions){
      const button=document.createElement('button');button.textContent=item.label;button.className=item.className||'secondary';
      button.addEventListener('click',async()=>{
        button.disabled=true;
        try{await item.run();}catch{notify(text('callbackFailed'));}finally{button.disabled=false;}
      });$('dialog-actions').append(button);
    }
    dialog.showModal();
    // Start destructive dialogs on Cancel; never autofocus Disconnect.
    ($('dialog-actions').querySelector('button')||$('dialog-close')).focus();
  }
  function closeModal(){if($('dialog').open)$('dialog').close();}
  $('dialog-close').addEventListener('click',closeModal);
  $('dialog').addEventListener('close',()=>{if(dialogFocus?.isConnected&&!root.hidden)dialogFocus.focus({preventScroll:true});});
  $('dialog').addEventListener('cancel',(event)=>{event.preventDefault();closeModal();});
  $('dialog').addEventListener('click',event=>{
    if(event.target===$('dialog')){const box=$('dialog').getBoundingClientRect();if(event.clientX<box.left||event.clientX>box.right||event.clientY<box.top||event.clientY>box.bottom)closeModal();}
  });
  function rules() {
    modal(text('rules'),container=>{
      const rules=Array.isArray(data?.config?.rules)?data.config.rules:[];
      if(!rules.length){const p=document.createElement('p');p.textContent=text('rulesMissing');container.append(p);}
      rules.forEach((rule,index)=>{const h=document.createElement('h3');h.textContent=`${String(index+1).padStart(2,'0')}  ${rule.title||''}`;const p=document.createElement('p');p.textContent=rule.body||'';container.append(h,p);});
    });
  }
  function validUrl(value){try{const url=new URL(value);return url.protocol==='https:'&&!url.username&&!url.password?url.href:null;}catch{return null;}}
  function external(kind) {
    const url=validUrl(data?.config?.[kind]);
    if(!url){modal(text('unavailable'),text('linkMissing'));return;}
    // User gesture only; no automatic outbound requests or remote UI assets.
    if(inGame&&typeof window.invokeNative==='function'){window.invokeNative('openUrl',url);return;}
    modal(text('externalTitle'),container=>{
      const input=document.createElement('input');input.value=url;input.readOnly=true;input.setAttribute('aria-label','URL');input.addEventListener('focus',()=>input.select());container.append(input);
    },[{label:text('copy'),run:async()=>{try{await navigator.clipboard.writeText(url);notify(text('copied'));}catch{notify(text('copyFailed'));}}},{label:text('openLink'),className:'primary',run:()=>{window.open(url,'_blank','noopener,noreferrer');}}]);
  }
  async function native(kind) {
    if(!inGame){modal(text('nativePreview'),text('nativePreviewBody'));return;}
    if(pending)return;pending=true;
    try{const result=await nui('native',{kind});if(!result.ok)notify(text('callbackFailed'));}catch{notify(text('callbackFailed'));}finally{pending=false;}
  }
  async function resume() {
    if(!inGame){hide();return;}
    if(pending)return;pending=true;
    try{const result=await nui('close');if(!result.ok)notify(text('callbackFailed'));}catch{notify(text('callbackFailed'));}finally{pending=false;}
  }
  function disconnect() {
    modal(text('confirmDisconnect'),text('disconnectBody'),[
      {label:text('cancel'),run:closeModal},
      {label:text('leave'),className:'primary danger',run:async()=>{if(inGame){const result=await nui('disconnect');if(!result.ok)throw new Error();}else{closeModal();notify(text('previewDisconnect'));}}}
    ]);
  }
  async function refresh(){
    if(requestPending)return;requestPending=true;notify(text('refreshing'));
    try{const result=await nui('refresh');if(!result.ok)throw new Error();if(!inGame)setTimeout(()=>render(demoData),200);else{clearTimeout(loadTimer);loadTimer=setTimeout(()=>{requestPending=false;notify(text('loadFailed'));},10000);}}
    catch{requestPending=false;notify(text('callbackFailed'));}
  }
  root.addEventListener('click',event=>{
    const target=event.target.closest('button');if(!target||target.disabled)return;
    if(target.dataset.page)navigate(target.dataset.page);
    else if(target.dataset.native){if(target.dataset.native==='map')enterMap();else native(target.dataset.native);}
    else {
      const actions={resume,rules,disconnect,discord:()=>external('discord'),website:()=>external('website'),refresh};
      actions[target.dataset.action]?.();
    }
  });

  async function savePreferences(){
    const version=++saveVersion;
    set('save-state',text('saving'));
    try{
      if(inGame){const result=await nui('preferences',preferences);if(!result.ok)throw new Error();}
      else localStorage.setItem('shPausePreviewPreferences',JSON.stringify(preferences));
      if(version===saveVersion)set('save-state',text('saved'));
    }catch{if(version===saveVersion)set('save-state','');notify(text('preferencesFailed'));}
  }
  for(const key of ['opacity','blur','sound','reducedMotion'])$(key).addEventListener('input',()=>{
    preferences[key]=key==='opacity'?Number($(key).value):$(key).checked;applyPreferences();
    clearTimeout(saveTimer);saveTimer=setTimeout(savePreferences,200);
  });
  document.addEventListener('keydown',event=>{
    if(event.key!=='Escape')return;
    if($('dialog').open)return; // Native dialog cancel closes only the dialog.
    event.preventDefault();
    if(mapMode){leaveMap();return;}
    if(visible)resume();else if(!inGame){show({preferences});render(demoData);}
  });
  $('avatar').addEventListener('error',()=>{
    if(!$('avatar').classList.contains('fallback')){$('avatar').classList.add('fallback');$('avatar').src='assets/icon-user.svg';}
  });
  window.addEventListener('message',event=>{
    if(!inGame)return;
    const message=event.data;if(!message||typeof message!=='object')return;
    if(event.source===mapView.contentWindow)return;
    if(message.action==='mapUpdate'&&mapMode)sendMap(message.message);
    if(message.action==='mapNotice'&&visible&&typeof message.text==='string')notify(message.text);
    if(message.action==='open')show(message);
    if(message.action==='close')hide();
    if(message.action==='data'&&visible)render(message.payload);
    if(message.action==='portrait'&&visible&&typeof message.url==='string'&&/^https:\/\/nui-img\/[A-Za-z0-9_]+\/[A-Za-z0-9_]+(?:\?v=\d+)?$/.test(message.url)){$('avatar').classList.remove('fallback');$('avatar').src=message.url;}
    if(message.action==='error'&&visible)notify(text(message.key==='nativeFailed'?'nativeFailed':'callbackFailed'));
  });

  const demoData={
    config:{language:'en',serverName:'ROLEPLAY',description:'Your city. Your story. Make every moment count.',currency:'$',discord:'',website:'',theme:{accent:'#009DB0',muted:'#478991',neutral:'#7C7C7C'},
      rules:[{title:'Respect other players',body:'Treat everyone with respect. Harassment and discrimination are not allowed.'},{title:'Stay in character',body:'Keep roleplay believable. Do not use information your character has not learned in the city.'},{title:'Play fair',body:'Do not cheat or exploit bugs. Report issues to your server’s staff.'},{title:'Value your character’s life',body:'React realistically to danger and give others a fair chance to roleplay.'}],
      keybinds:[{category:'Menu',action:'Pause menu',key:'ESC / P / F10'},{category:'Movement',action:'Move',key:'W A S D'},{category:'Movement',action:'Sprint',key:'SHIFT'},{category:'Movement',action:'Jump',key:'SPACE'},{category:'Movement',action:'Enter / exit vehicle',key:'F'},{category:'Communication',action:'Chat',key:'T'}]},
    player:{name:'Alex Morgan',characterId:'1042',idLabel:'citizen',job:'Mechanic',cash:2450,bank:38200},online:128,maxPlayers:256,ping:34,framework:'preview',location:{zone:'Pillbox Hill',street:'Power St'}
  };
  if(!inGame){
    document.body.classList.add('preview');$('preview-label').hidden=false;
    try{const saved=JSON.parse(localStorage.getItem('shPausePreviewPreferences'));if(saved&&typeof saved==='object')preferences={...preferences,...saved};}catch{}
    show({preferences,language:demoData.config.language});render(demoData);
    $('preview-reopen').addEventListener('click',()=>{show({preferences});render(demoData);});
  }else{
    // Retry the startup handshake if CEF loads before Lua has registered callbacks.
    let attempts=0;
    const boot=async()=>{try{await nui('ready');}catch{if(++attempts<8)setTimeout(boot,750);}};boot();
  }
})();
