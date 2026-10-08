test('native zero-based spec names and icons are read without changing queue identity',function()
 local R=reset();local active,info,list=GetActiveSpecializationIndex,GetSpecializationInfo,GetSpecializations
 GetActiveSpecializationIndex=function() return 0 end
 GetSpecializationInfo=function(index) assert(index==0);return {SpecializationName='Arcane',SpecializationIconName='Spell_Holy_MagicalSentry',SpecializationId=17} end
 local before=R.spec;local locks=R:Locks(before);R:UpdateSpecDisplay()
 assert(R.window.spec:GetText()=='Arcane' and R.window.specIcon.texture=='Interface\\Icons\\Spell_Holy_MagicalSentry')
 assert(before==R.spec and locks==R:Locks(before) and #calls==0)
 GetSpecializationInfo=function() return {SpecializationName='  My Hybrid  ',SpecializationIconName='Interface\\Icons\\Spell_Frost_FrostBolt02'} end
 local d=R.Presentation:CurrentSpec();assert(d.name=='My Hybrid' and d.icon=='Interface\\Icons\\Spell_Frost_FrostBolt02')
 GetSpecializationInfo=function() error('not ready') end
 GetSpecializations=function() return {['0']={SpecializationName='Custom Frost',SpecializationIconName='Spell_Frost_FrostBolt02'},[1]={SpecializationName='Wrong Slot'}} end
 d=R.Presentation:CurrentSpec();assert(d.name=='Custom Frost' and d.index==0)
 GetActiveSpecializationIndex,GetSpecializationInfo,GetSpecializations=active,info,list
end)
test('spec metadata handles missing data, unnamed slots and spec changes without inventing a class',function()
 local R=reset();local active,info,list=GetActiveSpecializationIndex,GetSpecializationInfo,GetSpecializations
 GetActiveSpecializationIndex=function() return 0 end;GetSpecializationInfo=nil;GetSpecializations=nil
 local d=R.Presentation:CurrentSpec();assert(not d.verified and d.name=='Spec Unavailable')
 GetSpecializationInfo=function() return {SpecializationName='',SpecializationIconName=''} end
 d=R.Presentation:CurrentSpec();assert(d.name=='Unnamed Spec' and d.icon:find('DualWield',1,true))
 local reads=0;GetActiveSpecializationIndex=function() reads=reads+1;return reads==1 and 0 or 1 end
 assert(R.Presentation:CurrentSpec().name=='Spec Updating')
 GetActiveSpecializationIndex=function() error('API loading') end
 assert(not R.Presentation:CurrentSpec().verified and #calls==0)
 GetActiveSpecializationIndex,GetSpecializationInfo,GetSpecializations=active,info,list
end)
test('display refresh follows spec rename and icon changes while the planner is open',function()
 local R=reset();local info=GetSpecializationInfo;local name='Fire';local icon='Spell_Fire_FireBolt02'
 GetSpecializationInfo=function() return {SpecializationName=name,SpecializationIconName=icon} end
 R.window.nextSpecUpdate=nil;R.window.scripts.OnUpdate();assert(R.window.spec:GetText()=='Fire')
 name='Custom Build';icon='Spell_Frost_FrostBolt02';clock=2;R.window.scripts.OnUpdate()
 assert(R.window.spec:GetText()=='Custom Build' and R.window.specIcon.texture:find('FrostBolt02',1,true) and #calls==0)
 GetSpecializationInfo=info
end)
test('built-in font is used even when another addon supplies Emblem',function()
 local R=reset();local stub=LibStub;local fetched=false;local seen={}
 LibStub=function() fetched=true;return {Fetch=function() return 'Shared\\Emblem.ttf' end} end
 local object={SetFont=function(_,path,size,flags) seen[#seen+1]=path;assert(size==14 and flags=='');return true end}
 local chosen=R.Presentation:SetFont(object,14);LibStub=stub
 assert(chosen=='Fonts\\FRIZQT__.TTF' and #seen==1 and not fetched)
end)

test('bundled font fallback preserves requested outline if the built-in face cannot load',function()
 local R=reset()
 for _,failsWithError in ipairs({false,true}) do
  local seen={};local object={SetFont=function(_,path,size,flags)
   seen[#seen+1]=path;assert(size==22 and flags=='OUTLINE')
   if path=='Fonts\\FRIZQT__.TTF' then if failsWithError then error('Unavailable font') end;return false end
   return true
  end}
  local chosen=R.Presentation:SetFont(object,22,'OUTLINE')
  assert(#seen==2 and seen[1]=='Fonts\\FRIZQT__.TTF' and chosen=='Interface\\AddOns\\GrimfallReroll\\Fonts\\PT_Sans-Web-Regular.ttf')
 end
end)
test('both sections share centered action columns and fixed control widths',function()
 local R=reset();local w=R.window
 for _,p in pairs(w.panels) do
  assert(p.count.justifyH=='CENTER' and p.cost.justifyH=='CENTER')
  assert(p.count.width==164 and p.cost.width==164 and p.start.width==164 and p.historyControl.width==164)
  assert(p.count.point[2]==-14 and p.historyControl.point[2]==-14)
  assert(p.footer.points[2][2]==-6 and p.start.point[2]==-8 and p.cost.point[2]==-8)
  assert(p.historyToggle.parent==p.historyControl and p.historyText.parent==p.historyControl)
  assert(p.rows[1].name.justifyH=='LEFT' and p.rows[1].name.justifyV=='MIDDLE')
 end
 assert(#calls==0)
end)
test('history has an inset well, dark inner shadows and a lower gold bevel inside the frame',function()
 local R=reset()
 for _,p in pairs(R.window.historyDrawers) do
  assert(p.recess.top.height==5 and p.recess.left.width==5 and p.recess.bottom.height==2)
  assert(p.recess.top.vertexColor[4]==0.90 and p.recess.bottom.vertexColor[1]>0)
  assert(p.surface.point[2]==-10 and p.surface.vertexColor[4]==1)
  assert(p.title.justifyH=='CENTER' and p.title:GetText():find(' History',1,true))
  assert(p.newest.point[3]==-41 and p.scroll.point[3]==-78)
 end
end)
test('old and new history hover targets show separate spell tooltips for abilities and talents',function()
 local R=reset();R.character.history={
  {kind='ability',oldID=101,newID=102,oldName='Old Ability',newName='New Ability',at=time()},
  {kind='talent',oldID=301,newID=302,oldName='Old Talent',newName='New Talent',at=time()}}
 R:Render()
 for _,kind in ipairs({'ability','talent'}) do
  local row=R.window.historyDrawers[kind].rows[1]
  for _,which in ipairs({'old','new'}) do
   local hit=row[which..'Hit'];hit.scripts.OnEnter(hit)
   assert(GameTooltip.hyperlink=='spell:'..row.record[which..'ID'] and GameTooltip:IsOwned(hit))
   assert(row[which..'Name'].parent==hit and row[which..'Border'].parent==hit)
   assert(GameTooltip.anchor==(kind=='talent' and 'ANCHOR_LEFT' or 'ANCHOR_RIGHT'))
   hit.scripts.OnLeave();assert(not GameTooltip:IsShown())
  end
 end
 assert(#calls==0)
end)
test('legacy and unloaded history spells use a readable fallback without stale tooltip content',function()
 local R=reset();local owner=R.window;local info=GetSpellInfo;local hyperlink=GameTooltip.SetHyperlink
 R:ShowHistorySpellTooltip(owner,{kind='talent',oldName='Legacy Talent',newName='New Talent'},'old')
 assert(GameTooltip:GetText()=='Legacy Talent' and GameTooltip.hyperlink==nil)
 GetSpellInfo=function() return nil end
 R:ShowHistorySpellTooltip(owner,{kind='ability',newID=999,newName='Not Cached'},'new')
 assert(GameTooltip:GetText()=='Not Cached' and GameTooltip.hyperlink==nil)
 GetSpellInfo=info;GameTooltip.SetHyperlink=function() error('invalid spell') end
 R:ShowHistorySpellTooltip(owner,{kind='talent',oldID=301,oldName='Missing Talent'},'old')
 assert(GameTooltip:GetText()=='Missing Talent' and #calls==0)
 GameTooltip.SetHyperlink=hyperlink
end)
test('history tooltip targets scroll without rerolls and update to a newly prepended record',function()
 local R=reset();R.character.history={{kind='ability',oldID=101,newID=102,oldName='Old',newName='New'}};R:Render()
 local p=R.window.historyDrawers.ability;local hit=p.rows[1].oldHit
 hit.scripts.OnEnter(hit);table.insert(R.character.history,1,{kind='ability',oldID=103,newID=104,oldName='Latest',newName='Replacement'});R:Render()
 assert(not GameTooltip:IsShown());hit.scripts.OnEnter(hit);assert(GameTooltip.hyperlink=='spell:103')
 hit.scripts.OnMouseWheel(hit,-1);assert(not GameTooltip:IsShown() and #calls==0)
end)
