local R=GrimfallReroll
local backdrop={bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=false,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}}
local inset={bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',tile=false,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}
local panelBackdrop={bgFile='Interface\\Buttons\\WHITE8X8',insets={left=1,right=1,top=1,bottom=1}}
local function panel(frame,size)
    frame:SetBackdrop(panelBackdrop); frame:SetBackdropColor(0.038,0.052,0.062,1)
    R.Skin.Inlay(frame,size or 18)
    frame.surface=frame:CreateTexture(nil,'BACKGROUND');R.Skin.Sprite(frame.surface,'Panel');frame.surface:SetPoint('TOPLEFT',4,-4);frame.surface:SetPoint('BOTTOMRIGHT',-4,4)
end
local colors={ability={0.88,0.67,0.32},talent={0.68,0.55,0.88},gold={0.88,0.74,0.46}}
local function fill(parent,color,alpha,layer)
    local t=parent:CreateTexture(nil,layer or 'BACKGROUND'); t:SetTexture('Interface\\Buttons\\WHITE8X8')
    t:SetVertexColor(color[1],color[2],color[3],alpha or 1); return t
end
local function itemIcon(id)
    local _,_,_,_,_,_,_,_,_,texture=GetItemInfo(id)
    return texture or 'Interface\\Icons\\INV_Scroll_03'
end
-- Own our font objects: other addons may replace the global GameFont styles.
local fonts={}
local function font(name,size,r,g,b,flags)
    local f=CreateFont('RERollerFont'..name)
    R.Presentation:SetFont(f,size,flags)
    f:SetTextColor(r,g,b); f:SetShadowColor(0,0,0,0.85); f:SetShadowOffset(0,-1)
    fonts[name]=f; return f
end
font('Title',30,0.96,0.83,0.57); font('Heading',20,0.96,0.83,0.57)
font('HistoryHeading',17,0.96,0.92,0.81)
font('Body',14,0.91,0.90,0.87); font('Small',12,0.78,0.78,0.76)
font('Muted',12,0.73,0.76,0.79); font('Button',14,0.96,0.85,0.63)
font('ButtonHighlight',14,1,1,1); font('ButtonDisabled',14,0.48,0.48,0.48)
local function label(parent,style)
    local f=parent:CreateFontString(nil,'OVERLAY')
    f:SetFontObject(fonts[style or 'Body']); f:SetJustifyV('MIDDLE'); f:SetJustifyH('LEFT')
    f:SetWordWrap(false)
    return f
end
local function centered(f) f:SetJustifyH('CENTER');f:SetJustifyV('MIDDLE');return f end
local function button(parent,text,width,fn)
    local b=CreateFrame('Button',nil,parent); b:SetSize(width,28); b:SetBackdrop(panelBackdrop); R.Skin.Button(b,false)
    b.sheen=fill(b,{1,1,1},0); b.sheen:SetPoint('TOPLEFT',4,-3); b.sheen:SetPoint('TOPRIGHT',-4,-3); b.sheen:SetHeight(8)
    b.caption=label(b,'Button'); b.caption:SetPoint('CENTER',0,0); b.caption:SetJustifyH('CENTER'); b:SetFontString(b.caption)
    b:SetNormalFontObject(fonts.Button); b:SetHighlightFontObject(fonts.ButtonHighlight); b:SetDisabledFontObject(fonts.ButtonDisabled)
    b:SetPushedTextOffset(1,-1)
    local glow=fill(b,colors.gold,0.12,'HIGHLIGHT'); glow:SetPoint('TOPLEFT',3,-3); glow:SetPoint('BOTTOMRIGHT',-3,3); b:SetHighlightTexture(glow)
    R.uiButtons=R.uiButtons or {}; table.insert(R.uiButtons,b)
    b:SetText(text); b:SetScript('OnClick',fn); return b
end
local function icon(id)
    local _,_,texture=GetSpellInfo(id); return texture or 'Interface\\Icons\\INV_Misc_QuestionMark'
end
local function textureTag(id,size) return '|T'..icon(id)..':'..(size or 20)..'|t ' end
local function styleScroll(scroll)
    local name=scroll:GetName(); local bar=name and _G[name..'ScrollBar']
    if not bar then return end
    bar:SetWidth(8); bar:ClearAllPoints(); bar:SetPoint('TOPLEFT',scroll,'TOPRIGHT',9,-2); bar:SetPoint('BOTTOMLEFT',scroll,'BOTTOMRIGHT',9,2)
    bar:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'}); bar:SetBackdropColor(0.12,0.13,0.14,0.8)
    for _,suffix in ipairs({'ScrollUpButton','ScrollDownButton'}) do
        local b=_G[name..'ScrollBar'..suffix] or bar[suffix]
        if b then b:Hide(); b:EnableMouse(false) end
    end
    bar:SetThumbTexture('Interface\\Buttons\\WHITE8X8')
    local thumb=bar:GetThumbTexture(); if thumb then thumb:SetVertexColor(0.48,0.47,0.42,1); thumb:SetWidth(6); thumb:SetHeight(38) end
end
function R:ShowTooltip(owner,row)
    if not row then return end
    GameTooltip:SetOwner(owner,'ANCHOR_RIGHT')
    local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,'spell:'..row.spellID)
    if not ok then GameTooltip:SetText(row.name) end
    if row.kind=='talent' then GameTooltip:AddLine('Learned rank: '..row.rank,1,0.82,0) end
    local locked=self:Locks(self.spec)[row.key]
    GameTooltip:AddLine(locked and 'Protected. Right-click to unlock.' or 'Left-click: queue reroll. Right-click: protect.',0.9,0.9,0.9,true)
    GameTooltip:Show()
end
function R:RowClick(row,mouse)
    if not row or self.byKey[row.key]~=row or not self:CanEditEntry(row.key) then return end
    if mouse=='RightButton' then
        if self:Locks(self.spec)[row.key] then StaticPopup_Show('GRR_UNLOCK',row.name,nil,{key=row.key,spec=self.spec,context=self.lockContext})
        else self:Lock(row.key) end
    else self:Toggle(row.key) end
end
function R:IsHidingLocked(kind)
    return type(self.db.hideLocked)=='table' and self.db.hideLocked[kind]==true
end
function R:ToggleHideLocked(kind)
    if kind~='ability' and kind~='talent' then return end
    if type(self.db.hideLocked)~='table' then self.db.hideLocked={} end
    self.db.hideLocked[kind]=not self:IsHidingLocked(kind)
    local p=self.window and self.window.panels[kind]
    if p then p.scroll:SetVerticalScroll(0) end
    GameTooltip:Hide()
    self:Render()
