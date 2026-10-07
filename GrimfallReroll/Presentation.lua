local R=GrimfallReroll
local P={}; R.Presentation=P
local fallbackIcon='Interface\\Icons\\Ability_DualWieldSpecialization'
local function call(fn,...)
    if type(fn)=='function' then return pcall(fn,...) end
    return false
end
-- Read the zero-based custom spec slot exactly as Grimfall's native panel does.
-- Display metadata never changes queue identity, saved locks, or active spec.
function P:CurrentSpec()
    local ok,index=call(GetActiveSpecializationIndex); index=tonumber(index)
    if not ok or not index or index<0 or index%1~=0 then
        return {name='Spec Unavailable',icon='Interface\\Icons\\INV_Misc_QuestionMark',verified=false}
    end
    local infoOK,info=call(GetSpecializationInfo,index)
    if not infoOK or type(info)~='table' then
        local listOK,list=call(GetSpecializations)
        info=listOK and type(list)=='table' and (list[index] or list[tostring(index)]) or nil
    end
    local againOK,again=call(GetActiveSpecializationIndex)
    if not againOK or tonumber(again)~=index then
        return {name='Spec Updating',icon=fallbackIcon,verified=false}
    end
    if type(info)~='table' then return {name='Spec Unavailable',icon=fallbackIcon,index=index,verified=false} end
    local name=type(info.SpecializationName)=='string' and info.SpecializationName:match('^%s*(.-)%s*$') or ''
    local icon=info.SpecializationIconName
    if type(icon)~='string' or icon=='' then icon=fallbackIcon
    elseif not icon:find('\\',1,true) and not icon:find('/',1,true) then icon='Interface\\Icons\\'..icon end
    return {name=name~='' and name or 'Unnamed Spec',icon=icon,index=index,verified=true}
end
function P:SetFont(object,size)
    -- Reuse the user's installed Emblem face; it is not redistributed in our ZIP.
    local paths={}
    if LibStub then
        local ok,media=pcall(function() return LibStub('LibSharedMedia-3.0',true) end)
        if ok and media and type(media.Fetch)=='function' then
            local found,path=pcall(media.Fetch,media,'font','Emblem',true)
            if found and type(path)=='string' and path~='' then paths[#paths+1]=path end
        end
    end
    paths[#paths+1]='Interface\\AddOns\\VuhDo\\Fonts\\Emblem.ttf'
    paths[#paths+1]='Interface\\AddOns\\GrimfallReroll\\Fonts\\PT_Sans-Web-Regular.ttf'
    paths[#paths+1]='Fonts\\FRIZQT__.TTF'
    for _,path in ipairs(paths) do
        local ok,loaded=pcall(object.SetFont,object,path,size,'')
        if ok and loaded then return path end
    end
end
