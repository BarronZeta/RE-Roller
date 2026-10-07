function RunHistoryTests()
 local function populate(R,n)
  R.character.history={}
  for i=1,n do
   R.character.history[i]={oldID=101,newID=102,oldName='Old '..i,newName='New '..i,
    kind=i%2==0 and 'talent' or 'ability',at=time()-i,spec='specialization:1',spent=1}
  end
  R:LayoutHistory(); R:Render()
 end
 test('history drawers independently open left and right, with saved choices and empty states',function()
  local R=reset(); R:LayoutHistory(); R:Render(); local w=R.window
  local a,t=w.historyDrawers.ability,w.historyDrawers.talent
  assert(not a:IsShown() and not t:IsShown() and a.empty:IsShown() and t.empty:IsShown())
  w.panels.ability.historyToggle.scripts.OnClick()
  assert(a:IsShown() and not t:IsShown() and R.db.historyPanels.ability)
  assert(a.point[1]=='TOPRIGHT' and a.point[3]=='TOPLEFT' and a.point[4]==-R.Skin.gap)
  w.panels.talent.historyToggle.scripts.OnClick()
  assert(a:IsShown() and t:IsShown() and t.point[1]=='TOPLEFT' and t.point[3]=='TOPRIGHT')
  a.close.scripts.OnClick(); assert(not a:IsShown() and t:IsShown() and not R.db.historyPanels.ability)
  local db=R.db; R:InitializeDB(db); R:LayoutHistory(); assert(t:IsShown())
  assert(#calls==0)
 end)
 test('all saved history separates by type in original newest-first order with icons and old/new names',function()
  local R=reset(); populate(R,100); local a,t=R.window.historyDrawers.ability,R.window.historyDrawers.talent
  assert(#a.records==50 and #t.records==50 and #a.rows>=50 and #t.rows>=50)
  for _,p in ipairs({a,t}) do
   for i,h in ipairs(p.records) do
    assert(h.kind==p.kind and p.rows[i].record==h)
    assert(p.rows[i].oldName:GetText()==h.oldName and p.rows[i].newName:GetText()==h.newName and p.rows[i].from:GetText()=='From:' and p.rows[i].to:GetText()=='To:')
    assert(p.rows[i].oldIcon.texture and p.rows[i].newIcon.texture)
   end
  end
  assert(a.records[1].oldName=='Old 1' and a.records[50].oldName=='Old 99' and t.records[1].oldName=='Old 2')
  assert(#R.character.history==100 and #calls==0)
 end)
 test('mouse wheel scroll clamps independently and Newest returns only its drawer to the top',function()
  local R=reset(); populate(R,100); local a,t=R.window.historyDrawers.ability,R.window.historyDrawers.talent
  R:ScrollHistory(a,0); R:ScrollHistory(t,0)
  a.scroll.scripts.OnMouseWheel(a.scroll,-3)
  assert(a.scroll:GetVerticalScroll()==426 and t.scroll:GetVerticalScroll()==0)
  a.rows[1].scripts.OnMouseWheel(a.rows[1],-1000)
  assert(a.scroll:GetVerticalScroll()==a.canvas:GetHeight()-a.scroll:GetHeight())
  R:ScrollHistory(t,152); a.newest.scripts.OnClick()
  assert(a.scroll:GetVerticalScroll()==0 and t.scroll:GetVerticalScroll()==152)
  a.scroll.scripts.OnMouseWheel(a.scroll,1000); assert(a.scroll:GetVerticalScroll()==0 and #calls==0)
 end)
 test('new results preserve the older record being read; top view stays on newest',function()
  local R=reset(); populate(R,100); local a,t=R.window.historyDrawers.ability,R.window.historyDrawers.talent
  R:ScrollHistory(a,284); R:ScrollHistory(t,0); local visible=a.records[3]
  table.insert(R.character.history,1,{oldName='Latest old',newName='Latest new',kind='ability'})
  table.remove(R.character.history); R:Render()
  assert(a.records[math.floor(a.scroll:GetVerticalScroll()/142)+1]==visible and a.scroll:GetVerticalScroll()==426)
  R:Render(); assert(a.scroll:GetVerticalScroll()==426)
  a.newest.scripts.OnClick(); assert(a.scroll:GetVerticalScroll()==0 and a.rows[1].newName:GetText()=='Latest new')
  assert(t.scroll:GetVerticalScroll()==0 and #calls==0)
 end)
 test('legacy records without time or IDs remain readable; obsolete rows and scroll offsets clear',function()
  local R=reset(); populate(R,100); local p=R.window.historyDrawers.ability
  R:ScrollHistory(p,1000)
  R.character.history={{kind='ability',oldName='Legacy old',newName='Legacy new'}}; R:Render()
  assert(p.rows[1].when:GetText()=='Saved result' and p.rows[1].oldIcon.texture:find('QuestionMark'))
  assert(not p.rows[2]:IsShown() and p.rows[2].record==nil and p.scroll:GetVerticalScroll()==0)
  p.rows[1].scripts.OnEnter(p.rows[1]); assert(GameTooltip:GetText()=='Rerolled ability')
  R.character.history={}; R:Render(); assert(p.empty:IsShown() and not p.rows[1]:IsShown() and #p.records==0)
 end)
 test('history browsing and drawer closing during a reroll cannot cancel or initiate requests',function()
  local R=reset(); populate(R,10); R:Toggle('A:101'); R:Start('ability')
  local pending=R.pending; assert(R.running and pending and #calls==1)
  R:ToggleHistory('ability'); local p=R.window.historyDrawers.ability
  p.newest.scripts.OnClick(); p.close.scripts.OnClick()
  assert(R.running and R.pending==pending and #calls==1 and #R.character.history==10)
  R:Stop('test'); R.pending=nil; R:Clear(); assert(#R.character.history==10)
 end)
 test('combined planner and drawers fit screen for all toggle states, sizes and edge positions',function()
  local R=reset()
  for _,screen in ipairs({{1024,768},{1366,768},{1920,1080},{2560,1440}}) do
   for _,size in ipairs({{840,680},{980,760},{1300,950}}) do
    for _,sides in ipairs({{0,0},{278,0},{0,278},{278,278}}) do
     for _,pos in ipairs({{-2000,-2000},{0,0},{2000,2000}}) do
      local scale,x,y=R.HistoryFit(size[1],size[2],screen[1],screen[2],sides[1],sides[2],pos[1],pos[2])
      assert(scale>0 and scale<=1)
      assert(x-(size[1]/2+sides[1])*scale>=-screen[1]/2+15.99)
      assert(x+(size[1]/2+sides[2])*scale<=screen[1]/2-15.99)
      assert(y-size[2]/2*scale>=-screen[2]/2+15.99 and y+size[2]/2*scale<=screen[2]/2-15.99)
     end
    end
   end
  end
 end)
 test('automatic fitting leaves preferred size and position intact and restores when drawers close',function()
  local R=reset(); local w=R.window; local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
  UIParent:SetSize(1600,1200); w:SetSize(1300,760); R.db.x=0; R.db.y=0; R.db.width=1300; R.db.height=760
  R.db.historyPanels={ability=true,talent=true}; R:LayoutHistory(); assert(w:GetScale()<1)
  assert(R.db.width==1300 and R.db.height==760 and R.db.x==0 and R.db.y==0)
  R.db.historyPanels={}; R:LayoutHistory(); assert(w:GetScale()==1 and w.point[4]==0 and w.point[5]==0)
  UIParent:SetSize(sw,sh)
 end)
end