end
function R:CreateUI()
    if self.window then return end
    if self.db.layoutRevision~=8 then self.db.width=840;self.db.height=620;self.db.layoutRevision=8 end
    local w=CreateFrame('Frame','GrimfallRerollWindow',UIParent); self.window=w
    w:Hide(); w:SetSize(math.max(840,self.db.width or 840),math.max(620,self.db.height or 620)); w:SetPoint('CENTER',self.db.x or 0,self.db.y or 0)
    w:SetBackdrop(panelBackdrop); w:SetBackdropColor(0.025,0.031,0.038,1); w:SetMovable(true); w:SetResizable(true); w:SetMinResize(840,620); w:SetMaxResize(1300,950)
    w:SetClampedToScreen(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton'); w:SetFrameStrata('DIALOG')
    w:SetScript('OnDragStart',function(self) self:StartMoving() end)
    local function save(self)
        self:StopMovingOrSizing()
        local x,y=self:GetCenter(); local ux,uy=UIParent:GetCenter()
        local scale=self:GetScale() or 1
        if x and ux then R.db.x=x*scale-ux; R.db.y=y*scale-uy end
        R.db.width=self:GetWidth(); R.db.height=self:GetHeight()
        R:LayoutHistory()
    end
    w:SetScript('OnDragStop',save)
    w:SetScript('OnHide',function() R:Stop('Window closed; remaining rerolls stopped.'); GameTooltip:Hide() end)
    w.headerSurface=CreateFrame('Frame',nil,w); w.headerSurface:SetPoint('TOPLEFT',3,-3); w.headerSurface:SetPoint('TOPRIGHT',-3,-3); w.headerSurface:SetHeight(50); w.headerSurface:SetBackdrop(panelBackdrop); w.headerSurface:SetBackdropColor(0.028,0.039,0.047,1)
    w.header=fill(w,{0.025,0.035,0.045},1); w.header:SetPoint('TOPLEFT',13,-13); w.header:SetPoint('TOPRIGHT',-13,-13); w.header:SetHeight(50)
    w.emblemFrame=CreateFrame('Frame',nil,w.headerSurface); w.emblemFrame:SetSize(40,42); w.emblemFrame:SetPoint('TOPLEFT',15,-4); w.emblemFrame:SetBackdrop(inset); w.emblemFrame:SetBackdropColor(0.06,0.05,0.035,1); w.emblemFrame:SetBackdropBorderColor(0,0,0,0)
    w.emblem=w.emblemFrame:CreateTexture(nil,'ARTWORK'); R.Skin.Sprite(w.emblem,'Dice'); w.emblem:SetAllPoints()
    w.title=label(w.headerSurface,'Title'); w.title:SetPoint('TOPLEFT',67,-7); w.title:SetPoint('TOPRIGHT',-347,-7); w.title:SetHeight(32); w.title:SetText('RE: Roller by Vash')
    w.tagline=label(w,'Small'); w.tagline:SetPoint('TOPLEFT',88,-53); w.tagline:SetText('Choose what changes. Protect what matters.'); w.tagline:Hide()
    w.headerLine=fill(w,colors.gold,0.45); w.headerLine:SetPoint('TOPLEFT',4,-54); w.headerLine:SetPoint('TOPRIGHT',-4,-54); w.headerLine:SetHeight(1)
    local close=button(w.headerSurface,'X',28,function() w:Hide() end); close:SetPoint('TOPRIGHT',-13,-9)
    w.specBadge=CreateFrame('Frame',nil,w.headerSurface);w.specBadge:SetSize(194,40);w.specBadge:SetPoint('RIGHT',-143,0);w.specBadge:EnableMouse(true)
    w.specIcon=w.specBadge:CreateTexture(nil,'ARTWORK');w.specIcon:SetSize(30,30);w.specIcon:SetPoint('LEFT',6,0);w.specIcon:SetTexCoord(0.07,0.93,0.07,0.93)
    w.specLabel=centered(label(w.specBadge,'Muted'));w.specLabel:SetPoint('TOPLEFT',42,-1);w.specLabel:SetPoint('TOPRIGHT',-4,-1);w.specLabel:SetHeight(17);w.specLabel:SetText('Active Spec')
    w.spec=centered(label(w.specBadge,'Body')); w.spec:SetPoint('TOPLEFT',42,-18);w.spec:SetPoint('TOPRIGHT',-4,-18);w.spec:SetHeight(21)
    w.specBadge:SetScript('OnEnter',function(self)
        local s=R.Presentation:CurrentSpec();GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText(s.name,1,0.85,0.55)
        GameTooltip:AddLine(s.verified and 'Current Grimfall specialization' or 'Spec details are not available from the client yet.',0.85,0.87,0.9,true);GameTooltip:Show()
    end)
    w.specBadge:SetScript('OnLeave',function() GameTooltip:Hide() end)
    w.refresh=button(w.headerSurface,'Refresh',80,function() if not R.pending and not R.running then R:Refresh() end end); w.refresh:SetPoint('TOPRIGHT',-51,-9)
    w.panels={}
    for _,kind in ipairs({'ability','talent'}) do
        local p=CreateFrame('Frame',nil,w); w.panels[kind]=p; p.accent=colors[kind]; panel(p,16)
        p.ribbon=fill(p,p.accent,0.15); p.ribbon:SetPoint('TOPLEFT',4,-4); p.ribbon:SetPoint('TOPRIGHT',-4,-4); p.ribbon:SetHeight(34); p.ribbon:Hide()
        p.line=fill(p,p.accent,0.8); p.line:SetPoint('TOPLEFT',8,-3); p.line:SetPoint('TOPRIGHT',-8,-3); p.line:SetHeight(1); p.line:SetVertexColor(unpack(colors.gold)); p.line:Hide()
        p.badge=p:CreateTexture(nil,'ARTWORK'); p.badge:SetSize(22,22); p.badge:SetPoint('TOPLEFT',14,-12); p.badge:SetTexture(itemIcon(kind=='ability' and 640 or 639)); p.badge:SetTexCoord(0.07,0.93,0.07,0.93); p.badge:Hide()
        p.title=label(p,'Heading'); p.title:SetPoint('TOPLEFT',16,-10); p.title:SetHeight(26); p.title:SetTextColor(0.94,0.93,0.87); p.title:SetText(kind=='ability' and 'Abilities' or 'Talents')
        p.hideLockedControl=CreateFrame('Frame',nil,p);p.hideLockedControl:SetSize(104,26);p.hideLockedControl:SetPoint('TOPLEFT',116,-10);p.hideLockedControl:EnableMouse(true)
        p.hideLockedToggle=CreateFrame('CheckButton',nil,p.hideLockedControl,'UICheckButtonTemplate');p.hideLockedToggle:SetSize(22,22);p.hideLockedToggle:SetPoint('LEFT',0,0)
        p.hideLockedText=label(p.hideLockedControl,'Small');p.hideLockedText:SetPoint('LEFT',p.hideLockedToggle,'RIGHT',2,0);p.hideLockedText:SetSize(80,26);p.hideLockedText:SetText('Hide Locked')
        p.hideLockedToggle:GetCheckedTexture():SetVertexColor(unpack(p.accent))
        p.hideLockedToggle:SetScript('OnClick',function() R:ToggleHideLocked(kind) end)
        p.hideLockedControl:SetScript('OnMouseUp',function(_,mouse) if mouse=='LeftButton' then R:ToggleHideLocked(kind) end end)
        local function filterTooltip(owner)
            GameTooltip:SetOwner(owner,'ANCHOR_TOP');GameTooltip:SetText('Hide Locked',1,0.85,0.55)
            GameTooltip:AddLine('Hide protected '..(kind=='ability' and 'abilities' or 'talents')..' in this list. This does not unlock them or change reroll history.',0.9,0.91,0.92,true)
            GameTooltip:AddLine('Uncheck to show them again. This choice is saved.',0.75,0.78,0.81,true);GameTooltip:Show()
        end
        for _,control in ipairs({p.hideLockedControl,p.hideLockedToggle}) do
            control:SetScript('OnEnter',filterTooltip);control:SetScript('OnLeave',function() GameTooltip:Hide() end)
        end
        p.controlWidth=164
        p.count=centered(label(p,'Small')); p.count:SetPoint('TOPRIGHT',-14,-10); p.count:SetSize(p.controlWidth,26)
        p.historyControl=CreateFrame('Frame',nil,p);p.historyControl:SetSize(p.controlWidth,30);p.historyControl:SetPoint('TOPRIGHT',-14,-40)
        p.historyToggle=CreateFrame('CheckButton',nil,p.historyControl,'UICheckButtonTemplate'); p.historyToggle:SetSize(26,26); p.historyToggle:SetPoint('LEFT',35,0)
        p.historyToggle:SetScript('OnClick',function() R:ToggleHistory(kind) end)
        p.historyText=label(p.historyControl,'Body'); p.historyText:SetPoint('LEFT',p.historyToggle,'RIGHT',3,0);p.historyText:SetSize(65,26);p.historyText:SetText('History')
        p.historyControl:EnableMouse(true);p.historyControl:SetScript('OnMouseUp',function(_,mouse) if mouse=='LeftButton' then R:ToggleHistory(kind) end end)
        p.historyToggle:GetCheckedTexture():SetVertexColor(unpack(p.accent))
        -- Avoid anonymous InputBoxTemplate texture-name collisions on this 3.3.5 client.
        p.search=CreateFrame('EditBox',nil,p); p.search:SetAutoFocus(false); p.search:SetHeight(30); p.search:SetFontObject(fonts.Body)
        p.search:SetBackdrop(inset); p.search:SetBackdropColor(0.035,0.04,0.052,1); p.search:SetBackdropBorderColor(0.24,0.26,0.29,1); p.search:SetTextInsets(9,9,0,0)
        p.search:SetPoint('TOPLEFT',14,-40); p.search:SetPoint('TOPRIGHT',-190,-40); p.search:SetText('')
        p.placeholder=label(p.search,'Muted'); p.placeholder:SetPoint('LEFT',9,0); p.placeholder:SetHeight(20); p.placeholder:SetText(kind=='ability' and 'Search abilities...' or 'Search talents...')
        p.search:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
        p.search:SetScript('OnTextChanged',function() R:Render() end)
        p.search:SetScript('OnEnterPressed',function(self) self:ClearFocus() end)
        p.hint=label(p,'Muted'); p.hint:SetPoint('TOPLEFT',14,-76); p.hint:SetHeight(18); p.hint:SetText('Click to queue   |   Right-click to protect'); p.hint:Hide()
        p.scroll=CreateFrame('ScrollFrame','GrimfallRerollScroll_'..kind,p,'UIPanelScrollFrameTemplate')
        p.scroll:SetPoint('TOPLEFT',12,-76); p.scroll:SetPoint('BOTTOMRIGHT',-30,86)
        p.canvas=CreateFrame('Frame',nil,p.scroll); p.canvas:SetSize(360,1); p.scroll:SetScrollChild(p.canvas)
        p.empty=centered(label(p.scroll,'Small'));p.empty:SetPoint('TOPLEFT',12,-20);p.empty:SetPoint('TOPRIGHT',-12,-20);p.empty:SetHeight(72);p.empty:SetWordWrap(true);p.empty:Hide()
        p.rows={}
        p.footer=CreateFrame('Frame',nil,p); p.footer:SetPoint('BOTTOMLEFT',6,7); p.footer:SetPoint('BOTTOMRIGHT',-6,7); p.footer:SetHeight(78)
        panel(p.footer,10); p.footer:SetBackdropColor(0.046,0.059,0.066,1)
        p.scrollIconFrame=CreateFrame('Frame',nil,p.footer); p.scrollIconFrame:SetSize(48,48); p.scrollIconFrame:SetPoint('LEFT',10,0); p.scrollIconFrame:SetBackdrop(inset); p.scrollIconFrame:SetBackdropColor(0.02,0.02,0.02,1); p.scrollIconFrame:SetBackdropBorderColor(unpack(colors.gold))
        p.scrollIcon=p.scrollIconFrame:CreateTexture(nil,'ARTWORK'); p.scrollIcon:SetPoint('TOPLEFT',4,-4); p.scrollIcon:SetPoint('BOTTOMRIGHT',-4,4); p.scrollIcon:SetTexture(itemIcon(kind=='ability' and 640 or 639))
        p.budget=label(p.footer,'Body'); p.budget:SetPoint('TOPLEFT',64,-10); p.budget:SetPoint('TOPRIGHT',-184,-10); p.budget:SetHeight(22); p.budget:SetTextColor(unpack(colors.gold))
        p.available=label(p.footer,'Body'); p.available:SetPoint('BOTTOMLEFT',64,10); p.available:SetPoint('BOTTOMRIGHT',-184,10);p.available:SetHeight(24); p.available:SetJustifyH('LEFT')
        p.cost=centered(label(p.footer,'Small')); p.cost:SetPoint('TOPRIGHT',-8,-10); p.cost:SetSize(p.controlWidth,22)
        p.start=button(p.footer,kind=='ability' and 'Reroll Abilities' or 'Reroll Talents',p.controlWidth,function() R:Start(kind) end); p.start:SetPoint('BOTTOMRIGHT',-8,8)
        p.start.accent=colors.gold; R.Skin.Button(p.start,true); p.start:SetHeight(32)
    end
    w.status=label(w,'Small'); w.status:SetPoint('BOTTOMLEFT',18,108); w.status:SetPoint('BOTTOMRIGHT',-18,108); w.status:SetHeight(16); w.status:SetWordWrap(true)
    w.historyPanel=CreateFrame('Frame',nil,w); w.historyPanel:SetPoint('BOTTOMLEFT',6,6); w.historyPanel:SetPoint('BOTTOMRIGHT',-6,6); w.historyPanel:SetHeight(100); panel(w.historyPanel,16)
    w.historyTitle=label(w.historyPanel,'Body'); w.historyTitle:SetPoint('TOPLEFT',12,-8); w.historyTitle:SetHeight(20); w.historyTitle:SetTextColor(unpack(colors.gold)); w.historyTitle:SetText('Recent Transformations')
    w.announcementHint=label(w.historyPanel,'Muted'); w.announcementHint:SetPoint('TOPRIGHT',-12,-8); w.announcementHint:SetHeight(20); w.announcementHint:SetText('Latest 3  |  Full history on the sides'); w.announcementHint:Hide()
    w.announcementScroll=CreateFrame('ScrollFrame','RERollerAnnouncementScroll',w.historyPanel,'UIPanelScrollFrameTemplate')
    w.announcementScroll:SetPoint('TOPLEFT',12,-32); w.announcementScroll:SetHeight(58); w.announcementScroll:EnableMouseWheel(true)
    w.announcementCanvas=CreateFrame('Frame',nil,w.announcementScroll); w.announcementCanvas:SetSize(1,1); w.announcementScroll:SetScrollChild(w.announcementCanvas)
    local function scrollAnnouncements(delta)
        local maximum=math.max(0,w.announcementCanvas:GetHeight()-w.announcementScroll:GetHeight())
        w.announcementScroll:SetVerticalScroll(math.max(0,math.min(maximum,(w.announcementScroll:GetVerticalScroll() or 0)-delta*28)))
    end
    w.announcementScroll:SetScript('OnMouseWheel',function(_,delta) scrollAnnouncements(delta) end)
    w.historyRows={}
    for i=1,3 do
        local row=CreateFrame('Frame',nil,w.announcementCanvas); w.historyRows[i]=row
        row:EnableMouse(true); row:EnableMouseWheel(true); row:SetScript('OnMouseWheel',function(_,delta) scrollAnnouncements(delta) end)
        row.text=label(row,'Body'); row.text:SetPoint('TOPLEFT',8,-5); row.text:SetWordWrap(true); if row.text.SetNonSpaceWrap then row.text:SetNonSpaceWrap(true) end; row.text:SetJustifyV('TOP'); row.text:SetSpacing(2)
        row.shade=fill(row,{1,1,1},i%2==1 and 0.025 or 0); row.shade:SetAllPoints()
        row.stripe=fill(row,colors.gold,0.8); row.stripe:SetPoint('TOPLEFT',0,-2); row.stripe:SetPoint('BOTTOMLEFT',0,2); row.stripe:SetWidth(2); row.stripe:Hide()
        row.kind=label(row,'Muted'); row.kind:SetPoint('TOPRIGHT',-8,-5); row.kind:SetSize(64,20); row.kind:SetJustifyH('RIGHT')
        row:SetScript('OnEnter',function(self)
            if not self.record then return end
            GameTooltip:SetOwner(self,'ANCHOR_TOP'); GameTooltip:SetText(self.record.oldName,1,0.82,0)
            GameTooltip:AddLine('Replaced with '..self.record.newName,1,1,1,true); GameTooltip:Show()
        end)
        row:SetScript('OnLeave',function() GameTooltip:Hide() end)
    end
    w.footerBackground=fill(w,{0.025,0.031,0.038},1,'ARTWORK'); w.footerBackground:SetPoint('BOTTOMLEFT',3,3); w.footerBackground:SetPoint('BOTTOMRIGHT',-3,3); w.footerBackground:SetHeight(33); w.footerBackground:Hide()
    w.fast=CreateFrame('CheckButton',nil,w,'UICheckButtonTemplate'); w.fast:SetSize(24,24); w.fast:SetPoint('BOTTOMRIGHT',-154,69)
    w.fastText=label(w.fast,'Small'); w.fastText:SetPoint('LEFT',w.fast,'RIGHT',2,0); w.fastText:SetHeight(24); w.fastText:SetText('Quick Animation')
    w.fast:SetScript('OnClick',function(self) R.db.fast=self:GetChecked() and true or false end)
    w.clear=button(w,'Clear',64,function() R:Clear() end); w.clear:SetPoint('BOTTOMRIGHT',-16,18)
    w.stop=button(w,'Stop',64,function() R:Stop('Stopped. Any sent request is still being checked.') end); w.stop:SetPoint('RIGHT',w.clear,'LEFT',-6,0)
    w.pause=button(w,'Pause',76,function() R:Pause() end); w.pause:SetPoint('RIGHT',w.stop,'LEFT',-6,0)
    local grip=CreateFrame('Button',nil,w); grip:SetSize(16,16); grip:SetPoint('BOTTOMRIGHT',-7,7)
    grip:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up'); grip:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
    grip:SetScript('OnMouseDown',function() w:StartSizing('BOTTOMRIGHT') end); grip:SetScript('OnMouseUp',function() save(w) end)
    self:CreateHistoryUI()
    self.Skin.Apply(w)
    local function layout()
        local half=(w:GetWidth()-24)/2
        local a,t=w.panels.ability,w.panels.talent
        a:SetPoint('TOPLEFT',10,-56); a:SetPoint('BOTTOMLEFT',10,126); a:SetWidth(half)
        t:SetPoint('TOPRIGHT',-10,-56); t:SetPoint('BOTTOMRIGHT',-10,126); t:SetWidth(half)
        for _,p in pairs(w.panels) do p.canvas:SetWidth(half-44) end
        R:LayoutHistory()
        R:Render()
    end
    w:SetScript('OnSizeChanged',layout); layout()
    w:SetScript('OnUpdate',function()
        if not w.nextSpecUpdate or GetTime()>=w.nextSpecUpdate then R:UpdateSpecDisplay();w.nextSpecUpdate=GetTime()+1 end
    end)
    w:HookScript('OnShow',function() R:LayoutHistory(); R:Render() end)
    w:RegisterEvent('DISPLAY_SIZE_CHANGED'); w:RegisterEvent('UI_SCALE_CHANGED')
    w:SetScript('OnEvent',function() R:LayoutHistory(); R:Render() end)
    UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,'GrimfallRerollWindow')
    StaticPopupDialogs.GRR_UNLOCK={text='Unlock %s for rerolling?',button1=YES,button2=CANCEL,timeout=0,whileDead=1,hideOnEscape=1,
        OnAccept=function(self,data) data=data or self.data; if data and data.context then R:Unlock(data.key,data.spec,data.context) end end}
