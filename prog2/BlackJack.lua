--black
rednet.open("back")

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
            if message.type == "account_data" and message.cardId == cardUUID then
                local money = message.balance
                local playerUUID = message.uuid
                local username = message.username
                return money, playerUUID, username
            end

        end
    end
end





-- by Jurryteacher67
--local tmp = peripheral.wrap("bottom")
--tmp.ejectDisk()

os.pullEvent= function(...)
    while true do
        local t = table.pack(os.pullEventRaw(...))
        if t[1] ~= "terminate" then
            return table.unpack(t,1,t.n)
        end
    end
end
print("Was Made By Gaurdian15")
if fs.exists("/disk/terminate") then
    error("Service mode active",2)
end
shell.run("clear all")
--while not fs.exists("/disk2/money.lua") do
    --sleep(0.75)
    --print("You do not have a card inserted")
    --sleep(2)
    --shell.run("clear all")
--end

--print("Please do not remove your card from the drive during games")



local function calculate(win, amount, money)
    --local disk = peripheral.wrap("bottom")
    --if not disk.isPresent() then
        --os.reboot()
    --end
    if win then
        money = money + amount
    else
        money = money - amount
    end
    return money
end
print("Was Made By Gaurdian15")
--local money2 = fs.open("/disk2/money.lua", "r")
local money, playerUUID, username = interactWithCard(nil, "getBalance", nil)
--money2.close()

money = tonumber(money)

print("what is your bet?")
local bet = io.read()
bet = tonumber(bet)
if not bet or bet < 20 then
    bet = 20
end
if bet > money then
    print("you don't have the money required to play")
    print("Goodbye")
    sleep(5)
    os.reboot()
end



pcard1= math.random(1,11)
pcard2= math.random(1,11)
local pcard= pcard1+pcard2
acard1= math.random(1,11)
acard2= math.random(1,11)
local acard=acard1+acard2
while true do
    print("Card 1: ",pcard1)
    print("Card 2: ",pcard2)
    print("Total: ",pcard)
    print("")
    print("Would you like another card")
    print("Y for Yes N for No")
    local ans=read()
    print(ans)
    if(pcard>21) then
        print("you Bust")
        calculate(n, bet, money)
        break
    end
    if(ans=="Y") then
        local anscard= math.random(1,11)
        pcard=pcard+anscard
    elseif (ans=="N") then
        break
    else
        print("Invalid Input")
    end
end

while true do
    print("AI Card 1: ",acard1)
    print("AI Card 2: ",acard2)
    print("AI Total: ",acard)
    if(acard<16) then
        local aans=math.random(1,11)
        acard=aans+acard
        print("AI Card",aans)
    elseif(acard>=16) then
        break
    end
end
if(pcard>21) then
    money = calculate(false, bet, money)
    print("You Busted")
elseif(acard>21) then
    money = calculate(true, bet, money)
    print("Dealer Bust's")
elseif (pcard>acard) then
    moeny = calculate(true, bet, money)
    print("You Won")
elseif(acard>pcard) then
    money = calculate(false, bet, money)
    print("The Dealer won")
elseif(acard==pcard) then
    print("Push No One Wins")
end


print("Your new balance is: "..money)

--money2 = fs.open("/disk2/money.lua", "w")
interactWithCard(playerUUID, "updateBalance", money)
--money2.close()

--h = fs.open("disk/house.lua", "w")
--h.write(house)
--h.close()
print("If removing your card do it now")
sleep(5)
os.reboot()
