-- Queue scheduling and diagnostics only; native APIs and scrolls are mocks.
local function fresh(two)
 local R=reset();R.performance={};R.smoothReads=true;R.dirty=false;R.uiDirty=false
 R.nextAt=0;R.nextIdleRefresh=0;R.animationWaitAt=nil
 R:Toggle('A:101');if two then R:Toggle('A:102')end
 return R
end
local function tick(dt)
 clock=clock+dt
 for _,f in ipairs(PreviewFrames)do
  if f.events.ADDON_LOADED and f:GetScript('OnUpdate')then f:GetScript('OnUpdate')(f,dt)end
 end
end
local function result(R,id)
 local p=R.pending;assert(p)
 replaceAbility(p.target.id,id);scrollCounts[640]=scrollCounts[640]-1
 R:Result('ability',id)
end
local function override(object,key,value,body)
 local old=object[key];object[key]=value
 local ok,err=pcall(body);object[key]=old;if not ok then error(err,0)end
end
local function near(a,b)assert(math.abs(a-b)<0.001,tostring(a)..' ~= '..tostring(b))end

test('queue enforces 100 ms after confirmation while retaining a fresh next-request read',function()
 local R=fresh(true);R:Start();result(R,103);R:Step(false)
 assert(R.done==1 and #calls==1 and R.performance.snapshot.calls==2)
 clock=0.099;R:Step(false);assert(#calls==1 and R.performance.snapshot.calls==2)
 clock=0.101;R:Step(false);assert(#calls==2 and R.pending and R.performance.snapshot.calls==3)
 near(R.performance.rollTimings[1].requestReadMS,0)
end)

test('result events wake on the next frame without requesting from the event callback',function()
 local R=fresh(true);R:Start();tick(0)
 clock=0.01;replaceAbility(101,103);scrollCounts[640]=9
 Fire('CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED',103)
 assert(R.pending and R.done==0 and #calls==1 and R.performance.snapshot.calls==1)
 tick(0.001);assert(R.done==1 and not R.pending and #calls==1)
 assert(clock<0.05,'event should not await the fallback poll')
 tick(0.04);assert(#calls==1)
 tick(0.07);assert(#calls==2 and R.pending)
end)

test('bag readiness wakes a pending result but does not scan before the scroll changes',function()
 local R=fresh();R:Start();tick(0);R:Result('ability',103);tick(0.001)
 assert(R.performance.snapshot.calls==1 and R.pending)
 replaceAbility(101,103);scrollCounts[640]=9;Fire('BAG_UPDATE',0)
 assert(R.pending and R.done==0)
 tick(0.001);assert(R.done==1 and not R.running and R.performance.snapshot.calls==2)
end)

test('bag events without a result never authorize a roll or a result scan',function()
 local R=fresh(true);R:Start();replaceAbility(101,103);scrollCounts[640]=9
 for i=1,50 do Fire('BAG_UPDATE',0);tick(0.01)end
 assert(R.pending and R.done==0 and #calls==1 and R.performance.snapshot.calls==1)
 R:Result('ability',103);tick(0.001);assert(R.done==1)
end)

test('duplicate result and bag storms preserve the one-second stale-build retry gate',function()
 local R=fresh(true);R:Start();R:Result('ability',103);scrollCounts[640]=9;tick(0.001)
 assert(R.performance.queue_result_read.calls==1 and R.pending)
 local firstEvent=R.pending.eventAt
 for i=1,150 do
  Fire('CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED',103);Fire('BAG_UPDATE',0);tick(0.004)
 end
 assert(R.performance.queue_result_read.calls==1 and R.performance.queue_event.calls==1)
 assert(R.pending.eventAt==firstEvent and #calls==1)
 replaceAbility(101,103);clock=1.01;tick(0.001)
 assert(R.done==1 and R.performance.queue_result_read.calls==2 and #calls==1)
end)

test('50 ms fallback observes readiness even when inventory wakeup events are missing',function()
 local R=fresh();R:Start();R:Result('ability',103);tick(0)
 replaceAbility(101,103);scrollCounts[640]=9
 tick(0.02);assert(R.pending)
 tick(0.031);assert(R.done==1 and not R.running)
end)

test('animation hide wakes next frame at both speeds and preserves existing callbacks',function()
 for _,fast in ipairs({true,false})do
  local R=fresh(true);R.db.fast=fast;R:Start();result(R,103);R:Step(false)
  local f=CreateFrame('Frame');RandomMode_RollFrame=f;local hidden=0
  f:SetScript('OnHide',function()hidden=hidden+1 end)
  clock=0.11;tick(0);assert(#calls==1 and R.performance.snapshot.calls==2)
  R.Client:WatchAnimation(f);R.Client:WatchAnimation(f)
  clock=0.12;f:Hide();assert(#calls==1 and hidden==1 and R.queueWake)
  tick(0.001);assert(#calls==2 and R.performance.snapshot.calls==3)
  assert(R.pending.animationMS>0 and R.pending.minimumMS==100)
 end
end)

test('animation completion before minimum delay cannot bypass queue spacing',function()
 local R=fresh(true);R:Start();result(R,103);R:Step(false)
 local f=CreateFrame('Frame');RandomMode_RollFrame=f;R.Client:WatchAnimation(f)
 clock=0.02;f:Hide();tick(0.001);assert(#calls==1)
 tick(0.05);assert(#calls==1)
 tick(0.05);assert(#calls==2)
end)

test('waiting for animation makes no extra full reads and still times out',function()
 local R=fresh(true);R:Start();result(R,103);R:Step(false)
 RandomMode_RollFrame=CreateFrame('Frame');clock=0.11
 for i=1,200 do tick(0.05)end
 assert(R.running and #calls==1 and R.performance.snapshot.calls==2)
 clock=12.3;tick(0.1)
 assert(not R.running and #calls==1 and R.status:find('presentation did not finish'))
end)

test('pause observes the outstanding result but event wakeups never send the next roll',function()
 local R=fresh(true);R:Start();R:Pause();result(R,103);tick(0.001)
 assert(R.done==1 and R.paused and R.running)
 for i=1,10 do Fire('BAG_UPDATE',0);tick(0.1)end
 assert(#calls==1 and R.performance.snapshot.calls==2)
 R:Pause();assert(#calls==1);tick(0.001);assert(#calls==2)
end)

test('stop with a pending result records it without restarting or claiming queue completion',function()
 local R=fresh(true);R:Start();R:Stop('Stopped for test.');result(R,103);tick(0.001)
 assert(not R.running and not R.pending and #calls==1 and #R.character.history==1)
 assert(not R.status:find('Finished:') and R.db.lastQueueStatus.reason=='Stopped for test.')
 tick(1);assert(#calls==1)
end)

test('last confirmation immediately unlocks selection without an extra scan or request',function()
 local R=fresh();R:Start();result(R,103);R:Step(false)
 assert(not R.running and not R.pending and R.status=='Finished: 1 confirmed rerolls.')
 assert(R:CanEditEntry('A:102') and R.performance.snapshot.calls==2 and #calls==1)
 R:Toggle('A:102');assert(R.selected['A:102'])
 assert(R.db.lastQueueStatus.confirmed==1 and R.window.status:GetText()==R.status)
end)

test('a final confirmation while paused completes without sending another request',function()
 local R=fresh();R:Start();R:Pause();result(R,103);R:Step(false)
 assert(not R.running and not R.paused and not R.pending and #calls==1)
 assert(R.status=='Finished: 1 confirmed rerolls.')
end)

test('final confirmation does not bypass a lingering presentation on a newly started queue',function()
 local R=fresh();R:Start();result(R,103);R:Step(false)
 RandomMode_RollFrame=CreateFrame('Frame');R:Toggle('A:102');R:Start()
 assert(R.running and R.paused and not R.pending and #calls==1)
end)

test('fast transitions retain combat death spec ownership lock and scroll guards',function()
 for _,change in ipairs({'combat','death','spec','ownership','lock','scroll'})do
  local R=fresh(true);R:Start();result(R,103);R:Step(false)
  if change=='combat'then combat=true
  elseif change=='death'then dead=true
  elseif change=='spec'then spec=2
  elseif change=='ownership'then known[#known+1]=999
  elseif change=='lock'then R:Locks(R.spec)['A:102']=true
  else scrollCounts[640]=0 end
  clock=0.101;R:Step(false)
  assert(#calls==1 and not R.running and not R.pending,change)
 end
end)

test('animation-hide wakeup still detects an unrelated build change with no event',function()
 local R=fresh(true);R:Start();result(R,103);R:Step(false)
 RandomMode_RollFrame=CreateFrame('Frame');clock=0.11;tick(0)
 known[#known+1]=999;RandomMode_RollFrame:Hide();tick(0.001)
 assert(#calls==1 and not R.running and R.status:find('Build changed'))
end)

test('pending timeouts remain bounded and never retry a request',function()
 local R=fresh(true);R:Start()
 for i=1,50 do tick(0.05)end
 assert(#calls==1 and R.pending and R.performance.snapshot.calls==1)
 clock=20.1;tick(0.1)
 assert(not R.pending and not R.running and #calls==1 and R.status:find('20 seconds'))
end)

test('per-roll timing distinguishes observed latency from request and result read work',function()
 local R=fresh();local original=GetKnownClasslessSpellIds
 override(_G,'debugprofilestop',function()return clock*1000 end,function()
  override(_G,'GetKnownClasslessSpellIds',function()clock=clock+0.01;return original()end,function()
   R:Start();local at=R.pending.requestAt
   clock=at+0.2;R:Result('ability',103)
   replaceAbility(101,103);scrollCounts[640]=9;clock=at+0.25;R:Step(false)
  end)
 end)
 local t=R.performance.rollTimings[1]
 near(t.eventMS,200);near(t.scrollMS,250);near(t.confirmedMS,260)
 near(t.requestReadMS,10);near(t.resultReadMS,10)
 near(R.performance.queue_request_read.totalMS,10)
 near(R.performance.queue_result_read.totalMS,10)
 assert(not t.gapMS and R.performance.queue_confirm.calls==1)
end)

test('gap diagnostics include elapsed time but identify the configured 100 ms minimum separately',function()
 local R=fresh(true);R:Start();result(R,103);R:Step(false)
 clock=0.15;R:Step(false);result(R,104);R:Step(false)
 local t=R.performance.rollTimings[2]
 near(t.gapMS,150);near(t.minimumMS,100);near(t.animationMS,0)
 near(R.performance.queue_gap.totalMS,150)
end)

test('recent queue timing storage is bounded and counter reset clears it without changing history',function()
 local R=fresh();scrollCounts[640]=100
 for i=1,25 do
  if i>1 then R:Toggle('A:'..(200+i-1))end
  R:Start('ability');result(R,200+i);R:Step(false);clock=clock+0.2
 end
 assert(#R.performance.rollTimings==20 and #R.character.history==20 and #calls==25)
 R.Client:ResetPerformance();assert(not next(R.performance) and #R.character.history==20)
end)

test('pace diagnostics are bounded read-only and show a currently outstanding request',function()
 local R=fresh(true);R:Start();local pending,status,scans=R.pending,R.status,R.performance.snapshot.calls
 local output={}
 override(DEFAULT_CHAT_FRAME,'AddMessage',function(_,s)output[#output+1]=s end,function()
  SlashCmdList.GRIMFALLREROLL('pace');SlashCmdList.GRIMFALLREROLL('perf')
 end)
 assert(R.pending==pending and R.status==status and #calls==1 and R.performance.snapshot.calls==scans)
 local text=table.concat(output,'\n')
 assert(text:find('Outstanding request',1,true) and text:find('100 ms minimum',1,true))
 assert(text:find('not pure server time',1,true) and text:find('CPU timing API unavailable',1,true))
end)

test('idle inventory events cannot wake a queue or cause full build scans',function()
 local R=fresh();R.selected={};local scans=R.performance.snapshot and R.performance.snapshot.calls or 0
 for i=1,20 do Fire('BAG_UPDATE',0);tick(0.05)end
 assert(not R.queueWake and not R.running and not R.pending and #calls==0)
 assert((R.performance.snapshot and R.performance.snapshot.calls or 0)==scans)
end)

test('mixed fast queue still uses talent IDs and independent exact scroll counts',function()
 local R=fresh();R:Toggle('T:201');R:Start();result(R,103);R:Step(false)
 clock=0.101;R:Step(false)
 assert(#calls==2 and calls[2][1]=='talent' and calls[2][2]==201)
 talents={[202]={class=1,spell=302}};scrollCounts[639]=9
 Fire('CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED',302)
 Fire('CUSTOM_CLASSLESS_WILDCARD_TALENT_LEARN',302)
 tick(0.001)
 assert(R.done==2 and not R.running and #calls==2 and R.performance.snapshot.calls==4)
 assert(scrollCounts[640]==9 and scrollCounts[639]==9 and R.performance.queue_event.calls==2)
end)

test('event bursts coalesce to one result read per frame',function()
 local R=fresh(true);R:Start();replaceAbility(101,103);scrollCounts[640]=9
 for i=1,100 do Fire('CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED',103);Fire('BAG_UPDATE',0)end
 assert(R.performance.snapshot.calls==1 and #calls==1)
 tick(0.001)
 assert(R.performance.snapshot.calls==2 and R.done==1 and #calls==1)
end)

test('request refusal never retries under rapid event wakeups',function()
 local R=fresh(true);requestAllowed=false;R:Start()
 assert(not R.running and R.pending and #calls==1)
 for i=1,100 do Fire('BAG_UPDATE',0);tick(0.01)end
 assert(#calls==1 and R.performance.snapshot.calls==1)
end)

test('a late incompatible result after the next request fails closed without another request',function()
 local R=fresh(true);R:Start();result(R,103);R:Step(false)
 clock=0.101;R:Step(false)
 R:Result('ability',103);R:Result('ability',104)
 assert(not R.running and R.pending.ambiguous and #calls==2)
 for i=1,10 do Fire('BAG_UPDATE',0);tick(0.1)end
 assert(#calls==2 and #R.character.history==1)
end)

test('native synchronous result callbacks cannot recursively send another request',function()
 local R=fresh(true);local request=ClasslessUnlearnSpell
 override(_G,'ClasslessUnlearnSpell',function(id)
  local ok=request(id);replaceAbility(id,103);scrollCounts[640]=9
  Fire('CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED',103);Fire('BAG_UPDATE',0)
  return ok
 end,function()R:Start()end)
 assert(#calls==1 and R.pending and R.done==0)
 tick(0.001);assert(R.done==1 and #calls==1)
 tick(0.04);assert(#calls==1)
end)

test('pace shows at most five recent records and does not persist timing tables',function()
 local R=fresh();R.performance.rollTimings={}
 for i=1,20 do R.performance.rollTimings[i]={kind='ability',eventMS=i,confirmedMS=i+1}end
 local output={}
 override(DEFAULT_CHAT_FRAME,'AddMessage',function(_,s)output[#output+1]=s end,function()R.Client:QueueReport()end)
 assert(#output<=14 and table.concat(output,'\n'):find('Last 5 confirmed rolls',1,true))
 assert(not R.db.rollTimings and not R.character.rollTimings and #calls==0)
end)
