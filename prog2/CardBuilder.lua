--[[
    Casino ATM and Card Creator
    Copyright Herr Katze and minecartchris
    License: MIT
]]
local strings = require("cc.strings")
local nfc = peripheral.find("nfc_reader")
local modem = peripheral.find("modem", function(n,w) return not w.isWireless() end)
local mon = peripheral.find("monitor")

rednet.open(peripheral.getName(modem))

local infoText = {
  "== Getting Started ==",
  "",
  "1. Register:",
  "   \\casino register",
  "",
  "2. Add money:",
  "   /pay kcasino6vr",
  "   <amount>",
}

local function wrapText(text, width)
  local result = {}
  for part in (text .. "\n"):gmatch("(.-)\n") do
    if part == "" then
      table.insert(result, "")
    else
      for _, line in ipairs(strings.wrap(part, width)) do
        table.insert(result, line)
      end
    end
  end
  return result
end

local function drawPanel(lines, x0, width, h)
  local startY = math.floor((h - math.min(#lines, h)) / 2) + 1
  for i, line in ipairs(lines) do
    local y = startY + i - 1
    if y > h then break end
    local x = x0 + math.floor((width - #line) / 2)
    mon.setCursorPos(x, y)
    mon.write(line)
  end
end

local function drawSeparator(col, h)
  for y = 1, h do
    mon.setCursorPos(col, y)
    mon.write("|")
  end
end

local function showOnMonitor(text)
  if not mon then return end
  mon.setTextScale(0.5)
  local w, h = mon.getSize()

  local rightW = math.floor(w / 3)
  local sepCol = w - rightW
  local leftW = sepCol - 1
  local rightX = sepCol + 2
  rightW = w - rightX + 1

  local statusLines = wrapText(text, rightW)

  mon.clear()
  drawSeparator(sepCol, h)
  drawPanel(infoText, 1, leftW, h)
  drawPanel(statusLines, rightX, rightW, h)
end

local function createCard(cardId)
  showOnMonitor("Creating card...\n\nPlease tap your card\non the reader")
  local timer = os.startTimer(60)
  local done = false
  nfc.write("casinoAccount_"..cardId, "Casino Card")
  while not done do
    local ev, id = os.pullEvent()
    print(ev)
    if ev == "timer" and id == timer then
      nfc.cancelWrite()
      showOnMonitor("Card creation\ntimed out")
      rednet.broadcast({type="card_timeout"}, "casinoATMC2S")
      return
    end
    if ev == "nfc_write" then done = true end
  end
  showOnMonitor("Card created!\n\nYou may remove\nyour card")
  rednet.broadcast({type="card_created"}, "casinoATMC2S")
end

local function rednetListener()
  rednet.host("nfc_atm_write",tostring(os.getComputerID()))
  showOnMonitor("Casino ATM\n\nReady")
  while true do
    local id, message = rednet.receive("nfc_atm_write")
    createCard(message)
    sleep(3)
    showOnMonitor("Casino ATM\n\nReady")
  end
end

rednetListener()
