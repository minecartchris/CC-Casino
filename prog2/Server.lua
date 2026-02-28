--[[
  Casino Central Server
  Copyright 2026 Herr Katze and minecartchris
  License: MIT
]]

-- permission function takes uuid as argument

local loop = require("taskmaster")()
local sha256 = require("sha256")

local nfc = peripheral.find("nfc_reader")
local modem = peripheral.find("modem", function(n,w) return not w.isWireless() end)

rednet.open(peripheral.getName(modem))
local permissions = {}

function permissions.all()
  return true
end

function permissions.admin(player)
  --TODO: check player uuid against configurable admins, currently hardcoded to be Herr Katze
  if player == "1f558cbb-0752-49c0-ace4-7f9ed0506fe3" then return true end
  if player == "1de578d0-4eae-48db-abc9-7bf3354f809b" then return true end
  return false
end

local accounts = {}
--[[
  Account format:
  {
    username = "HerrKatzeGaming",
    uuid = "1f558cbb-0752-49c0-ace4-7f9ed0506fe3",
    balance = 69420,
    validCard = nil, -- either nil for no card, or a random uuid,
    banned = false
  }
]]

local function saveAccounts()
  local data = textutils.serialize(accounts)
  local f = fs.open("accounts.slt","w")
  f.write(data)
  f.close()
end
if not fs.exists("accounts.slt") then
  saveAccounts()
end

do
  local f = fs.open("accounts.slt","r")
  data = f.readAll()
  f.close()
  accounts = textutils.unserialize(data)
end

local pkeyFile = fs.open("pkey","r")
assert(pkeyFile,"private key file does not exist!")
local pkey = pkeyFile.readLine()
pkeyFile.close()
local function createAccount(username,uuid,balance)
balance = balance or 0
accounts[uuid] = {
  username = username,
  uuid = uuid,
  balance = balance
}
saveAccounts()
end

local function registerCard(uuid)
  local r = http.get("https://www.uuidgenerator.net/api/version4")
  local cardId = r.readAll()
  r.close()
  rednet.broadcast(cardId,"nfc_atm_write")
  local id, message = rednet.receive("casinoATMC2S", 61) -- 61 seconds so that the timeout should be handled properly
  if not id then
    chatbox.tell(uuid, "<red>Did not receive response from ATM, Please ping a casino maintainer</red>", "Chris's Casino", "minimessage")
    return
  end
  if message.type == "card_timeout" then
    chatbox.tell(uuid, "<red>Card creation timed out. Re run the command to register your card.</red>", "Chris's Casino", "minimessage")
    return
  end
  if message.type == "card_created" then
    accounts[uuid].validCard = cardId
    chatbox.tell(uuid, "<green>Card registered.", "Chris's Casino", "minimessage")
    saveAccounts()
    return
  end
  print("[ERROR] Received Invalid message type",message.type)
end

local function revokeCard(uuid)
  if not accounts[uuid] then
    chatbox.tell(uuid,"<red>Cannot revoke card for non-existant account</red>", "Chris's Casino", "minimessage")
    return
  end
  if not accounts[uuid].validCard then
    chatbox.tell(uuid,"<red>Card not created or already revoked.</red>", "Chris's Casino", "minimessage")
    return
  end
  accounts[uuid].validCard = nil
  saveAccounts()
  chatbox.tell(uuid, "<green>Card revoked. use <blue>\\casino register</blue> to obtain a new one. Your balance will transfer to the new card.", "Chris's Casino", "minimessage")
end

local function deleteAccount(uuid)
  accounts[uuid] = nil
end

local kromerNode = "https://kromer.reconnected.cc/api/krist"


local commands = {}
local function makeaddressbyte(byte)
    local byte = 48 + math.floor(byte/7)
    return string.char(byte + 39 > 122 and 101 or byte > 57 and byte + 39 or byte)
