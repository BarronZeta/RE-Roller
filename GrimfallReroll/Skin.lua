local R=GrimfallReroll
local path='Interface\\AddOns\\GrimfallReroll\\Art\\'
R.Skin={outset=112,top=112,bottom=4,gap=8,historyWidth=237}
local S=R.Skin
-- Source pixel rectangles were cut directly from FinalLayout.png. POT padding,
-- not image scaling: runtime UVs exclude the padding and preserve the artwork.
S.assets={Header={901,111,1024,128},LeftCap={108,104,128,128},RightCap={108,104,128,128},
 LeftPillar={53,464,64,512},RightPillar={53,464,64,512},LeftBase={296,84,512,128},RightBase={296,84,512,128},
 Rail={132,38,256,64},Stone={100,36,128,64},Inlay={237,496,256,512},MainInlay={835,596,1024,1024},
 Panel={64,30,64,32},Dice={40,42,64,64},Button={94,30,128,32},Action={187,35,256,64},
 Lock={23,26,32,32},CheckedGold={25,27,32,32},CheckedViolet={25,27,32,32},Unchecked={25,27,32,32}}
function S.Sprite(t,name,x,y,width,height)
 local a=S.assets[name]; t:SetTexture(path..name)
 x,y,width,height=x or 0,y or 0,width or a[1],height or a[2]
 t:SetTexCoord(x/a[3],(x+width)/a[3],y/a[4],(y+height)/a[4])
