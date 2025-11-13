--Slot
sleep(0.25)

os.pullEvent=os.pullEventRaw
if fs.exists("/disk/terminate") then
    error("Service mode active",2)
end
modem = peripheral.wrap("back")
shell.run("clear all")
while not fs.exists("/disk2/money.lua") do
    sleep(0.75)
    print("You do not have a card inserted")
    sleep(2)
    shell.run("clear all")
end
print("Please do not remove your card from the drive during games")
local money = " "
local winner = false
local randnum = 0
local bet = 0
local money2 = fs.open("/disk2/money.lua", "r")
money = money2.readAll()
money2.close()
local h = fs.open("disk/house.lua", "r")
house = h.readAll()
h.close()
print("$",money)
money = tonumber(money)
print("what is your bet?")
bet = tonumber(io.read())
print("what is your guess 1 to 15?")
userGess = tonumber(io.read()) 
if bet > money then
   print("You do not have enough funds")
   sleep(3)
   shell.run("reboot") 
end
randnum = tonumber(math.random(0, 14) + 1)
if userGess == randnum then
    winner = true
end
house = tonumber(house)
if not winner then
    print("you lost ;(")
    print("The correct number was", randnum)
    money = money - bet
    house = house + bet
    print("you have $",money, "left over")
end
if winner then
    bet = bet * 2
    money = bet + money
    print("You win!!!!!")
    house = house - bet
    print("You now have $", money)
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
sleep(2)
shell.run("clear all")
shell.run("startup")
