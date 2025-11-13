-- Load private key
local keyFile = fs.open("private.key", "r")
if not keyFile then
    print("Private key file not found.")
    return
end

local privateKey = keyFile.readAll()
keyFile.close()

write("Recipient Kromer address: ")
local to = read()

write("Amount to send (in KST): ")
local amountInput = read()
local amount = tonumber(amountInput)
if not amount or amount <= 0 then
    print("Invalid amount.")
    return
end

write("Metadata (optional): ")
local metadata = read()

local payload = {
    amount = amount,
    to = to,
    metadata = metadata ~= "" and metadata or nil,
    privatekey = privateKey
}

local url = "https://kromer.reconnected.cc/api/krist/transactions"

local headers = {
    ["Content-Type"] = "application/json"
}

local json = textutils.serializeJSON(payload)
print("Sending transaction to Kromer API...")
local response = http.post(url, json, headers)

if not response then
    print("Failed to contact Kromer API.")
    return
end

local result = response.readAll()
response.close()

local success, data = pcall(textutils.unserializeJSON, result)
if not success then
    print("Error parsing response: " .. result)
    return
end

if data.error then
    print("Transaction failed: " .. data.error)
else
    print("Transaction successful!")
    if data.transaction and data.transaction.txid then
        print("TX ID: " .. data.transaction.txid)
    else
        print("No TX ID returned. Raw transaction data:")
        print(textutils.serialize(data.transaction))
    end
end