end
local function make_address(key)
  local protein = {}
  local stick = sha256(sha256(key))
  local n = 0
  local link = 0
  local v2 = "k"
  repeat
      if n<9 then protein[n] = string.sub(stick,0,2)
      stick = sha256(sha256(stick)) end
      n = n+1
  until n==9
  n=0
  repeat
      link = tonumber(string.sub(stick,1+(2*n),2+(2*n)),16) % 9
      if string.len(protein[link]) ~= 0 then
          v2 = v2 .. makeaddressbyte(tonumber(protein[link],16))
          protein[link] = ''
          n=n+1
      else
      stick = sha256(stick)
      end
  until n==9
  return v2
end

local function split(inputstr, sep)
  sep = sep or ","
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end
local address = make_address(pkey)
print(address)
local function handleWebSockets()
    local id = -1
    local r,f = http.post(kromerNode.."/ws/start","{\"privatekey\":\""..pkey.."\"}",{["content-type"]="application/json"})
    local resp = textutils.unserialiseJSON(r.readAll())
    r.close()
    r = nil
    if  resp.ok then
        socket = http.websocket(resp.url)
        print("Connected to Krist Websockets")
        id = id + 1
        socket.send('{\"id\":'..id ..',\"type\":\"subscribe\",\"event\":\"ownTransactions\"}')
        while true do
            event = {os.pullEvent()}
            if event[1] == "websocket_message" then
                if event[2] == resp.url then
                    wsevent = textutils.unserialiseJSON(event[3])
                    if wsevent.event == "transaction" and wsevent.transaction.to == address then
                        local from = wsevent.transaction.from
                        local hasMessage = false
                        local hasError = false
                        local hasUUID = false
                        local otherUUID = nil
                        err = ""
                        if wsevent.transaction.metadata then
                            mta = split(wsevent.transaction.metadata,";")
                            for i,p in pairs(mta) do
                                if p:match("useruuid") and not hasUUID then
                                    otherUUID = split(p,"=")[2]
                                    hasUUID = true
                                end
                            end
                        end
                        print(otherUUID)
                        if not otherUUID then
                          os.queueEvent("make_transaction",wsevent.transaction.from,wsevent.transaction.value)
                        else
                          if not accounts[otherUUID] then
                            chatbox.tell(otherUUID,"<red>Player doesn't have an account.", "Chris's Casino", "minimessage")
                            os.queueEvent("make_transaction",wsevent.transaction.from,wsevent.transaction.value)
                          else
                          accounts[otherUUID].balance = accounts[otherUUID].balance + wsevent.transaction.value
                          chatbox.tell(otherUUID,"<green>Added <blue>"..wsevent.transaction.value.."</blue> to your balance", "Chris's Casino", "minimessage")
                          saveAccounts()
                          end
                        end

                    elseif wsevent.type == "keepalive" or wsevent.type == "response" then
                    else
                    end
                end


            elseif event[1] == "make_transaction" then
                id = id + 1
                local rq = {
                    id = id,
                    type="make_transaction",
                    to = event[2],
                    amount = event[3],
                    metadata = event[4],
                }
                socket.send(textutils.serialiseJSON(rq))
                local c
                repeat
                c = socket.receive()
                c = textutils.unserialiseJSON(c)
                until c.type == "response"
                os.queueEvent("transaction_complete",c.ok)
            end
        end
    end
