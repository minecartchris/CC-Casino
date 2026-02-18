local blockScanner = peripheral.wrap("right")
assert(blockScanner, "Must have a block scanner on right!")
turtle.select(1)
turtle.equipLeft()
local x, y, z = gps.locate()
turtle.equipLeft()
local headers = {
    ["Content-Type"] = "application/json"
}
local websocketServer = "ws://173.89.136.133:8000/ws"
local ws = http.websocket(websocketServer, headers)
print(x, y, z)
local data = {
    ["type"] = "scanner",
    ["id"] = os.getComputerID(),
    ["x"] = x,
    ["y"] = y,
    ["z"] = z,
}
ws.send(textutils.serializeJSON(data))
local direction = nil
local scanAmount = nil

-- --- scanner.lua changes ---

-- 1. Replace the existing while true loop at the top with this:
print("Waiting for server instructions...")

while true do
    local message = ws.receive()
    if message == nil then
        print("Error: Connection lost while waiting for instructions.")
        return
    end

    local data = textutils.unserializeJSON(message)

    if data then
        if data.type == "keep-alive" then
            print("Heartbeat received...")
        elseif data.direction and data.amount then
            direction = data.direction
            scanAmount = data.amount

            print("Received Config! Dir: " .. direction .. " Amount: " .. scanAmount)
            break
        end
    end
end






-- movement helpers
local function drain()
    -- Check for any pending messages without blocking
    while true do
        -- timeout of 0 makes it non-blocking
        local msg = ws.receive(0)
        if msg == nil then break end
        -- We don't need to do anything with pings here,
        -- just reading them keeps the connection alive.
    end
end

-- Update your movement helpers to call drain()
local amountForward = 0
local function forward()
    drain() -- Keep connection alive
    if not turtle.forward() then return false end
    if direction == "n" then
        z = z - 1
    elseif direction == "s" then
        z = z + 1
    elseif direction == "e" then
        x = x + 1
    elseif direction == "w" then
        x = x - 1
    end
    amountForward = amountForward + 1
    return true
end

local function down()
    drain() -- Keep connection alive
    if turtle.down() then
        y = y - 1
        return true
    end
    return false
end

local function up()
    drain() -- Keep connection alive
    if turtle.up() then
        y = y + 1
        return true
    end
    return false
end

local killed = false

local function checkIfKill()
    while true do
        local message = ws.receive()

        if message == nil then
            print("Error: Connection lost while waiting for instructions.")
            return -- Exit the script or trigger a reconnect
        end

        local data = textutils.unserializeJSON(message)

        -- Safety check: did JSON parsing work?
        if data then
            if data.type == "killAll" then
                print("I am Dead")
                killed = true
            end
        end
    end
end

function clamp(value, min_val, max_val)
    return math.min(math.max(value, min_val), max_val)
end

local SCAN_HEIGHT = 16
local body = {
    ["status"] = "scanning",
    ["id"] = os.getComputerID()
}
ws.send(textutils.serializeJSON(body))

local hardnessTable = {}
local function scan()
    for chunk = 1, scanAmount do
        local blocks = {}
        for scanChunk = 1, 40 do
            local totalMovedDown = 0
            local bedrock = false

            -- descend + scan until bedrock
            while not bedrock do
                local movedThisSlice = 0



                -- scan current slice
                for _, block in pairs(blockScanner.scan()) do
                    if not (block.x == 0 and block.z == 0) and block.name ~= "minecraft:air" and block.name ~= "minecraft:lava" and block.name ~= "minecraft:water" then --and ORE_DICT[block.name] then
                        local rx = x + block.x
                        local ry = y + block.y
                        local rz = z + block.z
                        if ry > -59 then
                            table.insert(blocks, {
                                block = block.name,
                                x = x + block.x,
                                y = y + block.y,
                                z = z + block.z
                            })
                            if not hardnessTable[block.name] then
                                hardnessTable[block.name] = clamp(blockScanner.getBlockMeta(block.x, block.y, block.z),
                                    0.5, 5)
                            end
                        end
                    end
                end

                -- move down up to 16 blocks
                for i = 1, SCAN_HEIGHT do
                    local hasBlock, data = turtle.inspectDown()
                    if killed then
                        print("I have been killed")
                        bedrock = true
                        break
                    end
                    if hasBlock and data.name == "minecraft:bedrock" then
                        bedrock = true
                        break
                    end

                    if hasBlock then
                        turtle.digDown()
                    end

                    if not down() then
                        bedrock = true
                        break
                    end

                    movedThisSlice = movedThisSlice + 1
                    totalMovedDown = totalMovedDown + 1
                end
            end

            print("Reached bedrock, depth:", totalMovedDown)

            -- return to original Y
            for i = 1, totalMovedDown do
                up()
            end
            local body = {
                ["id"] = os.getComputerID(),
                ["type"] = "scanner_data", -- Adding a type helps Python sort logic
                ["blocks"] = blocks,       -- 'blocks' is just the list of ores
                ["hardness"] = hardnessTable
            }
            local jsonData = textutils.serialiseJSON(body)
            ws.send(jsonData)
            -- move to next column
            if chunk ~= scanAmount then
                for i = 1, 16 do
                    turtle.dig()
                    forward()
                end
            else
                turtle.turnLeft()
                turtle.turnLeft()
                for i = 1, amountForward do
                    turtle.forward()
                end
                turtle.turnLeft()
                turtle.turnLeft()
            end
            break
        end
    end
end

parallel.waitForAny(scan, checkIfKill)
local body = {
    ["status"] = "finished",
    ["type"] = "scanner",
    ["id"] = os.getComputerID()
}
ws.send(textutils.serializeJSON(body))