end
function R:UpdateSpecDisplay()
    local w=self.window;if not w or not w:IsShown() then return end
    local s=self.Presentation:CurrentSpec();w.spec:SetText(s.name);w.specIcon:SetTexture(s.icon)
end
function R:Render()
    local w=self.window; if not w or not w:IsShown() or self.rendering then return end
    local started=debugprofilestop and debugprofilestop() or 0
    self.rendering=true
    self:UpdateSpecDisplay()
    local totals=self:Totals()
    local locks=self.spec and self:Locks(self.spec) or {}
    for _,kind in ipairs({'ability','talent'}) do
        local p=w.panels[kind]; local search=string.lower(p.search:GetText() or ''); local index,total=0,0
        local hideLocked=self:IsHidingLocked(kind);p.hideLockedToggle:SetChecked(hideLocked)
        styleScroll(p.scroll)
        if search=='' then p.placeholder:Show() else p.placeholder:Hide() end
        for _,entry in ipairs(self.rows) do if entry.kind==kind then
            total=total+1
            local locked=locks[entry.key]
            if not (hideLocked and locked) and (search=='' or string.find(string.lower(entry.name),search,1,true)) then
                index=index+1; local b=p.rows[index]
                if not b then
                    b=CreateFrame('Button',nil,p.canvas); p.rows[index]=b; b:SetHeight(54); b:RegisterForClicks('LeftButtonUp','RightButtonUp')
                    b.shade=b:CreateTexture(nil,'BACKGROUND'); b.shade:SetAllPoints(); b.shade:SetTexture('Interface\\Buttons\\WHITE8X8')
                    b.stripe=fill(b,p.accent,1,'ARTWORK'); b.stripe:SetPoint('TOPLEFT',0,-3); b.stripe:SetPoint('BOTTOMLEFT',0,3); b.stripe:SetWidth(2)
                    b:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight'); b:GetHighlightTexture():SetBlendMode('ADD')
                    b.slot=CreateFrame('Frame',nil,b); b.slot:SetSize(24,28); b.slot:SetPoint('LEFT',8,0)
                    b.box=b.slot:CreateTexture(nil,'ARTWORK'); b.box:SetSize(24,24); b.box:SetPoint('CENTER',b.slot,'CENTER',0,0)
                    b.mark=b.slot:CreateTexture(nil,'OVERLAY'); b.mark:SetSize(24,24); b.mark:SetPoint('CENTER',b.slot,'CENTER',0,0)
                    b.lock=b.slot:CreateTexture(nil,'OVERLAY'); b.lock:SetSize(18,22); b.lock:SetPoint('CENTER',b.slot,'CENTER',0,0); R.Skin.Sprite(b.lock,'Lock')
                    b.iconFrame=CreateFrame('Frame',nil,b); b.iconFrame:SetSize(44,44); b.iconFrame:SetPoint('LEFT',42,0); b.iconFrame:SetBackdrop(inset); b.iconFrame:SetBackdropColor(0.02,0.02,0.02,1); b.iconFrame:SetBackdropBorderColor(unpack(colors.gold))
                    b.icon=b.iconFrame:CreateTexture(nil,'ARTWORK'); b.icon:SetSize(38,38); b.icon:SetPoint('CENTER',b.iconFrame,'CENTER',0,0); b.icon:SetTexCoord(0.07,0.93,0.07,0.93)
                    b.name=label(b,'Body'); b.name:SetPoint('LEFT',b.iconFrame,'RIGHT',12,0); b.name:SetPoint('RIGHT',-5,0); b.name:SetHeight(24)
                    b:SetScript('OnClick',function(self,mouse) R:RowClick(self.entry,mouse) end)
                    b:SetScript('OnEnter',function(self) R:ShowTooltip(self,self.entry) end)
                    b:SetScript('OnLeave',function() GameTooltip:Hide() end)
                end
                if b.entry~=entry and GameTooltip:IsOwned(b) then GameTooltip:Hide() end
                b.entry=entry; b:SetPoint('TOPLEFT',0,-(index-1)*54); b:SetWidth(p.canvas:GetWidth()); b:Show()
                b.shade:SetVertexColor(1,1,1,index%2==0 and 0.035 or 0.015)
                R.Skin.Sprite(b.box,'Unchecked')
                R.Skin.Sprite(b.mark,kind=='ability' and 'CheckedGold' or 'CheckedViolet'); b.mark:SetVertexColor(1,1,1,1)
                if locked then b.box:Hide(); b.mark:Hide(); b.lock:Show()
                else b.box:Show(); b.lock:Hide(); if self.selected[entry.key] then b.mark:Show() else b.mark:Hide() end end
                b.icon:SetTexture(entry.icon or icon(entry.spellID)); b.name:SetText(entry.name..(entry.kind=='talent' and (' ('..entry.rank..')') or ''))
                local selected=self.selected[entry.key] and not locked
                if locked then b.name:SetTextColor(0.86,0.86,0.84); b.icon:SetVertexColor(0.9,0.9,0.9,1)
                elseif selected then b.name:SetTextColor(unpack(p.accent)); b.icon:SetVertexColor(1,1,1,1)
                else b.name:SetTextColor(0.92,0.91,0.87); b.icon:SetVertexColor(1,1,1,1) end
                if selected then b.stripe:Show(); b.shade:SetVertexColor(p.accent[1],p.accent[2],p.accent[3],0.05) else b.stripe:Hide() end
            end
        end end
        for i=index+1,#p.rows do
            local b=p.rows[i];if GameTooltip:IsOwned(b) then GameTooltip:Hide() end
            b.entry=nil;b:Hide()
        end
        p.canvas:SetHeight(math.max(1,index*54)); p.count:SetText(index==total and (total..' learned') or (index..' / '..total..' shown'))
        p.scroll:UpdateScrollChildRect()
        local viewKey=tostring(self.spec)..'\001'..search..'\001'..tostring(hideLocked)
        local offset=p.filterViewKey==viewKey and (p.scroll:GetVerticalScroll() or 0) or 0
        p.filterViewKey=viewKey
        p.scroll:SetVerticalScroll(math.max(0,math.min(offset,math.max(0,p.canvas:GetHeight()-p.scroll:GetHeight()))))
        if index==0 then
            local plural=kind=='ability' and 'abilities' or 'talents'
            local message=total==0 and ('No learned '..plural..' to display.')
                or (search~='' and ('No '..(hideLocked and 'unlocked ' or '')..plural..' match your search.'..(hideLocked and '\nClear search or uncheck Hide Locked.' or '\nTry a different search.')))
                or ('All '..plural..' are locked.\nUncheck Hide Locked to show them.')
            p.empty:SetText(message);p.empty:Show()
        else p.empty:Hide() end
        local scrollName=kind=='ability' and 'Scroll of Destiny' or 'Scroll of Reshaping'; local n=self.Client:Count(kind)
        p.budget:SetText(scrollName); p.available:SetText((n or '?')..' in bags')
        p.available:SetTextColor(n and n>0 and 0.80 or 0.85,n and n>0 and 0.85 or 0.54,n and n>0 and 0.72 or 0.43)
        p.cost:SetText(totals[kind]==0 and 'Nothing queued' or (totals[kind]..' queued / '..totals[kind]..' scrolls'))
        local enough=n and n>=totals[kind]
        p.cost:SetTextColor(enough and 0.9 or 1,enough and 0.85 or 0.3,enough and 0.7 or 0.25)
        if self.ready and not self.running and not self.pending and totals[kind]>0 and enough then p.start:Enable() else p.start:Disable() end
    end
    w.status:SetText(self.status or '')
    self:RenderAnnouncements()
    self:RenderHistory()
    styleScroll(w.announcementScroll)
    w.fast:SetChecked(self.db.fast)
    local busy=self.running or self.pending
    if busy then w.clear:Disable(); w.refresh:Disable(); w.fast:Disable() else w.clear:Enable(); w.refresh:Enable(); w.fast:Enable() end
    if self.running then w.pause:Enable() else w.pause:Disable() end
    if busy then w.stop:Enable() else w.stop:Disable() end
    w.pause:SetText(self.paused and 'Resume' or 'Pause')
    for _,b in ipairs(self.uiButtons or {}) do
        local c=b.accent or colors.gold
        local enabled=b:IsEnabled()
        b:SetBackdropColor(enabled and 0.085 or 0.08,enabled and 0.09 or 0.085,enabled and 0.095 or 0.10,1)
        for _,t in ipairs(b.buttonPieces or {}) do t:SetVertexColor(enabled and 1 or 0.45,enabled and 1 or 0.45,enabled and 1 or 0.45,1) end
        b:SetBackdropBorderColor(enabled and c[1]*0.75 or 0.24,enabled and c[2]*0.75 or 0.25,enabled and c[3]*0.75 or 0.28,1)
    end
    self.rendering=false
    self:MeasureWork('render',started)
