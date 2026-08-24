--Roulette

local configOk, config = pcall(dofile, "roulette_config.lua")
if not configOk or type(config) ~= "table" then
  error("Missing or invalid roulette_config.lua - see prog2/roulette_config.lua in the repo for the expected format.", 0)
end

rednet.open(config.modemSide)

-- Validate the card reader up front instead of blindly trusting whatever
-- fires an nfc_data event - on a shared wired network that could be a
-- reader on a completely different machine. See roulette_config.lua.
if not config.nfcName then
  error("roulette_config.lua: nfcName is not set. Place the card reader, " ..
    "find its peripheral name (run peripheral.getNames() in the lua prompt), " ..
    "and set nfcName in roulette_config.lua before running Roulette.", 0)
end
local nfcReader = peripheral.wrap(config.nfcName)
if not nfcReader then
  error("No NFC reader found at '" .. config.nfcName ..
    "' - check roulette_config.lua matches the reader's actual wiring.", 0)
end

-- Draw everything on the attached monitor instead of the computer's own
-- terminal, so it's all on one screen. Only ever use a monitor directly
-- touching THIS computer - peripheral.find would happily hand back any
-- monitor reachable over the shared wired network (e.g. one wired up on a
-- completely different machine elsewhere in the casino), which silently
-- steals that machine's monitor instead. Falls back to the computer's own
-- terminal if no monitor is wired up.
local function find_local_monitor()
  local SIDES = { "top", "bottom", "left", "right", "front", "back" }
  for _, side in ipairs(SIDES) do
    if peripheral.getType(side) == "monitor" then
      return peripheral.wrap(side), side
    end
  end
  return nil, nil
end

-- The full table layout (0 + 12 number columns + dozens/even-money rows)
-- needs real width - a single 1x1 monitor block won't fit it. The simpler
-- button layout needs much less. Try the table layout first, falling back
-- to the simple buttons on a smaller monitor, so this keeps working no
-- matter what size monitor ends up wired to a given machine.
local MIN_TABLE_W, MIN_TABLE_H = 56, 18
local MIN_SIMPLE_W, MIN_SIMPLE_H = 29, 13

local function try_pick_scale(mon, minW, minH)
  local scale = 5
  while scale >= 0.5 do
    mon.setTextScale(scale)
    local w, h = mon.getSize()
    if w >= minW and h >= minH then
      return true
    end
    scale = scale - 0.5
  end
  return false
end

local function clear_top()
  term.clear()
  term.setCursorPos(1, 1)
end

local monitor, monitorSide = find_local_monitor()
local uiTier -- "table" | "simple" | nil (no monitor / too small -> keyboard)
if monitor then
  -- setTextScale only exists on the monitor object itself, not on the
  -- generic term redirect interface, so it must be called before/outside
  -- of term.* calls.
  if try_pick_scale(monitor, MIN_TABLE_W, MIN_TABLE_H) then
    uiTier = "table"
  elseif try_pick_scale(monitor, MIN_SIMPLE_W, MIN_SIMPLE_H) then
    uiTier = "simple"
  else
    monitor.setTextScale(1) -- too small either way; best effort
    uiTier = "simple"
  end
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
      if message.type == "account_locked" and message.cardId == cardUUID then
        -- The server already has an open session for this card (it didn't
        -- get an updateBalance yet, e.g. another machine crashed mid-round).
        -- Tell the player instead of just timing out and printing a
        -- misleading "server is down".
        return "locked", nil, nil, message.remainingSeconds
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

-- European wheel: 0-36, single zero. Standard red/black split.
local RED_NUMBERS = {}
for _, n in ipairs({ 1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36 }) do
  RED_NUMBERS[n] = true
end

local function number_color(n)
  if n == 0 then
    return "green"
  elseif RED_NUMBERS[n] then
    return "red"
  else
    return "black"
  end
end

