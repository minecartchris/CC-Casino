--slot2
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

os.pullEvent= function(...)
    while true do
        local t = table.pack(os.pullEventRaw(...))
        if t[1] ~= "terminate" then
            return table.unpack(t,1,t.n)
        end
    end
end

if fs.exists("/disk/terminate") then
    error("Service mode active",2)
end


math.randomseed(os.epoch("utc"))
for i = 1, 5 do math.random() end

local function random(min, max)
  return math.random(min, max)
end

local function input(message)
  local w, h = term.getSize()
  term.setCursorPos(1, h)
  term.clearLine()
  io.write(message)
  return io.read()
end

local function calculate_winnings(got, b)
  --local b = tonumber(bet) or 0
  if got[1] == got[2] and got[2] == got[3] then
    return b * 10
  elseif got[1] == got[2] or got[2] == got[3] or got[1] == got[3] then
    return b
  else
    return 0
  end
end

local function draw()
  local letters = {'', '', '', ' '}
  local got = {}
  for i = 1, 3 do
    table.insert(got, letters[random(1, #letters)])
  end
  return got
end

local function draw_display(display)
  local w, h = term.getSize()
  local midW = math.floor(w / 2)
  local midH = math.floor(h / 2)

  term.clear()

  term.setCursorPos(midW - 5, midH - 1)
  print("+-----------+")
  term.setCursorPos(midW - 5, midH)
  print("| " .. (display[1] or "-") .. " | " .. (display[2] or "-") .. " | " .. (display[3] or "-") .. " |")
  term.setCursorPos(midW - 5, midH + 1)
  print("+-----------+")
end

local function spin(current_got)
  local letters = {'', '', '', ' '}
  local delay = 0.05
  for i = 1, 12 do
    local display = {}
    for j = 1, 3 do
      if current_got[j] then
        display[j] = current_got[j]
      else
        display[j] = letters[random(1, #letters)]
      end
    end

    draw_display(display)

    sleep(delay)
    if i > 6 then
      delay = delay + 0.05
    end
  end
end

local function run()
  term.clear()
  print("Welcome to the Slot Machine!")
  print("Please swipe your card to begin")
  money, playerUUID, username = interactWithCard(nil, "getBalance", nil)

  term.clear()
  print("Welcome ".. username .." have fun!")
  local bet_input = tonumber(input("Bet: "))
  if money < bet_input then
    print("please get more money or bet less as you can't bet more then you have")
  end
  local final = draw()
  local current = {nil, nil, nil}

  for i = 1, 3 do
    spin(current)
    current[i] = final[i]
    draw_display(current)
    sleep(0.5)
  end

  local winnings = calculate_winnings(final, bet_input)

  local w, h = term.getSize()
  term.setCursorPos(math.floor(w/2) - 6, math.floor(h/2) + 3)
  money = money + winnings
  interactWithCard(playerUUID, "updateBalance", money)
  print("WON: " .. winnings)

  for i = 1, 4 do
    sleep(0.3)
    term.setCursorPos(math.floor(w/2) - 5, math.floor(h/2))
    term.write("           ")
    sleep(0.3)
    draw_display(final)
  end
  sleep(30)
end
shell.execute("clear")
while true do
  run()
end