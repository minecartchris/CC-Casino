--[[
    Casino ATM and Card Creator
    Copyright Herr Katze and minecartchris
    License: MIT
]]
local nfc = peripheral.find("nfc_reader")
local modem = peripheral.find("modem", function(n,w) return not w.isWireless() end)

rednet.open(peripheral.getName(modem))

local function createCard(cardId)
  local timer = os.startTimer(60)
  local done = false
  nfc.write("casinoAccount_"..cardId, "Casino Card")
  while not done do
    local ev, id  = os.pullEvent()
    print(ev)
    if ev == "timer" and id == timer then
      nfc.cancelWrite()
      rednet.broadcast({type="card_timeout"}, "casinoATMC2S")
    end
    if ev == "nfc_write" then done = true end
  end
  rednet.broadcast({type="card_created"}, "casinoATMC2S")
end

local function rednetListener()
  rednet.host("nfc_atm_write",tostring(os.getComputerID()))
  while true do
    local id, message =rednet.receive("nfc_atm_write")
    createCard(message)
  end
end

rednetListener()
