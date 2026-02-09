local OriginalFarmingMenu = {
    onShovel = ISFarmingMenu.onShovel
}

ISFarmingMenu.onShovel = function(worldObjects, plant, player, sq)
    OriginalFarmingMenu.onShovel(worldObjects, plant, player, sq)
    
    ISFarmingMenu.cursor = ISFarmingCursorMouse:new(player, 
        ISFarmingMenu.onShovelSelected, ISFarmingMenu.isShovelValid)
    getCell():setDrag(ISFarmingMenu.cursor, player:getPlayerNum())
end

ISFarmingMenu.onShovelSelected = function()
    local cursor = ISFarmingMenu.cursor
    local player = cursor.character
    
    if not ISFarmingMenu.walkToPlant(player, cursor.sq) then
        return
    end
    
    local plant = CFarmingSystem.instance:getLuaObjectOnSquare(cursor.sq)
    local handItem = player:getPrimaryHandItem()

    ISTimedActionQueue.add(ISShovelAction:new(player, handItem, plant, 40))
end

ISFarmingMenu.isShovelValid = function()
    if not ISFarmingMenu.cursor then
        return false
    end
    
    local cursor = ISFarmingMenu.cursor
    local plant = CFarmingSystem.instance:getLuaObjectOnSquare(cursor.sq)

    if not ISFarmingMenu.isValidPlant(plant) then
        cursor.tooltipTxt = "<RGB:1,0,0> " .. getText("Farming_Tooltip_NotAPlant")
        return false
    end

    local plantName = ISFarmingMenu.getPlantName(plant)
    cursor.tooltipTxt = plantName .. " <LINE> " .. getText('Tooltip_RemoveThisFurrow')
    
    return true
end

local DigWormsAction = ISBaseTimedAction:derive("DigWormsAction")

local function walkToWormDiggingSite(player, square)
    if not square or not ISFarmingMenu.canDigHereSquare(square) then
        return false
    end
    
    if AdjacentFreeTileFinder.isTileOrAdjacent(player:getCurrentSquare(), square) then
        return true
    end
    
    local adjacent = AdjacentFreeTileFinder.Find(square, player)
    if adjacent == nil then
        return false
    end
    
    ISTimedActionQueue.add(ISWalkToTimedAction:new(player, adjacent))
    return true
end

function DigWormsAction:isValid()
    return self.character and self.gridSquare and ISFarmingMenu.canDigHereSquare(self.gridSquare)
end

function DigWormsAction:waitToStart()
    self.character:faceLocation(self.gridSquare:getX(), self.gridSquare:getY())
    return self.character:shouldBeTurning()
end

function DigWormsAction:update()
    self.character:faceLocation(self.gridSquare:getX(), self.gridSquare:getY())
    if self.item then
        self.item:setJobDelta(self:getJobDelta())
    end
    self.character:setMetabolicTarget(Metabolics.DiggingSpade)
end

function DigWormsAction:start()
    if self.item then
        self.item:setJobType(getText("ContextMenu_Dig"))
        self.item:setJobDelta(0.0)
        
        local digType = self.item:getDigType()
        if digType == "Trowel" or self.item:getType() == "HandShovel" or 
           self.item:getType() == "HandFork" or self.item:getType() == "EntrenchingTool" then
            self.sound = self.character:playSound("DigFurrowWithTrowel")
        else
            self.sound = self.character:playSound("DigFurrowWithShovel")
        end
    end

    addSound(self.character, 
             self.character:getX(), 
             self.character:getY(), 
             self.character:getZ(), 10, 1)
    
    self:setActionAnim(BuildingHelper.getShovelAnim(self.item))

    if self.item then
        self:setOverrideHandModels(self.item:getStaticModel(), nil)
    end
end

function DigWormsAction:stop()
    if self.sound and self.sound ~= 0 then
        self.character:getEmitter():stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
    if self.item then
        self.item:setJobDelta(0.0)
    end
end

function DigWormsAction:perform()
    if self.item then
        self.item:getContainer():setDrawDirty(true)
        self.item:setJobDelta(0.0)
    end
    
    if self.sound and self.sound ~= 0 then
        self.character:getEmitter():stopOrTriggerSound(self.sound)
    end

    local rainIntensity = getClimateManager():getRainIntensity()
    local minRainIntensity = 0.15
    local randRange = 5
    
    if rainIntensity > minRainIntensity then 
        randRange = 3
    end

    if ZombRand(randRange) == 0 then
        self.character:getInventory():AddItem("Base.Worm")
        self.character:Say(getText("IGUI_DigWorms_FoundWorm") or "Found a worm!")
    end
    
    if ZombRand(20) == 0 then
        local possibleItems = {"Base.Stone", "Base.Twigs", "Base.Grasshopper", "Base.Clay"}
        local randomItem = possibleItems[ZombRand(#possibleItems) + 1]
        self.character:getInventory():AddItem(randomItem)
    end

    ISBaseTimedAction.perform(self)
    
    local plowAction = DigWormsAction:new(self.character, self.gridSquare, self.item, 150)
    ISTimedActionQueue.add(plowAction)
end

function DigWormsAction:new(character, square, item, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    
    o.character = character
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = character:isTimedActionInstant() and 1 or (time or 150)
    o.item = item
    o.gridSquare = square
    o.caloriesModifier = 5
    o.sound = 0
    
    return o
end

local function getDiggingTool(player)
    local inv = player:getInventory()
    
    local tools = {
        "Shovel",
        "Trowel",
        "HandShovel",
        "HandFork",
        "EntrenchingTool",
        "GardenFork",
        "SnowShovel",
        "GardenHoe",
        "PickAxe"
    }
    
    for _, toolType in ipairs(tools) do
        local tool = inv:getFirstTypeRecurse(toolType)
        if tool then
            return tool
        end
    end
    
    return nil
end

local function beginWormDigging(player, handItem, sq)
    if not sq or not ISFarmingMenu.canDigHereSquare(sq) then
        return
    end
    
    ISInventoryPaneContextMenu.equipWeapon(handItem, true, 
        handItem:isTwoHandWeapon(), player:getPlayerNum())

    if walkToWormDiggingSite(player, sq) then
        local digAction = DigWormsAction:new(player, sq, handItem, 150)
        ISTimedActionQueue.add(digAction)
    end
end

local function addWormDiggingOption(playerIndex, context, worldObjects, test)
    if #worldObjects == 0 then return end
    
    local player = getSpecificPlayer(playerIndex)
    local shovel = getDiggingTool(player)
    
    if not shovel then return end
    
    local sq = worldObjects[1]:getSquare()
    
    -- Проверяем, можно ли копать на этой поверхности
    if not ISFarmingMenu.canDigHereSquare(sq) then
        return
    end
    
    local digOptionName = getText("ContextMenu_Dig")
    local digOption = context:getOptionFromName(digOptionName)
    
    local wormDigOptionName = getText("ContextMenu_DigWormsAction") or "Dig for Worms"
    
    if digOption then
        context:insertOptionAfter(digOptionName, wormDigOptionName, 
            player, beginWormDigging, shovel, sq)
    else
        context:addOption(wormDigOptionName, player, beginWormDigging, shovel, sq)
    end
end

Events.OnFillWorldObjectContextMenu.Add(addWormDiggingOption)