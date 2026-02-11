-- PropaneGeneratorUtils.lua
-- Общие утилиты для мода

PropaneGenerator = {}

-- Конфигурация
PropaneGenerator.config = {
    FUEL_PER_FULL_TANK = 50,
    PROPANE_MIN_TO_KEEP = 0.70,
    EMPTY_TANK_THRESHOLD = 0.001
}

-- Утилиты для работы с генераторами
function PropaneGenerator.isPropaneGenerator(generator)
    if not generator then return false end
    local modData = generator:getModData()
    return modData.isPropaneGenerator == true
end

function PropaneGenerator.getGeneratorTypeString(generator)
    if PropaneGenerator.isPropaneGenerator(generator) then
        return getText("IGUI_GeneratorType_Propane") or "Propane Generator"
    else
        return getText("IGUI_GeneratorType_Gasoline") or "Gasoline Generator"
    end
end

-- Утилиты для работы с топливом
function PropaneGenerator.calculateFuelTransfer(generator, propaneTank)
    if not generator or not propaneTank then return 0 end
    
    local currentFuel = generator:getFuel()
    local maxFuel = generator:getMaxFuel()
    llocal currentUses = self.propaneTank:getCurrentUses()
	local maxUses = self.propaneTank:getMaxUses()
	local tankPercent = currentUses / maxUses
    
    local availableFuel = tankPercent * PropaneGenerator.config.FUEL_PER_FULL_TANK
    local freeSpace = maxFuel - currentFuel
    
    return math.min(availableFuel, freeSpace)
end

-- Утилиты для текстов
function PropaneGenerator.getTooltipText(generator)
    local text = ""
    
    if PropaneGenerator.isPropaneGenerator(generator) then
        text = text .. getText("Tooltip_PropaneGenerator_Bonuses") .. "\n"
        text = text .. "- " .. getText("Tooltip_PropaneGenerator_Quieter") .. "\n"
        text = text .. "- " .. getText("Tooltip_PropaneGenerator_MoreReliable") .. "\n"
    end
    
    return text
end



debugPrint("PropaneGeneratorUtils.lua zagruzhen")
