local FUEL_CONFIGS = {
    -- Формат настройки: {префикс, начальный_индекс, конечный_индекс, время_горения_в_минутах, время_растопки_в_минутах}
    -- Листья: d_floorleaves_1_0 до d_floorleaves_1_11 (12 предметов)
    {prefix = "d_floorleaves_1_", startIdx = 0, endIdx = 11, fuelMinutes = 5, tinderMinutes = 5},
    -- Мусор: trash_01_0 до trash_01_53 (54 предмета)
    {prefix = "trash_01_", startIdx = 0, endIdx = 53, fuelMinutes = 3, tinderMinutes = 3},
    -- Пример добавления новых предметов:
    -- {prefix = "twigs_01_", startIdx = 0, endIdx = 7, fuelMinutes = 8, tinderMinutes = 6},
    -- {prefix = "paper_02_", startIdx = 0, endIdx = 15, fuelMinutes = 2, tinderMinutes = 1},
}

local allFuelItems = {}

local function generateFuelItems()
    allFuelItems = {}
    
    for _, config in ipairs(FUEL_CONFIGS) do
        for i = config.startIdx, config.endIdx do
            local itemName = config.prefix .. i
            local fuelHours = config.fuelMinutes / 60.0
            local tinderHours = config.tinderMinutes / 60.0
            
            table.insert(allFuelItems, {
                name = itemName,
                fuelHours = fuelHours,
                tinderHours = tinderHours
            })
        end
    end
end

local function addToFuelTables()
    for _, itemData in ipairs(allFuelItems) do
        local itemName = itemData.name
        
        if not campingFuelType[itemName] then
            campingFuelType[itemName] = itemData.fuelHours
        end
        
        if not campingLightFireType[itemName] then
            campingLightFireType[itemName] = itemData.tinderHours
        end
    end
end

local function addTagsToItems()
    for _, itemData in ipairs(allFuelItems) do
        local item = ScriptManager.instance:getItem(itemData.name)
        
        if item then
            local tags = item:getTags()
            
            if not tags:contains("IsFireFuel") then
                tags:add("IsFireFuel")
            end
            
            if not tags:contains("IsFireTinder") then
                tags:add("IsFireTinder")
            end
        end
    end
end

local function initializeMod()
    generateFuelItems()
    addToFuelTables()
    addTagsToItems()
end

Events.OnGameStart.Add(initializeMod)
Events.OnLoad.Add(initializeMod)

local originalFillMenu = ISWorldObjectContextMenu.onFillWorldObjectContextMenu
ISWorldObjectContextMenu.onFillWorldObjectContextMenu = function(player, context, worldobjects, test)
    local result = originalFillMenu and originalFillMenu(player, context, worldobjects, test)
    addToFuelTables()
    return result
end