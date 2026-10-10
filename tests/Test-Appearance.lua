-- Appearance is independent of the queue and native animation. No live APIs.
local function fresh()
 local R=reset();R:SetSkin('titan');return R
end
local function regionsHidden(list)for _,t in pairs(list or {})do assert(not t:IsShown())end end
test('Titan remains the default without migrating existing settings',function()
 local R=fresh();R.db.skin=nil;R:ApplySkin();assert(R.Skin.Mode()=='titan' and R.db.skin==nil)
 local db=R.db;local character=R.character;local locks=R:Locks(R.spec);local history=character.history
 db.skin='unsupported';R:ApplySkin();assert(R.Skin.Mode()=='titan' and db.skin=='unsupported')
 assert(not R:SetSkin('invalid') and R.db==db and R.character==character and R:Locks(R.spec)==locks and character.history==history)
end)
test('clean removes every outer Titan layer and ornamental panel and button border',function()
 local R=fresh();R:SetSkin('clean');local w=R.window;local f=w.titanFrame
 assert(not w.guardian:IsShown() and not f.opaque:IsShown() and not w.emblemFrame:IsShown())
 regionsHidden(f.pieces);regionsHidden(f.stone);regionsHidden(f.rails[1]);regionsHidden(f.rails[2]);regionsHidden(w.plinths);regionsHidden(w.inlay)
 for _,p in ipairs({w.historyPanel,w.panels.ability,w.panels.talent,w.panels.ability.footer,w.panels.talent.footer,w.historyDrawers.ability,w.historyDrawers.talent})do
  regionsHidden(p.inlay);regionsHidden(p.recess);assert(not p.surface:IsShown() and #p.cleanEdges==4)
  for _,edge in ipairs(p.cleanEdges)do assert(edge:IsShown())end
 end
 for _,b in ipairs(R.uiButtons)do regionsHidden(b.buttonPieces);assert(#b.cleanEdges==4)end
 assert(w.title.fontObject.fontSize==24 and w.skinToggle:GetText()=='Skin: Clean' and #calls==0)
end)
test('switching back restores original Titan sprites typography and bevels',function()
 local R=fresh();local w=R.window;local sprite=w.guardian.texture;local uv=w.guardian.coords
 R:SetSkin('clean');R:SetSkin('titan')
 assert(w.guardian:IsShown() and w.guardian.texture==sprite and w.guardian.coords==uv and w.emblemFrame:IsShown())
 assert(w.title.fontObject.fontSize==30 and w.title.point[2]==-347)
 for _,p in pairs(w.historyDrawers)do
  assert(p.surface:IsShown() and p.recess.top:IsShown() and p.inlay[1]:IsShown());regionsHidden(p.cleanEdges)
 end
 for _,b in ipairs(R.uiButtons)do assert(b.buttonPieces[5]:IsShown());regionsHidden(b.cleanEdges)end
 assert(w.panels.ability.rows[1].box.texture:find('Art\\Unchecked',1,true) and #calls==0)
end)
test('appearance changes preserve selection locks search and saved display preferences',function()
 local R=fresh();R:Lock('A:102');R:Toggle('A:101');R.db.fast=false;R.db.hideLocked={ability=true};R.db.historyPanels={ability=true,talent=true}
 R.db.x=90;R.db.y=20;R.db.launcher={x=50,y=60};R.window.panels.ability.search:SetText('Spell');R:LayoutHistory();R:Render()
 local selected,locks,history=R.selected,R:Locks(R.spec),R.character.history
 local launch=R.db.launcher;local hide=R.db.hideLocked;local prefs=R.db.historyPanels;local width,height=R.db.width,R.db.height
 R:SetSkin('clean');R:SetSkin('titan')
 assert(R.selected==selected and selected['A:101'] and R:Locks(R.spec)==locks and locks['A:102'] and R.character.history==history)
 assert(R.db.launcher==launch and R.db.hideLocked==hide and R.db.historyPanels==prefs and not R.db.fast)
 assert(R.db.width==width and R.db.height==height and R.db.x==90 and R.db.y==20 and R.window.panels.ability.search:GetText()=='Spell' and #calls==0)
end)
test('skin button stays usable and changes only appearance while a request is pending',function()
 local R=fresh();R:Toggle('A:101');R:Toggle('A:102');R:Start();assert(R.pending and #calls==1)
 local p,q,s,status=R.pending,R.queue,R.selected,R.status
 R.window.skinToggle.scripts.OnClick();assert(R.db.skin=='clean' and R.window:IsShown())
 assert(R.pending==p and R.queue==q and R.selected==s and R.status==status and R.running and #calls==1)
 R.window.skinToggle.scripts.OnClick();assert(R.db.skin=='titan' and R.pending==p and #calls==1)
end)
test('theme changes during two-roll queue preserve exact confirmations and scroll counts',function()
 local R=fresh();R:Toggle('A:101');R:Toggle('A:102');R:Start();R:SetSkin('clean')
 replaceAbility(101,103);scrollCounts[640]=9;R:Result('ability',103);R:Step(false)
 assert(R.done==1 and #calls==1);R:SetSkin('titan');clock=1;R:Step(false);assert(#calls==2)
 R:SetSkin('clean');replaceAbility(102,104);scrollCounts[640]=8;R:Result('ability',104);R:Step(false)
 assert(R.done==2 and not R.running and not R.pending and #R.character.history==2 and #calls==2)
 assert(scrollCounts[640]==8 and scrollCounts[639]==10)
end)
test('skin switching does not read a build request a refresh or interrupt a display scan',function()
 local R=fresh();R.smoothReads=true;R:RequestRefresh();local job=R.refreshJob;assert(job)
 local snapshot,refresh,step=R.Client.Snapshot,R.RequestRefresh,R.Step
 local function forbidden()error('appearance invoked game work')end
 R.Client.Snapshot=forbidden;R.RequestRefresh=forbidden;R.Step=forbidden
 local ok,why=pcall(function()R:SetSkin('clean');R:SetSkin('titan')end)
 R.Client.Snapshot=snapshot;R.RequestRefresh=refresh;R.Step=step
 assert(ok,why);assert(R.refreshJob==job and #calls==0);R:CancelRefresh()
end)
test('commands accept normalized skin names and do not toggle a closed window',function()
 local R=fresh();R.window:Hide();local status=R.status
 SlashCmdList.GRIMFALLREROLL(' SKIN   CLEAN ');assert(R.db.skin=='clean' and not R.window:IsShown())
 SlashCmdList.GRIMFALLREROLL('skin');SlashCmdList.GRIMFALLREROLL('skin invalid')
 assert(R.db.skin=='clean' and not R.window:IsShown() and R.status==status and not R.refreshJob and #calls==0)
 SlashCmdList.GRIMFALLREROLL('skin titan');assert(R.db.skin=='titan' and not R.window:IsShown())
end)
test('saved clean choice survives database reinitialization and does not become per-spec',function()
 local R=fresh();R:SetSkin('clean');local db=R.db;local chars=db.characters
 R:InitializeDB(db);assert(R.Skin.Mode()=='clean' and db.characters==chars)
 spec=2;R:Refresh();R:Render();assert(R.db.skin=='clean' and R.window.appearanceMode=='clean')
 spec=1;R:Refresh();assert(R.db.skin=='clean' and #calls==0)
end)
test('row selection and protection symbols remain visible in clean mode',function()
 local R=fresh();R:SetSkin('clean');R:Lock('A:102');R:Toggle('A:101');R:Render()
 local rows=R.window.panels.ability.rows;local selected,locked
 for _,b in ipairs(rows)do if b.entry then if b.entry.key=='A:101'then selected=b elseif b.entry.key=='A:102'then locked=b end end end
 assert(selected.mark:IsShown() and selected.mark.texture=='Interface\\Buttons\\UI-CheckBox-Check')
 assert(locked.lock:IsShown() and not locked.mark:IsShown() and not locked.box:IsShown())
 selected.scripts.OnEnter(selected);assert(GameTooltip.hyperlink=='spell:101')
 locked.scripts.OnClick(locked,'LeftButton');assert(not R.selected['A:102'] and #calls==0)
end)
test('new and recycled rows inherit clean visuals without changing spell icons',function()
 local R=fresh();R:SetSkin('clean');local icon=R.window.panels.ability.rows[1].icon.texture
 for i=110,160 do known[#known+1]=i end;R:Refresh();R:Render()
 for _,b in ipairs(R.window.panels.ability.rows)do if b.entry then assert(b.skinMode=='clean' and b.box.texture:find('UI-CheckBox-Up',1,true))end end
 assert(R.window.panels.ability.rows[1].icon.texture==icon and #calls==0)
end)
test('new and cached history rows are styled in both modes without rewriting history',function()
 local R=fresh();R:SetSkin('clean');local history={{kind='ability',oldID=101,newID=102,oldName='Old',newName='New'}};R.character.history=history;R:Render()
 local row=R.window.historyDrawers.ability.rows[1];assert(row.skinMode=='clean' and row.oldBorder.borderColor[1]==0.32)
 R:SetSkin('titan');assert(row.skinMode=='titan' and row.oldBorder.borderColor[1]==0.88)
 R:SetSkin('clean');assert(R.character.history==history and #history==1 and #calls==0)
end)
test('both themes keep every history configuration on screen without wasted Titan margins in clean',function()
 local R=fresh();local w=R.window;local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
 for _,screen in ipairs({{1024,768},{1366,768},{1920,1080}})do
  UIParent:SetSize(screen[1],screen[2])
  for _,size in ipairs({{840,620},{1300,950}})do w:SetSize(size[1],size[2])
   for _,prefs in ipairs({{},{ability=true},{talent=true},{ability=true,talent=true}})do
    R.db.historyPanels=prefs;R.db.x=2000;R.db.y=-2000
    for _,mode in ipairs({'titan','clean'})do
     R:SetSkin(mode);R:LayoutHistory();local clean=mode=='clean';local scale=w:GetScale();local x,y=w.point[4]*scale,w.point[5]*scale
     local left=(prefs.ability and 245 or 0)+(clean and 0 or 112);local right=(prefs.talent and 245 or 0)+(clean and 0 or 112)
     assert(x-(size[1]/2+left)*scale>=-screen[1]/2+15.99 and x+(size[1]/2+right)*scale<=screen[1]/2-15.99)
     assert(y-(size[2]/2+(clean and 0 or 4))*scale>=-screen[2]/2+15.99 and y+(size[2]/2+(clean and 0 or 112))*scale<=screen[2]/2-15.99)
     assert(w.historyDrawers.ability.height==size[2]-(clean and 28 or 98))
    end
   end
  end
 end
 UIParent:SetSize(sw,sh);w:SetSize(840,620);R.db.x=0;R.db.y=0;R:SetSkin('titan');R:LayoutHistory()
end)
test('repeated toggles reuse their textures and do not add animation callbacks or native reads',function()
 local R=fresh();local w=R.window;local update=w.scripts.OnUpdate
 R:SetSkin('clean');R:SetSkin('titan');local n=#PreviewFrames
 for i=1,30 do R:SetSkin('clean');R:SetSkin('titan')end
 assert(#PreviewFrames==n and w.scripts.OnUpdate==update and #calls==0)
end)
test('appearance button fits beside Quick Animation and exposes the saved-choice tooltip',function()
 local R=fresh();local b=R.window.skinToggle
 assert(b.width==110 and b.height==28 and b.point[2]==16 and b.parent==R.window.historyPanel and b:IsEnabled())
 b.scripts.OnEnter(b);assert(GameTooltip:GetText()=='Appearance' and GameTooltip.lines[1]:find('Saved',1,true))
 b.scripts.OnLeave();assert(not GameTooltip:IsShown() and #calls==0)
end)
test('clean preference set before UI creation applies on first open without showing Titan art',function()
 local R=fresh();local old=R.window;R.window=nil
 local ok,why=pcall(function()
  R:SetSkin('clean');assert(R.window==nil);R:CreateUI();R.window:Show();R:Render()
  assert(R.window.appearanceMode=='clean' and not R.window.guardian:IsShown() and R.window.cleanEdges[1]:IsShown())
 end)
 if R.window then R.window:Hide()end;R.window=old;R:SetSkin('titan');old:Show();R:Render()
 assert(ok,why);assert(#calls==0)
end)
