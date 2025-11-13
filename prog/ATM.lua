--ATM
print("Please insert a cc-casino branded disk!")
while not fs.exists("/disk/money.lua") do
    sleep()
end

print("Would you like to [d]eposit, [w]ithdraw, or check your [b]alance?")
local answer = io.read()
local db = fs.open("/disk2/log.log", "a")
local id = disk.getID("bottom")
if answer == "d" or answer == "deposit" then
    local item = turtle.getItemDetail()
    if item.name ~= "minecraft:iron_ingot" or item.name == nil then
        print("Please insert iron ingots!")
        sleep(1)
        shell.run("reboot")
    end

    local ironCount = turtle.getItemCount()
    local card = fs.open("/disk/money.lua", "r")
    local money = tonumber(card.readAll())

    card.close()

    money = money + ironCount
    turtle.drop()

    card = fs.open("/disk/money.lua", "w")
    card.write(money)
    db.write(ironCount..id.."\n")
    card.close()
    print("Your balance is now $"..money)
    
    sleep(2)
elseif answer == "w" or answer == "withdraw" then
    print("How much would you like to withdraw?")
    answer = tonumber(io.read())

    local card = fs.open("/disk/money.lua", "r")
    local money = tonumber(card.readAll())

    card.close()

    if answer > money then
        print("That's more than you have! Try again.")

        sleep(2)
    else
        money = money - answer

        print("You now have $"..money)

        turtle.suck(answer)
        db.write(answer..id.."\n")
        card = fs.open("/disk/money.lua", "w")
        card.write(money)
        card.close()

        sleep(2)
    end
elseif answer == "b" or answer == "balance" then
    local card = fs.open("/disk/money.lua", "r")
    local money = tonumber(card.readAll())

    print("Your balance is $"..money)

    card.close()

    sleep(2)
end

db.close()
shell.run("reboot")
