--Plinko (monitor-simulated peg board)

rednet.open("back")

-- Draw everything (instructions, prompts, and the drop animation) on the
-- attached monitor instead of the computer's own terminal, so it's all on
-- one screen. Falls back to the computer terminal if no monitor is wired up.
--
-- Only ever use a monitor directly touching THIS computer. peripheral.find
-- would happily hand back any monitor reachable over the shared wired
-- network (e.g. one wired up on a completely different machine elsewhere
-- in the casino), which silently steals that machine's monitor instead.
local function find_local_monitor()
  local SIDES = { "top", "bottom", "left", "right", "front", "back" }
  for _, side in ipairs(SIDES) do
    if peripheral.getType(side) == "monitor" then
      return peripheral.wrap(side), side
    end
  end
  return nil, nil
end

-- Board + buttons need at least this many columns/rows to lay out cleanly.
-- Pick the largest (most readable) text scale that still fits, since
-- monitors come in different physical sizes across machines.
local MIN_MONITOR_W, MIN_MONITOR_H = 29, 12

local function pick_scale(mon)
  local best = 1
  local scale = 5
  while scale >= 0.5 do
    mon.setTextScale(scale)
    local w, h = mon.getSize()
    if w >= MIN_MONITOR_W and h >= MIN_MONITOR_H then
      best = scale
      break
    end
    scale = scale - 0.5
  end
  mon.setTextScale(best)
end

local function clear_top()
  term.clear()
  term.setCursorPos(1, 1)
end

local monitor, monitorSide = find_local_monitor()
if monitor then
  -- setTextScale only exists on the monitor object itself, not on the
  -- generic term redirect interface, so it must be called before/outside
  -- of term.* calls.
  pick_scale(monitor)
  term.redirect(monitor)
  -- Monitors keep whatever colors/scale the last program left them in
  -- (unlike the shell's own terminal), so force known-good ones here -
  -- otherwise leftover state (e.g. black-on-black) can make everything
  -- we draw invisible even though it's actually being written.
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
else
  print("No monitor found - showing the game on this screen instead.")
  print("Check a monitor is directly touching this computer (or reachable")
  print("over an activated wired modem) if you expected one.")
  sleep(3)
end

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

os.pullEvent = function(...)
  while true do
    local t = table.pack(os.pullEventRaw(...))
    if t[1] ~= "terminate" then
      return table.unpack(t, 1, t.n)
    end
  end
end

if fs.exists("/disk/terminate") then
  error("Service mode active", 2)
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

local function clamp(n, lo, hi)
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function clamp_col(col, w)
  return clamp(col, 1, w)
end

-- Symmetric payout curve: edges pay big (rare), center pays little (common).
-- Tune this table after testing to adjust the house edge.
local ROWS = 8
local MULTIPLIERS = { 5, 2, 1, 0.5, 0.2, 0.5, 1, 2, 5 }
local MULT_LABELS = { "5x", "2x", "1x", ".5x", ".2x", ".5x", "1x", "2x", "5x" }
local SLOTS = #MULTIPLIERS
local CELL_W = 3

local function board_metrics(w, h)
  local trackWidth = SLOTS * CELL_W
  local left = math.max(1, math.floor((w - trackWidth) / 2))
  local boardTop = 2
  local multRow = boardTop + ROWS
  local buttonRow = math.min(multRow + 2, h)
  return left, boardTop, multRow, buttonRow
end

local function make_buttons(buttonRow)
  local defs = {
    { label = "-10", delta = -10 },
    { label = "-1",  delta = -1 },
    { label = "+1",  delta = 1 },
    { label = "+10", delta = 10 },
    { label = "GO",  delta = nil },
  }
  local buttons = {}
  local x = 2
  for _, def in ipairs(defs) do
    local text = "[" .. def.label .. "]"
    local x1 = x
    local x2 = x + #text - 1
    table.insert(buttons, { text = text, x1 = x1, x2 = x2, delta = def.delta, row = buttonRow })
    x = x2 + 2
  end
  return buttons
end

local function draw_buttons(buttons)
  for _, b in ipairs(buttons) do
    term.setCursorPos(b.x1, b.row)
    if b.delta == nil then
      term.setTextColor(colors.lime)
    else
      term.setTextColor(colors.yellow)
    end
    term.write(b.text)
  end
  term.setTextColor(colors.white)
end

-- row/position describe the ball (nil row = no ball drawn, idle/bet screen).
-- highlightSlot flashes that landing slot in the payout row.
local function draw_frame(bet, money, buttons, row, position, highlightSlot)
  term.setBackgroundColor(colors.black)
  term.clear()
  local w, h = term.getSize()
  local left, boardTop, multRow = board_metrics(w, h)

  term.setCursorPos(1, 1)
  term.setTextColor(colors.white)
  term.write("Bet: " .. bet .. "  Bal: " .. money)

  term.setTextColor(colors.gray)
  for r = 0, ROWS - 1 do
    local y = boardTop + r
    local off = (r % 2 == 0) and 1 or 3
    local col = left + off
    while col < left + SLOTS * CELL_W do
      term.setCursorPos(col, y)
      term.write(".")
      col = col + CELL_W
    end
  end

  if row then
    local ballCol = clamp_col(math.floor(left + position * CELL_W + CELL_W / 2 + 0.5), w)
    local ballRow = boardTop + math.min(math.floor(row), ROWS - 1)
    term.setTextColor(colors.orange)
    term.setCursorPos(ballCol, ballRow)
    term.write("o")
  end

  for i = 1, SLOTS do
    local mx = left + (i - 1) * CELL_W
    term.setCursorPos(mx, multRow)
    if highlightSlot == i then
      term.setBackgroundColor(colors.yellow)
      term.setTextColor(colors.black)
    else
      term.setBackgroundColor(colors.black)
      if MULTIPLIERS[i] >= 2 then
        term.setTextColor(colors.green)
      elseif MULTIPLIERS[i] >= 1 then
        term.setTextColor(colors.white)
      else
        term.setTextColor(colors.red)
      end
    end
    term.write(string.format("%-" .. CELL_W .. "s", MULT_LABELS[i]))
  end
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)

  draw_buttons(buttons)
