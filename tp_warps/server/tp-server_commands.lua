local API    = {}

TriggerEvent("getTPAPI", function(cb) API = cb end)

-----------------------------------------------------------
--[[ Local Functions  ]]--
-----------------------------------------------------------

local IsPlayerAllowlisted = function (currentGroup)

    for _, group in pairs (Config.AllowlistedGroups) do
        if currentGroup == group then
            return true
        end
    end

    return false
end

---------------------------------------------------------------
--[[ Base Commands ]]--
---------------------------------------------------------------

RegisterCommand(Config.Command, function(source, args)
    local _source = source

    local group = API.getGroup(_source)

    if not IsPlayerAllowlisted(group) then
        TriggerEvent('tp_libs:sendNotification', _source, Locales['NOT_ENOUGH_PERMISSIONS'], "error")
        return
    end

    if args then

        local inputWarpName = tostring(args[1])
    
		if inputWarpName == nil or Config.Warps[inputWarpName] == nil then
            TriggerEvent('tp_libs:sendNotification', _source, Locales['WARP_DOES_NOT_EXIST'], "error")
            return
        end

        TriggerClientEvent("tp_warps:teleportOnSelectedWarpName", _source, inputWarpName)

    end

end, false)

---------------------------------------------------------------
--[[ Chat Events ]]--
---------------------------------------------------------------

RegisterServerEvent("tp_warps:addChatSuggestions")
AddEventHandler("tp_warps:addChatSuggestions", function()
    local _source = source
    local group   = API.getGroup(_source)

    if not IsPlayerAllowlisted(group) then
        return
    end

    TriggerClientEvent("chat:addSuggestion", _source, "/" .. Config.Command, "Execute this command to teleport on an existing warp.", {
        { name = "Name",  help = 'Warp Name { valentine, rhodes, vanhorn, blackwater, etc. }' },
    })

end)