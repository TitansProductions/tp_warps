
local API     = {}

TriggerEvent("getTPAPI", function(cb) API = cb end)

-----------------------------------------------------------
--[[ Base Events ]]--
-----------------------------------------------------------

RegisterServerEvent('tp_mailbox:createRegistrationAccount')
AddEventHandler('tp_mailbox:createRegistrationAccount', function()
  local _source             = source

  local steamName           = GetPlayerName(_source)
  local identifier          = API.getIdentifier(_source)
  local charidentifier      = API.getChar(_source)
  local firstname, lastname = API.getFirstName(_source), API.getLastName(_source)

  local money               = API.getMoney(_source)

  if money < Config.RegistrationCost then
    TriggerClientEvent("tp_notify:sendNotification", _source, Locales['NOT_ENOUGH_FOR_REGISTRATION'].title, string.format(Locales['NOT_ENOUGH_FOR_REGISTRATION'].message, city), Locales['NOT_ENOUGH_FOR_REGISTRATION'].icon, "error", Locales['NOT_ENOUGH_FOR_REGISTRATION'].duration)
    return
  end

  API.removeMoney(_source, Config.RegistrationCost)

  local randomLetters = Config.RandomGeneratedLetters[ math.random( #Config.RandomGeneratedLetters )]
  local randomNumbers = charidentifier .. math.random(1, 9) .. math.random(1, 9) .. math.random(1, 9) .. math.random(1, 9)
        
  local uniqueId = randomLetters .. "-" .. randomNumbers

  -- If the framework is RSG or QBCORE, unique telegram id is CitizenID.
  if API.getFramework() == 'rsg' or API.getFramework() == 'qbcore' then
    uniqueId = API.getIdentifier(_source)
  end

  local Parameters = { 
    ['identifier']     = identifier,
    ['charidentifier'] = charidentifier,
    ['firstname']      = firstname,
    ['lastname']       = lastname,
    ['uniqueId']       = uniqueId,
  }
    
  exports.ghmattimysql:execute("INSERT INTO `tp_mailbox_registrations` ( `identifier`, `charidentifier`, `firstname`, `lastname`, `uniqueId`) VALUES ( @identifier, @charidentifier, @firstname, @lastname, @uniqueId)", Parameters)

  TriggerClientEvent("tp_mailbox:updatePlayerTelegramId", _source, uniqueId)

  TriggerClientEvent("tp_notify:sendNotification", _source, Locales['SUCCESSFUL_REGISTRATION'].title, string.format(Locales['SUCCESSFUL_REGISTRATION'].message, city), Locales['SUCCESSFUL_REGISTRATION'].icon, "success", Locales['SUCCESSFUL_REGISTRATION'].duration)

  local webhookData = Config.DiscordWebhooking['REGISTERED']
    
  if webhookData.Enable then
    local title   = "📬` The following player has been successfully registered on the mailbox post office.`"
      
    local message = "**Steam name: **`" .. steamName .. "`**\nIdentifier: **`" .. identifier .. " (Char: " .. charidentifier .. ") `"
    API.sendToDiscord(webhookData.Url, title, message, webhookData.Color)
  end

end)

RegisterServerEvent('tp_mailbox:requestMailboxInformation')
AddEventHandler('tp_mailbox:requestMailboxInformation', function()
  local _source = source

  if (API.getPlayer(_source) == nil) then
    return
  end

  local identifier          = API.getIdentifier(_source)
  local charidentifier      = API.getChar(_source)
  local firstname, lastname = API.getFirstName(_source), API.getLastName(_source)

  local job                 = API.getJob(_source)

  -- We check if the connected players has uniqueId available before sending the Mailbox data
  -- If the player does not have uniqueId, we generate it.
  exports["ghmattimysql"]:execute("SELECT * FROM `tp_mailbox_registrations` WHERE `identifier` = @identifier AND `charidentifier` = @charidentifier", { 
    ["@identifier"] = identifier , ["@charidentifier"] = charidentifier }, function(result)

      local uniqueId = nil

      if result[1] then
        uniqueId = result[1].uniqueId
      end

    -- Sending Telegrams Data & User Mailbox ID (Generated / Not).
    local userData = { id = uniqueId, job = job, firstname = firstname, lastname = lastname }
    TriggerClientEvent("tp_mailbox:getMailboxInformation", _source, userData)

  end)

end)

-----------------------------------------------------------
--[[ General Events ]]--
-----------------------------------------------------------

RegisterServerEvent('tp_mailbox:sendTelegram')
AddEventHandler('tp_mailbox:sendTelegram', function(personalTelegramId, selectedTelegramId, title, content, location, stamp, anonymous) 
  local _source             = source

  local identifier          = API.getIdentifier(_source)
  local charidentifier      = API.getChar(_source)
  local username            = API.getFirstName(_source) .. " " .. API.getLastName(_source)

  local timeStamp           = os.date('%d').. '/' ..os.date('%m').. '/' .. Config.Year .. " " .. os.date('%H') .. ":" .. os.date('%M')
  local stampBackgroundUrl  = Config.Stamps[stamp].BackgroundImage

  local anonymousValue      = 0

  local money   = API.getMoney(_source)

  if money < Config.Stamps[stamp].Cost then
    TriggerClientEvent("tp_mailbox:sendNotification", _source, Locales['TELEGRAM_NOT_ENOUGH_MONEY'], "error")
    return
  end
  
  -- If the telegram id is for all the registered citizens.
  if selectedTelegramId == -1 or selectedTelegramId == '-1' then

    exports["ghmattimysql"]:execute("SELECT * FROM `tp_mailbox_registrations`", {}, function(players)

      local registeredPlayersLength  = GetTableLength(players)

      API.removeMoney(_source, Config.Stamps[stamp].Cost)

      for index, player in pairs (players) do
        
        local Parameters = { 
  
          ['sender_username']    = username, 
          ['sender_uniqueId']    = personalTelegramId,
      
          ['receiver_uniqueId']  = player.uniqueId,
      
          ['title']              = title,
          ['message']            = content,
          ['city']               = location, 
          ['timestamp']          = timeStamp,
          ['stamp']              = stampBackgroundUrl,
          ['anonymous']          = 0,
        }

        exports.ghmattimysql:execute("INSERT INTO `tp_mailbox` (`sender_username`, `sender_uniqueId`, `receiver_uniqueId`, `title`, `message`, `city`, `timestamp`, `stamp`, `anonymous` ) VALUES ( @sender_username, @sender_uniqueId, @receiver_uniqueId, @title, @message, @city, @timestamp, @stamp, @anonymous)", Parameters)

        local targetSource = GetSourceFromParameters(player.identifier, player.charidentifier)
  
        if targetSource and targetSource ~= 0 then
          
          local notifyData = Locales['RECEIVED_MAIL']
          TriggerClientEvent("tp_notify:sendNotification", targetSource, notifyData.title, notifyData.message, notifyData.icon, "info", notifyData.duration)
      
          TriggerClientEvent("tp_mailbox:refreshTelegrams", targetSource)
        end
        
      end

      TriggerClientEvent('tp_mailbox:successfullTelegramSent', _source)
      TriggerClientEvent("tp_mailbox:sendNotification", _source, Locales['TELEGRAM_HAS_BEEN_SENT'], "success")
  
      local webhookData = Config.DiscordWebhooking['SENT_TELEGRAM']
      
      if webhookData.Enable then
        
        local webhookTitle   = "📬` " .. username .. " (Steam Identifier: " .. identifier .. " | Char Id: " .. charidentifier .. ") sent a telegram to all registered citizens.`"
          
        local message = "**\nTitle: **`" .. title .. "`**\nContent: **`" .. content .. ". `"
        TriggerEvent("tp_libs:sendToDiscord", webhookData.Url, webhookTitle, message, webhookData.Color)
      end

    end)
  
  else -- If the telegram id is for a specific registered citizen and not everyone.
    
    -- The anonymous can be a boolean or string due to javascript parse.
    if anonymous == true or anonymous == 'true' then
      username           = Locales['ANONYMOUS_SENDER_NAME']
      personalTelegramId = Locales['ANONYMOUS_TELEGRAM_ID']
  
      anonymousValue     = 1
    end

    API.removeMoney(_source, Config.Stamps[stamp].Cost)
  
    local Parameters = { 
  
      ['sender_username']    = username, 
      ['sender_uniqueId']    = personalTelegramId,
  
      ['receiver_uniqueId']  = selectedTelegramId,
  
      ['title']              = title,
      ['message']            = content,
      ['city']               = location, 
      ['timestamp']          = timeStamp,
      ['stamp']              = stampBackgroundUrl,
      ['anonymous']          = anonymousValue,
    }
  
    exports.ghmattimysql:execute("INSERT INTO `tp_mailbox` (`sender_username`, `sender_uniqueId`, `receiver_uniqueId`, `title`, `message`, `city`, `timestamp`, `stamp`, `anonymous` ) VALUES ( @sender_username, @sender_uniqueId, @receiver_uniqueId, @title, @message, @city, @timestamp, @stamp, @anonymous)", Parameters)
    
    TriggerClientEvent('tp_mailbox:successfullTelegramSent', _source)
    TriggerClientEvent("tp_mailbox:sendNotification", _source, Locales['TELEGRAM_HAS_BEEN_SENT'], "success")
  
    local targetSource = GetSourceFromParametersWithSQLResults(selectedTelegramId)
  
    if targetSource and targetSource ~= 0 then
      
      local notifyData = Locales['RECEIVED_MAIL']
      TriggerClientEvent("tp_notify:sendNotification", targetSource, notifyData.title, notifyData.message, notifyData.icon, "info", notifyData.duration)
  
      TriggerClientEvent("tp_mailbox:refreshTelegrams", targetSource)
    end
  
    local webhookData = Config.DiscordWebhooking['SENT_TELEGRAM']
      
    if webhookData.Enable then

      local targetData = GetDataFromSourceParameterWithSQLResults(selectedTelegramId)
      
      local webhookTitle   = "📬` " .. username .. 
      " (Steam Identifier: " .. identifier .. " | Char Id: " .. charidentifier .. ") sent a telegram to"..
      " (Target Steam Identifier: " .. targetData.identifier .. " | Target Char Id: " .. targetData.charidentifier .. " | Target First & Lastname: " .. targetData.firstname .. " " .. targetData.lastname .. ")`"

      local message = "**\nTitle: **`" .. title .. "`**\nContent: **`" .. content .. ". `"
      TriggerEvent("tp_libs:sendToDiscord", webhookData.Url, webhookTitle, message, webhookData.Color)
    end

  end

end)

RegisterServerEvent("tp_mailbox:setTelegramStateAsViewed")
AddEventHandler("tp_mailbox:setTelegramStateAsViewed", function(telegramId)
  exports.ghmattimysql:execute("UPDATE `tp_mailbox` SET `viewed` = @viewed WHERE id = @id", { ['id'] = tonumber(telegramId), ['viewed'] = 1})
end)

RegisterServerEvent('tp_mailbox:deleteSelectedTelegram')
AddEventHandler('tp_mailbox:deleteSelectedTelegram', function(telegramId)
  local _source = source

  exports.ghmattimysql:execute("DELETE FROM `tp_mailbox` WHERE `id` = @id", {["@id"] = telegramId}) 

  TriggerClientEvent("tp_mailbox:sendNotification", _source, Locales['TELEGRAM_HAS_BEEN_DELETED'], "info")
  TriggerClientEvent("tp_mailbox:refreshTelegrams", _source)
end)

-- Add new mailbox office contacts.
RegisterServerEvent("tp_mailbox:addContact")
AddEventHandler("tp_mailbox:addContact", function(telegramId, targetTelegramId, targetUsername)
  local _source = source

  exports["ghmattimysql"]:execute("SELECT * FROM `tp_mailbox_registrations` WHERE `uniqueId` = @uniqueId", { 
		["@uniqueId"] = telegramId }, function(result)

			local contactList = json.decode(result[1].contacts)

      table.insert(contactList, { uniqueid = targetTelegramId, username = targetUsername })

      exports.ghmattimysql:execute("UPDATE `tp_mailbox_registrations` SET `contacts` = @contacts WHERE uniqueId = @uniqueId", { 
        ['uniqueId'] = telegramId, 
        ['contacts'] = json.encode(contactList)
      })

      TriggerClientEvent("tp_mailbox:refreshContacts", _source)

    end)
end)


-- Add new mailbox office contacts.
RegisterServerEvent("tp_mailbox:removeContact")
AddEventHandler("tp_mailbox:removeContact", function(telegramId, targetTelegramId)
  local _source = source
  
  exports["ghmattimysql"]:execute("SELECT * FROM `tp_mailbox_registrations` WHERE `uniqueId` = @uniqueId", { 
		["@uniqueId"] = telegramId }, function(result)

			local contactList = json.decode(result[1].contacts)

      for _, contact in pairs (contactList) do

        if contact.uniqueid == targetTelegramId then
          table.remove(contactList, _)
        end

      end

      exports.ghmattimysql:execute("UPDATE `tp_mailbox_registrations` SET `contacts` = @contacts WHERE uniqueId = @uniqueId", { 
        ['uniqueId'] = telegramId, 
        ['contacts'] = json.encode(contactList)
      })

      TriggerClientEvent("tp_mailbox:refreshContacts", _source)

    end)
end)
