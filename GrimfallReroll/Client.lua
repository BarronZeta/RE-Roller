local R=GrimfallReroll
local C={}; R.Client=C
local classes={1,2,3,4,5,6,7,8,9,11}
local function call(fn,...)
    if type(fn)~='function' then return false end
    return pcall(fn,...)
end
local function num(row,...)
    for i=1,select('#',...) do local n=tonumber(row[select(i,...)]); if n then return n end end
end
local function rows(t)
    local result,seen={},{}
    if type(t)~='table' then return nil end
    for k,v in pairs(t) do
        if type(k)=='table' and not seen[k] then seen[k]=true; result[#result+1]=k end
        if type(v)=='table' and not seen[v] then seen[v]=true; result[#result+1]=v end
    end
    return result
end
local function ids(value,out,seen,depth)
    if depth>8 then return false end
    if type(value)=='number' or type(value)=='string' then
        local n=tonumber(value); if n and n>0 and n%1==0 then out[n]=true end
    elseif type(value)=='table' and not seen[value] then
        seen[value]=true
        for k,v in pairs(value) do
            if v==true then ids(k,out,seen,depth+1) end
            if not ids(v,out,seen,depth+1) then return false end
            if type(k)=='table' then if not ids(k,out,seen,depth+1) then return false end end
        end
    end
    return true
end
function C:Spec()
    local fn=GetActiveSpecializationIndex or GetActiveTalentGroup
    local ok,n=call(fn); n=tonumber(n)
    if ok and n and n>=0 and n%1==0 then return (GetActiveSpecializationIndex and 'specialization:' or 'group:')..n end
end
function C:Count(kind)
    local ok,n=call(GetItemCount,R.scrolls[kind],false)
    if ok and type(n)=='number' and n>=0 and n%1==0 then return n end
end
function C:Safe()
    if not R.eventsReady then return false,'Required Grimfall result events are unavailable.' end
    if InCombatLockdown and InCombatLockdown() then return false,'Leave combat before rerolling.' end
    if UnitAffectingCombat and UnitAffectingCombat('player') then return false,'Leave combat before rerolling.' end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost('player') then return false,'You must be alive to reroll.' end
    if not self:Spec() then return false,'Active specialization is unknown.' end
    return true
end
local function readSnapshot(self)
    local spec=self:Spec(); if not spec then return nil,'Cannot identify the active specialization.' end
    local ok,raw=call(GetKnownClasslessSpellIds)
    if not ok or (type(raw)~='table' and type(raw)~='number' and type(raw)~='string') then return nil,'Grimfall learned-ability API unavailable. No rerolls enabled.' end
    local known={}; if not ids(raw,known,{},0) then return nil,'Unexpected learned-ability data.' end
    local snap={spec=spec,rows={},byKey={}}
    local grouped={}
    for id in pairs(known) do
        local success,name,rank,icon=call(GetSpellInfo,id)
        if not success or not name then return nil,'An ability tooltip is not loaded yet. Refresh again.' end
        rank=rank or ''
        local rankNum=tonumber(rank:match('%d+')) or 0
        local key=rankNum>0 and ('A:rank:'..name) or ('A:'..id)
        local entry=grouped[key]
        if not entry then entry={kind='ability',key=key,id=id,spellID=id,name=name,rank=rankNum,icon=icon,ranks={}}; grouped[key]=entry end
        entry.ranks[id]=true
        if rankNum>entry.rank or (rankNum==entry.rank and id>entry.id) then entry.id=id; entry.spellID=id; entry.rank=rankNum; entry.icon=icon end
    end
    for _,entry in pairs(grouped) do snap.rows[#snap.rows+1]=entry; snap.byKey[entry.key]=entry end
    for _,class in ipairs(classes) do
        local success,specs=call(GetClasslessSpecializationSkillLineIds,class); specs=success and rows(specs)
        if not specs or #specs<1 then return nil,'Incomplete classless talent specializations (class '..class..').' end
        for _,s in ipairs(specs) do
            local skill=num(s,'ID','SkillLineID','skillLineID','skillLineId','id')
            if not skill then return nil,'Unknown classless specialization format.' end
            local tabOK,tab=call(GetClasslessTalentTabIdForSkillLine,class,skill); tab=tonumber(tab)
            if not tabOK or not tab or tab<=0 then return nil,'Talent tab unavailable. Refresh again.' end
            local treeOK,tree=call(GetClasslessTalentTreeData,tab)
            local talents=treeOK and type(tree)=='table' and rows(tree.talents or tree.Talents)
            if not talents or #talents==0 then return nil,'Talent tree data incomplete (tab '..tab..').' end
            for _,t in ipairs(talents) do
                local rank=num(t,'currentRank','CurrentRank','rank','Rank')
                if rank==nil then return nil,'Talent rank unavailable; no rerolls enabled.' end
                if rank>0 then
                    local id=num(t,'talentId','TalentID','TalentId','ID','id')
                    local abilityOK,isAbility=call(IsClasslessTalentConsideredAbility,id)
                    if not id or not abilityOK then return nil,'Talent identity/classification unavailable.' end
                    if not isAbility then
                        local rankIDs=t.spellRanks or t.SpellRanks or {}
                        local spell=num(t,'currentSpellId','CurrentSpellID','CurrentSpellId','currentSpellID') or tonumber(rankIDs[rank] or rankIDs[tostring(rank)])
                        if not spell or spell<=0 then return nil,'Learned talent spell ID unavailable.' end
                        local spellOK,name,_,icon=call(GetSpellInfo,spell)
                        if not spellOK or not name then return nil,'Talent tooltip data is still loading.' end
                        local key='T:'..id
                        local entry={kind='talent',key=key,id=id,spellID=spell,rank=rank,name=name,icon=icon}
                        entry.ranks={}
                        for i=1,rank do local n=tonumber(rankIDs[i] or rankIDs[tostring(i)]); if n then entry.ranks[n]=true end end
                        local prior=snap.byKey[key]
                        if prior and (prior.spellID~=spell or prior.rank~=rank) then return nil,'Conflicting talent rows; refresh again.' end
                        if not prior then snap.byKey[key]=entry; snap.rows[#snap.rows+1]=entry end
                    end
                end
            end
        end
    end
    if self:Spec()~=spec then return nil,'Specialization changed while reading the build.' end
    table.sort(snap.rows,function(a,b)
        if a.kind~=b.kind then return a.kind=='ability' end
        if a.name==b.name then return a.id<b.id end
        return a.name<b.name
    end)
    return snap
end
function C:Snapshot()
    local started=debugprofilestop and debugprofilestop() or 0
    local snapshot,reason=readSnapshot(self)
    R:MeasureWork('snapshot',started)
    return snapshot,reason
end
function C:PerformanceReport()
    local p=R.performance or {}
    local lines={'RE: Roller '..R.version..' performance (this session):'}
    for _,kind in ipairs({'snapshot','render'}) do
        local s=p[kind] or {calls=0,totalMS=0,maxMS=0}
        lines[#lines+1]=string.format('%s: %d calls; average %.2f ms; max %.2f ms.',kind,s.calls,s.calls>0 and s.totalMS/s.calls or 0,s.maxMS)
    end
    lines[#lines+1]=string.format('While rolling: %d frame gaps over 250 ms; largest %.2f s. Quick animation: %s.',p.slowFrames or 0,p.maxFrameGap or 0,R.db.fast and 'on' or 'off')
    lines[#lines+1]='Frame gaps include the game and other addons; they do not identify the cause by themselves.'
    if not debugprofilestop then lines[#lines+1]='Client timing API unavailable; work counters only.' end
    if R.db then R.db.lastPerformanceReport=table.concat(lines,'\n') end
    if DEFAULT_CHAT_FRAME then for _,line in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(line) end end
end
function C:Request(target)
    if target.kind=='talent' then
        local ok,allowed=call(ClasslessCanRerollTalent,target.id)
        if not ok or not allowed or type(ClasslessRerollTalent)~='function' then return false end
        return ClasslessRerollTalent(target.id)
    end
    if type(ClasslessUnlearnSpell)~='function' then return false end
    return ClasslessUnlearnSpell(target.id)
end
function C:AnimationBusy()
    return RandomMode_RollFrame and RandomMode_RollFrame:IsShown()
end
-- Fast presentation leaves all native OnPlay/OnFinished handlers intact, notably
-- Alpha3.OnPlay -> FlushClasslessWildcardSpellRollResults. It never calls Flush itself.
function C:RestoreAnimation()
    local saved=self.fastState; if not saved then return end
    self.fastState=nil; self.adjusting=true
    for _,s in ipairs(saved.animations) do
        s.object:SetDuration(s.duration); s.object:SetStartDelay(s.startDelay); s.object:SetEndDelay(s.endDelay)
    end
    saved.frame:SetAlpha(saved.alpha); self.adjusting=false
end
function C:PrepareAnimation()
    local f=RandomMode_RollFrame; local p=R.pending
    -- Talents use the same spell-roll presentation. Preserve its result-flush callbacks too.
    if not f or not p or not R.db.fast then return end
    if self.fastState then return end
    local scroll=f.Scroll and f.Scroll.Content and f.Scroll.Content.AnimationGroup
    local result=f.NewSpell and f.NewSpell.AnimG
    if not scroll or not scroll.Rotation1 or not result or not result.Scale2 or not result.Alpha2 or not result.Alpha3 then return end
    local targets={scroll.Rotation1,result.Scale2,result.Alpha2,result.Alpha3}
    for _,a in ipairs(targets) do if not a.GetDuration or not a.GetStartDelay or not a.GetEndDelay then return end end
    local saved={frame=f,alpha=f:GetAlpha(),animations={}}
    for _,a in ipairs(targets) do saved.animations[#saved.animations+1]={object=a,duration=a:GetDuration(),startDelay=a:GetStartDelay(),endDelay=a:GetEndDelay()} end
    self.fastState=saved; self.adjusting=true
    for _,a in ipairs(targets) do a:SetDuration(0.05); a:SetStartDelay(0); a:SetEndDelay(0) end
    f:SetAlpha(0); self.adjusting=false
    if not self.durationHooked then
        self.durationHooked=true
        hooksecurefunc(scroll.Rotation1,'SetDuration',function(a,value)
            if C.fastState and not C.adjusting and value>0.05 then C.adjusting=true; a:SetDuration(0.05); C.adjusting=false end
        end)
        f:HookScript('OnHide',function() C:RestoreAnimation() end)
    end
end
function C:HookAnimation()
    if self.animationHooked or type(hooksecurefunc)~='function' or type(ClasslessRandomRoll_CreateFrame)~='function' then return end
    self.animationHooked=true
    hooksecurefunc('ClasslessRandomRoll_CreateFrame',function() C:PrepareAnimation() end)
end
function C:Diagnose()
    local d={version=R.version,spec=self:Spec(),at=time(),apis={},abilityScrolls=self:Count('ability'),talentScrolls=self:Count('talent')}
    for _,name in ipairs({'GetKnownClasslessSpellIds','GetClasslessSpecializationSkillLineIds','GetClasslessTalentTabIdForSkillLine','GetClasslessTalentTreeData','IsClasslessTalentConsideredAbility','ClasslessUnlearnSpell','ClasslessCanRerollTalent','ClasslessRerollTalent','ClasslessRandomRoll_CreateFrame'}) do d.apis[name]=type(_G[name]) end
    local snapshot,reason=self:Snapshot(); d.issue=reason; d.rows=snapshot and #snapshot.rows or 0
    R.db.diagnostic=d
    R:SetStatus(reason or ('Diagnostics: '..d.rows..' entries read; scrolls '..tostring(d.abilityScrolls)..' / '..tostring(d.talentScrolls)..'.'))
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('RE: Roller by Vash: '..R.status) end
end
