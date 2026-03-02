--base-casino-game
rednet.open("modem-side")
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
                print("the server is down")
                print("please ping @minecartchris")
                sleep(30)
                --shell.run("reboot")
            end
            if not message then
                print("WTF!? I got a rednet message with no data!?")
                print("Rebooting...")
                sleep(5)
                os.reboot()
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

--init code
money, playerUUID, username = interactWithCard(nil, "getBalance", nil)

--update bal code after you change money
interactWithCard(playerUUID, "updateBalance", money)

