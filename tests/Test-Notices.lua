-- Presentation tests only. No game connection and no real scrolls are used.
local function record(i,kind)
 return {oldID=101,newID=102,oldName='Old '..i,newName='New '..i,spent=1,kind=kind or 'ability'}
end
local function expire(R)
 local n=R.notice; clock=n.started+n.hold+n.fade+0.01; n.scripts.OnUpdate()
end
test('notice uses built-in typography, centered icons and click-through foreground layering',function()
 local R=reset(); local r=record(1); RealNotifyForTests(R,r); local n=R.notice
 assert(n.parent==R.window and n.strata=='FULLSCREEN_DIALOG' and n.clamped and n.mouseEnabled==false)
 assert(n.text.fontObject.fontSize==22 and n.text.fontObject.fontPath==R.window.title.fontObject.fontPath)
 assert(n.text.fontObject.fontPath=='Fonts\\FRIZQT__.TTF' and n.text.justifyH=='CENTER')
 local _,icons=n.text:GetText():gsub('|T',''); assert(icons==2 and n.text:GetText():find('Old 1',1,true) and n.text:GetText():find('New 1',1,true))
 assert(n.point[1]=='BOTTOM' and n.point[2]==R.window and n.point[3]=='TOP' and n.point[5]>R.Skin.top and #calls==0)
end)
test('floating notice contains only result text with inline icons, outline and shadow, with no box or border',function()
 local R=reset();RealNotifyForTests(R,record(1));local n=R.notice
 assert(not rawget(n,'backdrop') and not rawget(n,'backdropColor') and not rawget(n,'borderColor'))
 assert(not n.title and not n.rule and n.text.fontObject.fontFlags=='OUTLINE')
 assert(n.text.shadowColor[4]==1 and n.text.shadowOffset[1]==1 and n.text.shadowOffset[2]==-1)
 local children=0
 for _,f in ipairs(PreviewFrames) do if f.parent==n then children=children+1;assert(f==n.text and f.kind=='FontString') end end
 assert(children==1 and #calls==0)
end)
test('rapid results are presented in confirmation order without replacing the active notice',function()
 local R=reset(); local records={}
 for i=1,10 do records[i]=record(i,i%2==0 and 'talent' or 'ability'); RealNotifyForTests(R,records[i]) end
 local n=R.notice
 assert(n.record==records[1] and #R.noticeQueue==9)
 for i=1,10 do
  assert(n.record==records[i] and n:IsShown() and n:GetAlpha()==1)
  assert(n.text:GetText():find(i%2==0 and '|cffbc9cf2' or '|cffffd27c',1,true))
  expire(R); assert(R.notice==n)
 end
 assert(not n:IsShown() and not n.record and #R.noticeQueue==0 and #calls==0)
end)
test('notice holds for reading, fades, and resets opacity for the next result',function()
 local R=reset(); RealNotifyForTests(R,record(1)); RealNotifyForTests(R,record(2)); local n=R.notice
 clock=n.started+n.hold-0.01; n.scripts.OnUpdate(); assert(n:GetAlpha()==1)
 clock=n.started+n.hold+n.fade/2; n.scripts.OnUpdate(); assert(math.abs(n:GetAlpha()-0.5)<0.001)
 expire(R); assert(n.record.oldName=='Old 2' and n:GetAlpha()==1)
end)
test('long notice names wrap inside measured bounds and reflow when the planner is resized',function()
 local R=reset(); local w=R.window; w:SetSize(840,620); w.scripts.OnSizeChanged()
 local r=record(1); r.oldName=string.rep('Long ability name ',12); r.newName=string.rep('Long replacement name ',12)
 RealNotifyForTests(R,r); local n=R.notice; local narrowHeight=n:GetHeight(); local started=n.started
 assert(n.text.wordWrap and n.text:GetStringHeight()<=n.text:GetHeight() and n:GetHeight()==n.text:GetHeight()+16)
 assert(n.text:GetWidth()==n:GetWidth()-32 and n:GetWidth()<=w:GetWidth()-32)
 assert(n:GetWidth()*w:GetScale()<=UIParent:GetWidth()-32)
 w:SetSize(1300,950); w.scripts.OnSizeChanged()
 assert(n:GetHeight()<=narrowHeight and n.record==r and n.started==started and #R.noticeQueue==0)
 assert(n.text:GetText():find(r.oldName,1,true) and n.text:GetText():find(r.newName,1,true))
end)
test('screen changes remeasure the notice without replaying it',function()
 local R=reset(); local oldWidth,oldHeight=UIParent:GetWidth(),UIParent:GetHeight()
 RealNotifyForTests(R,record(1)); local n=R.notice; local started=n.started
 UIParent:SetSize(800,600); R.window.scripts.OnEvent()
 assert(n.clamped and n:GetWidth()*R.window:GetScale()<=UIParent:GetWidth()-32)
 assert(n.started==started and #R.noticeQueue==0)
 UIParent:SetSize(oldWidth,oldHeight); R.window.scripts.OnEvent()
end)
test('refresh and history toggles neither duplicate nor restart an active notice',function()
 local R=reset(); RealNotifyForTests(R,record(1)); local n=R.notice; local started=n.started
 clock=1; R:Render(); R:Refresh(); R:ToggleHistory('ability'); R:ToggleHistory('talent'); R:AnchorNotice()
 assert(R.notice==n and n.record.oldName=='Old 1' and n.started==started and #R.noticeQueue==0 and #calls==0)
 expire(R); R:Render(); R:Refresh(); assert(not n:IsShown())
end)
test('closing the planner clears pending notices and reopening does not replay them',function()
 local R=reset(); RealNotifyForTests(R,record(1)); RealNotifyForTests(R,record(2)); local n=R.notice
 R.window:Hide(); assert(not n:IsShown() and not n.record and #R.noticeQueue==0)
 R.window:Show(); R:Render(); assert(not n:IsShown() and #R.noticeQueue==0 and #calls==0)
end)
test('late hidden results remain in chat/history without showing a notice',function()
 local R=reset(); R.window:Hide(); local r=record(1); R.character.history={r}
 local oldChat=DEFAULT_CHAT_FRAME; local messages={}
 DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
 RealNotifyForTests(R,r); DEFAULT_CHAT_FRAME=oldChat
 assert(#messages==1 and messages[1]:find('New 1',1,true) and #R.character.history==1)
 assert(not R.window:IsShown() and not R.notice:IsShown() and #R.noticeQueue==0 and #calls==0)
end)
test('notices work with Quick Animation off and reuse the same frame across batches',function()
 local R=reset(); R.db.fast=false; RealNotifyForTests(R,record(1)); local n=R.notice; expire(R)
 local count=#PreviewFrames; RealNotifyForTests(R,record(2,'talent'))
 assert(R.notice==n and #PreviewFrames==count and n:IsShown())
 assert(n.text:GetText():find('|cffbc9cf2',1,true) and R.db.fast==false and #calls==0)
end)
test('notice timers cannot spend scrolls, change reroll state, locks, selection or saved history',function()
 local R=reset(); R:Lock('A:101'); R:Toggle('A:102'); RealNotifyForTests(R,record(1))
 local pending={key='A:102'}; local queue={{key='T:201'}}; local history=R.character.history
 R.pending=pending; R.queue=queue; R.running=true; local selected=R.selected
 expire(R)
 assert(R.pending==pending and R.queue==queue and R.running and R.selected==selected and selected['A:102'])
 assert(R:Locks(R.spec)['A:101'] and R.character.history==history and #history==0 and #calls==0)
 assert(scrollCounts[640]==10 and scrollCounts[639]==10)
end)
test('actual confirmations enqueue notices but starting a reroll does not announce an unconfirmed result',function()
 local R=reset(); R.Notify=RealNotifyForTests; R:Toggle('A:101'); R:Toggle('A:102'); R:Start('ability')
 assert(#calls==1 and R.pending and not R.notice:IsShown())
 replaceAbility(101,103); scrollCounts[640]=9; R:Result('ability',103); R:Step(false)
 assert(R.notice:IsShown() and R.notice.record==R.character.history[1] and #R.character.history==1)
 assert(R.notice.record.oldID==101 and R.notice.record.newID==103 and #calls==1)
 clock=1; R:Step(false); assert(#calls==2 and R.pending and R.notice.record.oldID==101)
 replaceAbility(102,104); scrollCounts[640]=8; R:Result('ability',104); R:Step(false)
 assert(#R.character.history==2 and R.notice.record.oldID==101 and #R.noticeQueue==1)
 expire(R); assert(R.notice.record.oldID==102 and R.notice.record.newID==104 and #calls==2)
end)
