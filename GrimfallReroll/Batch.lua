-- Batch mode freezes the selected queue and displayed lists. Full build reads
-- happen before the first request and after native presentation of the last
-- result, not between rolls. Events + exact inventory deltas acknowledge each
-- request; only the final full build check commits confirmed history.
local R=GrimfallReroll
local strict={Start=R.Start,Step=R.Step,Stop=R.Stop,Refresh=R.Refresh,
    RequestRefresh=R.RequestRefresh,CanEditEntry=R.CanEditEntry,Clear=R.Clear}
function R:BatchEnabled()return self.db and self.db.batch~=false end
function R:SetBatchMode(enabled)
    if self.batch or self.running or self.pending or self.refreshJob then return false end
    self.db.batch=enabled and true or false
    self:SetStatus(enabled and 'Batch reads enabled: lists refresh after the queue finishes.' or 'Per-roll full verification enabled.')
    return true
end
function R:CanEditEntry(...)if self.batch then return false end;return strict.CanEditEntry(self,...)end
function R:Clear()if self.batch then return end;return strict.Clear(self)end
function R:Refresh()if self.batch then return end;return strict.Refresh(self)end
function R:RequestRefresh()if self.batch then return end;return strict.RequestRefresh(self)end
function R:Start(kind)
    if self.batch or self.pending or self.running then return end
    if not self:BatchEnabled() then return strict.Start(self,kind)end
    -- The original startup path still checks a fresh complete build, selected
    -- locks, total scroll budgets, combat/death and native event availability.
    self.startingBatch=true
    local ok,why=pcall(strict.Start,self,kind)
    self.startingBatch=nil
    if not ok then self:Stop('Batch startup failed safely: '..tostring(why))end
end
function R:Stop(reason)
    local batch=self.batch
    if batch then batch.stopped=true;batch.stopReason=reason or 'Stopped.'end
    strict.Stop(self,reason)
    -- An outstanding request still gets observed, but no further request can
    -- be sent. Core keeps polling the batch until its final read completes.
end
local function countsMatch(self,batch)
    for _,kind in ipairs({'ability','talent'})do
        local n=self.Client:Count(kind)
        if n==nil or n~=batch.counts[kind]then return false end
    end
    return true
end
local function reject(self,message)
    if self.pending then self.pending.ambiguous=true end
    self:Stop(message..' No further rerolls sent.')
end
function R:Step(clicked,startSnapshot,startReadMS)
    if self.startingBatch and not self.batch and self.running and startSnapshot then
        if startSnapshot.epoch~=(self.buildEpoch or 0)then self:Stop('Build changed during batch startup. Refresh and select again.');return end
        self.batch={before=startSnapshot,records={},counts={ability=self.Client:Count('ability'),talent=self.Client:Count('talent')},
            readMS=startReadMS or 0,started=GetTime()}
        self.performance=self.performance or {};self.performance.batchStarts=(self.performance.batchStarts or 0)+1
    end
    local batch=self.batch
    if not batch then return strict.Step(self,clicked,startSnapshot,startReadMS)end
    if self.pending then self:CheckBatchPending();return end
    if batch.stopped or #self.queue==0 then self:FinishBatch();return end
    if not self.running or self.paused or GetTime()<(self.nextAt or 0)then return end
    if self.manual and not clicked then return end
    local safe,why=self.Client:Safe()
    if not safe then reject(self,why);return end
    if self.Client:Spec()~=batch.before.spec then reject(self,'Active spec changed.');return end
    if not countsMatch(self,batch)then reject(self,'Scroll counts changed outside this batch.');return end
    if self.Client:AnimationBusy()then
        batch.animationAt=batch.animationAt or GetTime()
        if GetTime()-batch.animationAt>12 then reject(self,'Native presentation did not finish.')end
        return
    end
    batch.animationAt=nil
    local target=self.queue[1]
    if not target or self:Locks(batch.before.spec)[target.key] then reject(self,'Queued entry became protected.');return end
    -- Entries come only from the fresh initial snapshot. Never add a rolled
    -- replacement to this queue, and never guess a new talent ID from a spell ID.
    local original=batch.before.byKey[target.key]
    if not original or original.spellID~=target.spellID then reject(self,'Queued identity changed.');return end
    local other=target.kind=='ability' and 'talent' or 'ability'
    if not batch.counts[target.kind] or batch.counts[target.kind]<1 then reject(self,'No matching scroll remains.');return end
    table.remove(self.queue,1)
    local p={target=target,before=batch.before,at=GetTime(),requestAt=GetTime(),scrolls=batch.counts[target.kind],
        other=other,otherCount=batch.counts[other],requestReadMS=self.done==0 and batch.readMS or 0,resultReadMS=0}
    self.pending=p;self.selected[target.key]=nil
    if batch.lastAck then
        p.gapMS=math.max(0,(p.requestAt-batch.lastAck)*1000);p.minimumMS=self.interRollDelay*1000
        self:RecordWork('batch_gap',p.gapMS)
    end
    self:SetStatus('Rolling '..target.name..' ('..(self.done+1)..'/'..self.total..') - lists update after the batch.')
    p.requestAt=GetTime()
    local ok,requested=pcall(self.Client.Request,self.Client,target)
    if not ok or not requested then self:Stop('Reroll request refused or blocked. No retry; checking for a late result.')end
    self:WakeQueue()
