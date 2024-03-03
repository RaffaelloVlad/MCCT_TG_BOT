local serverURL = "https://8741-93-108-218-37.ngrok-free.app"

-- Configuration parameters for branch mining
local mainTunnelLength = 5
local branchInterval = 5
local branchLength = 3
local verticalDisplacement = 3

local badBlocks = {
    "minecraft:stone",
    "minecraft:dirt",
    "minecraft:grass",
    "minecraft:air",
    "minecraft:deepslate",
    "minecraft:tuff",
    "minecraft:diorite",
    "minecraft:granite",
    "minecraft:cobbled_deepslate"
    -- Add more as needed
}

-- Global stack to track all movements and turns for accurate backtracking
movementStack = {}

-- Function to add movements or turns to the movement stack
function addToMovementStack(action)
    table.insert(movementStack, action)
end

-- Enhanced movement functions with digging and movement tracking
function forward()
    while not turtle.forward() do
        turtle.dig()
        os.sleep(0.5) -- Wait for blocks like gravel to fall
    end
    addToMovementStack("forward")
end

function turnRight()
    turtle.turnRight()
    addToMovementStack("turnRight")
end

function turnLeft()
    turtle.turnLeft()
    addToMovementStack("turnLeft")
end

-- Function to reverse a turn action
function reverseTurn(turnAction)
    if turnAction == "turnRight" then
        turnLeft()
    elseif turnAction == "turnLeft" then
        turnRight()
    end
end

function moveUp()
    while not turtle.up() do
        turtle.digUp()
        os.sleep(0.5) -- Wait for blocks like gravel to fall or obstacles to be cleared
    end
    addToMovementStack("up")
end

function moveDown()
    while not turtle.down() do
        turtle.digDown()
        os.sleep(0.5) -- Similarly, wait for obstacles to be cleared
    end
    addToMovementStack("down")
end

-- Modified backtrack function to include an option for partial backtracking based on last action
function backtrack(steps, lastAction)
    steps = steps or #movementStack
    for i = 1, steps do
        if lastAction and i > 1 then break end -- Only backtrack once if lastAction is specified
        local action = lastAction or table.remove(movementStack)
        if action == "forward" then
            turtle.back()
        elseif action == "turnRight" then
            reverseTurn("turnRight")
        elseif action == "turnLeft" then
            reverseTurn("turnLeft")
        elseif action == "up" then
            turtle.down() -- Reverse an "up" movement by moving down
        elseif action == "down" then
            turtle.up() -- Reverse a "down" movement by moving up
        end
    end
end

function checkAndMineOresAround()
    -- Check forward direction first
    if isGoodBlock("forward") then
        exploreAndMine("forward")
    end

    -- Sequentially turn right and check the next direction
    for i = 1, 3 do -- Only need to turn right 3 times to check all horizontal directions
        turnRight()
        if isGoodBlock("forward") then
            exploreAndMine("forward")
        end
    end

    -- Check up and down without altering horizontal orientation
    if isGoodBlock("up") then
        exploreAndMine("up")
    end
    if isGoodBlock("down") then
        exploreAndMine("down")
    end

    -- Realign to original orientation by completing the 360-degree rotation
    turnRight() -- This final turn completes the full rotation back to the original orientation
end

-- Improved function to explore and mine out a vein of valuable ore and resume branch mining
function exploreAndMine(direction)
    local initialDirection = direction
    local veinMovementStack = {}

    local function mineVeinRecursively()
        for _, dir in ipairs({"forward", "up", "down"}) do
            if isGoodBlock(dir) then
                digAndMove(dir)
                table.insert(veinMovementStack, dir)
                mineVeinRecursively()
                -- Backtrack one step after exploring a branch of the vein
                local lastAction = table.remove(veinMovementStack)
                backtrack(1, lastAction)
            end
        end
    end

    mineVeinRecursively()
end

function digAndMove(direction)
    if direction == "forward" then
        turtle.dig()
        forward() -- Already calls addToMovementStack internally
    elseif direction == "up" then
        moveUp() -- Use the newly defined function for upward movement
    elseif direction == "down" then
        moveDown() -- Use the newly defined function for downward movement
    end
    checkAndMineOresAround() -- Check around after moving to a new block
end

-- Utility to check if a block is considered valuable
function isGoodBlock(direction)
    local success, data
    if direction == "forward" then
        success, data = turtle.inspect()
    elseif direction == "up" then
        success, data = turtle.inspectUp()
    elseif direction == "down" then
        success, data = turtle.inspectDown()
    end
    return success and not isBadBlock(data.name)
end

-- Checks if the block is in the bad block list
function isBadBlock(blockName)
    for _, badBlock in ipairs(badBlocks) do
        if blockName == badBlock then
            return true
        end
    end

    return false
end

-- Function to check and refuel the turtle
function checkAndRefuel()
    local fuelLevel = turtle.getFuelLevel()
    local fuelNeeded = verticalDisplacement + mainTunnelLength + ((2 * branchLength) * (mainTunnelLength/branchInterval)) + 200 -- Adjust based on your needs

    if fuelLevel < fuelNeeded then
        for slot = 1, 16 do
            turtle.select(slot)
            if turtle.refuel(0) then -- Check if it's a valid fuel source without consuming it
                local itemDetail = turtle.getItemDetail()
                local fuelValue = 80 -- Coal's fuel value

                -- Calculate how many of this fuel item is needed
                local itemsNeeded = math.ceil((fuelNeeded - fuelLevel) / fuelValue)
                local itemsAvailable = itemDetail.count

                -- Refuel with the lesser of needed or available items
                local itemsToRefuel = math.min(itemsNeeded, itemsAvailable)
                turtle.refuel(itemsToRefuel)

                fuelLevel = turtle.getFuelLevel()
                if fuelLevel >= fuelNeeded then
                    print("Refueled successfully. Current fuel level: " .. fuelLevel)
                    break -- Exit the loop if we've refueled enough
                end
            end
        end
    end

    turtle.select(1) -- Reset selected slot to the first one