end

local function wait_touch()
  while true do
    local _, side, x, y = os.pullEvent("monitor_touch")
    if side == monitorSide then
      return x, y
    end
    -- ignore touches on any other monitor reachable over the network
  end
end

local function get_bet_via_buttons(money, buttons)
  local bet = 1
  while true do
    draw_frame(bet, money, buttons, nil, nil)
    local x, y = wait_touch()
    for _, b in ipairs(buttons) do
      if y == b.row and x >= b.x1 and x <= b.x2 then
        if b.delta == nil then
          return bet
        else
          bet = clamp(bet + b.delta, 1, money)
        end
        break
      end
    end
  end
end

local function get_bet_via_keyboard(money)
  local betAmount
  while true do
    betAmount = tonumber(input("Bet amount: "))
    if not betAmount or betAmount <= 0 then
      print("Enter a valid positive bet amount")
      sleep(2)
    elseif betAmount > money then
      print("You can't bet more than you have")
      sleep(2)
    else
      return betAmount
    end
  end
end

local function drop_ball(bet, money, buttons)
  local position = 0
  local delay = 0.12
  draw_frame(bet, money, buttons, 0, position)
  sleep(0.3)
  for row = 1, ROWS do
    local nextPos = position
    if random(0, 1) == 1 then
      nextPos = position + 1
    end
    -- half-step: ball drifts sideways before settling on the row below,
    -- for a smoother fall instead of jumping row to row
    draw_frame(bet, money, buttons, row - 1, (position + nextPos) / 2)
    sleep(delay)
    position = nextPos
    draw_frame(bet, money, buttons, row, position)
    sleep(delay)
    if row > ROWS - 3 then
      delay = delay + 0.03
    end
  end
  return position -- 0..ROWS -> slot index (position + 1)
end

local function flash_landing(bet, money, buttons, slotIndex)
  for i = 1, 3 do
    draw_frame(bet, money, buttons, ROWS, slotIndex - 1, slotIndex)
    sleep(0.25)
    draw_frame(bet, money, buttons, ROWS, slotIndex - 1, nil)
    sleep(0.15)
  end
  draw_frame(bet, money, buttons, ROWS, slotIndex - 1, slotIndex)
end

local function run()
  clear_top()
  print("Welcome to Plinko!")
  print("Please swipe your card to begin")
  local money, playerUUID, username = interactWithCard(nil, "getBalance", nil)

  if money < 1 then
    clear_top()
    print("Welcome " .. username .. "!")
    print("You need at least 1 to play.")
    interactWithCard(playerUUID, "updateBalance", money)
    sleep(5)
    return
  end

  local betAmount
  if monitor then
    local w, h = term.getSize()
    local _, _, _, buttonRow = board_metrics(w, h)
    local buttons = make_buttons(buttonRow)
    betAmount = get_bet_via_buttons(money, buttons)

    local finalPosition = drop_ball(betAmount, money, buttons)
    local slotIndex = finalPosition + 1
    local multiplier = MULTIPLIERS[slotIndex]
    local winnings = betAmount * (multiplier - 1)
    money = money + winnings
    interactWithCard(playerUUID, "updateBalance", money)

    flash_landing(betAmount, money, buttons, slotIndex)
    sleep(2)
  else
    clear_top()
    print("Welcome " .. username .. ", good luck!")
    betAmount = get_bet_via_keyboard(money)

    -- No buttons/monitor to draw against on the fallback path; just
    -- resolve the drop with the existing text-mode animation.
    local position = 0
    for row = 1, ROWS do
      if random(0, 1) == 1 then
        position = position + 1
      end
      sleep(0.15)
    end
    local slotIndex = position + 1
    local multiplier = MULTIPLIERS[slotIndex]
    local winnings = betAmount * (multiplier - 1)
    money = money + winnings
    interactWithCard(playerUUID, "updateBalance", money)

    print("Landed in slot " .. slotIndex .. " (" .. multiplier .. "x)")
    if winnings >= 0 then
      print("WON: " .. winnings)
    else
      print("LOST: " .. -winnings)
    end
    sleep(5)
  end
end

shell.execute("clear")
while true do
  run()
end
