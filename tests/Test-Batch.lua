-- New default batch engine. Old suites continue exercising /rr batch off.
local function fresh(n)
 local R=reset();R.db.batch=nil;known={}
 for i=1,n or 6 do known[i]=100+i end
 R:Refresh();R.performance={}
 for _,row in ipairs(R.rows)do if row.kind=='ability'then R:Toggle(row.key)end end
 return R
end
local function tick(R,dt)clock=clock+(dt or 0.11);R:Step(false)end
local function ack(R,id,update)
 local p=assert(R.pending);id=id or (p.target.spellID+1000)
 if update~=false then
  if p.target.kind=='ability'then replaceAbility(p.target.spellID,id)
  else talents[p.target.id]=nil;talents[id]={class=1,spell=id,rank=1}end
 end
 scrollCounts[R.scrolls[p.target.kind]]=scrollCounts[R.scrolls[p.target.kind]]-1
 R:Result(p.target.kind,id);tick(R,0.05)
 return p
end
local function finish(R)
 for i=1,30 do if not R.batch then return end;tick(R,0.11)end
 error('batch not finished: '..tostring(R.status))
end
test('batch is the default while explicit per-roll verification remains available',function()
 local R=fresh();assert(R:BatchEnabled());assert(R:SetBatchMode(false) and not R:BatchEnabled())
 assert(R:SetBatchMode(true));R:Start('ability');assert(R.batch and #calls==1 and not R:SetBatchMode(false))
end)
test('six-roll batch makes exactly one initial and one final full read with no list refreshes between',function()
 local R=fresh();local read=R.Client.Snapshot;local scans=0
 R.Client.Snapshot=function(...)scans=scans+1;return read(...)end
 local ok,why=pcall(function()
  R:Start('ability');local rows=R.rows;local byKey=R.byKey;assert(scans==1 and #calls==1)
  for i=1,6 do
   ack(R);assert(not R.pending and scans==1 and R.rows==rows and R.byKey==byKey and #R.character.history==0)
   assert(R.done==i and #calls==i)
   if i<6 then tick(R);assert(R.pending and #calls==i+1 and scans==1)end
  end
  finish(R);assert(scans==2 and #calls==6 and #R.character.history==6 and R.done==6 and R.rows~=rows)
  assert(scrollCounts[640]==4 and scrollCounts[639]==10 and R.status:find('Lists refreshed once',1,true))
  assert(R.performance.queue_request_read.calls==1 and R.performance.queue_batch_final_read.calls==1 and not R.performance.queue_result_read)
 end)
 R.Client.Snapshot=read;assert(ok,why)
end)
test('six talent rolls use original talent IDs and only two full reads',function()
 local R=reset();R.db.batch=true;talents={};for i=1,6 do talents[200+i]={class=1,spell=300+i,rank=1}end
 R:Refresh();R.performance={};for _,row in ipairs(R.rows)do if row.kind=='talent'then R:Toggle(row.key)end end
 R:Start('talent')
 for i=1,6 do
  assert(calls[i][1]=='talent' and calls[i][2]>=201 and calls[i][2]<=206)
  ack(R);if i<6 then tick(R)end
 end
 finish(R);assert(#calls==6 and #R.character.history==6 and scrollCounts[639]==4 and scrollCounts[640]==10)
 assert(R.performance.snapshot.calls==2 and not R.performance.queue_result_read)
end)
test('batch events and bag updates alone cannot confirm or overlap a request',function()
 local R=fresh(2);R:Start('ability');local p=R.pending
 for i=1,10 do tick(R)end;assert(R.pending==p and #calls==1 and #R.character.history==0)
 R:Result('ability',1101);tick(R);assert(R.pending==p and #calls==1)
 scrollCounts[640]=9;replaceAbility(101,1101);tick(R);assert(not R.pending and #calls==1)
 tick(R);assert(#calls==2)
end)
test('batch without a result event waits even when the scroll and build change',function()
 local R=fresh(2);R:Start('ability');local p=R.pending
 replaceAbility(101,1101);scrollCounts[640]=9;for i=1,8 do Fire('BAG_UPDATE',0);tick(R)end
 assert(R.pending==p and R.done==0 and #calls==1 and not R.performance.queue_batch_final_read)
end)
test('native presentation must finish before acknowledgement and the next request',function()
 local R=fresh(2);R:Start('ability');RandomMode_RollFrame=CreateFrame('Frame');RandomMode_RollFrame:Show()
 ack(R);assert(R.pending and R.done==0 and #calls==1)
 for i=1,10 do tick(R)end;assert(#calls==1)
 RandomMode_RollFrame:Hide();tick(R);assert(not R.pending and R.done==1 and #calls==1)
 tick(R);assert(#calls==2)
end)
test('pause still observes one outstanding result but resume never overlaps it',function()
 local R=fresh(2);R:Start('ability');R:Pause();ack(R)
 for i=1,10 do tick(R)end;assert(R.paused and not R.pending and #calls==1)
 R:Pause();tick(R);assert(#calls==2);ack(R);finish(R);assert(#R.character.history==2)
end)
test('stop after an acknowledged result verifies partial history without sending remaining rolls',function()
 local R=fresh(6);R:Start('ability');ack(R);R:Stop('User stopped.');finish(R)
 assert(#calls==1 and #R.character.history==1 and R.status:find('User stopped.',1,true))
end)
test('stop while a request is pending still verifies its late result',function()
 local R=fresh(6);R:Start('ability');R:Stop('User stopped.');ack(R);finish(R)
 assert(#calls==1 and #R.character.history==1 and not R.running and not R.pending)
end)
test('closing the planner cancels remaining batch requests without reopening it',function()
 local R=fresh(3);R:Start('ability');R.window:Hide();ack(R);finish(R)
 assert(#calls==1 and not R.window:IsShown() and #R.character.history==1)
end)
test('stopped batch blocks editing refresh and new queues until final verification',function()
 local R=fresh(3);R:Start('ability');ack(R);R:Stop('Stop');local n=R.performance.snapshot.calls
 R:Refresh();R:RequestRefresh();R:Start('ability');R:Lock('A:102');R:Clear()
 assert(R.performance.snapshot.calls==n and #calls==1 and not R:Locks(R.spec)['A:102'])
 finish(R);assert(not R.batch)
end)
test('combat death spec changes and new protections stop the next batch request',function()
 for _,mode in ipairs({'combat','death','spec','lock'})do
  local R=fresh(2);R:Start('ability');ack(R)
  if mode=='combat'then combat=true elseif mode=='death'then dead=true elseif mode=='spec'then spec=3 else R:Locks(R.spec)['A:102']=true end
  tick(R);assert(#calls==1 and R.batch.stopped and not R.running)
 end
end)
test('unexpected target or other scroll spending aborts without another request',function()
 for _,mode in ipairs({'target','other'})do
  local R=fresh(2);R:Start('ability');R:Result('ability',1101);replaceAbility(101,1101)
  scrollCounts[640]=mode=='target' and 8 or 9;if mode=='other'then scrollCounts[639]=9 end
  tick(R);finish(R);assert(#calls==1 and #R.character.history==0 and R.status:find('review',1,true))
 end
end)
test('inventory changes between acknowledgements stop before next batch action',function()
 local R=fresh(2);R:Start('ability');ack(R);scrollCounts[640]=8;tick(R)
 assert(#calls==1 and R.batch.stopped)
end)
test('conflicting or wrong-kind result events abort a batch without false history',function()
 for _,mode in ipairs({'conflict','wrongkind'})do
  local R=fresh(2);R:Start('ability')
  R:Result(mode=='wrongkind' and 'talent' or 'ability',1101)
  if mode=='conflict'then R:Result('ability',1102)end
  tick(R);finish(R);assert(#calls==1 and #R.character.history==0)
 end
end)
test('a result matching another original queued entry is ambiguous and never advances',function()
 local R=fresh(2);R:Start('ability');R:Result('ability',102);scrollCounts[640]=9;tick(R)
 assert(#calls==1 and R.batch.stopped and R.done==0)
end)
test('a late result reused from a prior request cannot acknowledge the next request',function()
 local R=fresh(2);R:Start('ability');ack(R);tick(R)
 R:Result('ability',1101);scrollCounts[640]=8;tick(R)
 assert(R.batch.stopped and #calls==2 and R.done==1)
end)
test('request refusal and timeout never retry or create confirmed history',function()
 local R=fresh(2);requestAllowed=false;R:Start('ability');assert(#calls==1 and not R.running)
 tick(R,21);finish(R);assert(#calls==1 and #R.character.history==0 and not R.batch)
end)
test('synchronous result callbacks cannot recursively dispatch the next batch request',function()
 local R=fresh(2);local request=R.Client.Request
 R.Client.Request=function(self,target)local ok=request(self,target);replaceAbility(target.spellID,1101);scrollCounts[640]=9;R:Result('ability',1101);return ok end
 local ok,why=pcall(function()R:Start('ability');assert(#calls==1 and R.pending);tick(R);assert(#calls==1 and not R.pending)end)
 R.Client.Request=request;assert(ok,why)
end)
test('final read detects unrelated build changes instead of reporting success',function()
 local R=fresh(2);R:Start('ability');ack(R);tick(R);ack(R);known[#known+1]=9999;finish(R)
 assert(#calls==2 and #R.character.history==0 and R.status:find('Other build entries changed',1,true))
 assert(R.byKey['A:9999'] and R.db.lastQueueStatus.confirmed==0)
end)
test('stale final build retries are bounded and never send another request',function()
 local R=fresh(1);R:Start('ability');ack(R,1101,false);tick(R)
 local scans=R.performance.snapshot.calls;assert(R.batch and #R.character.history==0)
 for i=1,10 do tick(R,0.01)end;assert(R.performance.snapshot.calls==scans and #calls==1)
 replaceAbility(101,1101);tick(R,1);assert(not R.batch and #R.character.history==1 and #calls==1)
end)
test('final build timeout leaves no fabricated history and never retries a roll',function()
 local R=fresh(1);R:Start('ability');ack(R,1101,false);tick(R);tick(R,21)
 assert(not R.batch and #calls==1 and #R.character.history==0 and R.status:find('review',1,true))
end)
test('batch replacements clear only stale current-spec locks after final verification',function()
 local R=fresh(2);R.db.hideLocked={ability=true};R:Locks(R.spec)['A:1101']=true;R:Locks('specialization:3')['A:1101']=true
 R:Start('ability');ack(R);assert(R:Locks(R.spec)['A:1101']);tick(R);ack(R);finish(R)
 assert(not R:Locks(R.spec)['A:1101'] and R:Locks('specialization:3')['A:1101'] and not R.selected['A:1101'])
end)
test('batch final history is bounded at twenty per kind and ordered newest first',function()
 local R=fresh(6);for i=1,20 do R.character.history[i]={kind='ability',oldName='Older '..i}end
 R:Start('ability');for i=1,6 do ack(R);if i<6 then tick(R)end end;finish(R)
 assert(#R.character.history==20 and R.character.history[1].newID==1106 and R.character.history[6].newID==1101)
end)
test('skin history toggles and performance commands during a batch do not scan or change its queue',function()
 local R=fresh(2);R:Start('ability');local p=R.pending;local n=R.performance.snapshot.calls
 R:SetSkin('clean');R:ToggleHistory('ability');R:ToggleHistory('talent');R.Client:PerformanceReport();R.Client:QueueReport()
 R.Client:ResetPerformance();R:Start('ability')
 assert(R.pending==p and #calls==1 and R.performance.snapshot.calls==n and not R.window.clear:IsEnabled())
 assert(not R.window.panels.ability.start:IsEnabled() and R.window.stop:IsEnabled())
end)
test('batch mode preferences and commands reject changes while busy and persist while idle',function()
 local R=fresh(1);SlashCmdList.GRIMFALLREROLL('batch off');assert(not R:BatchEnabled())
 SlashCmdList.GRIMFALLREROLL('batch on');assert(R:BatchEnabled());R:Start('ability')
 SlashCmdList.GRIMFALLREROLL('batch off');assert(R:BatchEnabled());ack(R);finish(R)
 local db=R.db;R:InitializeDB(db);assert(R:BatchEnabled())
end)
test('real event loop runs a full default batch and does not schedule an extra idle refresh',function()
 local R=fresh(2);GrimfallRerollDB=R.db;Fire('ADDON_LOADED','GrimfallReroll');R:Refresh()
 R:Toggle('A:101');R:Toggle('A:102') -- existing fresh selections toggle off
 R:Toggle('A:101');R:Toggle('A:102')
 R.performance={};R:Start('ability')
 local function frame(dt)
  clock=clock+dt
  for _,f in ipairs(PreviewFrames)do if f.events.ADDON_LOADED and f.scripts.OnUpdate then f.scripts.OnUpdate(f,dt)end end
 end
 for i=1,2 do
  local p=assert(R.pending);replaceAbility(p.target.spellID,p.target.spellID+1000);scrollCounts[640]=scrollCounts[640]-1
  Fire('CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED',p.target.spellID+1000);Fire('SPELLS_CHANGED');Fire('BAG_UPDATE',0)
  assert(#calls==i);frame(0.05);assert(not R.pending and #calls==i)
  frame(0.11)
 end
 for i=1,5 do frame(0.4)end
 assert(not R.batch and not R.refreshJob and #calls==2 and #R.character.history==2)
 assert(R.performance.snapshot.calls==2 and not R.dirty)
end)
test('UI error or protected-action block stops batch dispatch without bypass or retry',function()
 for _,event in ipairs({'UI_ERROR_MESSAGE','ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN'})do
  local R=fresh(2);R:Start('ability');Fire(event,event=='UI_ERROR_MESSAGE' and 'Not ready' or 'GrimfallReroll')
  assert(R.batch.stopped and not R.running and #calls==1)
  ack(R);finish(R);assert(#calls==1 and #R.character.history==1)
 end
end)
test('batch initial scan still rejects locked selections and insufficient scroll budgets',function()
 local R=fresh(2);R:Lock('A:101');scrollCounts[640]=0;R:Start('ability');assert(#calls==0 and not R.batch)
 scrollCounts[640]=1;R:Start('ability');assert(#calls==1 and calls[1][2]==102)
end)
test('batch handles same-spell results only with result plus scroll and final full evidence',function()
 local R=fresh(1);R:Start('ability');ack(R,101);finish(R)
 assert(#R.character.history==1 and R.character.history[1].oldID==101 and R.character.history[1].newID==101 and #calls==1)
end)
test('batch final success emits each chat result once with no replay on refresh',function()
 local R=fresh(2);R.Notify=RealNotifyForTests;local chat=DEFAULT_CHAT_FRAME;local out={}
 DEFAULT_CHAT_FRAME={AddMessage=function(_,s)out[#out+1]=s end}
 local ok,why=pcall(function()
  R:Start('ability');ack(R);assert(#out==0);tick(R);ack(R);finish(R)
  assert(#out==3 and out[1]:find('Spell 101',1,true) and out[2]:find('Spell 102',1,true) and out[3]:find('Finished',1,true))
  R:Refresh();R:Render();assert(#out==3)
 end)
 DEFAULT_CHAT_FRAME=chat;assert(ok,why)
end)
test('final read failure is bounded and leaves original protections untouched',function()
 local R=fresh(1);R:Locks(R.spec)['A:1101']=true;R:Start('ability');ack(R)
 local read=R.Client.Snapshot;R.Client.Snapshot=function()return nil,'Unavailable'end
 local ok,why=pcall(function()tick(R);tick(R,21);assert(not R.batch and #calls==1 and #R.character.history==0 and R:Locks(R.spec)['A:1101'])end)
 R.Client.Snapshot=read;assert(ok,why)
end)