end
-- Read-only side drawers: the existing confirmed history remains authoritative.
local historyRowHeight=142
local historyWidth=R.Skin.historyWidth
function R:ToggleHistory(kind)
    if kind~='ability' and kind~='talent' then return end
    self.db.historyPanels=self.db.historyPanels or {}
    self.db.historyPanels[kind]=not self.db.historyPanels[kind]
    self:LayoutHistory(); self:Render()
end
function R.HistoryFit(width,height,screenWidth,screenHeight,left,right,x,y,top,bottom)
    top=top or 0; bottom=bottom or 0
    local scale=math.min(1,math.max(1,screenWidth-32)/(width+left+right),math.max(1,screenHeight-32)/(height+top+bottom))
    local minX=-screenWidth/2+16+(width/2+left)*scale
    local maxX=screenWidth/2-16-(width/2+right)*scale
    local minY=-screenHeight/2+16+(height/2+bottom)*scale
    local maxY=screenHeight/2-16-(height/2+top)*scale
    return scale,math.max(minX,math.min(maxX,x or 0)),math.max(minY,math.min(maxY,y or 0))
end
function R:LayoutHistory()
    local w=self.window; if not w or not w.historyDrawers or self.fittingHistory then return end
    self.fittingHistory=true
    local prefs=self.db.historyPanels or {}
    for _,kind in ipairs({'ability','talent'}) do
        local p=w.historyDrawers[kind]; local opened=prefs[kind]
        p:SetHeight(math.max(300,w:GetHeight()-98)); p.scroll:SetHeight(p:GetHeight()-96)
        if opened then p:Show() else p:Hide() end
        w.panels[kind].historyToggle:SetChecked(opened and true or false)
    end
    local scale,x,y=self.HistoryFit(w:GetWidth(),w:GetHeight(),UIParent:GetWidth(),UIParent:GetHeight(),
        (prefs.ability and historyWidth+self.Skin.gap or 0)+self.Skin.outset,
        (prefs.talent and historyWidth+self.Skin.gap or 0)+self.Skin.outset,
        self.db.x,self.db.y,self.Skin.top,self.Skin.bottom)
    self.Skin.Layout(w,prefs)
    w:SetScale(scale); w:ClearAllPoints(); w:SetPoint('CENTER',UIParent,'CENTER',x/scale,y/scale)
    self.fittingHistory=false
