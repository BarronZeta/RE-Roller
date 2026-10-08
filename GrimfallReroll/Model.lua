GrimfallReroll = {version='0.9.2', selected={}, rows={}, byKey={}, queue={}, running=false, status='Open /rr to load your build.'}
local R=GrimfallReroll
R.scrolls={ability=640,talent=639}
function R:Changed() if self.Render then self:Render() end end
function R:SetStatus(text) if self.status==text then return end; self.status=text; self:Changed() end
function R:MeasureWork(kind,started)
    self.performance=self.performance or {}
    local p=self.performance[kind] or {calls=0,totalMS=0,maxMS=0}; self.performance[kind]=p
    local ms=debugprofilestop and math.max(0,debugprofilestop()-started) or 0
    p.calls=p.calls+1; p.totalMS=p.totalMS+ms; p.maxMS=math.max(p.maxMS,ms)
end
function R:InitializeDB(db)
    self.db=db; db.schema=1; db.characters=db.characters or {}; db.fast=db.fast~=false
    local character=(UnitName('player') or '?')..' - '..(GetRealmName() or '?')
    db.characters[character]=db.characters[character] or {specs={},history={}}
    self.character=db.characters[character]
    self.lockContext={} -- Session-only identity for unlock confirmations; never saved.
end
function R:Locks(spec)
    local key=tostring(spec); local specs=self.character.specs
    specs[key]=specs[key] or {locks={}}; return specs[key].locks
end
function R:InvalidateSpecView()
    self.ready=false; self.selected={}; self.lockContext={}
    if type(StaticPopup_Hide)=='function' then StaticPopup_Hide('GRR_UNLOCK') end
end
function R:SpecViewIsCurrent()
    -- A display refresh is coalesced, but an edit must check the live spec now.
    -- This reads only the spec index, not the ability/talent trees.
    local active=self.Client:Spec()
    if not self.ready or not active or active~=self.spec then
        if self.ready then
            self:InvalidateSpecView()
            self:SetStatus('Active spec changed or is unavailable. Refresh before editing locks or selections.')
        end
        self.dirty=true; return false
    end
    return true
end
function R:CanEditEntry(key,spec,context)
    if self.running or self.pending or not self:SpecViewIsCurrent() then return false end
    if (spec and spec~=self.spec) or (context and context~=self.lockContext) then return false end
    return self.byKey[key]~=nil
end
function R:Refresh()
    local snapshot,reason=self.Client:Snapshot()
    if not snapshot then self:InvalidateSpecView(); self:SetStatus(reason); return nil end
    if self.spec~=snapshot.spec then
        local initial=self.spec==nil
        self:InvalidateSpecView(); self.spec=snapshot.spec
        self:Stop(initial and 'Ready. Select entries in either column to plan a reroll.' or 'Active spec changed; queue stopped.')
    end
    self.rows=snapshot.rows; self.byKey=snapshot.byKey; self.ready=true
    for key in pairs(self.selected) do if not self.byKey[key] or self:Locks(self.spec)[key] then self.selected[key]=nil end end
    self.snapshot=snapshot; self:Changed(); return snapshot
end
function R:Toggle(key)
    if not self:CanEditEntry(key) or self:Locks(self.spec)[key] then return end
    self.selected[key]=not self.selected[key] or nil; self:Changed()
end
function R:Lock(key)
    if not self:CanEditEntry(key) then return end
    self:Locks(self.spec)[key]=true; self.selected[key]=nil; self:Changed()
end
function R:Unlock(key,spec,context)
    if self.spec~=spec or not self:CanEditEntry(key,spec,context) then return end
    self:Locks(spec)[key]=nil; self:Changed()
end
function R:Totals()
    local totals={ability=0,talent=0}
    for key,selected in pairs(self.selected) do
        local row=self.byKey[key]; if selected and row and not self:Locks(self.spec)[key] then totals[row.kind]=totals[row.kind]+1 end
    end
    return totals