end
commands.balance = {
  exec= function(name, uuid, args)
    if accounts[uuid] and accounts[uuid].banned then
      chatbox.tell(uuid,"<red>You have been banned from Chris's Casino, Please contact a casino maintainer for a balance refund.", "Chris's Casino", "minimessage")
      return
    end
    if #args == 0 or not permissions.admin(uuid) then
      if not accounts[uuid] then
        chatbox.tell(name,"<red>You don't have an account, use <blue>\\casino register</blue> to get one", "Chris's Casino", "minimessage")
        return
      end
      chatbox.tell(name,"<green>Your balance is <blue>"..accounts[uuid].balance.."</blue>", "Chris's Casino", "minimessage")
    else
      local otherUUID = args[1]
        if not accounts[otherUUID] then
        chatbox.tell(name,"<red>Player doesn't have an account.", "Chris's Casino", "minimessage")
        return
      end
      chatbox.tell(name,"<green>"..accounts[otherUUID].username.."'s balance is <blue>"..accounts[otherUUID].balance.."</blue>", "Chris's Casino", "minimessage")
    end
  end,
  permission = permissions.all
}
commands.withdraw = {
  exec = function(name,uuid,args)
    local number = tonumber(args[1])
    if not number then
        chatbox.tell(uuid,"<red>This is not a number!</red>", "Chris's Casino","minimessage")
        return
    end
    if accounts[uuid] and accounts[uuid].banned then
      chatbox.tell(uuid,"<red>You have been banned from Chris's Casino, Please contact a casino maintainer for a balance refund.", "Chris's Casino", "minimessage")
      return
    end
    if not accounts[uuid] then
      chatbox.tell(name,"<red>You don't have an account, use <blue>\\casino register</blue> to get one", "Chris's Casino", "minimessage")
      return
    end
      local response = http.get(("https://kromer.reconnected.cc/api/v1/wallet/by-name/%s"):format(name))
      response = textutils.unserializeJSON(response.readAll())
      local address = response.data[1].address
      local amount = math.min(number,accounts[uuid].balance)
      print(amount)
      if amount == 0 then
        chatbox.tell(name,"<red>You have no money.</red>","Chris's Casino","minimessage")
      else
        accounts[uuid].balance = accounts[uuid].balance - amount
        saveAccounts()
        os.queueEvent("make_transaction",address,amount)
        chatbox.tell(name,"<red>Withdrew <blue>"..amount.."kro </blue> from your balance. You have <blue>"..accounts[uuid].balance.."</blue> remaining.", "Chris's Casino", "minimessage")
      end
  end,
  permission = permissions.all
}
commands.bal = commands.balance -- alias for \casino bal

commands.register = {
  exec = function(name, uuid, args)
    if accounts[uuid] and accounts[uuid].banned then
      chatbox.tell(uuid,"<red>You have been banned from Chris's Casino, Please contact a casino maintainer for a balance refund.", "Chris's Casino", "minimessage")
      return
    end
    if accounts[uuid] and accounts[uuid].validCard then
      chatbox.tell(name,"<green>You already have a registered card, use <blue>\\casino revoke</blue> to revoke it, then create a new one with <blue>\\casino register</blue>","Chris's Casino", "minimessage")
      return
    end
    if not accounts[uuid] then createAccount(name,uuid) end
    chatbox.tell(name,"<green>Creating card, tap on the NFC reader to register it. This card request will expire in 60s if not registered.", "Chris's Casino", "minimessage")
    registerCard(uuid)
  end,
  permission = permissions.all
}

commands.revoke = {
  exec = function(name, uuid, args)
    if accounts[uuid] and accounts[uuid].banned then
      chatbox.tell(uuid,"<red>You have been banned from Chris's Casino, Please contact a casino maintainer for a balance refund.", "Chris's Casino", "minimessage")
      return
    end
    revokeCard(uuid)
  end,
  permission = permissions.all
}

commands.ban = {
  exec = function(name, uuid, args)
    local account = args[1]
    if not accounts[account] then
      createAccount("$unknown",uuid)
    end
    if accounts[account].banned then
      chatbox.tell(name,"<red>User is already banned.", "Chris's Casino", "minimessage")
      return
    end
    accounts[account].banned = true
    chatbox.tell(name,"<green>Banned user with uuid "..account, "Chris's Casino", "minimessage")
  end,
  permission = permissions.admin
}

commands.pardon = {
  exec = function(name, uuid, args)
    local account = args[1]
    if not accounts[account] or not accounts[account].banned then
      chatbox.tell(name,"<red>User is not banned.", "Chris's Casino", "minimessage")
      return
    end
    accounts[account].banned = false
    if accounts[account].name == "$unknown" then deleteAccount(account) end -- Delete anonymous banned users.
    chatbox.tell(name,"<green>Pardoned user with uuid "..account, "Chris's Casino", "minimessage")
  end,
  permission = permissions.admin
}