end
function R:ScrollHistory(p,value)
    local maxScroll=math.max(0,p.canvas:GetHeight()-p.scroll:GetHeight())
    p.scroll:SetVerticalScroll(math.max(0,math.min(maxScroll,value)))
end
function R:CreateHistoryUI()
    local w=self.window; w.historyDrawers={}
    for _,kind in ipairs({'ability','talent'}) do
        local p=CreateFrame('Frame',nil,w); w.historyDrawers[kind]=p; p.kind=kind; p.rows={}; p.records={}
        p:SetWidth(historyWidth); panel(p,20);R.Skin.Recess(p); p:EnableMouse(true)
        if kind=='ability' then p:SetPoint('TOPRIGHT',w,'TOPLEFT',-R.Skin.gap,-14)
        else p:SetPoint('TOPLEFT',w,'TOPRIGHT',R.Skin.gap,-14) end
        p.ribbon=fill(p,colors[kind],0.15); p.ribbon:SetPoint('TOPLEFT',4,-4); p.ribbon:SetPoint('TOPRIGHT',-4,-4); p.ribbon:SetHeight(36); p.ribbon:Hide()
        p.title=centered(label(p,'HistoryHeading')); p.title:SetPoint('TOPLEFT',14,-12);p.title:SetPoint('TOPRIGHT',-44,-12); p.title:SetHeight(26); p.title:SetText(kind=='ability' and 'Ability History' or 'Talent History')
        p.close=button(p,'X',26,function() R:ToggleHistory(kind) end); p.close:SetPoint('TOPRIGHT',-9,-10)
        p.count=label(p,'Muted'); p.count:SetPoint('TOPLEFT',16,-44);p.count:SetWidth(historyWidth-99); p.count:SetHeight(22)
        p.headerRule=fill(p,colors.gold,0.25,'BORDER');p.headerRule:SetPoint('TOPLEFT',14,-72);p.headerRule:SetPoint('TOPRIGHT',-14,-72);p.headerRule:SetHeight(1)
        p.scroll=CreateFrame('ScrollFrame','RERollerHistoryScroll_'..kind,p,'UIPanelScrollFrameTemplate')
        p.scroll:SetPoint('TOPLEFT',14,-78); p.scroll:SetWidth(historyWidth-48); p.scroll:EnableMouseWheel(true)
        p.canvas=CreateFrame('Frame',nil,p.scroll); p.canvas:SetSize(historyWidth-48,1); p.scroll:SetScrollChild(p.canvas)
        p.scroll:SetScript('OnMouseWheel',function(self,delta) R:ScrollHistory(p,(self:GetVerticalScroll() or 0)-delta*historyRowHeight) end)
        p.empty=label(p.scroll,'Small'); p.empty:SetPoint('TOPLEFT',8,-12); p.empty:SetWidth(historyWidth-66); p.empty:SetHeight(54); p.empty:SetWordWrap(true); p.empty:SetText('No confirmed '..(kind=='ability' and 'ability' or 'talent')..' rerolls saved yet.')
        p.footer=label(p,'Muted'); p.footer:SetPoint('BOTTOMLEFT',12,12); p.footer:SetHeight(18); p.footer:SetText('Last 100 rolls total'); p.footer:Hide()
        p.newest=button(p,'Newest',62,function() R:ScrollHistory(p,0) end); p.newest:SetPoint('TOPRIGHT',-14,-41);p.newest:SetHeight(26)
        p:Hide()
    end