end
function R:Clear() if self.running or self.pending then return end; self.selected={}; self:Changed() end
function R:Stop(reason)
    local active=self.running or self.pending
    self.running=false; self.queue={}; self.paused=false
    -- An already sent request cannot be recalled; continue observing it, but never send the next one.
    if reason then self.status=reason end
    if active and reason and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffe0bd75RE: Roller by Vash:|r '..reason) end
    if self.db and active then self.db.lastQueueStatus={at=time(),reason=reason,confirmed=self.done or 0,pending=self.pending and self.pending.target.name or nil} end
    self:Changed()
end
function R:Start(kindFilter)
    if self.pending or self.running then return end
    if kindFilter and kindFilter~='ability' and kindFilter~='talent' then return end
    local snapshot=self:Refresh(); if not snapshot then return end
    local safe,reason=self.Client:Safe(); if not safe then self:SetStatus(reason); return end
    local totals=self:Totals()
    for kind,n in pairs(totals) do
        local available=self.Client:Count(kind)
        if (not kindFilter or kind==kindFilter) and n>0 and (available==nil or available<n) then self:SetStatus('Not enough '..(kind=='ability' and 'Scrolls of Destiny' or 'Scrolls of Reshaping')..' in bags.'); return end
    end
    self.queue={}
    for _,row in ipairs(self.rows) do if (not kindFilter or row.kind==kindFilter) and self.selected[row.key] and not self:Locks(self.spec)[row.key] then
        self.queue[#self.queue+1]={key=row.key,spellID=row.spellID,id=row.id,kind=row.kind,name=row.name,rank=row.rank}
    end end
    if #self.queue==0 then self:SetStatus('Select unlocked entries to reroll.'); return end
    self.total=#self.queue; self.done=0; self.running=true; self.paused=false; self.nextAt=0; self.animationWaitAt=nil
    self.expected=snapshot; self:Step(true)
end
function R:Pause()
    if not self.running then return end
    self.paused=not self.paused
    self:SetStatus(self.paused and 'Paused. Any outstanding result is still being checked.' or 'Resuming queue...')
end
function R.SameBuild(a,b)
    if not a or not b or a.spec~=b.spec then return false end
    for k,r in pairs(a.byKey) do local s=b.byKey[k]; if not s or s.spellID~=r.spellID or s.rank~=r.rank then return false end end
    for k in pairs(b.byKey) do if not a.byKey[k] then return false end end
    return true
end
function R:Step(clicked)
    if self.pending then self:CheckPending(); return end
    if not self.running or self.paused or GetTime()<(self.nextAt or 0) then return end
    if self.manual and not clicked then return end
    local safe,reason=self.Client:Safe(); if not safe then self:Stop(reason); return end
    if #self.queue==0 then self:Stop('Finished: '..(self.done or 0)..' confirmed rerolls.'); return end
    -- Native presentation can last several seconds. No build scan or queue
    -- mutation is needed until it has finished; still validate afresh before sending.
    if self.Client:AnimationBusy() then
        if self.done>0 then
            self.animationWaitAt=self.animationWaitAt or GetTime()
            if GetTime()-self.animationWaitAt>12 then self:Stop('Native roll presentation did not finish. Queue stopped.'); return end
            self.nextAt=GetTime()+0.3; self:SetStatus('Result confirmed; waiting for native presentation to finish...')
        else self.paused=true; self:SetStatus('An existing roll animation is active. Wait for it, then Resume.') end
        return
    end
    local before,err=self.Client:Snapshot()
    if not before or not self.SameBuild(self.expected,before) then self:Stop(err or 'Build changed outside this queue. Refresh and select again.'); return end
    local target=#self.queue>0 and table.remove(self.queue,1)
    if not target then self:Stop('Finished: '..(self.done or 0)..' confirmed rerolls.'); return end
    local current=before.byKey[target.key]
    if not current or current.spellID~=target.spellID or self:Locks(before.spec)[target.key] then self:Stop('Queued entry changed or became protected.'); return end
    local count=self.Client:Count(target.kind); local other=target.kind=='ability' and 'talent' or 'ability'
    local otherCount=self.Client:Count(other)
    if not count or count<1 or otherCount==nil then self:Stop('Scroll count unavailable or no scrolls remaining.'); return end
    self.animationWaitAt=nil
    self.pending={target=target,before=before,scrolls=count,other=other,otherCount=otherCount,at=GetTime()}
    self.selected[target.key]=nil
    self.status='Rerolling '..target.name..' ('..(self.done+1)..'/'..self.total..')...'; self:Changed()
    local ok,requested=pcall(self.Client.Request,self.Client,target)
    if not ok or not requested then
        -- Even an exception is not evidence that nothing reached the server: do not auto-retry.
        self:Stop('Reroll request was refused or blocked. No retry will be sent; checking for a late result.')
    end
end
function R:Result(kind,id)
    local p=self.pending; id=tonumber(id)
    if not p then return end
    -- SPELL_ROLLED is a generic presentation event, including talent rolls.
    -- Confirmation below still requires the replacement in the requested column,
    -- an otherwise unchanged build and exactly one matching scroll consumed.
    if (kind~='presentation' and kind~=p.target.kind) or not id or id<=0 or (p.result and p.result~=id) then
        p.ambiguous=true; self:Stop('Unexpected reroll result. Queue stopped for review.'); return
    end
    p.result=id; p.eventAt=GetTime(); p.nextSnapshotAt=nil
end
function R:CheckPending()
    local p=self.pending; if not p then return end
    if not p.ambiguous and self.Client:Spec()~=p.before.spec then p.ambiguous=true; self:Stop('Spec changed while awaiting a result.'); end
    if GetTime()-p.at>20 then
        self.pending=nil; self:Stop('Result not confirmed within 20 seconds. No retry sent. Check your build and scrolls before restarting.'); self:Refresh(); return
    end
    if p.ambiguous or not p.result then return end
    -- Cheap readiness checks first. The result event can precede the native
    -- flush/scroll update; scanning all talent trees repeatedly cannot hurry it.
    local count=self.Client:Count(p.target.kind); local other=self.Client:Count(p.other)
    if count==nil or other==nil then return end
    local spent=p.scrolls-count
    if spent==0 then return end
    if spent~=1 or other~=p.otherCount then p.ambiguous=true; self:Stop('Unexpected scroll-count change; queue stopped for review.'); return end
    if p.nextSnapshotAt and GetTime()<p.nextSnapshotAt then return end
    p.nextSnapshotAt=GetTime()+1
    local after=self.Client:Snapshot(); if not after or after.spec~=p.before.spec then return end
    local row
    for _,r in ipairs(after.rows) do if r.kind==p.target.kind and (r.spellID==p.result or (r.ranks and r.ranks[p.result])) then
        if row then p.ambiguous=true; self:Stop('Ambiguous replacement; queue stopped.'); return end
        row=r
    end end
    if not row then return end
    local old=after.byKey[p.target.key]
    if old and old.key~=row.key then return end
    -- Exactly the selected entry may change; the rest of the build must remain stable.
    for key,r in pairs(p.before.byKey) do
        if key~=p.target.key then
            local new=after.byKey[key]
            if not new or new.spellID~=r.spellID or new.rank~=r.rank then p.ambiguous=true; self:Stop('Other build entries changed; queue stopped.'); return end
        end
    end
    for key in pairs(after.byKey) do
        if not p.before.byKey[key] and key~=row.key then p.ambiguous=true; self:Stop('More than one replacement appeared; queue stopped.'); return end
    end
    local record={at=time(),spec=after.spec,kind=row.kind,oldID=p.target.spellID,oldName=p.target.name,newID=row.spellID,newName=row.name,spent=spent}
    table.insert(self.character.history,1,record); while #self.character.history>100 do table.remove(self.character.history) end
    self.pending=nil; self.done=(self.done or 0)+1; self.expected=after; self.nextAt=GetTime()+0.6
    self.rows=after.rows; self.byKey=after.byKey; self.snapshot=after; self.ready=true
    if self.Notify then self:Notify(record,true) end
    self.status='Confirmed: '..record.oldName..' -> '..record.newName..(self.paused and ' (paused)' or '')
    self:Changed()
end
