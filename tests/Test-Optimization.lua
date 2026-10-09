-- No client input or real scroll consumption. All native APIs remain mocks.
local function advance(R,n)
 for i=1,n or 100 do
  if not R.refreshJob then return end
  clock=clock+0.016;R.Client:AdvanceSnapshot();R:PollRefresh()
 end
 assert(not R.refreshJob,'Read-only job did not complete within its bound')
end
test('warm snapshots cache display metadata but reread learned IDs and every live talent tree',function()
 local R=reset();local spell,tree,knownAPI=GetSpellInfo,GetClasslessTalentTreeData,GetKnownClasslessSpellIds
 local lookups,trees,reads=0,0,0
 GetSpellInfo=function(...)lookups=lookups+1;return spell(...)end
 GetClasslessTalentTreeData=function(...)trees=trees+1;return tree(...)end
 GetKnownClasslessSpellIds=function(...)reads=reads+1;return knownAPI(...)end
 R.Client:InvalidateMetadata();assert(R.Client:Snapshot());local cold=lookups
 assert(R.Client:Snapshot());local warm=lookups-cold
 GetSpellInfo,GetClasslessTalentTreeData,GetKnownClasslessSpellIds=spell,tree,knownAPI
 assert(cold==3 and warm==0 and trees==20 and reads==2)
 assert(#calls==0 and scrollCounts[640]==10 and scrollCounts[639]==10)
end)
test('live talent ranks are never cached or inferred from spell-display cache',function()
 local R=reset();local first=R.Client:Snapshot();talents[201]={class=1,spell=302,rank=2}
 local second=R.Client:Snapshot();assert(first.byKey['T:201'].rank==1 and second.byKey['T:201'].rank==2 and second.byKey['T:201'].spellID==302)
 assert(#calls==0)
end)
test('missing spell responses are retried rather than negatively cached',function()
 local R=reset();local original=GetSpellInfo;local missing=true
 GetSpellInfo=function(id)if id==101 and missing then return nil end;return original(id)end
 local a=R.Client:Snapshot();assert(not a)
 missing=false;local b=R.Client:Snapshot();GetSpellInfo=original
 assert(b and b.byKey['A:101'] and #calls==0)
end)
test('API replacement and build events invalidate display metadata',function()
 local R=reset();local original=GetSpellInfo
 GetSpellInfo=function(id)return 'Changed '..id,'','IconNew'end
 local changed=R.Client:Snapshot();assert(changed.byKey['A:101'].name=='Changed 101')
 local epoch=R.Client.metadataEpoch;Fire('SPELLS_CHANGED');assert(R.Client.metadataEpoch>epoch and next(R.Client.spellCache)==nil)
 GetSpellInfo=original;assert(R.Client:Snapshot().byKey['A:101'].name=='Spell 101')
end)
test('display cache is bounded and ephemeral, never stored in character preferences',function()
 local R=reset();local db=R.db;local history=R.character.history
 for i=1,4100 do R.Client:SpellMetadata(20000+i)end
 assert(R.Client.spellCacheSize<=4096 and not db.spellCache and not R.character.spellCache)
 assert(R.db==db and R.character.history==history and #calls==0)
end)
test('read-only refresh publishes no partial rows and rejects selection and lock edits until complete',function()
 local R=reset();local oldRows=R.rows;R:RequestRefresh();local job=R.refreshJob
 assert(job and not job.done and R.rows==oldRows)
 R:Toggle('A:101');R:Lock('T:201');assert(not next(R.selected) and not R:Locks(R.spec)['T:201'])
 R.Client:AdvanceSnapshot();R:PollRefresh();assert(R.refreshJob and R.rows==oldRows and #calls==0)
 advance(R);assert(R.ready and R.rows~=oldRows and R.byKey['T:201'] and #calls==0)
end)
test('starting a roll cancels a partial display job and still makes full synchronous pre-request reads',function()
 local R=reset();R:Toggle('A:101');R:RequestRefresh();local job=R.refreshJob
 local original=R.Client.Snapshot;local scans=0
 R.Client.Snapshot=function(...)scans=scans+1;return original(...)end
 R:Start();R.Client.Snapshot=original
 assert(job.done and not job.snapshot and not R.refreshJob and scans==2 and #calls==1 and R.pending)
end)
test('result confirmation retains its complete synchronous read and exact-scroll requirement',function()
 local R=reset();R:Toggle('A:101');R:Start();R:Result('ability',103)
 local original=R.Client.Snapshot;local scans=0
 R.Client.Snapshot=function(...)scans=scans+1;return original(...)end
 R:Step(false);assert(scans==0 and R.done==0)
 replaceAbility(101,103);scrollCounts[640]=9;R:Step(false);R.Client.Snapshot=original
 assert(scans==1 and R.done==1 and not R.pending and #calls==1)
end)
test('spec changes and native build events invalidate an unfinished read-only snapshot',function()
 for _,mode in ipairs({'spec','event'})do
  local R=reset();R:RequestRefresh();local job=R.refreshJob;R.Client:AdvanceSnapshot()
  if mode=='spec'then spec=3 else Fire('PLAYER_TALENT_UPDATE')end
  R.Client:AdvanceSnapshot();R:PollRefresh()
  assert(job.done and not job.snapshot and not R.ready and #calls==0)
 end
end)
test('a missed ability-change event is caught by the read-only final learned-ID comparison',function()
 local R=reset();R:RequestRefresh();local job=R.refreshJob;R.Client:AdvanceSnapshot()
 known[#known+1]=999;advance(R)
 assert(job.done and not job.snapshot and not R.ready and #calls==0)
end)
test('Stop and hiding the window cancel a display scan without any game requests',function()
 local R=reset();R:RequestRefresh();local job=R.refreshJob;R:Stop('Stopped')
 assert(job.done and not job.snapshot and not R.Client.readJob and not R.refreshJob and #calls==0)
 R:RequestRefresh();job=R.refreshJob;R.window:Hide()
 assert(job.done and not R.refreshJob and #calls==0);R.window:Show()
end)
test('a read-only timeout or malformed tree stops the read without publishing partial data',function()
 local R=reset();R:RequestRefresh();local job=R.refreshJob;clock=31;R.Client:AdvanceSnapshot();R:PollRefresh()
 assert(job.done and not job.snapshot and not R.ready and #calls==0)
 R=reset();local original=GetClasslessTalentTreeData
 GetClasslessTalentTreeData=function()return {talents={}}end
 R:RequestRefresh();job=R.refreshJob;advance(R);GetClasslessTalentTreeData=original
 assert(not job.snapshot and not R.ready and #calls==0)
end)
test('confirmed snapshots consume covered dirty events without an extra full idle rescan',function()
 local R=reset();R.dirty=false;R:Toggle('A:101');R:Start()
 replaceAbility(101,103);scrollCounts[640]=9;Fire('SPELLS_CHANGED');R:Result('ability',103);R:Step(false)
 assert(R.done==1 and not R.dirty)
 clock=2;R:Step(false);assert(not R.running)
 local before=R.performance.snapshot.calls
 for i=1,10 do
  clock=clock+0.4;for _,f in ipairs(PreviewFrames)do if f.events.ADDON_LOADED and f:GetScript('OnUpdate')then f:GetScript('OnUpdate')(f,0.4)end end
 end
 assert(R.performance.snapshot.calls==before and not R.refreshJob and #calls==1)
end)
test('a build event raised after confirmation is not swallowed by dirty coalescing',function()
 local R=reset();R:Toggle('A:101');R:Start();replaceAbility(101,103);scrollCounts[640]=9
 R.Notify=function()Fire('PLAYER_TALENT_UPDATE')end;R:Result('ability',103);R:Step(false)
 assert(R.done==1 and R.dirty and #calls==1)
end)
test('unchanged status redraws do not reset visible row names icons or static artwork',function()
 local R=reset();R:Render();local row=R.window.panels.ability.rows[1]
 local icon,name,box=row.icon.SetTexture,row.name.SetText,row.box.SetTexture;local changes=0
 row.icon.SetTexture=function(...)changes=changes+1;return icon(...)end
 row.name.SetText=function(...)changes=changes+1;return name(...)end
 row.box.SetTexture=function(...)changes=changes+1;return box(...)end
 for i=1,20 do R:SetStatus('Count/status '..i)end
 row.icon.SetTexture,row.name.SetText,row.box.SetTexture=icon,name,box
 assert(changes==0 and #calls==0)
end)
test('performance reset and report are bounded read-only operations',function()
 local R=reset();local snapshot=R.snapshot;local locks=R:Locks(R.spec);local history=R.character.history
 R.Client:ResetPerformance();assert(not next(R.performance) and R.snapshot==snapshot and R:Locks(R.spec)==locks and R.character.history==history)
 local original=R.Client.Snapshot;R.Client.Snapshot=function()error('Report must not read build')end
 R.Client:PerformanceReport();R.Client.Snapshot=original;assert(#calls==0)
 R:RequestRefresh();local p=R.performance;R.Client:ResetPerformance();assert(R.performance==p);R:CancelRefresh()
end)
test('synthetic slow native-tree reads are profiled and bounded to individual refresh slices',function()
 local R=reset();local names={'debugprofilestop','GetClasslessSpecializationSkillLineIds','GetClasslessTalentTabIdForSkillLine','GetClasslessTalentTreeData','GetSpellInfo'}
 local saved={};for _,name in ipairs(names)do saved[name]=_G[name]end
 local cpu=0;debugprofilestop=function()return cpu end
 GetClasslessSpecializationSkillLineIds=function(class)cpu=cpu+0.5;return {{ID=class*100},{ID=class*100+1},{ID=class*100+2}}end
 GetClasslessTalentTabIdForSkillLine=function(class)cpu=cpu+0.5;return class end
 GetClasslessTalentTreeData=function(tab)cpu=cpu+18;return saved.GetClasslessTalentTreeData(tab)end
 GetSpellInfo=function(id)cpu=cpu+5;return saved.GetSpellInfo(id)end
 R.Client:InvalidateMetadata();R.performance={};local a=R.Client:Snapshot();local cold=R.performance.snapshot.maxMS
 assert(a and R.performance.api_talent_tree.calls==30 and R.performance.api_talent_tree.maxMS==18)
 R.performance={};assert(R.Client:Snapshot());local warm=R.performance.snapshot.maxMS
 assert(warm<cold and not R.performance.api_spell_info,'Warm metadata should remove display lookups, not tree reads')
 R.performance={};R:RequestRefresh();advance(R);local p=R.performance
 assert(p.snapshot_slice.calls>20 and p.snapshot_slice.maxMS<=22 and p.snapshot_slice.maxMS<cold/10)
 assert(p.snapshot.totalMS==warm and p.slowestTree.ms==18 and #calls==0)
 OPTIMIZATION_BENCHMARK={coldSnapshotMS=cold,warmSnapshotMS=warm,readOnlyMaxSliceMS=p.snapshot_slice.maxMS,nativeTreeMS=p.api_talent_tree.maxMS,
  treeReads=p.api_talent_tree.calls,refreshSlices=p.snapshot_slice.calls,live_game_tested=false}
 for _,name in ipairs(names)do _G[name]=saved[name]end
end)
test('synchronous refresh fallback restores ordinary view reads without consuming scrolls or changing protections',function()
 local R=reset();R:Lock('T:201');local locks=R:Locks(R.spec);local db=R.db
 R:SetSmoothReads(false);local result=R:RequestRefresh()
 assert(result and result.byKey and not R.refreshJob and R.ready and R:Locks(R.spec)==locks and locks['T:201'])
 assert(R.db==db and not db.smoothReads and #calls==0)
 R:SetSmoothReads(true);R:RequestRefresh();assert(R.refreshJob);R:CancelRefresh()
end)
test('a native build event during a synchronous validation rejects the snapshot and sends no request',function()
 local R=reset();R:Toggle('A:101');local original=GetClasslessTalentTreeData;local once=true
 GetClasslessTalentTreeData=function(tab)if once then once=false;Fire('SPELLS_CHANGED')end;return original(tab)end
 R:Start();GetClasslessTalentTreeData=original
 assert(not R.running and not R.pending and #calls==0 and not R.ready)
end)
test('manual synchronous fallback is refused while observing an outstanding reroll',function()
 local R=reset();R:Toggle('A:101');R:Start();local pending=R.pending
 SlashCmdList.GRIMFALLREROLL('refresh sync')
 assert(R.pending==pending and #calls==1 and not R.refreshJob)
end)
test('unchanged recent-result redraws reuse successful spell metadata instead of calling the native lookup again',function()
 local R=reset();local original=GetSpellInfo;local lookups=0
 GetSpellInfo=function(...)lookups=lookups+1;return original(...)end
 R.character.history={{at=1,kind='ability',oldID=101,newID=103,oldName='Old',newName='New'}}
 R:Render();local warmed=lookups
 for i=1,20 do R:SetStatus('Recent result status '..i)end
 GetSpellInfo=original;assert(warmed>0 and lookups==warmed and #calls==0)
end)
