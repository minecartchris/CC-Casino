local wireless = require("wireless")

os.pullEvent= function(...)
    while true do
        local t = table.pack(os.pullEventRaw(...))
        if t[1] ~= "terminate" then
            return table.unpack(t,1,t.n)
        end
    end
end

local function interactWithCard(userUUID, mode, money)
if mode == "updateBalance" then
    wireless.broadcast({
        uuid = userUUID,
        amount = money,
        type = "set"
    }, "machineBalanceModifier")
    end

    if mode == "getBalance" then
        local _, _, cardUUID = os.pullEvent("nfc_data")
        wireless.broadcast({
            card = cardUUID
        }, "getAccountData")

        while true do
            local id, message = wireless.receive("server_response", 10)
            if not id then
                print("the server is down")
                print("please ping @minecartchris")
                sleep(30)
                --shell.run("reboot")
            end
            if not message then
                print("WTF!? I got a rednet message with no data!?")
                print("Rebooting...")
                sleep(5)
            end
            if message.type == "account_data" and message.cardId == cardUUID then
                local money = message.balance
                local playerUUID = message.uuid
                local username = message.username
                return money, playerUUID, username
            end

        end
    end
end



sleep(0.25)

nfc = peripheral.wrap("bottom")

if fs.exists("/disk/terminate") then
    error("Service mode active",2)
end
modem = peripheral.wrap("back")
shell.run("clear all")
--while not fs.exists("/disk2/money.lua") do
    --sleep(0.75)
    --print("You do not have a card inserted")
    --sleep(2)
    --shell.run("clear all")
--end
--print("Please do not remove your card from the drive during games")
local money = " "
local winner = false
local randnum = 0
local bet = 0
--local money2 = fs.open("/disk2/money.lua", "r")
print("Welcome to the Slot Machine!")
print("Please swipe your card to begin")

--local _, _, userUUID = os.pullEvent("nfc_data")
money, playerUUID, username = interactWithCard(nil, "getBalance", nil)

--money2.close()
print("Welcome "..tostring(username))

print("$",money)
money = tonumber(money)
print("what is your bet?")
bet = tonumber(io.read())
print("what is your guess 1 to 15?")
userGess = tonumber(io.read())
if not bet or bet > money or bet < 0 then
   print("You do not have enough funds or did not enter a bet.")
   sleep(3)
   shell.run("reboot")
end
randnum = tonumber(math.random(0, 14) + 1)
if userGess == randnum then
    winner = true
end
if not winner then
    print("you lost ;(")
    print("The correct number was", randnum)
    money = money - bet
    print("you have $",money, "left over")
    interactWithCard(playerUUID, "updateBalance", money)
end
if winner then
    bet = bet * 2
    money = bet + money
    print("You win!!!!!")
    print("You now have $", money)
    interactWithCard(playerUUID, "updateBalance", money)
end

sleep(2)
os.reboot()
