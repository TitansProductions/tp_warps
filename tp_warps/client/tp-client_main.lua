
-----------------------------------------------------------
--[[ Local Functions ]]--
-----------------------------------------------------------

local TeleportToCoords = function(x, y, z, heading)
    local playerPedId = PlayerPedId()
    SetEntityCoords(playerPedId, x, y, z, true, true, true, false)

    if heading then
        SetEntityHeading(playerPedId, heading)
    end

    while not HasCollisionLoadedAroundEntity(PlayerPedId()) do
        Wait(500)
    end

end

-----------------------------------------------------------
--[[ Base Events ]]--
-----------------------------------------------------------

-- @isPlayerReady returns when the character is selected.
AddEventHandler("tp_libs:isPlayerReady", function()
    TriggerServerEvent('tp_warps:addChatSuggestions')
end)

Citizen.CreateThread(function ()
    
    Wait(2000)
    TriggerServerEvent('tp_warps:addChatSuggestions')
end)

-----------------------------------------------------------
--[[ Events ]]--
-----------------------------------------------------------

RegisterNetEvent("tp_warps:teleportOnSelectedWarpName")
AddEventHandler("tp_warps:teleportOnSelectedWarpName", function(warpName)

    if Config.Warps[warpName] == nil then
        return
    end

    DoScreenFadeOut(0)

    local coords = Config.Warps[warpName]

    TeleportToCoords(coords.x, coords.y, coords.z, coords.h)

    Wait(3000)
    DoScreenFadeIn(1000)
end)