end

-- Function to check if the inventory is full
function isInventoryFull()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            return false
        end
    end
    return true
end

-- Function to clean the inventory based on the bad block list
function cleanInventory(checkIfFull)
    -- If checkIfFull is true, only proceed if the inventory is full
    if checkIfFull and not isInventoryFull() then
        return
    end

    for slot = 1, 16 do
        local itemDetail = turtle.getItemDetail(slot)
        if itemDetail and isBadBlock(itemDetail.name) then
            turtle.select(slot)
            turtle.drop() -- Adjust this to dropUp() or dropDown() if needed
        end
    end
    turtle.select(1) -- Reset the selected slot to the first one after cleaning
end

function depositItems()
    for slot = 1, 16 do
        local itemDetail = turtle.getItemDetail(slot)
        -- Check if the item is not a bad block and also not coal
        if itemDetail and not isBadBlock(itemDetail.name) and itemDetail.name ~= "minecraft:coal" then
            turtle.select(slot)
            turtle.drop() -- Drop the item into the storage; adjust to dropUp() or dropDown() if necessary
        end
    end

    turtle.select(1) -- Reset to the first slot
end

-- Main mining logic with branch mining and exploration
function mainMiningLogic()
    checkAndRefuel()
    cleanInventory()

    for i = 1, verticalDisplacement do
        moveDown()
    end

    for i = 1, mainTunnelLength do
        turtle.dig() -- Ensure forward path is clear
        forward()
        checkAndMineOresAround() -- Check for ores in the main tunnel

        if (i % branchInterval == 0) then
            -- Dig branches and return to main path
            digBranchAndReturn("right")
            digBranchAndReturn("left")
            cleanInventory(true)
        end
    end

    -- After completing the main tunnel, turn around to face the starting direction
    turnRight()
    turnRight()

    -- Move back to the starting point of the main tunnel
    for i = 1, mainTunnelLength do
        forward() -- Assuming forward() can handle obstacles
    end

    cleanInventory()

    for i = 1, verticalDisplacement do
        moveUp()
    end

    -- Deposit items into the storage system
    depositItems()

    -- Optionally, turn around again if you want the turtle to face the original mining direction
    turnRight()
    turnRight()
end

function digBranchAndReturn(direction)
    if direction == "right" then
        turnRight()
    elseif direction == "left" then
        turnLeft()
    end

    for step = 1, branchLength do
        turtle.dig()
        forward()
        checkAndMineOresAround() -- This may alter the turtle's path due to vein exploration
    end

    if direction == "right" then
        -- After digging right branch, we turn 180 degrees to face the main tunnel
        turnLeft()
        turnLeft()
    elseif direction == "left" then
        -- After digging left branch, we turn 180 degrees to face the main tunnel
        turnRight()
        turnRight()
    end

    -- Move forward the length of the branch to return to the main tunnel entrance
    for step = 1, branchLength do
        forward() -- Move back to the main tunnel's entry point of this branch
    end

    if direction == "right" then
        turnRight() -- Correct orientation after returning from a right branch
    elseif direction == "left" then
        turnLeft() -- Correct orientation after returning from a left branch
    end
end

local function fetchConfig()
    local url = serverURL .. "/get-config"
    local response = http.get(url)

    if response then
        local data = response.readAll()
        response.close()

        local newConfig = textutils.unserialiseJSON(data)

        if newConfig then
            -- Compare newConfig with currentConfig to detect changes
            local configChanged = not (textutils.serialize(newConfig) == textutils.serialize(currentConfig))

            if configChanged then
                -- Update currentConfig with newConfig
                currentConfig = newConfig
                -- Update your local variables here
                mainTunnelLength = currentConfig.mainTunnelLength
                branchInterval = currentConfig.branchInterval
                branchLength = currentConfig.branchLength
                verticalDisplacement = currentConfig.verticalDisplacement
            end

            return configChanged
        end
    else
        print("Failed to fetch configuration")
        return false
    end
end

local function waitForCommands()
    while true do
        local url = serverURL .. "/get-command"
        local response = http.get(url)

        if response then
            local data = response.readAll()
            response.close()

            local command = textutils.unserialiseJSON(data)

            if command and command.action == "startMining" then
                local configChanged = fetchConfig()
                if configChanged then
                    print("Configuration changed. Starting mining operation with updated configuration...")
                    mainMiningLogic()
                else
                    print("Configuration unchanged. No need to restart mining operation.")
                end
            elseif command and command.action == "shutdown" then
                print("Shutting down...")
                break -- Exit the loop to shut down
            else
                print("No valid command received. Waiting for new commands...")
            end
        else
            print("Failed to fetch commands. Retrying...")
        end

        sleep(10) -- Wait before checking for new commands
    end
end

-- Start waiting for commands immediately
waitForCommands()