end
local function nine(parent,name,size,edge,center,layer)
 local a=S.assets[name]; local sx={0,20,a[1]-20,a[1]}; local sy={0,20,a[2]-20,a[2]}
 local out={}
 local coords={{1,1,'TOPLEFT'},{3,1,'TOPRIGHT'},{1,3,'BOTTOMLEFT'},{3,3,'BOTTOMRIGHT'},
 {2,1,'TOP'},{2,3,'BOTTOM'},{1,2,'LEFT'},{3,2,'RIGHT'}}
 for _,p in ipairs(coords) do
  local x,y,anchor=p[1],p[2],p[3]; local t=parent:CreateTexture(nil,layer or 'OVERLAY')
  if x~=2 and y~=2 then
   S.Sprite(t,name,sx[x],sy[y],20,20); t:SetSize(size,size); t:SetPoint(anchor,parent,anchor,0,0)
  elseif x==2 then
   S.Sprite(t,name,20,y==1 and 0 or a[2]-5,a[1]-40,5); t:SetHeight(edge)
   t:SetPoint(y==1 and 'TOPLEFT' or 'BOTTOMLEFT',parent,y==1 and 'TOPLEFT' or 'BOTTOMLEFT',size,0)
   t:SetPoint(y==1 and 'TOPRIGHT' or 'BOTTOMRIGHT',parent,y==1 and 'TOPRIGHT' or 'BOTTOMRIGHT',-size,0)
  else
   S.Sprite(t,name,x==1 and 0 or a[1]-5,20,5,a[2]-40); t:SetWidth(edge)
   t:SetPoint(x==1 and 'TOPLEFT' or 'TOPRIGHT',parent,x==1 and 'TOPLEFT' or 'TOPRIGHT',0,-size)
   t:SetPoint(x==1 and 'BOTTOMLEFT' or 'BOTTOMRIGHT',parent,x==1 and 'BOTTOMLEFT' or 'BOTTOMRIGHT',0,size)
  end
  out[#out+1]=t
 end
 return out
end
function S.Inlay(parent,size)
 parent.inlay=nine(parent,'Inlay',size or 16,4); return parent.inlay
end
function S.Recess(parent)
 -- Keep the original gold lip, with the dark top/left well and lit lower edge
 -- inside it. The inset is opaque; none of the game world bleeds through.
 parent.recess={}
 local function edge(key,anchor1,anchor2,x1,y1,x2,y2,width,height,r,g,b,a)
  local t=parent:CreateTexture(nil,'BORDER'); t:SetTexture('Interface\\Buttons\\WHITE8X8')
  t:SetVertexColor(r,g,b,a); t:SetPoint(anchor1,parent,anchor1,x1,y1);t:SetPoint(anchor2,parent,anchor2,x2,y2)
  if width then t:SetWidth(width) end;if height then t:SetHeight(height) end
  parent.recess[key]=t
 end
 parent.surface:ClearAllPoints();parent.surface:SetPoint('TOPLEFT',10,-10);parent.surface:SetPoint('BOTTOMRIGHT',-10,10)
 parent.surface:SetVertexColor(0.58,0.60,0.62,1)
 edge('top','TOPLEFT','TOPRIGHT',5,-5,-5,-5,nil,5,0,0,0,0.90)
 edge('left','TOPLEFT','BOTTOMLEFT',5,-10,5,9,5,nil,0,0,0,0.82)
 edge('bottom','BOTTOMLEFT','BOTTOMRIGHT',7,6,-7,6,nil,2,0.60,0.47,0.27,0.64)
 edge('right','TOPRIGHT','BOTTOMRIGHT',-6,-8,-6,8,2,nil,0.50,0.42,0.29,0.48)
 edge('softTop','TOPLEFT','TOPRIGHT',10,-10,-10,-10,nil,3,0,0,0,0.28)
 edge('softLeft','TOPLEFT','BOTTOMLEFT',10,-13,10,10,3,nil,0,0,0,0.25)
end
function S.Button(parent,action)
 local name=action and 'Action' or 'Button';local a=S.assets[name]
 parent.buttonPieces=parent.buttonPieces or {}
 local xs={0,5,a[1]-5,a[1]};local ys={0,5,a[2]-5,a[2]}
 local anchors={{'TOPLEFT','TOP','TOPRIGHT'},{'LEFT','CENTER','RIGHT'},{'BOTTOMLEFT','BOTTOM','BOTTOMRIGHT'}}
 for y=1,3 do for x=1,3 do
  local i=(y-1)*3+x;local t=parent.buttonPieces[i]
  if not t then t=parent:CreateTexture(nil,'BORDER');parent.buttonPieces[i]=t end
  S.Sprite(t,name,xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y])
  t:ClearAllPoints()
  if x~=2 and y~=2 then t:SetSize(5,5);t:SetPoint(anchors[y][x],parent,anchors[y][x],0,0)
  elseif y==2 and x==2 then t:SetPoint('TOPLEFT',parent,'TOPLEFT',5,-5);t:SetPoint('BOTTOMRIGHT',parent,'BOTTOMRIGHT',-5,5)
  elseif x==2 then
   t:SetHeight(5);t:SetPoint(y==1 and 'TOPLEFT' or 'BOTTOMLEFT',parent,y==1 and 'TOPLEFT' or 'BOTTOMLEFT',5,0)
   t:SetPoint(y==1 and 'TOPRIGHT' or 'BOTTOMRIGHT',parent,y==1 and 'TOPRIGHT' or 'BOTTOMRIGHT',-5,0)
  else
   t:SetWidth(5);t:SetPoint(x==1 and 'TOPLEFT' or 'TOPRIGHT',parent,x==1 and 'TOPLEFT' or 'TOPRIGHT',0,-5)
   t:SetPoint(x==1 and 'BOTTOMLEFT' or 'BOTTOMRIGHT',parent,x==1 and 'BOTTOMLEFT' or 'BOTTOMRIGHT',0,5)
  end
 end end
 parent.buttonArt=parent.buttonPieces[5]
end
local function texture(w,name,layer)
 local t=w:CreateTexture(nil,layer or 'ARTWORK'); S.Sprite(t,name); return t
end
local function tiles(w,pool,name,x,y,width,height,layer)
 local a=S.assets[name]; local used=0
 for dy=0,height-1,a[2] do for dx=0,width-1,a[1] do
  used=used+1; local t=pool[used]
  if not t then t=texture(w,name,layer or 'BACKGROUND'); pool[used]=t end
  local tw,th=math.min(a[1],width-dx),math.min(a[2],height-dy)
  S.Sprite(t,name,0,0,tw,th);t:ClearAllPoints();t:SetPoint('TOPLEFT',w,'TOPLEFT',x+dx,y-dy);t:SetSize(tw,th);t:Show()
 end end
 for i=used+1,#pool do pool[i]:Hide() end
