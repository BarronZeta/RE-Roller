-- Every test uses mocked APIs and in-memory saved data; no real client or scrolls.
local function withActiveSpec(fn,body)
    local original=GetActiveSpecializationIndex
    GetActiveSpecializationIndex=fn
    local ok,err=pcall(body)
    GetActiveSpecializationIndex=original
    assert(ok,err)
end
local function idleTick()
    clock=clock+0.4
    for _,f in ipairs(PreviewFrames) do
        if f.events.ADDON_LOADED and f:GetScript('OnUpdate') then f:GetScript('OnUpdate')(f,0.4) end
    end
end
local function prepare()
    local R=reset()
    R.dirty=false;R.uiDirty=false;R.nextIdleRefresh=nil
    popup=nil
    return R
end

test('lock clicks before a spec refresh cannot write ability or talent locks to the old spec',function()
    for _,key in ipairs({'A:101','T:201'}) do
        local R=prepare();local oldSpec=R.spec
        local oldLocks=R:Locks(oldSpec);local newLocks=R:Locks('specialization:3')
        spec=3;R:Lock(key)
        assert(not oldLocks[key] and not newLocks[key],'stale click wrote a lock')
        assert(not R.ready and R.dirty and #calls==0)
    end
end)

test('unlock clicks before a spec refresh leave both specs protections intact',function()
    for _,key in ipairs({'A:101','T:201'}) do
        local R=prepare();local oldSpec=R.spec;R:Lock(key)
        R:Locks('specialization:3')[key]=true
        spec=3;R:Unlock(key,oldSpec)
        assert(R:Locks(oldSpec)[key] and R:Locks('specialization:3')[key])
        assert(not R.ready and R.dirty and #calls==0)
    end
end)

test('unknown native spec rejects locking unlocking and selecting without creating a nil spec',function()
    for _,mode in ipairs({'missing','throw'}) do
        local R=prepare();R:Lock('T:201');local locks=R:Locks(R.spec)
        withActiveSpec(function() if mode=='throw' then error('loading') end end,function()
            R:Lock('A:101');R:Unlock('T:201',R.spec);R:Toggle('A:102')
        end)
        assert(not locks['A:101'] and locks['T:201'] and not next(R.selected))
        assert(not R.character.specs['nil'] and not R.ready and #calls==0)
    end
end)

test('failed build refresh blocks lock edits even when the active spec index still matches',function()
    local R=prepare();R:Lock('T:201');local locks=R:Locks(R.spec)
    local original=R.Client.Snapshot
    R.Client.Snapshot=function() return nil,'Build still loading.' end
    R:Refresh();R.Client.Snapshot=original
    R:Lock('A:101');R:Unlock('T:201',R.spec)
    assert(not locks['A:101'] and locks['T:201'] and not R.ready and #calls==0)
end)

test('selection from an old spec view is rejected before any reroll can be queued',function()
    local R=prepare();R:Toggle('A:102');spec=3;R:Toggle('A:101')
    assert(not next(R.selected) and not R.ready and #calls==0)
    R:Start('ability');assert(#calls==0 and not R.running)
end)

test('replaced row objects cannot lock unlock or select an entry after a fresh snapshot',function()
    local R=prepare();local oldAbility=R.byKey['A:101'];local oldTalent=R.byKey['T:201']
    R:Refresh()
    R:RowClick(oldAbility,'RightButton');R:RowClick(oldTalent,'LeftButton')
    assert(not R:Locks(R.spec)['A:101'] and not next(R.selected) and not popup)
    R:Lock('T:201');R:RowClick(oldTalent,'RightButton')
    assert(not popup and R:Locks(R.spec)['T:201'] and #calls==0)
end)

test('stale right-click cannot open an unlock popup or lock either spec before refresh',function()
    local R=prepare();R:Lock('T:201');local oldSpec=R.spec
    local talent=R.byKey['T:201'];local ability=R.byKey['A:101']
    spec=3;R:RowClick(talent,'RightButton');R:RowClick(ability,'RightButton')
    assert(not popup and R:Locks(oldSpec)['T:201'] and not R:Locks(oldSpec)['A:101'])
    assert(not next(R:Locks('specialization:3')) and #calls==0)
end)

test('unlock popup cannot change its old spec when native spec switches before refresh',function()
    local R=prepare();R:Lock('T:201');local oldSpec=R.spec
    R:RowClick(R.byKey['T:201'],'RightButton');local confirmation=popup.data
    spec=3;StaticPopupDialogs.GRR_UNLOCK.OnAccept({},confirmation)
    assert(R:Locks(oldSpec)['T:201'] and #calls==0)
end)

test('unlock popup cannot affect either spec after switching and refreshing',function()
    local R=prepare();R:Lock('T:201');local oldSpec=R.spec
    R:RowClick(R.byKey['T:201'],'RightButton');local confirmation=popup.data
    spec=3;R:Refresh();R:Lock('T:201')
    StaticPopupDialogs.GRR_UNLOCK.OnAccept({},confirmation)
    assert(R:Locks(oldSpec)['T:201'] and R:Locks(R.spec)['T:201'] and #calls==0)
end)

test('unlock popup expires even after switching away and back to the original spec',function()
    local R=prepare();R:Lock('T:201');local oldSpec=R.spec
    R:RowClick(R.byKey['T:201'],'RightButton');local confirmation=popup.data
    spec=3;R:Refresh();spec=1;R:Refresh()
    StaticPopupDialogs.GRR_UNLOCK.OnAccept({},confirmation)
    assert(R:Locks(oldSpec)['T:201'] and #calls==0)
end)

test('ordinary same-spec refresh preserves valid confirmation and unlocks only that spec',function()
    local R=prepare();R:Lock('T:201');R:Locks('specialization:3')['T:201']=true
    R:RowClick(R.byKey['T:201'],'RightButton');local confirmation=popup.data
    R:Refresh();StaticPopupDialogs.GRR_UNLOCK.OnAccept({},confirmation)
    assert(not R:Locks(R.spec)['T:201'] and R:Locks('specialization:3')['T:201'] and #calls==0)
end)

test('unlock popup without a spec-view token cannot remove a protection',function()
    local R=prepare();R:Lock('T:201')
    StaticPopupDialogs.GRR_UNLOCK.OnAccept({},{key='T:201',spec=R.spec})
    assert(R:Locks(R.spec)['T:201'] and #calls==0)
end)

test('native spec event invalidates clicks and pending unlock popup before the new index is available',function()
    local R=prepare();R:Lock('T:201');R:Toggle('A:102')
    R:RowClick(R.byKey['T:201'],'RightButton');local confirmation=popup.data
    Fire('ACTIVE_TALENT_GROUP_CHANGED')
    R:Lock('A:101');StaticPopupDialogs.GRR_UNLOCK.OnAccept({},confirmation)
    assert(not R.ready and not next(R.selected) and R.dirty)
    assert(R:Locks(R.spec)['T:201'] and not R:Locks(R.spec)['A:101'] and #calls==0)
    spec=3;idleTick();assert(R.ready and R.spec=='specialization:3')
end)

test('idle spec detection refreshes a missed switch once without repeatedly scanning stable builds',function()
    local R=prepare();R:Lock('T:201')
    local scans=R.performance.snapshot.calls
    spec=3;idleTick()
    assert(R.spec=='specialization:3' and R.ready and not R:Locks(R.spec)['T:201'])
    assert(R.performance.snapshot.calls==scans+1)
    for i=1,12 do idleTick() end
    assert(R.performance.snapshot.calls==scans+1 and #calls==0)
end)

test('same-spec edit guards read identity without adding full build scans or requests',function()
    local R=prepare();local scans=R.performance.snapshot.calls
    for i=1,20 do R:Lock('A:101');R:Unlock('A:101',R.spec);R:Toggle('A:102') end
    assert(R.performance.snapshot.calls==scans and #calls==0)
    assert(scrollCounts[640]==10 and scrollCounts[639]==10)
end)

test('spec invalidation closes only the RE Roller unlock popup',function()
    local R=prepare();local original=StaticPopup_Hide;local hidden={}
    StaticPopup_Hide=function(name) hidden[#hidden+1]=name end
    local ok,err=pcall(function()
        spec=3;R:Lock('A:101');R:Lock('T:201')
        assert(#hidden==1 and hidden[1]=='GRR_UNLOCK' and #calls==0)
    end)
    StaticPopup_Hide=original;assert(ok,err)
end)

test('unlock popup stays expired after a temporarily unknown spec recovers',function()
    local R=prepare();R:Lock('T:201')
    R:RowClick(R.byKey['T:201'],'RightButton');local confirmation=popup.data
    withActiveSpec(function() return nil end,function() R:Lock('A:101') end)
    R:Refresh();StaticPopupDialogs.GRR_UNLOCK.OnAccept({},confirmation)
    assert(R.ready and R:Locks(R.spec)['T:201'] and not R:Locks(R.spec)['A:101'] and #calls==0)
end)

test('unavailable spec recovery retries remain bounded and preserve all saved protections',function()
    local R=prepare();R:Lock('T:201');local locks=R:Locks(R.spec)
    local scans=R.performance.snapshot.calls
    withActiveSpec(function() return nil end,function()
        for i=1,12 do idleTick() end
    end)
    local retries=R.performance.snapshot.calls-scans
    assert(retries>=1 and retries<=5 and not R.ready and locks['T:201'] and #calls==0)
    R:Refresh();assert(R.ready and R:Locks(R.spec)==locks and locks['T:201'])
end)

test('Spell Power locked on one spec stays unlocked when rolled on the other spec in either direction',function()
    for _,indexes in ipairs({{0,3},{3,0}}) do
        local R=prepare();spec=indexes[1];talents={[1826]={class=8,spell=35581,rank=2}}
        R:Refresh();R:Lock('T:1826');local oldSpec=R.spec
        spec=indexes[2];talents={[201]={class=1,spell=301}};R:Refresh()
        R:Toggle('T:201');R:Start('talent')
        talents={[1826]={class=8,spell=35581,rank=2}};scrollCounts[639]=9
        R:Result('talent',35581);R:Step(false)
        assert(R.done==1 and not R:Locks(R.spec)['T:1826'] and R:Locks(oldSpec)['T:1826'])
    end
end)

test('ability locked on one spec stays unlocked when rolled on a different spec',function()
    local R=prepare();spec=0;R:Refresh();R:Lock('A:101')
    spec=3;known={102,103};R:Refresh();R:Toggle('A:103');R:Start('ability')
    replaceAbility(103,101);scrollCounts[640]=9;R:Result('ability',101);R:Step(false)
    assert(R.done==1 and not R:Locks(R.spec)['A:101'] and R:Locks('specialization:0')['A:101'])
end)

test('existing Spell Power protections in both saved specs remain intact with no migration or cleanup',function()
    local R=prepare();local locks0=R:Locks('specialization:0');local locks3=R:Locks('specialization:3')
    locks0['T:1826']=true;locks3['T:1826']=true
    local db=R.db;local history=R.character.history
    R:InitializeDB(db);spec=3;R:Refresh()
    assert(R:Locks('specialization:0')==locks0 and R:Locks('specialization:3')==locks3)
    R:Toggle('T:201');R:Start('talent')
    talents={[1826]={class=8,spell=35581,rank=2}};scrollCounts[639]=9
    R:Result('talent',35581);R:Step(false)
    assert(R.done==1 and locks0['T:1826'] and locks3['T:1826'] and history==R.character.history)
    assert(db.schema==1)
end)
