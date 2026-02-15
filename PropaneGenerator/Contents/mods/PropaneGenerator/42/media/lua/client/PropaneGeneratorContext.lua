-- PropaneGeneratorContext.lua
-- Контекстное меню для пропановых генераторов
-- Работает для ЛЮБОГО старого генератора (и бензин, и пропан)

require "ISUI/ISContextMenu"
require "PropaneGeneratorMod"
require "PropaneGeneratorPickup"
require "PropaneGeneratorPlacement"
require "PG_AddFuelHook"
require "PG_DrainFuel"  -- добавляем модуль слива

local function debugPrint(message)
    if ENABLE_DEBUG_PRINTS then
        print("[PROPAN_CONTEXT] " .. tostring(message))
    end
end

-- ====================================================================
-- ФУНКЦИИ ДЛЯ ПРОВЕРКИ ГЕНЕРАТОРА
-- ====================================================================

-- Все спрайты старых генераторов (и бензин, и пропан)
local OLD_GENERATOR_SPRITES = {
    "appliances_misc_01_4",
    "appliances_misc_01_5",
    "appliances_misc_01_6",
    "appliances_misc_01_7"
}

-- Проверка, является ли объект старым генератором (ЛЮБЫМ)
local function isOldGenerator(generator)
    if not generator then return false end
    local sprite = generator:getSprite()
    if not sprite then return false end
    local spriteName = sprite:getName()

    for _, sprite in ipairs(OLD_GENERATOR_SPRITES) do
        if spriteName == sprite then
            return true
        end
    end
    return false
end

-- Проверка, является ли генератор пропановым (для отладки)
local function isPropaneGenerator(generator)
    if not generator then return false end
    local sprite = generator:getSprite()
    if not sprite then return false end
    return sprite:getName() == "appliances_misc_01_5"
end

-- ====================================================================
-- ФУНКЦИИ ДЛЯ ОПЦИЙ КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

-- Функция для создания тултипа с преимуществами пропанового генератора
local function createPropaneAdvantagesTooltip(optionText)
    local tooltip = ISToolTip:new()
    tooltip:setName(optionText)
    tooltip.description = string.format(
        "%s\n\n%s\n%s",
        "Preimushchestva propanovogo generatora:",
        "-40% radius shuma (tihaya rabota)",
        "+60% nadezhnost' (rezhe lomaetsya)"
    )
    tooltip:setTexture("media/textures/PropaneTank.png")
    return tooltip
end

-- Функция для добавления опции "Заправить пропаном"
local function addPropaneRefuelOption(context, generator, player)
    local option = context:addOption("Zapravit' propanom", nil, onAddPropaneToGenerator, generator, player)
    local playerObj = getSpecificPlayer(player)
    local playerInv = playerObj:getInventory()
    
    local tooltip = createPropaneAdvantagesTooltip("Zapravit' propanom")
    option.toolTip = tooltip
    
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        tooltip.description = "Ne mogu podoyti\n\n" .. tooltip.description
        return option
    end
    
    if not playerInv:contains("Base.PropaneTank") then
        option.notAvailable = true
        tooltip.description = "Nuzhen propanovyy ballon\n\n" .. tooltip.description
        return option
    end
    
    if generator:getFuel() >= generator:getMaxFuel() then
        option.notAvailable = true
        tooltip.description = "Generator polon\n\n" .. tooltip.description
        return option
    end
    
    if generator:isActivated() then
        option.notAvailable = true
        tooltip.description = "Snachala vyklyuchite generator\n\n" .. tooltip.description
        return option
    end
    
    debugPrint("Opciya zapravki propanom dobavlena")
    return option
end

-- ====================================================================
-- ФУНКЦИИ ДЛЯ СЛИВА ТОПЛИВА (из PG_DrainFuel.lua)
-- ====================================================================

-- Проверка наличия шланга
local function hasHoseInInventory(character)
    if not character then return false end
    local inv = character:getInventory()
    local HOSE_ITEMS = {
        "Base.GardenHose",
        "Base.Hose",
        "Base.RubberHose",
        "Base.PlasticHose"
    }
    for _, hoseType in ipairs(HOSE_ITEMS) do
        if inv:contains(hoseType) then
            return true
        end
    end
    return false
end

