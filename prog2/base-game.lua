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
            if message.type == "account_locked" and message.cardId == cardUUID then
                -- The server already has an open session for this card (it
                -- didn't get an updateBalance yet, e.g. another machine
                -- crashed mid-round). Tell the player instead of just
                -- timing out and printing a misleading "server is down".
                return "locked", nil, nil, message.remainingSeconds
            end

        end
    end
end

--init code
local money, playerUUID, username, lockedSeconds = interactWithCard(nil, "getBalance", nil)
if money == "locked" then
    print("This card is still finishing another transaction.")
    print("Please wait " .. lockedSeconds .. "s and try again.")
    sleep(3)
    return
end

--update bal code after you change money
interactWithCard(playerUUID, "updateBalance", money)