-- Shows the current number with its real red/black/green pocket color, like
-- a wheel result - not just plain text - so it reads as a color changing
-- each tick during the spin, not just a scrolling number.
local function draw_wheel(number)
  local w, h = term.getSize()
  local midW = math.floor(w / 2)
  local midH = math.floor(h / 2)

  local color = number_color(number)
  local bg = colors.green
  if color == "red" then
    bg = colors.red
  elseif color == "black" then
    bg = colors.gray
  end

  term.setBackgroundColor(colors.black)
  term.clear()
  term.setTextColor(colors.white)
  term.setCursorPos(midW - 6, midH - 1)
  term.write("+------------+")
  term.setCursorPos(midW - 6, midH)
  term.write("|    ")
  term.setBackgroundColor(bg)
  term.write(string.format("%-4s", tostring(number)))
  term.setBackgroundColor(colors.black)
  term.write("    |")
  term.setCursorPos(midW - 6, midH + 1)
  term.write("+------------+")
end

local function spin_animation(finalNumber)
  local delay = 0.05
  for i = 1, 20 do
    local shown
    if i < 20 then
      shown = random(0, 36)
    else
      shown = finalNumber
    end
    draw_wheel(shown)
    sleep(delay)
    if i > 12 then
      delay = delay + 0.05
    end
  end
end

local function get_bet_via_keyboard(money)
  local betType, betValue, betAmount

  while true do
    betType = (input("Bet type (number/red/black/odd/even/high/low): ") or ""):lower()

    if betType == "number" then
      betValue = tonumber(input("Pick a number (0-36): "))
      if not betValue or betValue < 0 or betValue > 36 or betValue ~= math.floor(betValue) then
        print("Enter a whole number between 0 and 36")
        sleep(2)
        goto continue
      end
    elseif betType == "red" or betType == "black" or betType == "odd" or betType == "even"
        or betType == "high" or betType == "low" then
      betValue = nil
    else
      print("Unknown bet type")
      sleep(2)
      goto continue
    end

    betAmount = tonumber(input("Bet amount: "))
    if not betAmount or betAmount <= 0 then
      print("Enter a valid positive bet amount")
      sleep(2)
      goto continue
    elseif betAmount > money then
      print("You can't bet more than you have")
      sleep(2)
      goto continue
    end

    break
    ::continue::
  end

  return betType, betValue, betAmount
end

-- Touch button bet UI (monitor path only) --------------------------------

local TYPE_ROW1 = { { label = "RED", value = "red" }, { label = "BLK", value = "black" },
  { label = "ODD", value = "odd" }, { label = "EVN", value = "even" } }
local TYPE_ROW2 = { { label = "LOW", value = "low" }, { label = "HI", value = "high" },
  { label = "NUM", value = "number" } }
local QUAD_DELTAS = { { label = "-10", delta = -10 }, { label = "-1", delta = -1 },
  { label = "+1", delta = 1 }, { label = "+10", delta = 10 } }

local function make_type_buttons(defs, row)
  local buttons = {}
  local x = 2
  for _, def in ipairs(defs) do
    local text = "[" .. def.label .. "]"
    local x1 = x
    local x2 = x + #text - 1
    table.insert(buttons, { text = text, x1 = x1, x2 = x2, row = row, tag = "type", value = def.value })
    x = x2 + 2
  end
  return buttons
end

local function make_quad_buttons(row, tag)
  local buttons = {}
  local x = 2
  for _, def in ipairs(QUAD_DELTAS) do
    local text = "[" .. def.label .. "]"
    local x1 = x
    local x2 = x + #text - 1
    table.insert(buttons, { text = text, x1 = x1, x2 = x2, row = row, tag = tag, delta = def.delta })
    x = x2 + 2
  end
  return buttons
end

