results={}; local failures=0
function test(name,fn)
 local ok,err=pcall(fn); results[#results+1]=(ok and 'PASS: ' or 'FAIL: ')..name..(ok and '' or ': '..tostring(err)); if not ok then failures=failures+1 end
end
function FinishTests() assert(failures==0,failures..' tests failed') end
clock=0; calls={}; known={101,102}; talents={}; scrollCounts={[640]=10,[639]=10}; spec=1
function GetTime() return clock end
function time() return 1800000000+clock end
function date(format,at) return '10/06 12:00' end
function UnitName() return 'Test' end
function GetRealmName() return 'Offline' end
function GetActiveSpecializationIndex() return spec end
function UnitAffectingCombat() return combat end
function InCombatLockdown() return combat end
function UnitIsDeadOrGhost() return dead end
function GetItemCount(id,bank) assert(bank==false); return scrollCounts[id] end
function GetKnownClasslessSpellIds() return known end
function GetSpellInfo(id) return 'Spell '..id,'','Interface\\Icons\\Spell_Holy_MagicalSentry' end
function GetItemInfo(id) return 'Scroll',nil,nil,nil,nil,nil,nil,nil,nil,'Interface\\Icons\\INV_Scroll_03' end
function GetClasslessSpecializationSkillLineIds(class) return {{ID=class*100,DisplayName='Spec'}} end
function GetClasslessTalentTabIdForSkillLine(class,skill) return class end
function GetClasslessTalentTreeData(tab)
 local list={}; for id,t in pairs(talents) do if t.class==tab then list[#list+1]={talentId=id,currentRank=t.rank or 1,currentSpellId=t.spell,spellRanks={t.spell}} end end
 if #list==0 then list[1]={talentId=1000+tab,currentRank=0} end
 return {talents=list}
end
function IsClasslessTalentConsideredAbility(id) return false end
function ClasslessCanRerollTalent(id) return talentAllowed~=false end
function ClasslessUnlearnSpell(id) calls[#calls+1]={'ability',id}; return requestAllowed~=false end
function ClasslessRerollTalent(id) calls[#calls+1]={'talent',id}; return requestAllowed~=false end
DEFAULT_CHAT_FRAME={AddMessage=function() end}
UIParent={}; UISpecialFrames={}; StaticPopupDialogs={}; SlashCmdList={}; YES='Yes'; CANCEL='Cancel'
local frames={}; PreviewFrames=frames; local methods={}
function methods:SetScript(k,fn) self.scripts[k]=fn end
function methods:GetScript(k) return self.scripts[k] end
function methods:HookScript(k,fn) local old=self.scripts[k]; self.scripts[k]=function(...) if old then old(...) end; fn(...) end end
function methods:RegisterEvent(k) self.events[k]=true end
function methods:Show() local change=not self.shown; self.shown=true; if change and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local change=self.shown; self.shown=false; if change and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width or 920 end
function methods:GetHeight() return self.height or 650 end
function methods:SetScale(v) self.scale=v end
function methods:GetScale() return self.scale or 1 end
function methods:SetVerticalScroll(v) self.verticalScroll=v end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:SetPoint(...)
 self.point={...}; self.points=self.points or {}
 for i,p in ipairs(self.points) do if p[1]==self.point[1] then self.points[i]=self.point; return end end
 self.points[#self.points+1]=self.point
end
function methods:ClearAllPoints() self.points={}; self.point=nil end
function methods:SetAllPoints(target) self:SetPoint('TOPLEFT',target or self.parent,'TOPLEFT',0,0); self:SetPoint('BOTTOMRIGHT',target or self.parent,'BOTTOMRIGHT',0,0) end
function methods:SetBackdrop(v) self.backdrop=v end
function methods:SetBackdropBorderColor(...) self.borderColor={...} end
function methods:SetTextColor(...) self.textColor={...} end
function methods:SetShadowColor(...) self.shadowColor={...} end
function methods:SetShadowOffset(...) self.shadowOffset={...} end
function methods:GetName() return self.name end
function methods:GetPoint() return unpack(self.point or {'CENTER',UIParent,'CENTER',0,0}) end
function methods:GetCenter() return 500,400 end
function methods:SetText(t) self.text=t end
function methods:SetFont(path,size,flags) self.fontPath=path; self.fontSize=size; self.fontFlags=flags;return true end
function methods:SetOwner(owner,anchor) self.owner=owner;self.anchor=anchor end
function methods:IsOwned(owner) return self.owner==owner end
function methods:ClearLines() self.text='';self.lines={};self.hyperlink=nil end
function methods:AddLine(text,...) self.lines=self.lines or {};self.lines[#self.lines+1]=text end
function methods:SetHyperlink(link) self.hyperlink=link;self.text=link end
function methods:SetFontObject(f) assert(f,'missing font'); self.fontObject=f end
function methods:SetNormalFontObject(f) self.normalFont=f end
function methods:SetHighlightFontObject(f) self.highlightFont=f end
function methods:SetDisabledFontObject(f) self.disabledFont=f end
function methods:SetJustifyH(v) self.justifyH=v end
function methods:SetJustifyV(v) self.justifyV=v end
function methods:SetWordWrap(v) self.wordWrap=v end
function methods:GetText() return self.text or '' end
function methods:GetStringHeight()
 local s=(self.text or ''):gsub('|T.-|t','[]'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
 local columns=math.max(1,math.floor(self:GetWidth()/7))
 return math.max(1,math.ceil(#s/columns))*18
end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:IsEnabled() return self.enabled~=false end
function methods:SetVertexColor(...) self.vertexColor={...} end
function methods:SetAlpha(a) self.alpha=a end
function methods:GetAlpha() return rawget(self,'alpha') or 1 end
function methods:SetFrameStrata(v) self.strata=v end
function methods:SetClampedToScreen(v) self.clamped=v end
function methods:EnableMouse(v) self.mouseEnabled=v end
function methods:SetBackdropColor(...) self.backdropColor={...} end
function methods:SetTexture(v) self.texture=v end
function methods:SetTexCoord(...) self.coords={...} end
function methods:CreateTexture(name,layer) local f=CreateFrame('Texture',name,self); f.layer=layer; return f end
function methods:CreateFontString(name,layer) local f=CreateFrame('FontString',name,self); f.layer=layer; return f end
function methods:GetHighlightTexture() return CreateFrame('Texture') end
function methods:GetCheckedTexture() self.checkedTexture=self.checkedTexture or CreateFrame('Texture'); return self.checkedTexture end
function methods:SetDuration(n) self.duration=n end
function methods:GetDuration() return rawget(self,'duration') or 3 end
function methods:SetStartDelay(n) self.startDelay=n end
function methods:GetStartDelay() return rawget(self,'startDelay') or 0 end
function methods:SetEndDelay(n) self.endDelay=n end
function methods:GetEndDelay() return rawget(self,'endDelay') or 0 end
setmetatable(methods,{__index=function(_,key) if key:match('^[A-Z]') then return function() end end end})
function CreateFrame(kind,name,parent,template)
 local f=setmetatable({scripts={},events={},shown=true,kind=kind,name=name,parent=parent,template=template},{__index=methods})
 frames[#frames+1]=f; f.uid=#frames; if name then _G[name]=f end; return f
end
UIParent=CreateFrame('Frame','UIParent'); GameTooltip=CreateFrame('GameTooltip')
function CreateFont(name) assert(name:match('^RERollerFont'),'must not replace global fonts'); return CreateFrame('Font',name) end
function StaticPopup_Show(name,txt,unused,data) popup={name=name,txt=txt,data=data} end
function hooksecurefunc(object,key,fn)
 if type(object)=='string' then fn=key; key=object; object=_G end
 local original=object[key]; assert(type(original)=='function','missing hook '..key)
 object[key]=function(...) local r=original(...); fn(...); return r end
end
function ClasslessRandomRoll_CreateFrame() end
function Fire(event,...)
 for _,f in ipairs(frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end
function reset()
 local R=GrimfallReroll
 clock=0; calls={}; known={101,102}; talents={[201]={class=1,spell=301}}; spec=1; combat=false; dead=false; requestAllowed=true; talentAllowed=true
 scrollCounts={[640]=10,[639]=10}; RandomMode_RollFrame=nil
 R.pending=nil; R.running=false; R.queue={}; R.selected={}; R.spec=nil; R.ready=false; R.expected=nil; R.status='Ready'; R.done=0; R.total=0; R.manual=nil
 R.rows={}; R.byKey={}; R.eventsReady=true; R.Client.fastState=nil
 R:InitializeDB({}); R:Refresh()
 if R.window then
  R.window:Show()
  for _,p in pairs(R.window.panels) do p.search:SetText('') end
  R:Render()
 end
 R.Notify=function(self,r) self.lastNotice=r end
 return R
end
function replaceAbility(old,new)
 for i,id in ipairs(known) do if id==old then known[i]=new end end
end
function RunTests()
 test('direct classless APIs list learned abilities and talents without GGA or opening classless panel',function()
  local R=reset(); assert(R.ready and #R.rows==3 and R.byKey['T:201'].spellID==301 and R.byKey['A:101'])
 end)
 test('separate bag-only scroll mapping',function()
  local R=reset(); scrollCounts[640]=7; scrollCounts[639]=2
  assert(R.Client:Count('ability')==7 and R.Client:Count('talent')==2 and #calls==0)
 end)
 test('left click selects; lock silently removes selection; unlock needs explicit action',function()
  local R=reset(); R:Toggle('A:101'); assert(R.selected['A:101'])
  R:Lock('A:101'); assert(not R.selected['A:101'] and R:Locks(R.spec)['A:101'])
  R:Toggle('A:101'); assert(not R.selected['A:101'])
  R:Unlock('A:101','wrong'); assert(R:Locks(R.spec)['A:101'])
  R:Unlock('A:101',R.spec); R:Toggle('A:101'); assert(R.selected['A:101'] and #calls==0)
 end)
 test('one queued entry consumes one confirmed scroll; replacement never requeued',function()
  local R=reset(); R:Toggle('A:101'); R:Start(); assert(#calls==1 and calls[1][2]==101 and R.pending)
  R:Step(false); assert(#calls==1)
  R:Result('ability',103); replaceAbility(101,103); R:Step(false); assert(R.pending and R.done==0)
  scrollCounts[640]=9; R:Step(false); assert(not R.pending and R.done==1 and R.lastNotice.newID==103)
  clock=1; R:Step(false); assert(not R.running and #calls==1 and not R.selected['A:103'])
 end)
 test('mixed queue uses spell ID for ability and TALENT ID for talent',function()
  local R=reset(); R:Toggle('A:101'); R:Toggle('T:201'); R:Start()
  replaceAbility(101,103); scrollCounts[640]=9; R:Result('ability',103); R:Step(false)
  clock=1; R:Step(false); assert(#calls==2 and calls[2][1]=='talent' and calls[2][2]==201)
  talents={[202]={class=1,spell=302}}; scrollCounts[639]=9; R:Result('talent',302); R:Step(false)
  assert(R.done==2 and #R.character.history==2 and not R.pending)
 end)
 test('stop after request records eventual result but never executes remaining queue',function()
  local R=reset(); R:Toggle('A:101'); R:Toggle('A:102'); R:Start(); R:Stop('Stopped')
  replaceAbility(101,103); scrollCounts[640]=9; R:Result('ability',103); R:Step(false)
  clock=2; R:Step(false); assert(#calls==1 and #R.character.history==1 and not R.running)
 end)
 test('pause waits for result and requires Resume before next request',function()
  local R=reset(); R:Toggle('A:101'); R:Toggle('A:102'); R:Start(); R:Pause()
  replaceAbility(101,103); scrollCounts[640]=9; R:Result('ability',103); R:Step(false)
  clock=2; R:Step(false); assert(#calls==1 and R.paused)
  R:Pause(); R:Step(false); assert(#calls==2)
 end)
 test('missing result, delayed learned state or missing scroll change cannot confirm',function()
  local R=reset(); R:Toggle('A:101'); R:Start(); replaceAbility(101,103); scrollCounts[640]=9
  R:Step(false); assert(R.pending and R.done==0)
  clock=21; R:Step(false); assert(not R.pending and not R.running and #calls==1)
 end)
 test('ambiguous/multiple results stop without retry',function()
  local R=reset(); R:Toggle('A:101'); R:Start(); R:Result('ability',103); R:Result('ability',104)
  assert(not R.running and R.pending.ambiguous); clock=21; R:Step(false); assert(#calls==1)
 end)
 test('unrelated build change prevents next queued action',function()
  local R=reset(); R:Toggle('A:101'); R:Toggle('A:102'); R:Start()
  replaceAbility(101,103); scrollCounts[640]=9; R:Result('ability',103); R:Step(false)
  known[#known+1]=999; clock=2; R:Step(false); assert(#calls==1 and not R.running)
 end)
 test('spec switch stops and isolates saved locks',function()
  local R=reset(); R:Lock('A:102'); R:Toggle('A:101'); R:Start(); spec=2; R:Step(false)
  assert(not R.running and R.pending.ambiguous)
  clock=21; R:Step(false); assert(not R:Locks(R.spec)['A:102'] and R:Locks('specialization:1')['A:102'])
 end)
 test('combat, death, insufficient scrolls and absent result events block startup',function()
  for _,mode in ipairs({'combat','dead','scroll','events'}) do
   local R=reset(); R:Toggle('A:101')
   if mode=='combat' then combat=true elseif mode=='dead' then dead=true elseif mode=='scroll' then scrollCounts[640]=0 else R.eventsReady=false end
   R:Start(); assert(#calls==0,mode)
  end
 end)
 test('request refusal is never automatically retried',function()
  local R=reset(); R:Toggle('A:101'); requestAllowed=false; R:Start()
  clock=21; R:Step(false); assert(#calls==1 and not R.running and not R.pending)
 end)
 test('unexpected scroll spending or other-scroll changes stop the run',function()
  for _,other in ipairs({false,true}) do
   local R=reset(); R:Toggle('A:101'); R:Start(); replaceAbility(101,103); R:Result('ability',103)
   scrollCounts[640]=other and 9 or 8; if other then scrollCounts[639]=9 end
   R:Step(false); assert(not R.running and R.pending.ambiguous and R.done==0)
  end
 end)
 test('partial talent API data fails closed instead of spending scrolls',function()
  local R=reset(); local original=GetClasslessTalentTreeData
  GetClasslessTalentTreeData=function(tab) if tab==11 then return nil end; return original(tab) end
  R:Refresh(); assert(not R.ready); R:Start(); assert(#calls==0)
  GetClasslessTalentTreeData=original
 end)
 test('same ability can legitimately roll again only with event plus scroll evidence',function()
  local R=reset(); R:Toggle('A:101'); R:Start(); R:Result('ability',101); scrollCounts[640]=9; R:Step(false)
  assert(R.done==1 and not R.pending and not R.selected['A:101'])
 end)
 test('existing native animation prevents concurrent reroll request',function()
  local R=reset(); RandomMode_RollFrame=CreateFrame('Frame'); R:Toggle('A:101'); R:Start()
  assert(R.paused and #calls==0 and not R.pending)
 end)
end
function RunUITests()
 local realNotify=GrimfallReroll.Notify
 RealNotifyForTests=realNotify
 test('real UI creates Blizzard-styled independent columns with no GGA/Vashworks dependency',function()
  local R=reset(); R.window=nil; R:CreateUI(); R.window:Show(); R:Render()
  assert(R.window.panels.ability and R.window.panels.talent and #R.window.panels.ability.rows==2 and #R.window.panels.talent.rows==1)
  assert(#calls==0 and not R.window.panels.ability.start.enabled)
  R:RowClick(R.byKey['A:101'],'LeftButton'); assert(R.window.panels.ability.start.enabled and R.selected['A:101'])
  R:RowClick(R.byKey['A:101'],'RightButton'); assert(not R.selected['A:101'] and R:Locks(R.spec)['A:101'])
  R:RowClick(R.byKey['A:101'],'RightButton'); assert(popup.name=='GRR_UNLOCK')
  StaticPopupDialogs.GRR_UNLOCK.OnAccept({},popup.data); assert(not R:Locks(R.spec)['A:101'] and #calls==0)
 end)
 test('RE:Roller branding, solid backgrounds and independent search boxes',function()
  local R=reset(); R.window:Show(); R:Render()
  assert(R.window.title:GetText()=='RE: Roller by Vash' and R.window.backdropColor[4]==1)
  for _,p in pairs(R.window.panels) do assert(p.search.template==nil and p.search.backdropColor[4]==1 and p.placeholder:IsShown()) end
 end)
 test('built-in headings and body keep body, metadata and button sizes consistent',function()
  local R=reset(); local w=R.window
  assert(w.title.fontObject.fontSize==30 and w.title.justifyH=='LEFT' and w.title.justifyV=='MIDDLE')
  assert(w.title.point[1]=='TOPRIGHT' and w.title.height==32)
  for _,p in pairs(w.panels) do
   assert(p.title.fontObject.fontSize==20 and p.title.height==p.count.height and p.title.point[3]==p.count.point[3])
   assert(p.search.fontObject.fontSize==14 and p.placeholder.fontObject.fontSize==12)
   assert(p.rows[1].name.fontObject.fontSize==14 and p.rows[1].name.wordWrap==false and p.rows[1].name.justifyV=='MIDDLE')
   assert(p.budget.fontObject.fontPath=='Fonts\\FRIZQT__.TTF' and p.budget.fontObject.fontSize==14)
   assert(p.cost.fontObject.fontSize==12 and p.cost.height==22 and p.start.height==32)
   assert(p.start.normalFont.fontSize==14 and p.start.disabledFont.fontSize==14 and p.start.highlightFont.fontSize==14)
  end
 end)
 test('three wrapped announcement rows measure their own height and preserve full names on hover',function()
  local R=reset(); local w=R.window
  assert(#w.historyRows==3 and w.historyPanel.height==100 and w.historyTitle:GetText()=='Recent Transformations')
  assert(w.historyRows[1].text:GetText()=='Your confirmed rerolls will appear here.')
  R.character.history={{oldName=string.rep('Long ',30),newName='Replacement',kind='talent'},{oldName='Second',newName='New',kind='ability'},{oldName='Third',newName='Last',kind='talent'}}
  R:Render()
  local used=0
  for i,row in ipairs(w.historyRows) do
   assert(row.height==row.text.height+10 and row.point[3]==0 and row.text.fontObject.fontSize==14)
   assert(row.text.wordWrap==true and row.record==R.character.history[i] and row.parent==w.announcementCanvas)
   used=math.max(used,row.height)
  end
  w.historyRows[1].scripts.OnEnter(w.historyRows[1]); assert(GameTooltip:GetText()==R.character.history[1].oldName)
  R.character.history={}; R:Render(); assert(w.historyRows[2].text:GetText()=='' and not w.historyRows[2].record and w.historyRows[2].kind:GetText()=='')
 end)
 test('layout remains two equal columns at minimum and maximum window sizes',function()
  local R=reset(); local w=R.window
  for _,size in ipairs({{840,680},{980,760},{1300,950}}) do
   w:SetSize(size[1],size[2]); w.scripts.OnSizeChanged()
   for _,p in pairs(w.panels) do
    assert(p.width==(size[1]-24)/2 and p.canvas.width==p.width-44)
    assert(p.point[3]==126 and p.canvas.width>=352)
   end
  end
  w:SetSize(940,680); w.scripts.OnSizeChanged(); assert(#calls==0)
 end)
 test('redesign uses distinct section accents, queued stripe and protected icon dimming',function()
  local R=reset(); local a,t=R.window.panels.ability,R.window.panels.talent
  assert(a.accent[1]~=t.accent[1] and a.badge.texture and R.window.emblem.texture)
  local row=a.rows[1]; assert(not row.stripe:IsShown())
  R:Toggle(row.entry.key); assert(row.stripe:IsShown() and row.shade.vertexColor[4]==0.05)
  R:Lock(row.entry.key); assert(not row.stripe:IsShown() and row.icon.vertexColor[1]==0.9 and row.lock:IsShown())
  R:Unlock(row.entry.key,R.spec); assert(row.icon.vertexColor[1]==1 and row.box:IsShown())
  scrollCounts[640]=0; R:Render(); assert(a.available:GetText()=='0 in bags' and not a.start.enabled and a.start.backdropColor[1]==0.08)
 end)
 test('locked rows show only a centered lock; unlocking restores the checkbox in the same slot',function()
  local R=reset(); R.window:Show(); R:Render(); local b=R.window.panels.ability.rows[1]
  R:Toggle(b.entry.key); assert(b.box:IsShown() and b.mark:IsShown() and not b.lock:IsShown())
  R:Lock(b.entry.key); assert(not b.box:IsShown() and not b.mark:IsShown() and b.lock:IsShown())
  assert(b.box.point[1]=='CENTER' and b.lock.point[1]=='CENTER' and b.box.point[2]==b.lock.point[2])
  R:Unlock(b.entry.key,R.spec); assert(b.box:IsShown() and not b.mark:IsShown() and not b.lock:IsShown())
 end)
 test('each column button queues only its own selections and uses only its own scroll budget',function()
  local R=reset(); R.window:Show(); scrollCounts[640]=0; R:Toggle('A:101'); R:Toggle('T:201'); R:Render()
  assert(not R.window.panels.ability.start.enabled and R.window.panels.talent.start.enabled)
  R.window.panels.talent.start.scripts.OnClick(); assert(#calls==1 and calls[1][1]=='talent' and R.selected['A:101'])
  R=reset(); scrollCounts[639]=0; R:Toggle('A:101'); R:Toggle('T:201'); R:Render()
  assert(R.window.panels.ability.start.enabled and not R.window.panels.talent.start.enabled)
  R.window.panels.ability.start.scripts.OnClick(); assert(#calls==1 and calls[1][1]=='ability' and R.selected['T:201'])
 end)
 test('confirmed result updates static in-planner history without an overlay or expiration redraw',function()
  local R=reset(); R.window:Show()
  local record={oldID=101,newID=102,oldName='Old',newName='New',spent=1,kind='ability'}
  R.character.history={record}; realNotify(R,record)
  assert(not R.notice and not R.noticeQueue and not R.announcementUntil)
  assert(not R.window.historyRows[1].stripe:IsShown() and R.window.historyRows[1].record==record)
  clock=7; R.window.scripts.OnUpdate()
  assert(not R.notice and not R.window.historyRows[1].stripe:IsShown() and R.window.historyRows[1]:IsShown() and #calls==0)
 end)
 test('rapid multiple results remain bounded to three measured rows and all stay in full history',function()
  local R=reset(); local w=R.window
  w:SetSize(840,680); w.scripts.OnSizeChanged()
  for i=1,10 do
   local record={oldName=string.rep('Long ability name ',12)..i,newName=string.rep('Long replacement name ',12)..i,oldID=101,newID=102,kind=i%2==0 and 'talent' or 'ability',spent=1}
   table.insert(R.character.history,1,record); realNotify(R,record)
  end
  assert(#R.character.history==10 and #w.historyRows==3 and not R.notice and not R.noticeQueue)
  assert(w.historyRows[1].record==R.character.history[1] and w.historyRows[3].record==R.character.history[3])
  local used=0
  for _,row in ipairs(w.historyRows) do
   assert(row.point[3]==0 and row.text:GetStringHeight()<=row.text.height)
   assert(math.abs((row.text.width+16)*3+18-w.announcementCanvas.width)<0.001)
   used=math.max(used,row.height)
  end
  assert(w.announcementCanvas.height==used and used>w.announcementScroll.height and w.historyPanel.height==100)
  assert(w.announcementCanvas.parent==w.announcementScroll and w.announcementScroll.parent==w.historyPanel)
  w.announcementScroll.scripts.OnMouseWheel(w.announcementScroll,-10000)
  assert(w.announcementScroll:GetVerticalScroll()==used-w.announcementScroll.height)
  w.historyRows[1].scripts.OnMouseWheel(w.historyRows[1],10000)
  assert(w.announcementScroll:GetVerticalScroll()==0 and #calls==0)
 end)
 test('resizing reflows announcements and clamps their scroll without changing saved results',function()
  local R=reset(); local w=R.window
  R.character.history={{oldName=string.rep('Old ',55),newName=string.rep('New ',55),kind='ability'}}
  w:SetSize(840,680); w.scripts.OnSizeChanged(); local narrow=w.historyRows[1].height
  w.announcementScroll.scripts.OnMouseWheel(w.announcementScroll,-1000)
  w:SetSize(1300,950); w.scripts.OnSizeChanged()
  assert(w.historyRows[1].height<narrow and #R.character.history==1)
  assert(w.announcementScroll:GetVerticalScroll()<=math.max(0,w.announcementCanvas.height-w.announcementScroll.height))
  R.character.history={}; R:Render(); assert(w.announcementScroll:GetVerticalScroll()==0 and not w.historyRows[2]:IsShown())
 end)
 test('new result scrolls announcement view to top, while ordinary renders preserve reading position',function()
  local R=reset(); local w=R.window; w:SetSize(840,680); w.scripts.OnSizeChanged()
  R.character.history={{oldName=string.rep('Old ',100),newName=string.rep('New ',100),kind='ability'}}; R:Render()
  w.announcementScroll.scripts.OnMouseWheel(w.announcementScroll,-1); local offset=w.announcementScroll:GetVerticalScroll()
  R:Render(); assert(offset>0 and w.announcementScroll:GetVerticalScroll()==offset)
  table.insert(R.character.history,1,{oldName='Fresh',newName='Replacement',kind='talent'}); R:Render()
  assert(w.announcementScroll:GetVerticalScroll()==0 and #calls==0)
 end)
 test('late results with planner closed go to chat and history without reopening any overlay',function()
  local R=reset(); local w=R.window
  local record={oldID=101,newID=102,oldName='Old',newName='New',spent=1,kind='ability'}
  realNotify(R,record); w:Hide()
  R.character.history={record}; realNotify(R,record)
  assert(not R.notice and not R.noticeQueue and not w:IsShown() and #calls==0)
  w:Show(); R:Render(); assert(w.historyRows[1].record==record and not R.notice)
 end)
 test('launcher is 32px, opens on click, saves free-drag position, and does not click after dragging',function()
  local R=reset(); R.launcher=nil; R:CreateLauncher(); local b=R.launcher
  assert(b:GetWidth()==32 and b:GetHeight()==32)
  if R.window:IsShown() then R.window:Hide() end
  clock=1; b.scripts.OnClick(); assert(R.window:IsShown() and #calls==0)
  b.scripts.OnDragStart(); b.scripts.OnDragStop(); assert(R.db.launcher.x==0 and R.db.launcher.y==0)
  b.scripts.OnClick(); assert(R.window:IsShown())
  clock=2; b.scripts.OnClick(); assert(not R.window:IsShown())
  R:CreateLauncher(); assert(b.point[1]=='CENTER'); R:CreateLauncher(true); assert(not R.db.launcher and b.point[1]=='TOPRIGHT')
 end)
 test('quick animation also shortens talent presentations and restores timings',function()
  local R=reset(); R.Client.durationHooked=nil; R:Toggle('T:201'); R:Start('talent')
  local f=CreateFrame('Frame'); f.Scroll={Content={AnimationGroup={Rotation1=CreateFrame('Animation')}}}
  f.NewSpell={AnimG={Scale2=CreateFrame('Animation'),Alpha2=CreateFrame('Animation'),Alpha3=CreateFrame('Animation')}}
  RandomMode_RollFrame=f; R.Client:PrepareAnimation(); assert(R.Client.fastState and f:GetAlpha()==0)
  f.Scroll.Content.AnimationGroup.Rotation1:SetDuration(5.5); assert(f.Scroll.Content.AnimationGroup.Rotation1:GetDuration()==0.05)
  f:Hide(); assert(not R.Client.fastState and f:GetAlpha()==1)
 end)
 test('search filters views without changing queue or hidden selection',function()
  local R=reset(); R:Toggle('A:101'); R.window.panels.ability.search:SetText('102'); R:Render()
  assert(R.window.panels.ability.rows[1].entry.id==102 and R.selected['A:101'] and R:Totals().ability==1)
  R.window.panels.ability.search:SetText(''); R:Render()
 end)
 test('window close stops remaining requests',function()
  local R=reset(); R:Toggle('A:101'); R:Start(); R.window:Hide(); assert(not R.running and R.pending and #calls==1)
 end)
 test('quick animation preserves callback scripts and restores original durations/alpha',function()
  local R=reset(); R.Client.durationHooked=nil; R:Toggle('A:101'); R:Start()
  local f=CreateFrame('Frame'); f.Scroll={Content={AnimationGroup={Rotation1=CreateFrame('Animation')}}}
  f.NewSpell={AnimG={Scale2=CreateFrame('Animation'),Alpha2=CreateFrame('Animation'),Alpha3=CreateFrame('Animation')}}
  local callback=function() end; f.NewSpell.AnimG.Alpha3:SetScript('OnPlay',callback)
  RandomMode_RollFrame=f; R.Client:PrepareAnimation()
  assert(f:GetAlpha()==0 and f.NewSpell.AnimG.Alpha3:GetScript('OnPlay')==callback)
  f.Scroll.Content.AnimationGroup.Rotation1:SetDuration(5.5); assert(f.Scroll.Content.AnimationGroup.Rotation1:GetDuration()==0.05)
  f:Hide(); assert(not R.Client.fastState and f:GetAlpha()==1 and f.NewSpell.AnimG.Alpha3:GetDuration()==3)
 end)
 test('quick animation does not change unrelated/manual rolls',function()
  local R=reset(); local f=CreateFrame('Frame'); RandomMode_RollFrame=f; R.Client:PrepareAnimation(); assert(not R.Client.fastState and f:GetAlpha()==1)
 end)
end
function RunCoreTests()
 test('shared SPELL_ROLLED presentation plus TALENT_LEARN confirms and advances two selected talents',function()
  local R=reset(); GrimfallRerollDB={}; Fire('ADDON_LOADED','GrimfallReroll'); talents[203]={class=2,spell=303}; R:Refresh(); R:Toggle('T:201'); R:Toggle('T:203'); R:Start('talent')
  assert(calls[1][2]==201)
  Fire('CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED',302); assert(R.running and not R.pending.ambiguous)
  talents[201]=nil; talents[202]={class=1,spell=302}; scrollCounts[639]=9
  Fire('CUSTOM_CLASSLESS_WILDCARD_TALENT_LEARN',302); R:Step(false); assert(R.done==1 and not R.pending)
  clock=1; R:Step(false); assert(#calls==2 and calls[2][2]==203)
  talents[203]=nil; talents[204]={class=2,spell=304}; scrollCounts[639]=8
  Fire('CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED',304); Fire('CUSTOM_CLASSLESS_WILDCARD_TALENT_LEARN',304); R:Step(false)
  clock=2; R:Step(false); assert(R.done==2 and not R.running and #calls==2)
 end)
 test('actual addon event registration and result routing confirm a reroll',function()
  local R=reset(); GrimfallRerollDB={}; Fire('ADDON_LOADED','GrimfallReroll'); assert(R.eventsReady)
  R:Refresh(); R:Toggle('T:201'); R:Start()
  talents={[202]={class=1,spell=302}}; scrollCounts[639]=9
  Fire('CUSTOM_CLASSLESS_WILDCARD_TALENT_LEARN',302); R:Step(false)
  assert(R.done==1 and not R.pending and #R.character.history==1)
 end)
 test('native server errors stop further requests, while still checking late result',function()
  local R=reset(); R:Toggle('A:101'); R:Toggle('A:102'); R:Start()
  Fire('UI_ERROR_MESSAGE','Not ready'); assert(not R.running and R.pending and #calls==1)
  replaceAbility(101,103); scrollCounts[640]=9; Fire('CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED',103); R:Step(false)
  clock=3; R:Step(false); assert(#calls==1)
 end)
 test('combat event stops queue immediately',function()
  local R=reset(); R:Toggle('A:101'); R:Start(); Fire('PLAYER_REGEN_DISABLED')
  assert(not R.running and R.pending and #calls==1)
 end)
 test('ordinary-speed presentation waits then continues without skipping or repeating',function()
  local R=reset(); R:Toggle('A:101'); R:Toggle('A:102'); R:Start()
  replaceAbility(101,103); scrollCounts[640]=9; R:Result('ability',103); R:Step(false)
  local f=CreateFrame('Frame'); RandomMode_RollFrame=f; clock=1; R:Step(false)
  assert(R.running and not R.paused and #calls==1)
  f:Hide(); clock=2; R:Step(false); assert(#calls==2 and calls[2][2]==102)
 end)
 test('diagnostics collect only read-only data and never trigger native request',function()
  local R=reset(); R.Client:Diagnose(); assert(R.db.diagnostic.rows==3 and #calls==0)
 end)
end
