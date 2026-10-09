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

local function clockMS()return debugprofilestop and debugprofilestop()or 0 end
local function timed(kind,fn,...)
    local started=clockMS();local ok,a,b,c,d,e=call(fn,...)
    local ms=math.max(0,clockMS()-started);R:RecordWork('api_'..kind,ms)
    if kind=='talent_tree'then
        R.performance=R.performance or {};local prior=R.performance.slowestTree
        if not prior or ms>prior.ms then R.performance.slowestTree={tab=select(1,...),ms=ms}end
    end
    return ok,a,b,c,d,e
end
function C:InvalidateMetadata()
    self.spellCache={};self.spellCacheSize=0;self.metadataEpoch=(self.metadataEpoch or 0)+1
    self.spellFunction=GetSpellInfo;self.locale=GetLocale and GetLocale()or ''
end
function C:EnsureMetadata()
    local locale=GetLocale and GetLocale()or ''
    if not self.spellCache or self.spellFunction~=GetSpellInfo or self.locale~=locale then self:InvalidateMetadata()end
end
function C:SpellMetadata(id)
    self:EnsureMetadata()
    local p=R.performance or {};R.performance=p
    local cached=self.spellCache[id]
    if cached then p.cacheHits=(p.cacheHits or 0)+1;return true,cached.name,cached.rank,cached.icon end
    p.cacheMisses=(p.cacheMisses or 0)+1
    local ok,name,rank,icon=timed('spell_info',GetSpellInfo,id)
    -- Cache only complete canonical display metadata, never live ownership/rank.
    -- Missing/error responses are retried normally, not stored as negative hits.
    if ok and type(name)=='string' and name~='' and type(icon)=='string' and icon~=''then
        if (self.spellCacheSize or 0)>=4096 then self:InvalidateMetadata()end
        self.spellCache[id]={name=name,rank=rank,icon=icon};self.spellCacheSize=(self.spellCacheSize or 0)+1
    end
    return ok,name,rank,icon
