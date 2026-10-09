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
    if event=='CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED' or event=='CUSTOM_CLASSLESS_WILDCARD_TALENT_LEARN'
        or event=='ACTIVE_TALENT_GROUP_CHANGED' or event=='SPELLS_CHANGED' or event=='PLAYER_TALENT_UPDATE' or event=='PLAYER_ENTERING_WORLD'then
        R:BuildChanged(true)
    end
    if event=='CUSTOM_CLASSLESS_WILDCARD_SPELL_ROLLED' then R:Result('presentation',arg)
    elseif event=='CUSTOM_CLASSLESS_WILDCARD_TALENT_LEARN' then R:Result('talent',arg)
    elseif event=='ACTIVE_TALENT_GROUP_CHANGED' then
        R:InvalidateSpecView(); R:Stop('Queue stopped: active talent group changed.'); R.dirty=true
    elseif event=='PLAYER_REGEN_DISABLED' or event=='PLAYER_LEAVING_WORLD' or event=='PLAYER_LOGOUT' then
        R:Stop('Queue stopped: '..event:lower():gsub('_',' ')..'.'); R.dirty=true
    elseif event=='UI_ERROR_MESSAGE' and (R.running or R.pending) then
        local message=select(2,...) or arg or 'Server error'; R:Stop('Stopped: '..tostring(message)..'. No retry sent.')
    elseif (event=='ADDON_ACTION_BLOCKED' or event=='ADDON_ACTION_FORBIDDEN') and arg=='GrimfallReroll' then
        R:Stop('Client blocked the reroll action. No automatic retry; use the native Unlearn menu for now.')
    elseif event=='BAG_UPDATE' then R.uiDirty=true
    elseif event=='SPELLS_CHANGED' or event=='PLAYER_TALENT_UPDATE' or event=='PLAYER_ENTERING_WORLD' then R.dirty=true end
end)
frame:SetScript('OnUpdate',function(self,dt)
    if not R.db then return end
    -- Only read-only display scans are spread across frames. Mutating request
    -- validation and result confirmation retain their original complete reads.
    if R.refreshJob then R.Client:AdvanceSnapshot();R:PollRefresh()end
    if R.running or R.pending then
        R.performance=R.performance or {}
        local p=R.performance; p.maxFrameGap=math.max(p.maxFrameGap or 0,dt)
        if dt>0.25 then p.slowFrames=(p.slowFrames or 0)+1 end
    end
    elapsed=elapsed+dt; if elapsed<0.3 then return end; elapsed=0
    if R.pending or R.running then R:Step(false)
    elseif R.window and R.window:IsShown() then
        if R.refreshJob then return end
        R:SpecViewIsCurrent() -- Cheap fallback if the custom client omits a spec-change event.
        if R.dirty and GetTime()>=(R.nextIdleRefresh or 0) then
            R.dirty=false; R.uiDirty=false; R.nextIdleRefresh=GetTime()+1; R:RequestRefresh()
        elseif R.uiDirty then R.uiDirty=false; R:Changed() end
    end
end)
SLASH_GRIMFALLREROLL1='/grr'
SLASH_GRIMFALLREROLL2='/rerolls'
SLASH_GRIMFALLREROLL3='/rr'
SLASH_GRIMFALLREROLL4='/reroller'
local function commandHelp(unknown)
    if not DEFAULT_CHAT_FRAME then return end
    if unknown then DEFAULT_CHAT_FRAME:AddMessage('RE: Roller: unknown command /rr '..unknown..'. Window and queue unchanged.')end
    DEFAULT_CHAT_FRAME:AddMessage('RE: Roller commands: /rr opens/closes the planner; /rr stop stops the queue; /rr icon resets the launcher.')
    DEFAULT_CHAT_FRAME:AddMessage('/rr perf prints the performance report in chat; /rr perf reset clears timing counters while idle (it does not print a report).')
    DEFAULT_CHAT_FRAME:AddMessage('/rr smooth on|off changes display-read mode; /rr refresh sync refreshes while idle; /rr diagnose, /rr history, /rr help.')
end
SlashCmdList.GRIMFALLREROLL=function(msg)
    msg=string.lower(msg or ''):gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ')
    if msg=='' then R:ToggleUI()
    elseif msg=='help' then commandHelp()
    elseif msg=='stop' then R:Stop('Stopped by /rr stop.')
    elseif msg=='icon' then R:CreateLauncher(true)
    elseif msg=='diagnose' then R.Client:Diagnose()
    elseif msg=='performance' or msg=='perf' then R.Client:PerformanceReport()
    elseif msg=='performance reset' or msg=='perf reset' then R.Client:ResetPerformance()
    elseif msg=='smooth on' then R:SetSmoothReads(true)
    elseif msg=='smooth off' then R:SetSmoothReads(false)
    elseif msg=='refresh sync' then
        if not R.running and not R.pending then R:Refresh()else R:SetStatus('Finish or stop the current reroll before a manual refresh.')end
    elseif msg=='history' then
        for i=1,20 do local h=R.character and R.character.history[i]; if h then DEFAULT_CHAT_FRAME:AddMessage(date('%H:%M',h.at)..' '..h.kind..': '..h.oldName..' -> '..h.newName..' ('..h.spent..' scroll)') end end
    else commandHelp(msg) end
end
