-- BlackJackCC by jimisdam

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
                return 'error'
                --shell.run("reboot")
            end

            if not message then
                print("WTF!? I got a rednet message with no data!?")
                print("Rebooting...")
                sleep(5)
                return 'error'
            end

            if message.type == "account_data" and message.cardId == cardUUID then
                return {
                    balance = message.balance,
                    uuid = message.uuid,
                    username = message.username,
                }
            end
        end
    end
end

-- local SUITS = { 'spades', 'hearts', 'clubs', 'diamonds' }
local SUITMOJIS = {
    utf8.char(6), -- 'â ', -- 'â ï¸',
    utf8.char(3), -- 'â¥', -- 'â¥ï¸',
    utf8.char(5), -- 'â£', -- 'â£ï¸',
    utf8.char(4), -- 'â¦', -- 'â¦ï¸',
}

local FACES = { 'ace', 2, 3, 4, 5, 6, 7, 8, 9, 10, 'jack', 'queen', 'king' }

local DEFAULT_DECK = {}
for si = 1, #SUITMOJIS do
    for fi = 1, #FACES do
        local card = { si, fi }
        table.insert(DEFAULT_DECK, card)
    end
end

local function list_concat(list1, list2)
    local new_list = {}
    table.move(list1, 1, #list1, 1, new_list)
    table.move(list2, 1, #list2, #list1 + 1, new_list)
    return new_list
end

local function deck_populate(deck, times)
    times = times or 1
    if times > 0 then
        deck = list_concat(deck, deck)
        return deck_populate(deck, times - 1)
    end
    return deck
end

local function list_shuffle(list, times)
    times = times or 1
    if times > 0 then
        for i = 1, #list do
            local j = math.random(#list)
            list[i], list[j] = list[j], list[i]
        end
        return list_shuffle(list, times - 1)
    end
end
local deck_shuffle = list_shuffle

local function hand_serve(deck, times, hand)
    times = times or 1
    hand = hand or {}
    if times > 0 then
        local card = table.remove(deck, 1)
        table.insert(hand, card)
        return hand_serve(deck, times - 1, hand)
    end
    return hand
end

local function card_count(card)
    local f = card[2]
    if f > 10 then
        return 10
    else
        return f
    end
end

local function hand_count(hand)
    local score = 0
    local had_ace = false

    for _ci, card in ipairs(hand) do
        score = score + card_count(card)
        had_ace = had_ace or (card[2] == 1)
    end

    if (score <= 11) and had_ace then
        score = score + 10
    end

    return score
end

local function card_pretty(card, is_hidden)
    is_hidden = is_hidden or false
    if is_hidden then
        return '??'
    end

    local s = SUITMOJIS[card[1]]
    local f = FACES[card[2]]

    if type(f) == 'number' then
        f = tostring(f)
    elseif type(f) == 'string' then
        f = f:sub(1, 1):upper()
    end

    return s .. f
end

local function card_print(card, is_hidden)
    is_hidden = is_hidden or false

    local suit_fg_colour = colors.toBlit(colors.red)
    if card[1] % 2 > 0 then
        suit_fg_colour = colors.toBlit(colors.black)
    end

    local card_str = card_pretty(card, is_hidden)
    local face_fg_colour = colors.toBlit(colors.black):rep(#card_str - 1)

    term.blit(card_str, suit_fg_colour .. face_fg_colour, ('0'):rep(#card_str))
end

local function hand_print(hand, is_dealer)
    is_dealer = is_dealer or false
    for ci, card in ipairs(hand) do
        local separator = ', '
        if ci == #hand then
            separator = ''
        end

        card_print(card, is_dealer and ci == 1 and #hand == 2)
        io.write(separator)
    end
end

local function term_reset()
    term.clear()
    term.setCursorPos(1, 1)
end

local function credits_print(who)
    print('[BlackJack by ' .. who .. ']\n')
end

local function game_print(dealer_hand, player_hand, is_first_round)
    is_first_round = is_first_round or false

    local dealer_count_str = ': ' .. hand_count(dealer_hand)
    if is_first_round then
        dealer_count_str = ''
    end
    print('[Dealer' .. dealer_count_str .. ']')
    hand_print(dealer_hand, is_first_round)
    print('\n')

    print('[Player: ' .. hand_count(player_hand) .. ']')
    hand_print(player_hand)
    print('\n')
end

local function game_winner(dealer_hand, player_hand)
    local dealer_count = hand_count(dealer_hand)
    local player_count = hand_count(player_hand)

    local has_dealer_blackjack = dealer_count == 21 and #dealer_hand == 2
    local has_player_blackjack = player_count == 21 and #player_hand == 2

    if has_dealer_blackjack and not has_player_blackjack then
        return 'dealer'
    elseif has_player_blackjack and not has_dealer_blackjack then
        return 'player'
    end

    local is_dealer_greater = dealer_count > player_count
    local is_player_greater = player_count > dealer_count

    local has_dealer_busted = dealer_count > 21
    local has_player_busted = player_count > 21

    local dealer_wins = has_player_busted or (not has_dealer_busted and is_dealer_greater)
    local player_wins = not has_player_busted and (has_dealer_busted or is_player_greater)

    if dealer_wins then
        return 'dealer'
    elseif player_wins then
        return 'player'
    end

    return 'tie'
end

-- Game Script

rednet.open('back')

os.pullEvent = function(...)
    while true do
        local t = table.pack(os.pullEventRaw(...))
        if t[1] ~= 'terminate' then
            return table.unpack(t, 1, t.n)
        end
    end
end

::post_init::

term_reset()
credits_print('jimisdam')
print('Please swipe your card to begin')

local player_data = interactWithCard(nil, "getBalance", nil)
if player_data == 'error' then
    goto post_init
end

local player_bet = nil
while true do
    term_reset()
    credits_print('jimisdam')

    print('Balance: ' .. player_data.balance)
    io.write('Bet: ')

    player_bet = tonumber(read())
    if not player_bet then
        print('\nNot a number')
        goto continue
    elseif player_data.balance < player_bet then
        print('\nInsufficient amount')
        goto continue
    end
    break

    ::continue::
    sleep(3)
end

local deck = deck_populate(DEFAULT_DECK)
deck_shuffle(deck, 1000)

local dealer_hand = hand_serve(deck, 2)
local player_hand = hand_serve(deck)

repeat
    hand_serve(deck, 1, player_hand)

    term_reset()
    credits_print('jimisdam')
    game_print(dealer_hand, player_hand, #dealer_hand == 2)
    io.write("Want to Hit? (y/n): ")
until hand_count(player_hand) >= 21 or read() ~= 'y'

while hand_count(dealer_hand) < 17 do
    hand_serve(deck, 1, dealer_hand)

    term_reset()
    credits_print('jimisdam')
    game_print(dealer_hand, player_hand)
end

term_reset()
credits_print('jimisdam')
game_print(dealer_hand, player_hand)

local winner = game_winner(dealer_hand, player_hand)

if winner == 'dealer' then
    print('You Busted!')
    player_data.balance = player_data.balance - player_bet
elseif winner == 'player' then
    print('You Win!')
    player_data.balance = player_data.balance + player_bet
elseif winner == 'tie' then
    print("Tie!")
else
    print('WTF CASE!')
end

print('\nBalance: ' .. player_data.balance)
interactWithCard(player_data.uuid, 'updateBalance', player_data.balance)

sleep(5)
goto post_init
