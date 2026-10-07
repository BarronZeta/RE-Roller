test('reference-derived frame uses sliced native pixels and excludes POT padding',function()
 local R=reset();local w=R.window
 assert(w.guardian.texture=='Interface\\AddOns\\GrimfallReroll\\Art\\Header')
 assert(w.guardian.width==901 and w.guardian.height==111)
 assert(w.guardian.coords[2]==901/1024 and w.guardian.coords[4]==111/128)
 for _,p in pairs(w.historyDrawers) do assert(#p.inlay==8 and p.width==237 and p.point[5]==-14) end
 assert(#calls==0)
end)
test('source guardian remains fixed across drawer combinations and resizing',function()
 local R=reset();local w=R.window
 for _,size in ipairs({{840,620},{980,760},{1300,950}}) do
  w:SetSize(size[1],size[2]);w.scripts.OnSizeChanged()
  for _,prefs in ipairs({{},{ability=true},{talent=true},{ability=true,talent=true}}) do
   R.db.historyPanels=prefs;R:LayoutHistory()
   assert(w.guardian.width==901 and w.guardian.height==111)
   assert(w.guardian.coords[2]==901/1024)
   assert(w.titanFrame.LeftCap.width==108 and w.titanFrame.RightCap.width==108)
   assert(w.plinths.ability.width==(prefs.ability and 296 or 80))
   assert(w.plinths.talent.width==(prefs.talent and 296 or 80))
   for _,pool in ipairs(w.titanFrame.rails) do for _,t in ipairs(pool) do if t:IsShown() then
    assert(t.width>0 and t.width<=132 and t.height>0 and t.height<=38)
   end end end
  end
 end
 local count=#PreviewFrames;R:LayoutHistory();R:LayoutHistory();assert(#PreviewFrames==count and #calls==0)
end)
test('inset panels clear original corner caps and base medallions',function()
 local R=reset();local w=R.window
 for _,h in ipairs({620,760,950}) do
  w:SetHeight(h);R:LayoutHistory()
  for _,p in pairs(w.historyDrawers) do
   assert(math.abs(p.point[4])==8 and p.point[5]==-14)
   assert(h-14-p.height==84)
  end
 end
 assert(w.historyDrawers.ability.title:GetText()=='Ability History')
 assert(w.historyDrawers.talent.title:GetText()=='Talent History')
 assert(w.emblemFrame.width==40 and w.emblemFrame.height==42 and w.emblemFrame.parent==w.headerSurface)
end)
test('opaque stone backing fills the assembly with exact cropped source tiles',function()
 local R=reset();local w=R.window;R.db.historyPanels={ability=true,talent=true};R:LayoutHistory()
 assert(w.titanFrame.opaque.vertexColor[4]==1)
 for _,t in ipairs(w.titanFrame.stone) do if t:IsShown() then
  assert(t.width<=100 and t.height<=36 and t.texture=='Interface\\AddOns\\GrimfallReroll\\Art\\Stone')
 end end
end)
test('ornament bounds stay on-screen for all states, sizes and edge positions',function()
 local R=reset()
 for _,screen in ipairs({{1024,768},{1366,768},{1920,1080},{2560,1440}}) do
  for _,size in ipairs({{840,620},{980,760},{1300,950}}) do
   for _,sides in ipairs({{112,112},{357,112},{112,357},{357,357}}) do
    for _,pos in ipairs({{-2000,-2000},{0,0},{2000,2000}}) do
     local s,x,y=R.HistoryFit(size[1],size[2],screen[1],screen[2],sides[1],sides[2],pos[1],pos[2],112,4)
     assert(s>0 and s<=1)
     assert(x-(size[1]/2+sides[1])*s>=-screen[1]/2+15.99 and x+(size[1]/2+sides[2])*s<=screen[1]/2-15.99)
     assert(y-(size[2]/2+4)*s>=-screen[2]/2+15.99 and y+(size[2]/2+112)*s<=screen[2]/2-15.99)
    end
   end
  end
 end
end)
test('source button artwork is preserved while all labels use the built-in font',function()
 local R=reset();local w=R.window
 assert(w.title.fontObject.fontPath=='Fonts\\FRIZQT__.TTF')
 assert(w.panels.ability.rows[1].name.fontObject.fontPath=='Fonts\\FRIZQT__.TTF')
 for _,b in ipairs(R.uiButtons) do assert(b.buttonArt and b.buttonArt.texture:find('Art\\',1,true)) end
 assert(w.panels.ability.rows[1].box.texture:find('Unchecked',1,true))
 assert(#calls==0)
end)
test('layout migration changes dimensions only once and preserves locks and history',function()
 local R=reset();local history=R.character.history;local locks=R:Locks(R.spec)
 R.db.layoutRevision=8;R.db.width=1000;R.db.height=800;R:CreateUI()
 assert(R.db.width==1000 and R.db.height==800 and history==R.character.history and locks==R:Locks(R.spec))
end)
