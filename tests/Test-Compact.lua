local function history(n,kind)
 local out={};for i=1,n do out[i]={kind=kind or (i%2==0 and 'talent' or 'ability'),oldName='Old '..i,newName='New '..i,oldID=101,newID=102,at=time()-i}end
 return out
end
test('history migration keeps newest twenty of each kind in original order and table identity',function()
 local R=reset();local h=history(100);R.character.history=h;local first=h[1];local last=h[40]
 R:InitializeDB(R.db);assert(R.character.history==h and #h==40 and h[1]==first and h[40]==last)
 for i,r in ipairs(h)do assert(r.oldName=='Old '..i)end
end)
test('one history cannot consume or evict the other history allowance',function()
 local R=reset();local h=history(61,'ability');local rare={kind='talent',oldName='Talent'};h[62]=rare;R.character.history=h
 R:TrimHistory(R.character);assert(#h==21 and h[21]==rare)
 for i=1,35 do table.insert(h,1,{kind='ability',oldName='Later '..i});R:TrimHistory(R.character)end
 assert(#h==21 and h[1].oldName=='Later 35' and h[20].oldName=='Later 16' and h[21]==rare)
end)
test('history pruning is per character and leaves all specs locks and other settings intact',function()
 local R=reset();local db=R.db;R:Lock('T:201');local locks=R:Locks(R.spec)
 db.skin='clean';db.x=47;db.characters.Other={history=history(99,'talent'),specs={preserved={locks={['A:9']=true}}}}
 R.character.history=history(60);R:InitializeDB(db)
 assert(#R.character.history==40 and #db.characters.Other.history==20)
 assert(db.characters.Other.specs.preserved.locks['A:9'] and locks==R:Locks(R.spec) and locks['T:201'])
 assert(db.skin=='clean' and db.x==47 and #calls==0)
end)
test('new confirmations enforce history limit while Clear only clears selection',function()
 local R=reset();R.character.history=history(20,'ability');local oldest=R.character.history[20]
 R:Toggle('A:101');R:Start('ability');replaceAbility(101,103);scrollCounts[640]=9;R:Result('ability',103);R:Step(false)
 assert(#R.character.history==20 and R.character.history[1].newID==103)
 for _,h in ipairs(R.character.history)do assert(h~=oldest)end
 R:Clear();assert(#R.character.history==20 and #calls==1)
end)
test('history rows use smaller icons and compact two-line names with independent hover targets',function()
 local R=reset();R.character.history=history(2);R:Render()
 for _,p in pairs(R.window.historyDrawers)do
  local row=p.rows[1];assert(row.height==110 and row.oldIcon.width==28 and row.newIcon.height==28)
  assert(row.oldBorder.width==34 and row.newBorder.width==34 and row.oldName.width==138)
  assert(row.oldName.fontObject.fontSize==13 and row.oldName.wordWrap and row.newName.wordWrap)
  assert(row.oldHit.height==40 and row.newHit.height==40 and p.count:GetText()=='1 / 20 Rerolls Saved')
 end
end)
test('history display never allocates more than twenty records per drawer',function()
 local R=reset();R.character.history=history(100);R:Render()
 for _,p in pairs(R.window.historyDrawers)do assert(#p.records==20 and p.canvas.height==2200)end
 assert(#calls==0)
end)
test('unknown legacy history records are ignored without creating fabricated results',function()
 local R=reset();local good={kind='ability',oldName='Legacy',newName='Result'}
 R.character.history={false,{kind='invalid'},good};R:TrimHistory(R.character)
 assert(#R.character.history==1 and R.character.history[1]==good)
end)
test('dormant ability protection does not hide a newly confirmed replacement',function()
 local R=reset();R:Locks(R.spec)['A:103']=true;R:Locks('specialization:3')['A:103']=true
 R.db.hideLocked={ability=true};R:Toggle('A:101');R:Start('ability')
 replaceAbility(101,103);scrollCounts[640]=9;R:Result('ability',103);R:Step(false)
 assert(not R:Locks(R.spec)['A:103'] and R:Locks('specialization:3')['A:103'])
 local found=false;for _,row in ipairs(R.window.panels.ability.rows)do if row:IsShown() and row.entry.key=='A:103'then found=true end end
 assert(found and not R.selected['A:103'])
end)
test('unconfirmed or ambiguous replacements cannot clear dormant locks',function()
 local R=reset();R:Locks(R.spec)['A:103']=true;R:Toggle('A:101');R:Start('ability')
 R:Result('ability',103);R:Step(false);assert(R:Locks(R.spec)['A:103'])
 R:Result('ability',104);replaceAbility(101,103);scrollCounts[640]=9;R:Step(false)
 assert(R:Locks(R.spec)['A:103'] and #R.character.history==0)
end)
