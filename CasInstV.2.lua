local branch = "prog"
local serverPath = "https://git.astronand.dev/minecartchris/CC-Casnio/raw/branch/main/" + branch

while true do 
    if fs.exists("startup.lua") then 
        print("Would you like to Update the Current Startup File")
        local Ans=io.read()
        if(Ans=="Yes" or Ans=="yes" or Ans=="y" or Ans=="Y") then
            local soft = fs.open("startup.lua", "r")
            local data = soft.readLine()
            soft.close()
            print("file read")
            if data == "--ATM" then
                fs.delete("startup.lua")
                shell.run("wget "..serverPath.."/ATM.lua startup.lua")
            elseif data == "--Slot" then
                fs.delete("startup.lua")
                shell.run("wget "..serverPath.."/Slot.lua startup.lua")
            elseif data == "--tic" then
                fs.delete("startup.lua")
                shell.run("wget "..serverPath.."/ticTackToe.lua startup.lua")
            elseif data == "--black" then
                fs.delete("startup.lua")
                shell.run("wget "..serverPath.."/BlackJack.lua startup.lua")
            end
        elseif (Ans=="No" or Ans=="no" or Ans=="N" or Ans=="n") then
            print("Type Slot, ATM, tic, black jack to install game")
            local B=io.read()
            if B == "Slot" then
                shell.run("wget "..serverPath.."/Slot.lua startup.lua")
                break
            elseif B == "ATM" then
                shell.run("wget "..serverPath.."/ATM.lua startup.lua")
                break
            elseif B == "tic" then
                shell.run("wget "..serverPath.."/ticTackToe.lua startup.lua")
                break
            elseif B == "black jack" then
                shell.run("wget "..serverPath.."/BlackJack.lua startup.lua")
                break
            else
                print("Invalid Input")
            end
        else
            print("Invalid Input")
        end
    else
        print("Type Slot, ATM, tic, black jack to install game")
        local B=io.read()
        if B == "Slot" then
            shell.run("wget "..serverPath.."/Slot.lua startup.lua")
            break
        elseif B == "ATM" then
            shell.run("wget "..serverPath.."/ATM.lua startup.lua")
            break
        elseif B == "tic" then
            shell.run("wget "..serverPath.."/ticTackToe.lua startup.lua")
            break
        elseif B == "black jack" then
            shell.run("wget "..serverPath.."/BlackJack.lua startup.lua")
            break
        else
            print("Invalid Input")
        end
    end
end