end
local function activeClock(job)return clockMS()-(job and job.pausedMS or 0)end
local function checkpoint(job,api)
    if not job then return end
    if R.buildEpoch~=job.epoch then error('Build changed during the read-only scan.',0)end
    if api then job.calls=job.calls+1 else job.nodes=job.nodes+1 end
    local over=debugprofilestop and clockMS()-job.sliceStarted>=4
    if over or job.calls>=8 or job.nodes>=128 then
        local before=clockMS();coroutine.yield()
        job.pausedMS=job.pausedMS+math.max(0,clockMS()-before)
        if R.buildEpoch~=job.epoch then error('Build changed during the read-only scan.',0)end
    end
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
local function readSnapshot(self,job)
    self:EnsureMetadata();local epoch,metadata=R.buildEpoch or 0,self.metadataEpoch
    local abilityStarted=activeClock(job)
    local spec=self:Spec(); if not spec then return nil,'Cannot identify the active specialization.' end
    local ok,raw=timed('known_abilities',GetKnownClasslessSpellIds);checkpoint(job,true)
    if not ok or (type(raw)~='table' and type(raw)~='number' and type(raw)~='string') then return nil,'Grimfall learned-ability API unavailable. No rerolls enabled.' end
    local known={}; if not ids(raw,known,{},0) then return nil,'Unexpected learned-ability data.' end
    local snap={spec=spec,rows={},byKey={},epoch=epoch}
    local grouped={}
    for id in pairs(known) do
        local success,name,rank,icon=self:SpellMetadata(id);checkpoint(job,true)
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
    R:RecordWork('stage_abilities',activeClock(job)-abilityStarted)
    local talentStarted=activeClock(job)
    for _,class in ipairs(classes) do
        local success,specs=timed('specializations',GetClasslessSpecializationSkillLineIds,class);checkpoint(job,true);specs=success and rows(specs)
        if not specs or #specs<1 then return nil,'Incomplete classless talent specializations (class '..class..').' end
        for _,s in ipairs(specs) do
            local skill=num(s,'ID','SkillLineID','skillLineID','skillLineId','id')
            if not skill then return nil,'Unknown classless specialization format.' end
            local tabOK,tab=timed('tab_map',GetClasslessTalentTabIdForSkillLine,class,skill);checkpoint(job,true);tab=tonumber(tab)
            if not tabOK or not tab or tab<=0 then return nil,'Talent tab unavailable. Refresh again.' end
            local treeOK,tree=timed('talent_tree',GetClasslessTalentTreeData,tab);checkpoint(job,true)
            local talents=treeOK and type(tree)=='table' and rows(tree.talents or tree.Talents)
            if not talents or #talents==0 then return nil,'Talent tree data incomplete (tab '..tab..').' end
            for _,t in ipairs(talents) do
                local rank=num(t,'currentRank','CurrentRank','rank','Rank')
                if rank==nil then return nil,'Talent rank unavailable; no rerolls enabled.' end
                if rank>0 then
                    local id=num(t,'talentId','TalentID','TalentId','ID','id')
                    local abilityOK,isAbility=timed('talent_classification',IsClasslessTalentConsideredAbility,id);checkpoint(job,true)
                    if not id or not abilityOK then return nil,'Talent identity/classification unavailable.' end
                    if not isAbility then
                        local rankIDs=t.spellRanks or t.SpellRanks or {}
                        local spell=num(t,'currentSpellId','CurrentSpellID','CurrentSpellId','currentSpellID') or tonumber(rankIDs[rank] or rankIDs[tostring(rank)])
                        if not spell or spell<=0 then return nil,'Learned talent spell ID unavailable.' end
                        local spellOK,name,_,icon=self:SpellMetadata(spell);checkpoint(job,true)
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
                checkpoint(job,false)
            end
        end
    end
    R:RecordWork('stage_talents',activeClock(job)-talentStarted)
    if job then
        local finalOK,finalRaw=timed('known_abilities',GetKnownClasslessSpellIds);local final={}
        if not finalOK or not ids(finalRaw,final,{},0)then return nil,'Learned abilities changed or became unavailable.'end
        for id in pairs(known)do if not final[id]then return nil,'Learned abilities changed during refresh.'end end
        for id in pairs(final)do if not known[id]then return nil,'Learned abilities changed during refresh.'end end
    end
    if (R.buildEpoch or 0)~=epoch or self.metadataEpoch~=metadata then return nil,'Build or display metadata changed while reading. Refresh again.'end
    if self:Spec()~=spec then return nil,'Specialization changed while reading the build.' end
    local sortStarted=activeClock(job)
    table.sort(snap.rows,function(a,b)
        if a.kind~=b.kind then return a.kind=='ability' end
        if a.name==b.name then return a.id<b.id end
        return a.name<b.name
    end)
    R:RecordWork('stage_sort',activeClock(job)-sortStarted)
    return snap
end

function C:Snapshot()
    local started=clockMS()
    local ok,snapshot,reason=pcall(readSnapshot,self)
    R:MeasureWork('snapshot',started)
    if not ok then return nil,'Build read failed safely: '..tostring(snapshot)end
    return snapshot,reason
end
function C:BeginSnapshot()
    self:CancelSnapshot('A new read-only refresh replaced the old one.')
    local job={epoch=R.buildEpoch or 0,spec=self:Spec(),wallStarted=GetTime(),activeMS=0,pausedMS=0,calls=0,nodes=0}
    job.thread=coroutine.create(function()return readSnapshot(self,job)end)
    self.readJob=job;return job
end
local function finishJob(self,job,snapshot,reason)
    job.done=true;job.snapshot=snapshot;job.reason=reason;job.thread=nil
    if self.readJob==job then self.readJob=nil end
    R:RecordWork('snapshot',job.activeMS)
    R:RecordWork('snapshot_wall',math.max(0,(GetTime()-job.wallStarted)*1000))
    R.performance.asyncCompleted=(R.performance.asyncCompleted or 0)+(snapshot and 1 or 0)
    R.performance.asyncAborted=(R.performance.asyncAborted or 0)+(snapshot and 0 or 1)
