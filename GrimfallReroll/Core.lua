local R=GrimfallReroll
local frame=CreateFrame('Frame'); local elapsed=0
frame:RegisterEvent('ADDON_LOADED')
frame:SetScript('OnEvent',function(self,event,...)
    local arg=...
    if event=='ADDON_LOADED' then
        if arg~='GrimfallReroll' then return end
        GrimfallRerollDB=GrimfallRerollDB or {}; R:InitializeDB(GrimfallRerollDB)
        R.eventsReady=true
        for _,name in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_LEAVING_WORLD','PLAYER_LOGOUT','PLAYER_REGEN_DISABLED','ACTIVE_TALENT_GROUP_CHANGED','SPELLS_CHANGED','PLAYER_TALENT_UPDATE','BAG_UPDATE','UI_ERROR_MESSAGE','ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN','CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED','CUSTOM_CLASSLESS_WILDCARD_TALENT_LEARN'}) do
            local ok=pcall(self.RegisterEvent,self,name)
            if not ok and name:find('CUSTOM_',1,true) then R.eventsReady=false end
        end
        R.Client:HookAnimation(); R:CreateLauncher(); return
    end
    if not R.db then return end
    if event=='CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED' then R:Result('presentation',arg)
    elseif event=='CUSTOM_CLASSLESS_WILDCARD_TALENT_LEARN' then R:Result('talent',arg)
    elseif event=='PLAYER_REGEN_DISABLED' or event=='PLAYER_LEAVING_WORLD' or event=='PLAYER_LOGOUT' or event=='ACTIVE_TALENT_GROUP_CHANGED' then
        R:Stop('Queue stopped: '..event:lower():gsub('_',' ')..'.'); R.dirty=true
    elseif event=='UI_ERROR_MESSAGE' and (R.running or R.pending) then
        local message=select(2,...) or arg or 'Server error'; R:Stop('Stopped: '..tostring(message)..'. No retry sent.')
    elseif (event=='ADDON_ACTION_BLOCKED' or event=='ADDON_ACTION_FORBIDDEN') and arg=='GrimfallReroll' then
        R:Stop('Client blocked the reroll action. No automatic retry; use the native Unlearn menu for now.')
    else R.dirty=true end
end)
frame:SetScript('OnUpdate',function(self,dt)
    if not R.db then return end
    elapsed=elapsed+dt; if elapsed<0.3 then return end; elapsed=0
    if R.pending or R.running then R:Step(false)
    elseif R.dirty and R.window and R.window:IsShown() then R.dirty=false; R:Refresh() end
end)
SLASH_GRIMFALLREROLL1='/grr'
SLASH_GRIMFALLREROLL2='/rerolls'
SLASH_GRIMFALLREROLL3='/rr'
SLASH_GRIMFALLREROLL4='/reroller'
SlashCmdList.GRIMFALLREROLL=function(msg)
    msg=string.lower(msg or '')
    if msg=='stop' then R:Stop('Stopped by /rr stop.')
    elseif msg=='icon' then R:CreateLauncher(true)
    elseif msg=='diagnose' then R.Client:Diagnose()
    elseif msg=='history' then
        for i=1,20 do local h=R.character and R.character.history[i]; if h then DEFAULT_CHAT_FRAME:AddMessage(date('%H:%M',h.at)..' '..h.kind..': '..h.oldName..' -> '..h.newName..' ('..h.spent..' scroll)') end end
    else R:ToggleUI() end
end