end
function S.Apply(w)
 local f=CreateFrame('Frame',nil,w); w.titanFrame=f; f:EnableMouse(false)
 f.stone={};f.rails={{},{}};f.pieces={}
 f.opaque=w:CreateTexture(nil,'BACKGROUND');f.opaque:SetTexture('Interface\\Buttons\\WHITE8X8');f.opaque:SetVertexColor(0.03,0.037,0.042,1)
 f.opaque:SetPoint('TOPLEFT',f,'TOPLEFT',16,-42);f.opaque:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-16,6)
 for _,name in ipairs({'LeftCap','RightCap','LeftPillar','RightPillar'}) do f[name]=texture(w,name);f.pieces[#f.pieces+1]=f[name] end
 w.guardian=texture(w,'Header','OVERLAY');w.guardian:SetSize(901,111);w.guardian:SetPoint('BOTTOM',w,'TOP',0,0)
 w.plinths={ability=texture(w,'LeftBase'),talent=texture(w,'RightBase')}
 w.inlay=nine(w,'MainInlay',20,5)
 S.Layout(w,{})
end
function S.Layout(w,prefs)
 local f=w.titanFrame;if not f then return end
 if S.Mode()=='clean' then
  f:Hide();f.opaque:Hide();w.guardian:Hide()
  for _,t in ipairs(f.pieces)do t:Hide()end
  for _,pool in ipairs({f.stone,f.rails[1],f.rails[2]})do for _,t in ipairs(pool)do t:Hide()end end
  for _,t in pairs(w.plinths)do t:Hide()end
  return
 end
 f:Show();f.opaque:Show();w.guardian:Show()
 for _,t in ipairs(f.pieces)do t:Show()end
 local left=prefs.ability and S.historyWidth+S.gap or 0
 local right=prefs.talent and S.historyWidth+S.gap or 0
 local lx=left>0 and -left-56 or -112
 local rx=w:GetWidth()+(right>0 and right+56 or 112)
 f:ClearAllPoints();f:SetPoint('TOPLEFT',w,'TOPLEFT',lx,56);f:SetPoint('BOTTOMRIGHT',w,'BOTTOMRIGHT',rx-w:GetWidth(),-4)
 tiles(w,f.stone,'Stone',lx+18,34,rx-lx-36,w:GetHeight()+34,'BACKGROUND')
 local mid=w:GetWidth()/2
 tiles(w,f.rails[1],'Rail',lx+80,40,math.max(0,mid-440-(lx+80)),39,'BORDER')
 tiles(w,f.rails[2],'Rail',mid+440,40,math.max(0,rx-80-mid-440),39,'BORDER')
 f.LeftCap:ClearAllPoints();f.LeftCap:SetPoint('TOPLEFT',w,'TOPLEFT',lx,56);f.LeftCap:SetSize(108,104)
 f.RightCap:ClearAllPoints();f.RightCap:SetPoint('TOPRIGHT',w,'TOPLEFT',rx,56);f.RightCap:SetSize(108,104)
 local height=w:GetHeight()-128
 f.LeftPillar:ClearAllPoints();f.LeftPillar:SetPoint('TOPLEFT',w,'TOPLEFT',lx+1,-44);f.LeftPillar:SetSize(53,height)
 f.RightPillar:ClearAllPoints();f.RightPillar:SetPoint('TOPRIGHT',w,'TOPLEFT',rx-1,-44);f.RightPillar:SetSize(53,height)
 for _,kind in ipairs({'ability','talent'}) do
  local t=w.plinths[kind];t:ClearAllPoints()
  if prefs[kind] then S.Sprite(t,kind=='ability' and 'LeftBase' or 'RightBase');t:SetSize(296,84)
  else S.Sprite(t,kind=='ability' and 'LeftBase' or 'RightBase',kind=='ability' and 0 or 216,0,80,84);t:SetSize(80,84) end
  if kind=='ability' then t:SetPoint('BOTTOMLEFT',w,'BOTTOMLEFT',lx,0)
  else t:SetPoint('BOTTOMRIGHT',w,'TOPLEFT',rx,-w:GetHeight()) end
  t:Show()
 end
end

-- Appearance only: no build reads, queue actions, or saved-data migration.
function S.Mode()return R.db and R.db.skin=='clean' and 'clean' or 'titan'end
local function show(region,value)if value then region:Show()else region:Hide()end end
local function showAll(regions,value)for _,region in pairs(regions or {})do show(region,value)end end
function S.Edges(parent,visible)
 if visible and not parent.cleanEdges then
  parent.cleanEdges={}
  for _,side in ipairs({'TOP','BOTTOM','LEFT','RIGHT'})do
   local t=parent:CreateTexture(nil,'OVERLAY');t:SetTexture('Interface\\Buttons\\WHITE8X8')
   t:SetVertexColor(0.27,0.34,0.40,1)
   if side=='TOP' or side=='BOTTOM'then
    t:SetHeight(1);t:SetPoint(side..'LEFT',parent,side..'LEFT',0,0);t:SetPoint(side..'RIGHT',parent,side..'RIGHT',0,0)
   else
    t:SetWidth(1);t:SetPoint('TOP'..side,parent,'TOP'..side,0,0);t:SetPoint('BOTTOM'..side,parent,'BOTTOM'..side,0,0)
   end
   parent.cleanEdges[#parent.cleanEdges+1]=t
  end
 end
 showAll(parent.cleanEdges,visible)
end
function S.StyleButton(b)
 local mode=S.Mode();local clean=mode=='clean'
 if b.skinMode~=mode then
  showAll(b.buttonPieces,not clean);S.Edges(b,clean)
  if b.glow then b.glow:SetVertexColor(clean and 0.35 or 0.88,clean and 0.75 or 0.74,clean and 1 or 0.46,0.12)end
  b.skinMode=mode
 end
 if clean then
  local enabled=b:IsEnabled();b:SetBackdropColor(enabled and 0.075 or 0.045,enabled and 0.10 or 0.055,enabled and 0.13 or 0.065,1)
  for _,t in ipairs(b.cleanEdges)do t:SetVertexColor(enabled and 0.33 or 0.17,enabled and 0.46 or 0.21,enabled and 0.56 or 0.25,1)end
 end
end
function S.StyleRow(b,kind)
 local mode=S.Mode();if b.skinMode==mode then return end
 if mode=='clean'then
  b.box:SetTexture('Interface\\Buttons\\UI-CheckBox-Up');b.box:SetTexCoord(0,1,0,1)
  b.mark:SetTexture('Interface\\Buttons\\UI-CheckBox-Check');b.mark:SetTexCoord(0,1,0,1)
  b.mark:SetVertexColor(kind=='talent' and 0.74 or 0.45,0.82,1,1)
  b.iconFrame:SetBackdropBorderColor(0.32,0.39,0.46,1)
 else
  S.Sprite(b.box,'Unchecked');S.Sprite(b.mark,kind=='ability' and 'CheckedGold' or 'CheckedViolet')
  b.mark:SetVertexColor(1,1,1,1);b.iconFrame:SetBackdropBorderColor(0.88,0.74,0.46,1)
 end
 b.skinMode=mode;b.staticArtReady=true
end
function S.StyleHistoryRow(row)
 local mode=S.Mode();if row.skinMode==mode then return end
 local c=mode=='clean' and {0.32,0.39,0.46} or {0.88,0.74,0.46}
 for _,side in ipairs({'old','new'})do row[side..'Border']:SetBackdropBorderColor(c[1],c[2],c[3],1)end
 if row.rule then row.rule:SetVertexColor(c[1],c[2],c[3],0.22)end
 row.skinMode=mode
end
function S.SetAppearance(w)
 local clean=S.Mode()=='clean'
 showAll(w.inlay,not clean);S.Edges(w,clean)
 local panels={w.historyPanel,w.panels.ability,w.panels.talent,w.panels.ability.footer,w.panels.talent.footer,
  w.historyDrawers.ability,w.historyDrawers.talent}
 for _,p in ipairs(panels)do
  showAll(p.inlay,not clean);show(p.surface,not clean);showAll(p.recess,not clean);S.Edges(p,clean)
 end
 show(w.emblemFrame,not clean)
 w.title:ClearAllPoints();w.title:SetPoint('TOPLEFT',clean and 18 or 67,-7);w.title:SetPoint('TOPRIGHT',-347,-7)
 local c=clean and {0.55,0.70,0.82} or {0.88,0.74,0.46}
 w.headerLine:SetVertexColor(c[1],c[2],c[3],0.45)
 for _,kind in ipairs({'ability','talent'})do
  local p=w.panels[kind];p.scrollIconFrame:SetBackdropBorderColor(c[1],c[2],c[3],1)
  p.budget:SetTextColor(c[1],c[2],c[3])
  for _,b in ipairs(p.rows)do S.StyleRow(b,kind)end
  local drawer=w.historyDrawers[kind];drawer.headerRule:SetVertexColor(c[1],c[2],c[3],0.25)
  for _,row in ipairs(drawer.rows)do S.StyleHistoryRow(row)end
 end
 for _,b in ipairs(R.uiButtons or {})do S.StyleButton(b)end
end
