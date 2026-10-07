function RunPerformanceTests()
 local R=GrimfallReroll
 test('result events without a spent scroll do not repeatedly scan talent trees',function()
  R=reset();R:Toggle('A:101');R:Start();R:Result('ability',103)
  local original=R.Client.Snapshot;local scans=0
  R.Client.Snapshot=function(...) scans=scans+1;return original(...) end
  for i=1,20 do clock=i*0.3;R:Step(false) end
  R.Client.Snapshot=original
  assert(scans==0,'Full snapshots while waiting for scroll: '..scans)
  replaceAbility(101,103);scrollCounts[640]=9;R:Step(false);assert(R.done==1)
 end)
 test('waiting for native presentation does not rescan or redraw unchanged state',function()
  R=reset();R:Toggle('A:101');R:Toggle('A:102');R:Start()
  replaceAbility(101,103);scrollCounts[640]=9;R:Result('ability',103);R:Step(false)
  RandomMode_RollFrame=CreateFrame('Frame')
  local original=R.Client.Snapshot;local render=R.Render;local scans,draws=0,0
  R.Client.Snapshot=function(...) scans=scans+1;return original(...) end
  R.Render=function(...) draws=draws+1;return render(...) end
  for i=1,20 do clock=i*0.4;R:Step(false) end
  R.Client.Snapshot=original;R.Render=render
  assert(scans==0 and draws<=1,'waiting work: snapshots='..scans..' redraws='..draws)
  RandomMode_RollFrame:Hide();clock=9;R:Step(false);assert(#calls==2)
 end)
 test('bag and unrelated UI error bursts do not trigger full idle build snapshots',function()
  R=reset();R.dirty=false;R.uiDirty=false
  local original=R.Client.Snapshot;local scans=0
  R.Client.Snapshot=function(...) scans=scans+1;return original(...) end
  for i=1,20 do
   Fire('BAG_UPDATE',0);Fire('UI_ERROR_MESSAGE','Spell is not ready yet')
   clock=clock+0.4
   for _,f in ipairs(PreviewFrames) do if f.events.ADDON_LOADED and f:GetScript('OnUpdate') then f:GetScript('OnUpdate')(f,0.4) end end
  end
  R.Client.Snapshot=original
  assert(scans==0,'Idle build snapshots for inventory/errors: '..scans)
 end)
 test('unrelated status redraws reuse unchanged history rows',function()
  R=reset();R.db.historyPanels={ability=true,talent=true};R:LayoutHistory()
  R.character.history={{at=1,kind='ability',oldID=101,newID=102,oldName='Old',newName='New'}};R:Render()
  local row=R.window.historyDrawers.ability.rows[1];local original=row.oldIcon.SetTexture;local changes=0
  row.oldIcon.SetTexture=function(...) changes=changes+1;return original(...) end
  for i=1,20 do R:SetStatus('Status '..i) end
  row.oldIcon.SetTexture=original;assert(changes==0,'History texture resets='..changes)
 end)
 test('stale post-result build retries are bounded and still confirm fresh state',function()
  R=reset();R:Toggle('A:101');R:Start();R:Result('ability',103);scrollCounts[640]=9
  local original=R.Client.Snapshot;local scans=0
  R.Client.Snapshot=function(...) scans=scans+1;return original(...) end
  for i=1,9 do clock=i/10;R:Step(false) end
  R.Client.Snapshot=original;assert(scans==1 and R.done==0 and #calls==1)
  replaceAbility(101,103);clock=1.2;R:Step(false);assert(R.done==1 and #calls==1)
 end)
 test('build change during animation wait still prevents sending next request',function()
  R=reset();R:Toggle('A:101');R:Toggle('A:102');R:Start()
  replaceAbility(101,103);scrollCounts[640]=9;R:Result('ability',103);R:Step(false)
  RandomMode_RollFrame=CreateFrame('Frame');clock=1;R:Step(false)
  known[#known+1]=999;RandomMode_RollFrame:Hide();clock=2;R:Step(false)
  assert(not R.running and #calls==1 and R.status:find('Build changed'))
 end)
 test('performance report is read-only and does not rescan or send requests',function()
  R=reset();local before=R.performance.snapshot.calls;R.Client:PerformanceReport()
  assert(R.performance.snapshot.calls==before and #calls==0 and R.db.lastPerformanceReport:find('Frame gaps'))
 end)
end
