-- Same-action startup reuse, scan-status ownership, and non-destructive commands.
-- All native APIs and requests are mocks; no real game state is touched.
local function fresh()
 local R=reset();R.smoothReads=true;R.performance={};return R
end
local function override(object,key,value,body)
 local old=object[key];object[key]=value
 local ok,err=pcall(body);object[key]=old
 if not ok then error(err,0)end
end
local function finishRead(R)
 for i=1,100 do
  if not R.refreshJob then return end
  clock=clock+0.016;R.Client:AdvanceSnapshot();R:PollRefresh()
 end
 error('Display read did not finish')
end
local function duringStartup(R,change,body)
 local safe=R.Client.Safe;local once=true
 override(R.Client,'Safe',function(...)
  if once then once=false;change()end
  return safe(...)
 end,body)
end

test('queue startup performs one fresh full read, not the cached display read or two validations',function()
 local R=fresh();local display=R.snapshot;R:Toggle('A:101')
 R:Start()
 assert(R.pending and R.pending.before~=display and #calls==1)
 assert(R.performance.snapshot.calls==1 and R.performance.api_known_abilities.calls==1)
 assert(R.performance.api_talent_tree.calls==10 and R.performance.startupReadsReused==1)
end)

test('four confirmed ability rolls keep every result and later pre-request read',function()
 local R=fresh();known={101,102,103,104};R:Refresh();R.performance={}
 for _,id in ipairs(known)do R:Toggle('A:'..id)end
 R:Start('ability')
 for i=1,4 do
  local p=R.pending;assert(p and #calls==i)
  local new=200+i;replaceAbility(p.target.id,new);scrollCounts[640]=10-i
  R:Result('ability',new);R:Step(false);assert(R.done==i and not R.pending)
  clock=clock+1;R:Step(false)
 end
 assert(not R.running and #R.character.history==4 and #calls==4)
 assert(R.performance.snapshot.calls==8 and R.performance.api_known_abilities.calls==8)
 assert(R.performance.startupReadsReused==1 and scrollCounts[640]==6 and scrollCounts[639]==10)
end)

test('synthetic 260 ms learned-ID cost is paid once at startup, not twice',function()
 local R=fresh();R:Toggle('A:101');local cpu=0;local read=GetKnownClasslessSpellIds
 override(_G,'debugprofilestop',function()return cpu end,function()
  override(_G,'GetKnownClasslessSpellIds',function()cpu=cpu+260;return read()end,function()
   R:Start()
  end)
 end)
 assert(cpu==260 and R.performance.api_known_abilities.calls==1 and #calls==1)
end)

test('startup build-epoch invalidation rereads the complete build and rejects changed ownership',function()
 local R=fresh();R:Toggle('A:101')
 duringStartup(R,function()replaceAbility(101,999);R:BuildChanged(true)end,function()R:Start()end)
 assert(R.performance.snapshot.calls==2 and not R.performance.startupReadsReused)
 assert(not R.running and not R.pending and #calls==0 and R.status:find('Build changed'))
end)

test('startup epoch change without a build change still requires a fresh validation',function()
 local R=fresh();R:Toggle('A:101')
 duringStartup(R,function()R:BuildChanged(true)end,function()R:Start()end)
 assert(R.performance.snapshot.calls==2 and not R.performance.startupReadsReused)
 assert(R.pending and #calls==1)
end)

test('startup spec change without an event cannot reuse the old spec snapshot',function()
 local R=fresh();R:Toggle('A:101')
 duringStartup(R,function()spec=2 end,function()R:Start()end)
 assert(R.performance.snapshot.calls==2 and not R.performance.startupReadsReused)
 assert(not R.running and not R.pending and #calls==0)
end)

test('startup still refuses combat and death before making a request',function()
 for _,reason in ipairs({'combat','death'})do
  local R=fresh();R:Toggle('A:101')
  duringStartup(R,function()if reason=='combat'then combat=true else dead=true end end,function()R:Start()end)
  assert(not R.running and not R.pending and #calls==0)
 end
end)

test('startup respects locks added after the snapshot but before its first request',function()
 local R=fresh();R:Toggle('A:101');R:Toggle('A:102');local safe=R.Client.Safe;local checks=0
 override(R.Client,'Safe',function(...)
  checks=checks+1;if checks==2 then R:Locks(R.spec)['A:101']=true end
  return safe(...)
 end,function()R:Start()end)
 assert(R:Locks(R.spec)['A:101'] and not R.running and not R.pending and #calls==0)
end)

test('startup still checks live scroll counts after its full snapshot',function()
 local R=fresh();R:Toggle('A:101');local safe=R.Client.Safe;local checks=0
 override(R.Client,'Safe',function(...)
  checks=checks+1;if checks==2 then scrollCounts[640]=0 end
  return safe(...)
 end,function()R:Start()end)
 assert(not R.running and not R.pending and #calls==0)
end)

test('an animation-delayed first roll discards startup reuse and rereads before resuming',function()
 local R=fresh();R:Toggle('A:101');RandomMode_RollFrame=CreateFrame('Frame')
 R:Start();assert(R.paused and R.running and #calls==0 and R.performance.snapshot.calls==1)
 known[#known+1]=999 -- deliberately omit the event: resumed validation must see it
 RandomMode_RollFrame:Hide();R:Pause();clock=1;R:Step(true)
 assert(R.performance.snapshot.calls==2 and not R.performance.startupReadsReused)
 assert(not R.running and not R.pending and #calls==0)
end)

test('a later reroll detects changed ownership even when no native build event arrives',function()
 local R=fresh();R:Toggle('A:101');R:Toggle('A:102');R:Start()
 replaceAbility(101,103);scrollCounts[640]=9;R:Result('ability',103);R:Step(false)
 known[#known+1]=999;clock=1;R:Step(false)
 assert(#calls==1 and R.done==1 and not R.running and R.performance.snapshot.calls==3)
end)

test('same-spec background completion clears Reading in both the model and visible status',function()
 local R=fresh();R:RequestRefresh();local job=R.refreshJob;finishRead(R)
 assert(job.done and job.snapshot and not R.refreshJob and R.ready)
 assert(R.status:find('Ready.',1,true) and R.window.status:GetText()==R.status and #calls==0)
end)

test('synchronous fallback clears a cancelled Reading label after successful refresh',function()
 local R=fresh();R:RequestRefresh();local job=R.refreshJob
 SlashCmdList.GRIMFALLREROLL('refresh sync')
 assert(job.done and not job.snapshot and not R.refreshJob and R.ready)
 assert(R.status:find('Ready.',1,true) and #calls==0)
end)

test('successful snapshots do not overwrite unrelated stop error or result messages',function()
 local R=fresh()
 for _,message in ipairs({'Stopped by /rr stop.','Client blocked the reroll action.','Finished: 4 confirmed rerolls.'})do
  R:SetStatus(message);R:Refresh();assert(R.status==message)
 end
 assert(#calls==0)
end)

test('failed background reads retain their failure reason instead of claiming Ready',function()
 local R=fresh()
 override(_G,'GetClasslessTalentTreeData',function()return {talents={}}end,function()
  R:RequestRefresh();finishRead(R)
 end)
 assert(not R.ready and R.status:find('incomplete') and #calls==0)
end)

test('pref typos print help without changing the window pending queue or selected entries',function()
 local R=fresh();R:Toggle('A:101');R:Toggle('A:102');R:Start()
 local pending,queue,selected,status=R.pending,R.queue,R.selected,R.status;local messages={}
 override(DEFAULT_CHAT_FRAME,'AddMessage',function(_,s)messages[#messages+1]=s end,function()
  SlashCmdList.GRIMFALLREROLL('pref');SlashCmdList.GRIMFALLREROLL('pref reset')
 end)
 assert(R.window:IsShown() and R.running and R.pending==pending and R.queue==queue and R.selected==selected and R.status==status)
 assert(#calls==1 and table.concat(messages,'\n'):find('/rr perf',1,true))
end)

test('help and unknown commands leave a closed window closed and start no display scan',function()
 local R=fresh();R.window:Hide();local status=R.status
 SlashCmdList.GRIMFALLREROLL('help');SlashCmdList.GRIMFALLREROLL('unknown')
 assert(not R.window:IsShown() and not R.refreshJob and R.status==status and #calls==0)
end)

test('perf commands accept case and whitespace without toggling the window',function()
 local R=fresh();local messages={}
 override(DEFAULT_CHAT_FRAME,'AddMessage',function(_,s)messages[#messages+1]=s end,function()
  SlashCmdList.GRIMFALLREROLL('  PeRf   ReSeT  ');assert(not next(R.performance))
  SlashCmdList.GRIMFALLREROLL('\t PERFORMANCE  ')
 end)
 assert(R.window:IsShown() and not R.refreshJob and #calls==0)
 local output=table.concat(messages,'\n')
 assert(output:find('counters reset',1,true) and output:find('Same-action startup reads reused: 0',1,true))
end)

test('only an empty rr command retains the original window toggle behavior',function()
 local R=fresh();assert(R.window:IsShown())
 SlashCmdList.GRIMFALLREROLL('  ');assert(not R.window:IsShown())
 SlashCmdList.GRIMFALLREROLL('');assert(R.window:IsShown() and R.refreshJob and #calls==0)
 R:CancelRefresh()
end)