end
function R:ShowHistorySpellTooltip(owner,record,which)
    if not record then return end
    local id=tonumber(record[which..'ID']);local name=record[which..'Name'] or 'Unknown'
    GameTooltip:SetOwner(owner,record.kind=='talent' and 'ANCHOR_LEFT' or 'ANCHOR_RIGHT')
    GameTooltip:ClearLines()
    local loaded=false
    if id and id>0 and id%1==0 then
        local known,spellName=pcall(GetSpellInfo,id)
        if known and spellName then loaded=pcall(GameTooltip.SetHyperlink,GameTooltip,'spell:'..id) end
    end
    if not loaded then
        GameTooltip:SetText(name,1,0.85,0.55)
        GameTooltip:AddLine('Spell details unavailable for this saved result.',0.75,0.78,0.81,true)
    end
    GameTooltip:AddLine(' ',1,1,1)
    GameTooltip:AddLine(which=='old' and 'Rolled Away' or 'Rolled Into',unpack(colors[record.kind] or colors.gold))
    GameTooltip:AddLine((which=='old' and 'Replaced with: ' or 'Replaced: ')..(record[which=='old' and 'newName' or 'oldName'] or 'Unknown'),0.90,0.91,0.92,true)
    if record.at then GameTooltip:AddLine(date('%Y-%m-%d %H:%M',record.at),0.73,0.76,0.79) end
    GameTooltip:Show()
