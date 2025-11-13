--black

-- by Jurryteacher67
local tmp = peripheral.wrap("bottom")
tmp.ejectDisk()

os.pullEvent=os.pullEventRaw
print("Was Made By Gaurdian15")
if fs.exists("/disk/terminate") then
    error("Service mode active",2)
end
shell.run("clear all")
while not fs.exists("/disk2/money.lua") do
    sleep(0.75)
    print("You do not have a card inserted")
    sleep(2)
    shell.run("clear all")
end

print("Please do not remove your card from the drive during games")

local function calculate(win, amount, money)
    --local disk = peripheral.wrap("bottom")
    --if not disk.isPresent() then
        --os.reboot()
    --end

    if win == "n" then
        money = money - amount
        house = house + amount
    elseif win == "y" then
        money = money + amount
        house = house - amount
    end
end
print("Was Made By Gaurdian15")
local money2 = fs.open("/disk2/money.lua", "r")
money = money2.readAll()
money2.close()

money = tonumber(money)

print("what is your bet?")
local bet = io.read()
bet = tonumber(bet)
if bet < 20 then
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
    calculate(n, bet, money)
    print("You Busted")
elseif(acard>21) then
    calculate(y, bet, money)
    print("Dealer Bust's")
elseif (pcard>acard) then
    calculate(y, bet, money)
    print("You Won")
elseif(acard>pcard) then
    calculate(n, bet, money) 
    print("The Dealer won")
elseif(acard==pcard) then
    print("Push No One Wins")
end




money2 = fs.open("/disk2/money.lua", "w")
money2.write(money)
money2.close()
while true do 
    print("Would you liek to play again")
    local PA=io.read()
    if (PA=="Y") then
        break
    elseif (PA=="N") then 
        tmp.ejectDisk()
        break
    else
        print("Invalid Input")
    end
end
h = fs.open("disk/house.lua", "w")
h.write(house)
h.close()
print("If removing your card do it now")
sleep(5)
os.reboot()