-- Опция слива бензина
local function addDrainGasolineOption(context, generator, player)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    local option = context:addOption("Slyt benzin (nuzhen shlang)", nil, function()
        if not playerObj then return end
        
        if generator:isActivated() then
            playerObj:Say("Snachala vyklyuchite generator")
            return
        end
        
        if not hasHoseInInventory(playerObj) then
            playerObj:Say("Nuzhen shlang")
            return
        end
        
        local action = ISDrainGasoline:new(playerObj, generator)
        ISTimedActionQueue.add(action)
    end)
    
    local tooltip = ISToolTip:new()
    tooltip:setName("Slyt benzin")
    
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        tooltip.description = "Ne mogu podoyti k generatoru"
        option.toolTip = tooltip
        return option
    end
    
    if generator:isActivated() then
        option.notAvailable = true
        tooltip.description = "Generator vklyuchen - snachala vyklyuchite"
        option.toolTip = tooltip
        return option
    end
    
    if generator:getFuel() <= 0 then
        option.notAvailable = true
        tooltip.description = "V generatore net benzina"
        option.toolTip = tooltip
        return option
    end
    
    if not hasHoseInInventory(playerObj) then
        option.notAvailable = true
        tooltip.description = "Nuzhen shlang (GardenHose, RubberHose, PlasticHose)"
        option.toolTip = tooltip
        return option
    end
    
    tooltip.description = "Slivaet benzin na zemlyu. Shlang mozhet porvatsya (10% shans)."
    option.toolTip = tooltip
    debugPrint("Opciya sliva benzina dobavlena")
    return option
end

-- Опция спуска газа
local function addDrainPropaneOption(context, generator, player)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    local option = context:addOption("Spustit gaz", nil, function()
        if not playerObj then return end
        
        if generator:isActivated() then
            playerObj:Say("Snachala vyklyuchite generator")
            return
        end
        
        local action = ISDrainPropane:new(playerObj, generator)
        ISTimedActionQueue.add(action)
    end)
    
    local tooltip = ISToolTip:new()
    tooltip:setName("Spustit gaz")
    
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        tooltip.description = "Ne mogu podoyti k generatoru"
        option.toolTip = tooltip
        return option
    end
    
    if generator:isActivated() then
        option.notAvailable = true
        tooltip.description = "Generator vklyuchen - snachala vyklyuchite"
        option.toolTip = tooltip
        return option
    end
    
    if generator:getFuel() <= 0 then
        option.notAvailable = true
        tooltip.description = "V generatore net gaza"
        option.toolTip = tooltip
        return option
    end
    
    tooltip.description = "Vypuskaet gaz v atmosferu."
    option.toolTip = tooltip
    debugPrint("Opciya spuska gaza dobavlena")
    return option
end

-- Отладочная опция
local function addDebugOption(context, generator, player)
    if not ENABLE_DEBUG_PRINTS then return end
    
    local option = context:addOption("🔧 OTLADKA GENERATORA", nil, function()
        debugGeneratorProperties(generator, "kontekstnoe menyu")
        local playerObj = getSpecificPlayer(player)
        if playerObj then
            playerObj:Say("Otladka generatora vypolnena, proverte console F11")
        end
    end)
    
    local tooltip = ISToolTip:new()
    tooltip:setName("🔧 OTLADKA GENERATORA")
    tooltip.description = "Pokazat v console vse parametry generatora\n(Nazhmite F11 chtoby otkryt console)"
    option.toolTip = tooltip
    
    return option
end

-- ====================================================================
-- ОСНОВНОЙ ОБРАБОТЧИК КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

local function onFillWorldObjectContextMenu(player, context, worldobjects)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    -- Ищем ЛЮБОЙ старый генератор (и бензин, и пропан)
    local generator = nil
    for i = 1, #worldobjects do
        local obj = worldobjects[i]
        if isOldGenerator(obj) then
            generator = obj
            break
        end
    end
    
    if not generator then
        return
    end
    
    debugPrint("Generator nayden, tip: " .. (isPropaneGenerator(generator) and "PROPAN" or "BENZIN"))
    
    -- ВСЕГДА добавляем опцию заправки (но с проверкой баллона)
    addPropaneRefuelOption(context, generator, player)
    
    -- Добавляем опции слива в зависимости от типа
    if generator:getFuel() > 0 and not generator:isActivated() then
        if isPropaneGenerator(generator) then
            addDrainPropaneOption(context, generator, player)
        else
            addDrainGasolineOption(context, generator, player)
        end
    end
    
    -- Отладка
    if ENABLE_DEBUG_PRINTS then
        addDebugOption(context, generator, player)
    end
end

-- ====================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ====================================================================

local function initializeContextMenu()
    debugPrint("Inicializaciya kontekstnogo menyu")
    Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
    debugPrint("Kontekstnoe menyu inicializirovano")
end

Events.OnGameStart.Add(initializeContextMenu)

debugPrint("PropaneGeneratorContext.lua ZAGRUZhEN")