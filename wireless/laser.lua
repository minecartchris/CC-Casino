local x, y, z = gps.locate()
local laser = peripheral.wrap("left")
local websocketServer = "ws://173.89.136.133:8000/ws"
local headers = {
    ["Content-Type"] = "application/json"
}
local ws = http.websocket(websocketServer, headers)
local data = {
    ["type"] = "laser",
    ["id"] = os.getComputerID(),
    ["x"] = x,
    ["y"] = y,
    ["z"] = z,
}
ws.send(textutils.serializeJSON(data))

local function fire(fx, fy, fz, power)
    local relx = fx - x
    local rely = fy - y
    local relz = fz - z
    local pitch = -math.atan2(rely, math.sqrt(relx * relx + relz * relz))
    local yaw = math.atan2(-relx, relz)
    laser.fire(math.deg(yaw), math.deg(pitch), power)
end

while true do
    local message = ws.receive()

    if message == nil then
        print("Error: Connection lost while waiting for instructions.")
        return -- Exit the script or trigger a reconnect
    end

    local data = textutils.unserializeJSON(message)

    -- Safety check: did JSON parsing work?
    if data then
        if data.type == "keep-alive" then
            print("Heartbeat received...")
        elseif data.type == "fire" then
            fire(data.x, data.y, data.z, data.power)
            local body = {
                ["type"] = "fired",
                ["id"] = os.getComputerID()
            }
            ws.send(textutils.serializeJSON(body))
        elseif data.type == "killAll" then
            break
        end
    end
end