end
function C:CancelSnapshot(reason)
    local job=self.readJob;if job then finishJob(self,job,nil,reason or 'Read-only scan cancelled.')end
end
function C:AdvanceSnapshot()
    local job=self.readJob;if not job then return end
    if R.running or R.pending then self:CancelSnapshot('Reroll validation takes priority.');return end
    if R.buildEpoch~=job.epoch or self:Spec()~=job.spec then self:CancelSnapshot('Build or spec changed during refresh.');return end
    if GetTime()-job.wallStarted>30 then self:CancelSnapshot('Read-only refresh timed out; no reroll sent. Try /rr refresh sync.');return end
    job.sliceStarted=clockMS();job.calls=0;job.nodes=0
    local ok,snapshot,reason=coroutine.resume(job.thread)
    local ms=math.max(0,clockMS()-job.sliceStarted);job.activeMS=job.activeMS+ms
    R:RecordWork('snapshot_slice',ms)
    if not ok then finishJob(self,job,nil,'Read-only build read failed: '..tostring(snapshot))
    elseif coroutine.status(job.thread)=='dead'then finishJob(self,job,snapshot,reason)end
end
function C:PerformanceReport()
    local p=R.performance or {}
    local lines={'RE: Roller '..R.version..' performance (this session):'}
    local names={{'snapshot','snapshot work'},{'snapshot_slice','read-only refresh slice'},{'snapshot_wall','read-only refresh wall time'},
        {'render','render'},{'stage_abilities','ability stage'},{'stage_talents','talent stage'},{'stage_sort','sorting'},
        {'api_known_abilities','API learned abilities'},{'api_specializations','API talent specializations'},
        {'api_tab_map','API talent tab mapping'},{'api_talent_tree','API talent tree data'},
        {'api_talent_classification','API talent classification'},{'api_spell_info','API spell metadata'}}
    for _,entry in ipairs(names)do
        local s=p[entry[1]]
        if s then lines[#lines+1]=string.format('%s: %d calls; average %.2f ms; max %.2f ms.',entry[2],s.calls,s.calls>0 and s.totalMS/s.calls or 0,s.maxMS)end
    end
    lines[#lines+1]=string.format('Display cache: %d hits / %d misses. Read-only scans: %d complete / %d cancelled.',p.cacheHits or 0,p.cacheMisses or 0,p.asyncCompleted or 0,p.asyncAborted or 0)
    lines[#lines+1]=string.format('Same-action startup reads reused: %d. Later requests and result confirmations still read the complete build.',p.startupReadsReused or 0)
    lines[#lines+1]='Display refresh: '..(R.smoothReads==false and 'synchronous' or 'frame-spread')..'. Queue request/result validation: synchronous.'
    if p.slowestTree then lines[#lines+1]=string.format('Slowest native tree read: tab %s, %.2f ms.',tostring(p.slowestTree.tab),p.slowestTree.ms)end
    lines[#lines+1]=string.format('While rolling: %d frame gaps over 250 ms; largest %.2f s. Quick animation: %s.',p.slowFrames or 0,p.maxFrameGap or 0,R.db.fast and 'on' or 'off')
    lines[#lines+1]='Frame gaps include the game and other addons; they do not identify the cause by themselves.'
    lines[#lines+1]='Stages include their API calls; do not add them together. Fresh request/result checks remain synchronous; a native call cannot be interrupted.'
    if not debugprofilestop then lines[#lines+1]='Client timing API unavailable; refresh is bounded by call/row counts only.'end
    if R.db then R.db.lastPerformanceReport=table.concat(lines,'\n')end
    if DEFAULT_CHAT_FRAME then for _,line in ipairs(lines)do DEFAULT_CHAT_FRAME:AddMessage(line)end end
end
function C:ResetPerformance()
    if R.running or R.pending or R.refreshJob then R:SetStatus('Wait for the current scan/roll before resetting performance counters.');return end
    R.performance={}
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('RE: Roller: performance counters reset; build, locks, scrolls and history unchanged.')end
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
