-- Chat-only result notifications. No game connection or real scrolls.
local function record(i,kind)
 return {oldID=101,newID=102,oldName='Old '..i,newName='New '..i,spent=1,kind=kind or 'ability'}
end
local function captureChat(fn)
 local original=DEFAULT_CHAT_FRAME; local messages={}
 DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
 local ok,err=pcall(fn,messages); DEFAULT_CHAT_FRAME=original
 assert(ok,err); return messages
end
local function noOverlay(R)
 assert(not R.notice and not R.noticeQueue and not R.announcementUntil and not R.announcementRecord)
 assert(not R.CreateNotice and not R.UpdateNotice and not R.QueueNotice and not R.ShowNextNotice and not R.AnchorNotice)
end

test('confirmed result keeps one chat message with both names, icons and scroll cost',function()
 local R=reset(); local r=record(1)
 local messages=captureChat(function() RealNotifyForTests(R,r) end)
 assert(#messages==1 and messages[1]:find('RE: Roller by Vash:',1,true))
 assert(messages[1]:find('Old 1',1,true) and messages[1]:find('New 1',1,true) and messages[1]:find('1 scroll used',1,true))
 local _,icons=messages[1]:gsub('|T',''); assert(icons==2 and #calls==0); noOverlay(R)
end)
test('ability and talent results both use chat without any floating frame',function()
 local R=reset()
 local messages=captureChat(function()
  RealNotifyForTests(R,record(1,'ability')); RealNotifyForTests(R,record(2,'talent'))
 end)
 assert(#messages==2 and messages[1]:find('New 1',1,true) and messages[2]:find('New 2',1,true))
 for _,frame in ipairs(PreviewFrames) do assert(frame.strata~='FULLSCREEN_DIALOG') end
 noOverlay(R)
end)
test('rapid confirmations deliver chat immediately in order without an animation queue',function()
 local R=reset(); local frames=#PreviewFrames
 local messages=captureChat(function()
  for i=1,100 do RealNotifyForTests(R,record(i,i%2==0 and 'talent' or 'ability'),true) end
 end)
 assert(#messages==100 and #PreviewFrames==frames and #calls==0)
 for i=1,100 do assert(messages[i]:find('Old '..i..'  ->  ',1,true)) end
 noOverlay(R)
end)
test('deferred notification does no render or full build scan',function()
 local R=reset(); local render,snapshot=R.Render,R.Client.Snapshot; local draws,scans=0,0
 R.Render=function() draws=draws+1 end; R.Client.Snapshot=function() scans=scans+1 end
 local ok,err=pcall(RealNotifyForTests,R,record(1),true)
 R.Render,R.Client.Snapshot=render,snapshot
 assert(ok,err); assert(draws==0 and scans==0); noOverlay(R)
end)
test('nondeferred notification performs only the normal static-history render',function()
 local R=reset(); local r=record(1); R.character.history={r}
 local render=R.Render; local draws=0
 R.Render=function(...) draws=draws+1; return render(...) end
 local ok,err=pcall(RealNotifyForTests,R,r); R.Render=render
 assert(ok,err); assert(draws==1 and R.window.historyRows[1].record==r)
 assert(not R.window.historyRows[1].stripe:IsShown()); noOverlay(R)
end)
test('notification has no fade ticks or six-second expiration redraw',function()
 local R=reset(); RealNotifyForTests(R,record(1),true)
 local render=R.Render; local draws=0; local frames=#PreviewFrames
 R.Render=function(...) draws=draws+1; return render(...) end
 for i=1,20 do clock=i; R.window.scripts.OnUpdate() end
 R.Render=render
 assert(draws==0 and #PreviewFrames==frames and #calls==0); noOverlay(R)
end)
test('long result names remain complete in chat without measuring an overlay',function()
 local R=reset(); local r=record(1); r.oldName=string.rep('Long old name ',40);r.newName=string.rep('Long new name ',40)
 local frames=#PreviewFrames
 local messages=captureChat(function() RealNotifyForTests(R,r,true) end)
 assert(#messages==1 and messages[1]:find(r.oldName,1,true) and messages[1]:find(r.newName,1,true))
 assert(#PreviewFrames==frames); noOverlay(R)
end)
test('refresh, resizing and history toggles do not replay chat notifications',function()
 local R=reset()
 local messages=captureChat(function()
  RealNotifyForTests(R,record(1)); R:Refresh();R:ToggleHistory('ability');R:ToggleHistory('talent')
  R.window:SetSize(980,760);R.window.scripts.OnSizeChanged();R.window.scripts.OnEvent();R:Render()
 end)
 assert(#messages==1 and #calls==0); noOverlay(R)
end)
test('closing and reopening preserves static history without replaying chat',function()
 local R=reset();local r=record(1);R.character.history={r}
 local messages=captureChat(function()
  RealNotifyForTests(R,r);R.window:Hide();R.window:Show();R:Render()
 end)
 assert(#messages==1 and #R.character.history==1 and R.window.historyRows[1].record==r and #calls==0);noOverlay(R)
end)
test('late hidden results still reach chat and history without reopening the planner',function()
 local R=reset();R.window:Hide();local r=record(1);R.character.history={r}
 local messages=captureChat(function() RealNotifyForTests(R,r) end)
 assert(#messages==1 and #R.character.history==1 and not R.window:IsShown() and #calls==0);noOverlay(R)
end)
test('chat delivery leaves locks, selection, pending requests and scrolls unchanged',function()
 local R=reset();R.db.fast=false;R:Lock('A:101');R:Toggle('A:102')
 local pending={key='A:102'};local queue={{key='T:201'}};local history=R.character.history;local selected=R.selected
 R.pending=pending;R.queue=queue;R.running=true
 RealNotifyForTests(R,record(1),true)
 assert(R.pending==pending and R.queue==queue and R.running and R.selected==selected and selected['A:102'])
 assert(R:Locks(R.spec)['A:101'] and R.character.history==history and #history==0 and #calls==0)
 assert(scrollCounts[640]==10 and scrollCounts[639]==10 and not R.db.fast);noOverlay(R)
end)
test('actual confirmations notify exactly once; starting or duplicate events cannot announce unconfirmed rolls',function()
 local R=reset();R.Notify=RealNotifyForTests
 local messages=captureChat(function(messages)
  R:Toggle('A:101');R:Toggle('A:102');R:Start('ability')
  assert(#calls==1 and R.pending and #messages==0)
  R:Result('ability',103);R:Step(false);assert(#messages==0)
  replaceAbility(101,103);scrollCounts[640]=9;R:Step(false)
  assert(#messages==1 and #R.character.history==1 and #calls==1)
  R:Result('ability',103);R:Step(false);assert(#messages==1)
  clock=1;R:Step(false);assert(#calls==2 and R.pending)
  replaceAbility(102,104);scrollCounts[640]=8;R:Result('ability',104);R:Step(false)
  assert(#R.character.history==2 and #messages==2 and #calls==2)
 end)
 assert(messages[1]:find('Spell 101',1,true) and messages[2]:find('Spell 102',1,true));noOverlay(R)
end)
