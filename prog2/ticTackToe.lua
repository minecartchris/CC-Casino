os.pullEvent=os.pullEventRaw
if fs.exists("/disk/terminate") then
    error("Service mode active",2)
end
--tic
--[[
	
	TIC-TAC-TOE
	by Evan Hahn (http://www.evanhahn.com/)
	
	This is a program that allows you to play tic-tac-toe against the
	computer.
	
	You may change the configuration (below) to make the board more than 3x3,
	or play with "white" and "black" instead of "x" and "o", and change how
	the board is displayed.
	
	How it works:
	
	The board is represented by a 2D table of spaces. They are filled with
	nil to start. When you play, you put an "x" or an "o" into the table. The
	board is used to keep track of piece locations and to display them. It
	does not calculate wins.
		
	The board also has regions. A region is a place where a player may win
	(horizontal, vertical, or diagonal). It holds pointers to the board table.
	Player 1 is represented by +, and Player 2 by -. Each piece in the region
	increments or decrements the checking of the region. Basically, two X's
	returns as 2. Two O's returns as -2. 3 or -3 is a winning region.
	
	Some notes:
	
	- There are other ways to program this, but I did not elect to use them.
	  One alternate way: Generate a table that holds string representations
	  of all the winning boards. Check for wins against that table instead.
	
	- I am unfamiliar with accepted style and best practices of Lua, and
	  my code may reflect that.
	
--]]

----------------------------------------------
-- Configuration (change this if you wish!) --
----------------------------------------------

-- Are they playable by human or computer-controlled?
PLAYER_1_HUMAN = true
PLAYER_2_HUMAN = false

-- Board size
BOARD_RANK = 3	-- The board will be this in both dimensions.

-- Display stuff
PLAYER_1 = "x"	-- Player 1 is represented by this. Player 1 goes first.
PLAYER_2 = "o"	-- Player 2 is represented by this.
EMPTY_SPACE = " "	-- An empty space is displayed like this.
DISPLAY_HORIZONTAL_SEPARATOR = "-"	-- Horizontal lines look like this.
DISPLAY_VERTICAL_SEPARATOR = " | "	-- Vertical lines look like this


--[[ ###################################################################
     ####   Don't mess with things below here unless you are brave  ####
     ################################################################### --]]

------------------------
-- More configuration --
------------------------

MAX_BOARD_RANK = 100	-- Won't run above this number. Prevents crashes.

-------------------------------------------------------
-- Don't run if the board is larger than the maximum --
-------------------------------------------------------

if BOARD_RANK > MAX_BOARD_RANK then os.exit(0) end

-----------------------------
-- Create board (2D table) --
-----------------------------

space = {}
for i = 0, (BOARD_RANK - 1) do
	space[i] = {}
	for j = 0, (BOARD_RANK - 1) do
		space[i][j] = nil	-- start each space with nil
	end
end

---------------------
-- Board functions --
---------------------

-- get the piece at a given spot
function getPiece(x, y)
	return space[x][y]
end

-- get the piece at a given spot; if nil, return " "
-- this is useful for output.
function getPieceNoNil(x, y)
	if getPiece(x, y) ~= nil then
		return getPiece(x, y)
	else
		return EMPTY_SPACE
	end	
end

-- is that space empty?
function isEmpty(x, y)
	if getPiece(x, y) == nil then
		return true
	else
		return false
	end
end

-- place a piece there, but make sure nothing is there already.
-- if you can't play there, return false.
function placePiece(x, y, piece)
	if isEmpty(x, y) == true then
		space[x][y] = piece
		return true
	else
		return false
	end
end

-- is the game over?
function isGameOver()
	if checkWin() == false then	-- if there is no win...
		for i = 0, (BOARD_RANK - 1) do	-- is the board empty?
			for j = 0, (BOARD_RANK - 1) do
				if isEmpty(i, j) == true then return false end
			end
		end
		return true
	else	-- there is a win; the game is over
		return true
	end
end

-- create a string made up of a certain number of smaller strings
-- this is useful for the display.
function repeatString(to_repeat, amount)
	if amount <= 0 then return "" end
	local to_return = ""
	for i = 1, amount do
		to_return = to_return .. to_repeat
	end
	return to_return
end

-- display the board.
-- this uses the configuration file pretty much entirely.
function displayBoard()
	
	-- find the widest player
	local widest_piece = math.max(string.len(PLAYER_1), string.len(PLAYER_2), string.len(EMPTY_SPACE))
	
	-- display board, top to bottom
	io.write("\n") -- make sure it starts on a new line
	for i = (BOARD_RANK - 1), 0, -1 do
		local row = ""	-- start with an empty row
		for j = 0, (BOARD_RANK - 1) do	-- generate that row
			local piece = getPieceNoNil(j, i)
			row = row .. piece
			row = row .. repeatString(" ", widest_piece - string.len(piece))
			if j ~= (BOARD_RANK - 1) then
				row = row .. DISPLAY_VERTICAL_SEPARATOR
			end
		end
		io.write(row)	-- output row
		if i ~= 0 then	-- output horizontal line as long as the row
			io.write("\n")
			local repeats = math.ceil(string.len(row) / string.len(DISPLAY_HORIZONTAL_SEPARATOR))
			io.write(repeatString(DISPLAY_HORIZONTAL_SEPARATOR, repeats))
			io.write("\n")
		end
	end
	
	-- finish off with a line break
	io.write("\n")
end

-------------------------------------------------
-- Create regions (I admit this is a bit ugly) --
-------------------------------------------------

-- declare region and a number to increment
region = {}
region_number = 0

-- vertical
for i = 0, (BOARD_RANK - 1) do
	region[region_number] = {}
	for j = 0, (BOARD_RANK - 1) do
		region[region_number][j] = {}
		region[region_number][j]["x"] = i
		region[region_number][j]["y"] = j
	end
	region_number = region_number + 1
end

-- horizontal
for i = 0, (BOARD_RANK - 1) do
	region[region_number] = {}
	for j = 0, (BOARD_RANK - 1) do
		region[region_number][j] = {}
		region[region_number][j]["x"] = j
		region[region_number][j]["y"] = i
	end
	region_number = region_number + 1
end

-- diagonal, bottom-left to top-right
region[region_number] = {}
for i = 0, (BOARD_RANK - 1) do
	region[region_number][i] = {}
	region[region_number][i]["x"] = i
	region[region_number][i]["y"] = i
end
region_number = region_number + 1

-- diagonal, top-left to bottom-right
region[region_number] = {}
for i = (BOARD_RANK - 1), 0, -1 do
	region[region_number][i] = {}
	region[region_number][i]["x"] = BOARD_RANK - i - 1
	region[region_number][i]["y"] = i
end
region_number = region_number + 1

----------------------
-- Region functions --
----------------------

-- get a region
function getRegion(number)
	return region[number]
end

-- check for a win in a particular region.
-- returns a number representation of the region. occurrences of player 1
-- add 1, occurrences of player 2 subtract 1. so if there are two X pieces,
-- it will return 2. one O will return -1.
function checkWinInRegion(number)
	local to_return = 0
	for i, v in pairs(getRegion(number)) do
		local piece = getPiece(v["x"], v["y"])
		if piece == PLAYER_1 then to_return = to_return + 1 end
		if piece == PLAYER_2 then to_return = to_return - 1 end
	end
	return to_return
end

-- check for a win in every region.
-- returns false if no winner.
-- returns the winner if there is one.
function checkWin()
	for i in pairs(region) do
		local win = checkWinInRegion(i)
		if math.abs(win) == BOARD_RANK then
			if win == math.abs(win) then
				return PLAYER_1
			else
				return PLAYER_2
			end
		end
	end
	return false
end

------------------
-- UI Functions --
------------------

-- human play
function humanPlay(piece)
	
	io.write(piece .. ", here's the board:\n")
	displayBoard()
	local placed = false
	while placed == false do	-- loop until they play correctly
		io.write("\nWhere would you like to play your " .. piece .. "?\n")
		io.write("Give the X-coordinate (starting with 0). ")
		local x = tonumber(io.read())
		io.write("Now give the Y-coordinate (starting with 0). ")
		local y = tonumber(io.read())
		placed = placePiece(x, y, piece)
		if placed == false then
			io.write("I'm afraid you can't play there!")
		end
	end
	displayBoard()
	io.write("\n")
	
end

-- AI play
function AIPlay(piece)
	
	-- am I negative or positive?
	local me = 0
	if piece == PLAYER_1 then me = 1 end
	if piece == PLAYER_2 then me = -1 end
	
	-- look for a region in which I can win
	for i in pairs(region) do
		local win = checkWinInRegion(i)
		if win == ((BOARD_RANK - 1) * me) then
			for j, v in pairs(getRegion(i)) do
				if isEmpty(v["x"], v["y"]) == true then
					placePiece(v["x"], v["y"], piece)
					return
				end
			end
		end
	end
	
	-- look for a region in which I can block
	for i in pairs(region) do
		local win = checkWinInRegion(i)
		if win == ((BOARD_RANK - 1) * (me * -1)) then
			for j, v in pairs(getRegion(i)) do
				if isEmpty(v["x"], v["y"]) == true then
					placePiece(v["x"], v["y"], piece)
					return
				end
			end
		end
	end
	
	-- play first empty space, if no better option
	for i = 0, (BOARD_RANK - 1) do
		for j = 0, (BOARD_RANK - 1) do
			if placePiece(i, j, piece) ~= false then return end
		end
	end
	
end

----------
-- Main --
----------

-- welcome!
io.write("Welcome to Tic-Tac-Toe!\n\n")

-- play the game until someone wins
while true do
	
	-- break if the game is won
	if isGameOver() == true then break end
	
	-- player 1
	if PLAYER_1_HUMAN == true then humanPlay(PLAYER_1)
	else AIPlay(PLAYER_1) end
	sleep(1)
	shell.run("clear all")
	-- break if the game is won
	if isGameOver() == true then break end
	
	-- player 2
	if PLAYER_2_HUMAN == true then humanPlay(PLAYER_2)
	else AIPlay(PLAYER_2) end
	
end

-- show the final board
io.write("The final board:\n")
displayBoard()
io.write("\n")

-- write who won, or if there is a tie
win = checkWin()
if win == false then
	io.write("Tie game!\n")
else
	io.write(win)
	io.write(" wins!\n")
end
sleep(5)
shell.run("clear all")
shell.run("startup")
