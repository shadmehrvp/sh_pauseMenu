const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'../html');
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  fs.readFile(file,(err,bytes)=>{if(err){res.writeHead(404).end();return;}res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.css':'text/css','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');res.end(bytes);});
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,...(process.env.BROWSER_PATH?{executablePath:process.env.BROWSER_PATH}:{})});
 try{
  const page=await browser.newPage({viewport:{width:1720,height:720},colorScheme:'dark'});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{
   if(window!==top)return;
   const nativeFetch=window.fetch;
   window.GetParentResourceName=()=> 'sh_pauseMenu';window.calls=[];window.savedPlaces=[];
   const player={x:200,y:-900,z:30,heading:0,zone:'Pillbox Hill',street:'Power St'};
   window.fetch=async(url,options)=>{
    if(!String(url).startsWith('https://sh_pauseMenu/'))return nativeFetch(url,options);
    const endpoint=url.split('/').pop(),body=JSON.parse(options.body);window.calls.push({endpoint,body});
    const frame={type:'frame',player,waypoint:false,route:[],markers:[{id:'b1',x:300,y:-1000,z:30,label:'Hospital',category:'Services',sprite:61,color:'#60a5fa'},{id:'b2',x:600,y:-1100,z:30,label:'Hospital',category:'Services',sprite:61,color:'#60a5fa'},{id:'b3',x:100,y:-850,z:30,label:'Barber',category:'Shops',sprite:71,color:'#60a5fa'}],places:window.savedPlaces,shared:[],camera:{x:200,y:-1160,z:650,pitch:-68,yaw:0,fov:50,distance:650}};
    let result={ok:true};
    if(endpoint==='mapOpen')result={ok:true,message:{type:'open',serverName:'SH Roleplay',frame,colors:[{id:'purple',label:'Purple',hex:'#9a6bff'}],tiles:[]}};
    if(endpoint==='mapAction'){
      const {name,data}=body;result=true;
      if(name==='pick')result={x:500,y:-1000};
      if(name==='placesList')result={ok:true,places:window.savedPlaces};
      if(name==='placesAdd'){window.savedPlaces=[{id:1,...data}];result={ok:true,places:window.savedPlaces};}
      if(name==='placesDelete'){window.savedPlaces=[];result={ok:true,places:[]};}
      if(name==='waypoint')setTimeout(()=>window.postMessage({action:'mapUpdate',message:{type:'frame',player,waypoint:{...data,z:30},route:[player,{x:data.x,y:data.y,z:30}]}},'*'),10);
    }
    if(endpoint==='native'||endpoint==='close')window.postMessage({action:'close'},'*');
    return {ok:true,json:async()=>result};
   };
  });
  await page.goto(`http://127.0.0.1:${server.address().port}/index.html`);
  await page.waitForFunction(()=>window.calls.some(c=>c.endpoint==='ready'));
  await page.evaluate(()=>{
    window.postMessage({action:'open'},'*');
    window.postMessage({action:'data',payload:{config:{serverName:'SH Roleplay',currency:'$',theme:{},rules:[],keybinds:[]},player:{name:'Alex Morgan',characterId:'1',job:'Police',cash:100,bank:200},online:1,maxPlayers:48,location:{zone:'Pillbox Hill'}}},'*');
  });
  await page.locator('.map-open').click();
  const map=page.frameLocator('#map-view');await map.locator('body:not([hidden])').waitFor();
  assert.equal(await map.locator('#city').textContent(),'SH Roleplay');
  await map.locator('[data-filter="saved"]').click();await map.locator('.empty').waitFor();assert.equal(await map.locator('[data-group]').count(),0);
  await map.locator('[data-filter="nearby"]').click();await map.locator('[data-group="0"]').waitFor();
  await map.locator('[data-filter="all"]').click();
  await map.locator('[data-group="0"]').click();
  await map.locator('[data-cycle="0"][data-dir="1"]').click();assert.equal(await map.locator('.cycle').first().textContent(),'‹2/2›');
  await map.locator('[data-cycle="0"][data-dir="-1"]').click();
  await map.locator('[data-visible="0"]').uncheck();assert.equal(await map.locator('.group.hidden').count(),1);
  assert(await map.locator('[data-visible="1"]').isChecked(),'Hiding hospitals does not hide a different place type');
  await map.locator('[data-visible="0"]').check();
  await map.locator('#gps').click();await map.locator('.waypoint').waitFor();
  await map.locator('#gps').getByText('Remove waypoint',{exact:true}).waitFor();
  await map.locator('#tour:not([disabled])').waitFor();
  if(process.env.SCREENSHOT_PATH){
    await page.addStyleTag({content:'html{background:radial-gradient(ellipse at 60% 45%,#264854,#0b1c25 75%)}'});
    await map.locator('body').evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(img=>img.complete?Promise.resolve():new Promise(r=>{img.onload=r;img.onerror=r;})));});
    await page.screenshot({path:process.env.SCREENSHOT_PATH});
    for(const viewport of [{width:900,height:650},{width:650,height:600}]){
      await page.setViewportSize(viewport);
      const boxes=await map.locator('aside,nav,.card,.identity').evaluateAll(nodes=>nodes.filter(n=>!n.hidden).map(n=>{const r=n.getBoundingClientRect();return {left:r.left,right:r.right,top:r.top,bottom:r.bottom};}));
      assert(boxes.every(r=>r.left>=0&&r.right<=viewport.width+1&&r.top>=0&&r.bottom<=viewport.height+1),'Map panels stay inside the viewport');
    }
    await page.setViewportSize({width:1720,height:720});
  }
  await map.locator('#tour').click();
  await map.locator('#add-place').click();await map.locator('#place-name').fill('<img src=x> Home');await map.locator('#save').click();
  await page.waitForFunction(()=>window.savedPlaces.length===1);
  await map.locator('#search').fill('Home');assert.equal(await map.locator('#locations img[src="x"]').count(),0,'place names are escaped');
  await map.locator('#search').fill('');await map.locator('#mode').click();assert.equal(await map.locator('body.flat').count(),1);
  await map.locator('#mode').click();await map.locator('#zin').click();await map.locator('#zout').click();await map.locator('#recenter').click();
  await page.mouse.move(700,350);await page.mouse.down();await page.mouse.move(800,410,{steps:4});await page.mouse.up();
  await page.mouse.move(700,350);await page.mouse.down({button:'right'});await page.mouse.move(770,390,{steps:4});await page.mouse.up({button:'right'});
  await page.waitForFunction(()=>window.calls.some(c=>c.body.name==='pan')&&window.calls.some(c=>c.body.name==='rotate'));
  await map.locator('#remove').click();await map.locator('#clear').waitFor({state:'hidden'});
  await map.locator('#back').click();await page.locator('#map-view').waitFor({state:'hidden'});
  await page.keyboard.press('Escape');await page.locator('#pause').waitFor({state:'hidden'});
  assert.deepEqual(errors,[]);
  console.log('PASS: independent map UI, waypoint, tour, saved places, safe text, 2D/3D, zoom, pan, rotate and close');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(error=>{console.error(error);process.exitCode=1;});