end
function R:RenderHistory()
    local w=self.window; if not w.historyDrawers then return end
    local history=self.character.history or {}
    -- Records are immutable and capped at 100. Status/bag/selection changes
    -- must not reset hundreds of textures and text regions in the drawers.
    if w.renderedHistory==history and w.renderedHistoryCount==#history and w.renderedHistoryFirst==history[1] and w.renderedHistoryLast==history[#history] then
        for _,p in pairs(w.historyDrawers) do self:ScrollHistory(p,p.scroll:GetVerticalScroll() or 0) end
        return
    end
    for _,kind in ipairs({'ability','talent'}) do
        local p=w.historyDrawers[kind]
        styleScroll(p.scroll)
        local offset=p.scroll:GetVerticalScroll() or 0
        local oldTop=offset>0 and p.records[math.floor(offset/historyRowHeight)+1]
        local records={}
        for _,h in ipairs(self.character.history or {}) do if h.kind==kind then records[#records+1]=h end end
        -- Preserve the visible record while reviewing older rolls and new results arrive.
        if oldTop then for i,h in ipairs(records) do if h==oldTop then offset=(i-1)*historyRowHeight+offset%historyRowHeight; break end end end
        p.records=records
        p.count:SetText(#records..' Rerolls Saved')
        for i,h in ipairs(records) do
            local row=p.rows[i]
            if not row then
                row=CreateFrame('Frame',nil,p.canvas); p.rows[i]=row; row:SetSize(historyWidth-48,historyRowHeight); row:EnableMouse(true); row:EnableMouseWheel(true)
                row.shade=fill(row,{1,1,1},0); row.shade:SetPoint('TOPLEFT',0,-2); row.shade:SetPoint('BOTTOMRIGHT',0,2)
                row.when=centered(label(row,'Muted')); row.when:SetPoint('TOPLEFT',4,-3);row.when:SetPoint('TOPRIGHT',-4,-3); row.when:SetHeight(18)
                for _,which in ipairs({'old','new'}) do
                    local side=which
                    local hit=CreateFrame('Frame',nil,row);row[side..'Hit']=hit;hit:SetPoint('TOPLEFT',4,side=='old' and -26 or -84);hit:SetSize(historyWidth-56,48);hit:EnableMouse(true);hit:EnableMouseWheel(true)
                    hit:SetScript('OnEnter',function(self) R:ShowHistorySpellTooltip(self,row.record,side) end)
                    hit:SetScript('OnLeave',function() GameTooltip:Hide() end)
                    hit:SetScript('OnHide',function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
                    hit:SetScript('OnMouseWheel',function(_,delta) GameTooltip:Hide();R:ScrollHistory(p,(p.scroll:GetVerticalScroll() or 0)-delta*historyRowHeight) end)
                end
                row.oldBorder=CreateFrame('Frame',nil,row.oldHit); row.oldBorder:SetPoint('LEFT',0,0); row.oldBorder:SetSize(44,44); row.oldBorder:SetBackdrop(inset); row.oldBorder:SetBackdropBorderColor(unpack(colors.gold))
                row.oldIcon=row.oldBorder:CreateTexture(nil,'ARTWORK'); row.oldIcon:SetSize(38,38); row.oldIcon:SetPoint('CENTER',0,0)
                row.oldName=label(row.oldHit,'Body'); row.oldName:SetPoint('TOPLEFT',53,-17); row.oldName:SetWidth(historyWidth-109); row.oldName:SetHeight(30); row.oldName:SetWordWrap(true)
                row.newBorder=CreateFrame('Frame',nil,row.newHit); row.newBorder:SetPoint('LEFT',0,0); row.newBorder:SetSize(44,44); row.newBorder:SetBackdrop(inset); row.newBorder:SetBackdropBorderColor(unpack(colors.gold))
                row.newIcon=row.newBorder:CreateTexture(nil,'ARTWORK'); row.newIcon:SetSize(38,38); row.newIcon:SetPoint('CENTER',0,0)
                row.newName=label(row.newHit,'Body'); row.newName:SetPoint('TOPLEFT',53,-17); row.newName:SetWidth(historyWidth-109); row.newName:SetHeight(30); row.newName:SetWordWrap(true); row.newName:SetTextColor(0.94,0.93,0.87)
                row.from=label(row.oldHit,'Small'); row.from:SetPoint('TOPLEFT',53,-1);row.from:SetHeight(16); row.from:SetText('From:')
                row.to=label(row.newHit,'Small'); row.to:SetPoint('TOPLEFT',53,-1);row.to:SetHeight(16); row.to:SetText('To:')
                row.rule=fill(row,colors.gold,0.22); row.rule:SetHeight(1); row.rule:SetPoint('BOTTOMLEFT',6,2); row.rule:SetPoint('BOTTOMRIGHT',-6,2)
                row:SetScript('OnMouseWheel',function(_,delta) R:ScrollHistory(p,(p.scroll:GetVerticalScroll() or 0)-delta*historyRowHeight) end)
                row:SetScript('OnEnter',function(self)
                    local r=self.record; if not r then return end
                    GameTooltip:SetOwner(self,kind=='ability' and 'ANCHOR_RIGHT' or 'ANCHOR_LEFT'); GameTooltip:SetText('Rerolled '..(kind=='ability' and 'ability' or 'talent'),unpack(colors[kind]))
                    GameTooltip:AddLine('From: '..(r.oldName or 'Unknown'),0.75,0.75,0.75,true)
                    GameTooltip:AddLine('To: '..(r.newName or 'Unknown'),1,1,1,true)
                    if r.at then GameTooltip:AddLine(date('%Y-%m-%d %H:%M:%S',r.at),0.65,0.65,0.65) end
                    if r.spec then GameTooltip:AddLine(r.spec:gsub(':',' '),0.65,0.65,0.65) end
                    GameTooltip:Show()
                end)
                row:SetScript('OnLeave',function() GameTooltip:Hide() end)
            end
            if row.record~=h and (GameTooltip:IsOwned(row.oldHit) or GameTooltip:IsOwned(row.newHit)) then GameTooltip:Hide() end
            row.record=h; row:SetPoint('TOPLEFT',0,-(i-1)*historyRowHeight)
            row.when:SetText(h.at and date('%Y-%m-%d %H:%M',h.at) or 'Saved result')
            row.oldIcon:SetTexture(h.oldID and icon(h.oldID) or 'Interface\\Icons\\INV_Misc_QuestionMark')
            row.newIcon:SetTexture(h.newID and icon(h.newID) or 'Interface\\Icons\\INV_Misc_QuestionMark')
            row.oldName:SetText(h.oldName or 'Unknown'); row.newName:SetText(h.newName or 'Unknown'); row:Show()
        end
        for i=#records+1,#p.rows do p.rows[i].record=nil; p.rows[i]:Hide() end
        if #records==0 then p.empty:Show() else p.empty:Hide() end
        p.canvas:SetHeight(math.max(1,#records*historyRowHeight)); p.scroll:UpdateScrollChildRect(); self:ScrollHistory(p,offset)
    end
    w.renderedHistory=history; w.renderedHistoryCount=#history; w.renderedHistoryFirst=history[1]; w.renderedHistoryLast=history[#history]
end
function R:RenderAnnouncements()
    local w=self.window; if not w or not w.announcementScroll then return end
    local history=self.character and self.character.history or {}
    local width=math.max(200,w:GetWidth()-280)
    w.announcementScroll:SetWidth(width); w.announcementCanvas:SetWidth(width)
    local height=0
    local cardWidth=(width-18)/3
    for i,row in ipairs(w.historyRows) do
        local h=history[i]; row.record=h
        row.text:SetWidth(cardWidth-16); row.text:SetHeight(0)
        row.text:SetText(h and ((h.oldID and textureTag(h.oldID,16) or '')..'|cff999da3'..(h.oldName or 'Unknown')..'|r  ->  '..(h.newID and textureTag(h.newID,16) or '')..(h.newName or 'Unknown')) or (i==1 and 'Your confirmed rerolls will appear here.' or ''))
        row.kind:SetText(h and (h.kind=='talent' and 'Talent' or 'Ability') or ''); row.kind:Hide()
        if h then row.kind:SetTextColor(unpack(colors[h.kind] or colors.gold)) end
        if h or i==1 then
            local textHeight=math.max(18,row.text:GetStringHeight() or 18)
            row.text:SetHeight(textHeight); row:SetSize(cardWidth,textHeight+10)
            row:ClearAllPoints(); row:SetPoint('TOPLEFT',(i-1)*(cardWidth+9),0); row:Show()
            row.shade:SetVertexColor(1,1,1,i%2==1 and 0.025 or 0); row.stripe:Hide()
            height=math.max(height,textHeight+10)
        else row:Hide(); row.stripe:Hide() end
    end
    w.announcementCanvas:SetHeight(math.max(1,height)); w.announcementScroll:UpdateScrollChildRect()
    local offset=w.announcementScroll:GetVerticalScroll() or 0
    if w.lastAnnouncement~=history[1] then offset=0; w.lastAnnouncement=history[1] end
    local maximum=math.max(0,height-w.announcementScroll:GetHeight())
    w.announcementScroll:SetVerticalScroll(math.max(0,math.min(maximum,offset)))
end
-- Chat is the only transient result notification. The static recent/history
-- panels are updated by the normal confirmation render, without overlay work.
function R:Notify(record,deferRender)
    local text=textureTag(record.oldID)..record.oldName..'  ->  '..textureTag(record.newID)..record.newName
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffe0bd75RE: Roller by Vash:|r '..text..' | '..record.spent..' scroll used') end
    -- CheckPending performs one render after updating the final status.
    if not deferRender then self:Render() end
end
function R:ToggleUI()
    self:CreateUI()
    if self.window:IsShown() then self.window:Hide() else self.window:Show(); self:Refresh(); self:Render() end
end
function R:CreateLauncher(resetPosition)
    if not self.launcher then
        local b=CreateFrame('Button','RERollerLauncher',UIParent); self.launcher=b
        b:SetSize(32,32); b:SetFrameStrata('MEDIUM'); b:SetMovable(true); b:SetClampedToScreen(true); b:EnableMouse(true)
        b:RegisterForClicks('LeftButtonUp'); b:RegisterForDrag('LeftButton')
        b.icon=b:CreateTexture(nil,'ARTWORK'); R.Skin.Sprite(b.icon,'Dice'); b.icon:SetSize(20,20); b.icon:SetPoint('CENTER',0,0); R.Skin.Sprite(b.icon,'Dice')
        b.border=b:CreateTexture(nil,'OVERLAY'); b.border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder'); b.border:SetSize(54,54); b.border:SetPoint('TOPLEFT',0,0)
        b:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
        b:SetScript('OnClick',function() if GetTime()>(b.suppressClickUntil or 0) then R:ToggleUI() end end)
        b:SetScript('OnDragStart',function() b:StartMoving(); b.suppressClickUntil=GetTime()+3600; GameTooltip:Hide() end)
        b:SetScript('OnDragStop',function()
            b:StopMovingOrSizing(); b.suppressClickUntil=GetTime()+0.2
            local x,y=b:GetCenter(); local ux,uy=UIParent:GetCenter()
            if x and ux then R.db.launcher={x=x-ux,y=y-uy} end
        end)
        b:SetScript('OnEnter',function()
            GameTooltip:SetOwner(b,'ANCHOR_RIGHT'); GameTooltip:SetText('RE: Roller by Vash',0.96,0.83,0.57)
            GameTooltip:AddLine('Click to open or close the planner.',1,1,1); GameTooltip:AddLine('Drag to move anywhere on screen.',0.8,0.8,0.8); GameTooltip:Show()
        end)
        b:SetScript('OnLeave',function() GameTooltip:Hide() end)
    end
    local b=self.launcher; b:ClearAllPoints()
    if resetPosition then self.db.launcher=nil end
    if self.db.launcher then b:SetPoint('CENTER',UIParent,'CENTER',self.db.launcher.x or 0,self.db.launcher.y or 0)
    else b:SetPoint('TOPRIGHT',UIParent,'TOPRIGHT',-190,-32) end
    b:Show()
end