commands.add = {
  exec = function(name, uuid, args)
    if not args[2] then
      chatbox.tell(name,"<red>Both a player UUID and a number must be provided", "Chris's Casino", "minimessage")
      return
    end
    local otherUUID = args[1]
    if not accounts[otherUUID] then
      chatbox.tell(name,"<red>Player doesn't have an account.", "Chris's Casino", "minimessage")
      return
    end
    accounts[otherUUID].balance = accounts[otherUUID].balance + tonumber(args[2])
    chatbox.tell(name,"<green>Added <blue>"..args[2].."</blue> To "..accounts[otherUUID].username.."'s balance", "Chris's Casino", "minimessage")
    saveAccounts()
  end,
  permission = permissions.admin
}

commands.subtract = {
  exec = function(name, uuid, args)
    local otherUUID = args[1]
    if not args[2] then
      chatbox.tell(name,"<red>Both a player UUID and a number must be provided", "Chris's Casino", "minimessage")
      return
    end
    if not accounts[otherUUID] then
      chatbox.tell(name,"<red>Player doesn't have an account.", "Chris's Casino", "minimessage")
      return
    end
    accounts[otherUUID].balance = accounts[otherUUID].balance - tonumber(args[2])
    chatbox.tell(name,"<green>Subtracted <blue>"..args[2].."</blue> From "..accounts[otherUUID].username.."'s balance", "Chris's Casino", "minimessage")
    saveAccounts()
  end,
  permission = permissions.admin
}

commands.setbal = {
  exec = function(name, uuid, args)
    local otherUUID = args[1]
    if not args[2] then
      chatbox.tell(name,"<red>Both a player UUID and a number must be provided", "Chris's Casino", "minimessage")
      return
    end
    if not accounts[otherUUID] then
      chatbox.tell(name,"<red>Player doesn't have an account.", "Chris's Casino", "minimessage")
      return
    end
    accounts[otherUUID].balance = tonumber(args[2])
    chatbox.tell(name,"<green>Set"..accounts[otherUUID].username.."'s balance to <blue>"..args[2].."</blue>", "Chris's Casino", "minimessage")
    saveAccounts()
  end,
  permission = permissions.admin
}

local function commandHandler()
  while true do
    _, user, command, args, data = os.pullEvent("command")
    if command ~= "casino" then goto notOurCommand end
    local subcommand = table.remove(args,1)
    if not commands[subcommand] then
      chatbox.tell(user,"<red>Invalid subcommand.</red>", "Chris's Casino", "minimessage")
      goto continue
    end
    do
    local uuid = data.user.uuid
    if not commands[subcommand].permission(uuid) then
      chatbox.tell(user,"<red>You do not have permission to run this command", "Chris's Casino", "minimessage")
      goto continue
    end
    loop:addFunction(commands[subcommand].exec,user,uuid,args)
    end
    ::continue::
    if accounts[data.user.uuid] and accounts[data.user.uuid].username ~= user then
      accounts[data.user.uuid].username = user
      chatbox.tell(user,"<green> Your username has been updated in the account database.", "Chris's Casino", "minimessage")
      saveAccounts()
    end
    ::notOurCommand:: -- separate label so we don't respond to other people's commands with a username change.
  end
end


local function rednetMessageHandler()
  while true do
    local id, message, protocol = rednet.receive()
    if protocol == "machineBalanceModifier" then
      if type(message) ~= "table" or not message.uuid or not message.amount then goto continue_rednet end -- Guard against bullshit messages
      if message.type == "add" then
        accounts[message.uuid].balance = accounts[message.uuid].balance + message.amount
      end
      if message.type == "subtract" then
        accounts[message.uuid].balance = accounts[message.uuid].balance + message.amount
      end
      if message.type == "set" then
        accounts[message.uuid].balance = message.amount
      end

    elseif protocol == "getAccountData" then
      if type(message) ~= "table" or not message.card then goto continue_rednet end
      for _, account in pairs(accounts) do
        if "casinoAccount_"..account.validCard == message.card then -- Here's our guy!
          rednet.send(id,{
            type = "account_data",
            uuid = account.uuid,
            username = account.username,
            balance = account.balance,
            cardId = message.card
        },"server_response")
          break
        end
      end
    end
    ::continue_rednet::
  end
end


loop:task(commandHandler)
:task(rednetMessageHandler)
:task(handleWebSockets)
  :run()