end
function R:CheckBatchPending()
    local batch,p=self.batch,self.pending;if not batch or not p then return end
    if self.Client:Spec()~=batch.before.spec then p.ambiguous=true;self:Stop('Spec changed while awaiting a result.')end
    if p.ambiguous then self.pending=nil;return end
    if GetTime()-p.at>20 then
        self.pending=nil;self:Stop('Result not acknowledged within 20 seconds. No retry sent.');return
    end
    if not p.result then return end
    local count,other=self.Client:Count(p.target.kind),self.Client:Count(p.other)
    if count==nil or other==nil then return end
    local spent=p.scrolls-count
    if spent==0 and other==p.otherCount then return end
    if spent~=1 or other~=p.otherCount then reject(self,'Unexpected scroll-count change.');return end
    if not p.scrollMS then
        p.scrollMS=math.max(0,(GetTime()-p.requestAt)*1000);self:RecordWork('queue_scroll',p.scrollMS)
    end
    -- The native animation owns the result-flush callback. Never hide it or
    -- invoke that callback ourselves, and do not overlap its next transaction.
    if self.Client:AnimationBusy()then return end
    for _,prior in ipairs(batch.records)do
        if prior.result==p.result then reject(self,'Duplicate or late result is ambiguous.');return end
    end
    for key,row in pairs(batch.before.byKey)do
        if key~=p.target.key and (row.spellID==p.result or (row.ranks and row.ranks[p.result]))then
            local alreadyRolled=false
            for _,prior in ipairs(batch.records)do if prior.target.key==key then alreadyRolled=true;break end end
            if not alreadyRolled then reject(self,'Result conflicts with another original build entry.');return end
        end
    end
    p.ackMS=math.max(0,(GetTime()-p.requestAt)*1000)
    self:RecordWork('batch_ack',p.ackMS)
    batch.records[#batch.records+1]=p;batch.counts[p.target.kind]=count;batch.lastAck=GetTime()
    self.pending=nil;self.done=#batch.records;self.nextAt=GetTime()+self.interRollDelay
    self:SetStatus(self.done..' / '..self.total..' results received - final build verification pending.')
    -- No game request is sent from this acknowledgement or from an event.
end
function R:VerifyBatch(batch,after)
    if after.spec~=batch.before.spec then return false,'Active spec changed.'end
    local expected={spec=after.spec,byKey={}};local resolved={}
    for key,row in pairs(batch.before.byKey)do expected.byKey[key]=row end
    for _,p in ipairs(batch.records)do expected.byKey[p.target.key]=nil end
    for _,p in ipairs(batch.records)do
        local found=nil
        for _,row in ipairs(after.rows)do
            if row.kind==p.target.kind and (row.spellID==p.result or (row.ranks and row.ranks[p.result]))then
                if found then return false,'Ambiguous replacement in final build.'end;found=row
            end
        end
        if not found then return nil,'Waiting for the client to publish the complete final build.'end
        if expected.byKey[found.key]then return false,'Final result conflicts with an unchanged entry.'end
        resolved[#resolved+1]=found;expected.byKey[found.key]=found
    end
    if not self.SameBuild(expected,after)then return false,'Other build entries changed during the batch.'end
    return true,resolved
end
function R:FinishBatch()
    local batch=self.batch;if not batch or self.pending then return end
    batch.finishAt=batch.finishAt or GetTime()
    if self.Client:AnimationBusy() and GetTime()-batch.finishAt<12 then return end
    if batch.nextRead and GetTime()<batch.nextRead then return end
    batch.nextRead=GetTime()+1
    local after,why=self:QueueSnapshot('batch_final_read')
    local valid,resolved
    if after then valid,resolved=self:VerifyBatch(batch,after)else resolved=why end
    if not countsMatch(self,batch)then valid=false;resolved='Final scroll counts do not match the acknowledged results.'end
    if valid==nil and GetTime()-batch.finishAt<20 then
        self:SetStatus(resolved or 'Waiting for the final build read.');return
    end
    if valid then
        local timings=self.performance.rollTimings or {};self.performance.rollTimings=timings
        for i,p in ipairs(batch.records)do
            local row=resolved[i]
            self:ReleaseReplacementLock(row,batch.before)
            local record={at=time(),spec=after.spec,kind=row.kind,oldID=p.target.spellID,oldName=p.target.name,
                newID=row.spellID,newName=row.name,spent=1}
            table.insert(self.character.history,1,record);self:TrimHistory(self.character)
            if self.Notify then self:Notify(record,true)end
            timings[#timings+1]={kind=row.kind,eventMS=p.eventMS,scrollMS=p.scrollMS,ackMS=p.ackMS,
                requestReadMS=p.requestReadMS,resultReadMS=0,gapMS=p.gapMS,minimumMS=p.minimumMS,batch=true}
            while #timings>20 do table.remove(timings,1)end
        end
    end
    self.batch=nil;self.pending=nil
    local message=valid and (batch.stopped and ((batch.stopReason or 'Stopped.')..' '..#batch.records..' completed results verified.')
        or ('Finished: '..#batch.records..' confirmed rerolls. Lists refreshed once.'))
        or ('Batch stopped for review: '..tostring(resolved or 'Final build unavailable.')..' No further rerolls sent.')
    strict.Stop(self,message)
    if after then self:ApplySnapshot(after)else self:InvalidateSpecView();self.dirty=true end
    if self.db.lastQueueStatus then
        self.db.lastQueueStatus.confirmed=valid and #batch.records or 0;self.db.lastQueueStatus.processed=#batch.records
    end
    self:SetStatus(message)
end