local function make_go_button(row, w)
  local text = "[ SPIN ]"
  local x1 = math.max(1, math.floor((w - #text) / 2))
  return { text = text, x1 = x1, x2 = x1 + #text - 1, row = row, tag = "go" }
end

local ROWS = { typeRow1 = 3, typeRow2 = 4, numLabel = 6, numAdjust = 7, betLabel = 9, betAdjust = 10, spin = 12 }

local function build_bet_buttons(w)
  local buttons = {}
  for _, b in ipairs(make_type_buttons(TYPE_ROW1, ROWS.typeRow1)) do table.insert(buttons, b) end
  for _, b in ipairs(make_type_buttons(TYPE_ROW2, ROWS.typeRow2)) do table.insert(buttons, b) end
  for _, b in ipairs(make_quad_buttons(ROWS.numAdjust, "num")) do table.insert(buttons, b) end
  for _, b in ipairs(make_quad_buttons(ROWS.betAdjust, "bet")) do table.insert(buttons, b) end
  table.insert(buttons, make_go_button(ROWS.spin, w))
  return buttons
end

local function draw_bet_screen(state, money, buttons)
  term.setBackgroundColor(colors.black)
  term.clear()

  term.setCursorPos(1, 1)
  term.setTextColor(colors.white)
  term.write("Type: " .. state.betType .. "  Bal: " .. money)

  term.setCursorPos(1, ROWS.numLabel)
  if state.betType == "number" then
    term.setTextColor(colors.white)
    term.write("Num: " .. state.betValue)
  else
    term.setTextColor(colors.gray)
    term.write("Num: --")
  end

  term.setCursorPos(1, ROWS.betLabel)
  term.setTextColor(colors.white)
  term.write("Bet: " .. state.betAmount)

  for _, b in ipairs(buttons) do
    term.setCursorPos(b.x1, b.row)
    if b.tag == "type" and b.value == state.betType then
      term.setBackgroundColor(colors.yellow)
      term.setTextColor(colors.black)
    elseif b.tag == "go" then
      term.setBackgroundColor(colors.black)
      term.setTextColor(colors.lime)
    else
      term.setBackgroundColor(colors.black)
      term.setTextColor(colors.yellow)
    end
    term.write(b.text)
  end
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
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

local function get_bet_via_buttons(money)
  local w = term.getSize()
  local buttons = build_bet_buttons(w)
  local state = { betType = "red", betValue = 0, betAmount = 1 }

  while true do
    draw_bet_screen(state, money, buttons)
    local x, y = wait_touch()
    for _, b in ipairs(buttons) do
      if y == b.row and x >= b.x1 and x <= b.x2 then
        if b.tag == "type" then
          state.betType = b.value
        elseif b.tag == "num" then
          state.betValue = clamp(state.betValue + b.delta, 0, 36)
        elseif b.tag == "bet" then
          state.betAmount = clamp(state.betAmount + b.delta, 1, money)
        elseif b.tag == "go" then
          if state.betAmount >= 1 and state.betAmount <= money then
            local betValue = (state.betType == "number") and state.betValue or nil
            return state.betType, betValue, state.betAmount
          end
        end
        break
      end
    end
  end
end

-- Full table-layout bet UI (monitor path, wide monitors only) -------------
-- Mimics a real roulette table felt, drawn with actual grid lines like a
-- table diagram: 0 + a 12x3 number grid (tap a number to bet it straight
-- up), a dozens row, and an even-money row (red/black/odd/even/high/low).
-- Tapping any cell selects it as the current bet; amount is adjusted
-- separately below the table.

local DOZEN_LABELS = { "1st 12", "2nd 12", "3rd 12" }
local EVEN_MONEY = {
  { label = "1-18", betType = "low" },
  { label = "EVEN", betType = "even" },
  { label = "RED", betType = "red" },
  { label = "BLACK", betType = "black" },
  { label = "ODD", betType = "odd" },
  { label = "19-36", betType = "high" },
}

local ZERO_W, CELL_W, NUM_COLS = 5, 3, 12

local TABLE_ROWS = {
  topBorder = 1, top = 2, div1 = 3, mid = 4, div2 = 5, bot = 6, gridBottom = 7,
  dozens = 8, div3 = 9, even = 10, evenBottom = 11,
  status = 13, betLabel = 14, amtButtons = 15, spin = 17,
}

-- 14 x-coordinates: the vertical border line before the zero column, after
-- it, and after each of the 12 number columns.
local function build_borders(boardLeft)
  local widths = { ZERO_W }
  for _ = 1, NUM_COLS do table.insert(widths, CELL_W) end
  local borders = { boardLeft }
  local x = boardLeft
  for _, w in ipairs(widths) do
    x = x + w + 1
    table.insert(borders, x)
  end
  return borders
end

local function table_width(borders)
  return borders[#borders] - borders[1] + 1
end

-- Collapse a run of number-column borders into wider grouped cells, e.g.
-- every 4 columns for dozens, every 2 for the even-money row.
local function group_borders(borders, groupSize)
  local numBorders = {}
  for i = 2, #borders do table.insert(numBorders, borders[i]) end
  local grouped = {}
  local i = 1
  while i <= #numBorders do
    table.insert(grouped, numBorders[i])
    i = i + groupSize
  end
  if grouped[#grouped] ~= numBorders[#numBorders] then
    table.insert(grouped, numBorders[#numBorders])
  end
  return grouped
end

local function build_table_cells(borders)
  local cells = {}
  table.insert(cells, {
    x1 = borders[1] + 1, x2 = borders[2] - 1,
    rows = { TABLE_ROWS.top, TABLE_ROWS.mid, TABLE_ROWS.bot },
    betType = "number", betValue = 0, label = "0",
  })
  for c = 1, NUM_COLS do
    local vals = { [TABLE_ROWS.top] = c * 3, [TABLE_ROWS.mid] = c * 3 - 1, [TABLE_ROWS.bot] = c * 3 - 2 }
    for row, val in pairs(vals) do
      table.insert(cells, {
        x1 = borders[c + 1] + 1, x2 = borders[c + 2] - 1, rows = { row },
        betType = "number", betValue = val, label = tostring(val),
      })
    end
  end
  local dozenBorders = group_borders(borders, 4)
  for i = 1, 3 do
    table.insert(cells, {
      x1 = dozenBorders[i] + 1, x2 = dozenBorders[i + 1] - 1, rows = { TABLE_ROWS.dozens },
      betType = "dozen" .. i, label = DOZEN_LABELS[i],
    })
  end
  local evenBorders = group_borders(borders, 2)
  for i, def in ipairs(EVEN_MONEY) do
    table.insert(cells, {
      x1 = evenBorders[i] + 1, x2 = evenBorders[i + 1] - 1, rows = { TABLE_ROWS.even },
      betType = def.betType, label = def.label,
    })
  end
  return cells
end

local function describe_selection(state)
  if state.betType == "number" then return "Number " .. state.betValue end
  if state.betType == "dozen1" then return "1st 12" end
  if state.betType == "dozen2" then return "2nd 12" end
  if state.betType == "dozen3" then return "3rd 12" end
  if state.betType == "low" then return "1-18" end
  if state.betType == "high" then return "19-36" end
  if state.betType == "even" then return "Even" end
  if state.betType == "odd" then return "Odd" end
  if state.betType == "red" then return "Red" end
  if state.betType == "black" then return "Black" end
  return tostring(state.betType)
end

-- Draws a horizontal grid line: "+" at every x in `xs`, "-" filling the
-- gaps between consecutive entries.
local function draw_hline(y, xs)
  term.setTextColor(colors.white)
  term.setCursorPos(xs[1], y)
  for i = 1, #xs - 1 do
    term.write("+" .. string.rep("-", xs[i + 1] - xs[i] - 1))
  end
  term.write("+")
end

-- Like draw_hline, but the first span (the zero column) is left blank
-- instead of dashed, since the zero cell has no divider within itself.
local function draw_hline_skip_first(y, xs)
  term.setTextColor(colors.white)
  term.setCursorPos(xs[1], y)
  term.write("|" .. string.rep(" ", xs[2] - xs[1] - 1))
  for i = 2, #xs - 1 do
    term.setCursorPos(xs[i], y)
    term.write("+" .. string.rep("-", xs[i + 1] - xs[i] - 1))
  end
  term.setCursorPos(xs[#xs], y)
  term.write("+")
end

local function draw_vlines(y, xs)
  term.setTextColor(colors.white)
  for _, x in ipairs(xs) do
    term.setCursorPos(x, y)
    term.write("|")
  end
end

local function draw_table_screen(state, money, boardLeft, borders, cells, amtButtons, goButton)
  term.setBackgroundColor(colors.black)
  term.clear()

  local dozenBorders = group_borders(borders, 4)
  local evenBorders = group_borders(borders, 2)

  draw_hline(TABLE_ROWS.topBorder, borders)
  draw_hline_skip_first(TABLE_ROWS.div1, borders)
  draw_hline_skip_first(TABLE_ROWS.div2, borders)
  draw_hline(TABLE_ROWS.gridBottom, borders)
  draw_hline(TABLE_ROWS.div3, evenBorders)
  draw_hline(TABLE_ROWS.evenBottom, evenBorders)
  draw_vlines(TABLE_ROWS.dozens, dozenBorders)
  draw_vlines(TABLE_ROWS.even, evenBorders)

  for _, cell in ipairs(cells) do
    local isNumberCell = cell.betType == "number"
    local selected = state.betType == cell.betType and
      (not isNumberCell or state.betValue == cell.betValue)

    local bg, fg = colors.gray, colors.white
    if isNumberCell then
      if cell.betValue == 0 then
        bg = colors.green
      else
        bg = (number_color(cell.betValue) == "red") and colors.red or colors.gray
      end
    elseif cell.betType == "red" then
      bg = colors.red
    elseif cell.betType == "black" then
      bg = colors.gray
    else
      bg = colors.blue
    end
    if selected then
      bg, fg = colors.yellow, colors.black
    end

    local width = cell.x2 - cell.x1 + 1
    for _, row in ipairs(cell.rows) do
      term.setCursorPos(cell.x1, row)
      term.setBackgroundColor(bg)
      term.setTextColor(fg)
      -- only print the label on the cell's middle row when it spans several
      if #cell.rows == 1 or row == cell.rows[math.ceil(#cell.rows / 2)] then
        local text = cell.label
        local pad = width - #text
        local leftPad = math.floor(pad / 2)
        term.write(string.rep(" ", math.max(0, leftPad)) ..
          text .. string.rep(" ", math.max(0, pad - leftPad)))
      else
        term.write(string.rep(" ", width))
      end
    end
  end

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)

  term.setCursorPos(boardLeft, TABLE_ROWS.status)
  term.write("Pick: " .. describe_selection(state) .. "   Bal: " .. money)
  term.setCursorPos(boardLeft, TABLE_ROWS.betLabel)
  term.write("Bet: " .. state.betAmount)

  for _, b in ipairs(amtButtons) do
    term.setCursorPos(b.x1, b.row)
    term.setTextColor(colors.yellow)
    term.write(b.text)
  end
  term.setCursorPos(goButton.x1, goButton.row)
  term.setTextColor(colors.lime)
  term.write(goButton.text)
  term.setTextColor(colors.white)
end

local function get_bet_via_table(money)
  local w = term.getSize()
  local tableWidth
  local boardLeft = 1
  do
    local probe = build_borders(1)
    tableWidth = table_width(probe)
    boardLeft = math.max(1, math.floor((w - tableWidth) / 2))
  end
  local borders = build_borders(boardLeft)
  local cells = build_table_cells(borders)
  local amtButtons = make_quad_buttons(TABLE_ROWS.amtButtons, "bet")
  local goButton = make_go_button(TABLE_ROWS.spin, w)

  local state = { betType = "red", betValue = nil, betAmount = 1 }

  while true do
    draw_table_screen(state, money, boardLeft, borders, cells, amtButtons, goButton)
    local x, y = wait_touch()

    local hitCell
    for _, cell in ipairs(cells) do
      for _, row in ipairs(cell.rows) do
        if y == row and x >= cell.x1 and x <= cell.x2 then
          hitCell = cell
          break
        end
      end
      if hitCell then break end
    end

    if hitCell then
      state.betType = hitCell.betType
      state.betValue = hitCell.betValue
    else
      for _, b in ipairs(amtButtons) do
        if y == b.row and x >= b.x1 and x <= b.x2 then
          state.betAmount = clamp(state.betAmount + b.delta, 1, money)
          break
        end
      end
      if y == goButton.row and x >= goButton.x1 and x <= goButton.x2 then
        if state.betAmount >= 1 and state.betAmount <= money then
          return state.betType, state.betValue, state.betAmount
        end
      end
    end
  end
end

-- --------------------------------------------------------------------------

local function calculate_winnings(number, betType, betValue, bet)
  if betType == "number" then
    if number == betValue then
      return bet * 35
    end
    return -bet
  end

  if number == 0 then
    return -bet -- zero loses all outside bets
  end

  local color = number_color(number)

  if betType == "red" then
    if color == "red" then return bet else return -bet end
  elseif betType == "black" then
    if color == "black" then return bet else return -bet end
  elseif betType == "odd" then
    if number % 2 == 1 then return bet else return -bet end
  elseif betType == "even" then
    if number % 2 == 0 then return bet else return -bet end
  elseif betType == "low" then
    if number >= 1 and number <= 18 then return bet else return -bet end
  elseif betType == "high" then
    if number >= 19 and number <= 36 then return bet else return -bet end
  elseif betType == "dozen1" then
    if number >= 1 and number <= 12 then return bet * 2 else return -bet end
  elseif betType == "dozen2" then
    if number >= 13 and number <= 24 then return bet * 2 else return -bet end
  elseif betType == "dozen3" then
    if number >= 25 and number <= 36 then return bet * 2 else return -bet end
  end

  return -bet
end

local function run()
  clear_top()
  print("Welcome to Roulette!")
  print("Please swipe your card to begin")
  local money, playerUUID, username, lockedSeconds = interactWithCard(nil, "getBalance", nil)
  if money == "locked" then
    clear_top()
    print("This card is still finishing another transaction.")
    print("Please wait " .. lockedSeconds .. "s and try again.")
    sleep(3)
    return
  end

  local betType, betValue, betAmount
  if uiTier == "table" then
    betType, betValue, betAmount = get_bet_via_table(money)
  elseif uiTier == "simple" then
    betType, betValue, betAmount = get_bet_via_buttons(money)
  else
    clear_top()
    print("Welcome " .. username .. ", good luck!")
    betType, betValue, betAmount = get_bet_via_keyboard(money)
  end

  local finalNumber = random(0, 36)
  spin_animation(finalNumber)

  local winnings = calculate_winnings(finalNumber, betType, betValue, betAmount)
  money = money + winnings
  interactWithCard(playerUUID, "updateBalance", money)

  local color = number_color(finalNumber)
  term.setCursorPos(1, select(2, term.getSize()) - 3)
  if color == "red" then
    term.setTextColor(colors.red)
  elseif color == "black" then
    term.setTextColor(colors.lightGray)
  else
    term.setTextColor(colors.green)
  end
  print(finalNumber .. " (" .. color .. ")")
  term.setTextColor(colors.white)

  if winnings >= 0 then
    print("WON: " .. winnings)
  else
    print("LOST: " .. -winnings)
  end

  sleep(30)
end

shell.execute("clear")
while true do
  run()
end
