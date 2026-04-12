--Slot

if fs.exists("/disk/terminate") then
    error("terminated for debugging")
end
_G.os.pullEvent = _G.os.pullEventRaw

local function clear()
    term.setCursorPos(1, 1)
    term.clear()
end

local function main()
    local nfc = assert(peripheral.find("nfc_reader", function(x) return x == "bottom" end), "NFC reader not found on bottom")
    local modem = assert(peripheral.find("modem"), "No modem found")
    local modemName = peripheral.getName(modem)

    rednet.open(modemName)

    local function interactWithCard(userUUID, mode, money)
        if mode == "updateBalance" then
            rednet.broadcast({
                uuid = userUUID,
                amount = money,
                type = "set"
            }, "machineBalanceModifier")
        end

        if mode == "getBalance" then
            local _, _, cardUUID = os.pullEvent("nfc_data")
            rednet.broadcast({
                card = cardUUID
            }, "getAccountData")

            while true do
                local id, message = rednet.receive("server_response", 10)
                if not id then
                    error("the server is down\nplease ping @minecartchris")
                end

                if message.type == "account_data" and message.cardId == cardUUID then
                    local money = message.balance
                    local playerUUID = message.uuid
                    local username = message.username
                    return money, playerUUID, username
                end

                error("unexpected behavior, account_data not received")
            end
        end
    end

    while true do
        clear()
        print("Welcome to the Slot Machine!")
        print("Please swipe your card to begin")

        local money, playerUUID, username = interactWithCard(nil, "getBalance", nil)
        money = tonumber(money)

        clear()
        print("Welcome "..tostring(username))
        print("$", money)
        print("")
        io.write("Please enter your bet> ")
        local bet = tonumber(read())
        if bet and bet <= money and bet > 0 then
            io.write("Please enter your guess> ")
            local guess = tonumber(read())

            local randNum = math.random(1, 15)

            print("")
            if randNum == guess then
                money = money + bet * 2
                interactWithCard(playerUUID, "updateBalance", money)
                print("You win!!!!!")
                print("You now have $", money)
            else
                money = money - bet
                interactWithCard(playerUUID, "updateBalance", money)
                print("You lost ;(")
                print("The correct number was", randNum)
                print("you have $", money, "left over")
            end
        else
            print("Invalid bet")
        end
        sleep(3)
    end
end

while true do
    clear()
    local s, e = pcall(main)

    if not s then
        clear()
        printError("Error:", e)
        printError("Press any key to continue (or auto restarting in 30 seconds)...")

        parallel.waitForAny(function()
            os.pullEvent("char")
        end, function()
            sleep(30)
        end)
    end

    sleep()
end
