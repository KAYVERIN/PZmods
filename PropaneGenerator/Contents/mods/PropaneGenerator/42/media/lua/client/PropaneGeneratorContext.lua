-- PropaneGeneratorContext.lua
-- Контекстное меню для пропановых генераторов

require "ISUI/ISContextMenu"

local function debugPrint(message)
    print("[PROPAN_CONTEXT] " .. tostring(message))
end

-- ====================================================================
-- ФУНКЦИИ ДЛЯ ПРОВЕРКИ ГЕНЕРАТОРА
-- ====================================================================

-- Проверка, является ли генератор пропановым
local function isPropaneGenerator(generator)
    if not generator then return false end
    local modData = generator:getModData()
    return modData.isPropaneGenerator == true
end

-- Проверка, является ли генератор старым (бензиновым)
local function isOldGenerator(generator)
    if not generator then return false end
    -- Проверка по спрайту или другим характеристикам
    local sprite = generator:getSprite()
    if not sprite then return false end
    local spriteName = sprite:getName()

    local oldSprites = {
        "appliances_misc_01_4", "appliances_misc_01_5",
        "appliances_misc_01_6", "appliances_misc_01_7"
    }

    for _, sprite in ipairs(oldSprites) do
        if spriteName == sprite then
            return true
        end
    end
    return false
end

-- ====================================================================
-- ФУНКЦИИ ДЛЯ ОПЦИЙ КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

-- Функция для добавления опции "Заправить пропаном"
local function addPropaneRefuelOption(context, generator, player)

	local optionText = getText("ContextMenu_RefuelPropane")
    local option = context:addOption(optionText, nil, onAddPropaneToGenerator, generator, player)
    local playerObj = getSpecificPlayer(player)
	local playerInv = playerObj:getInventory()
	
    -- Проверка 1: Может ли игрок подойти к генератору
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_CannotReach")
        option.toolTip = tooltip
		return option
    end
	
	-- Проверка наличия баллона в инвентаре
	if not playerInv:contains("Base.PropaneTank") then
		option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_NoPropaneTank")
        option.toolTip = tooltip
		return option
	end

    -- Проверка 3: Генератор не должен быть полным
    if generator:getFuel() >= generator:getMaxFuel() then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_GeneratorFull")
        option.toolTip = tooltip
		return option
    end

    -- Проверка 4: Генератор не должен быть включен
    if generator:isActivated() then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_GeneratorActive")
        option.toolTip = tooltip
		return option
    end	
	
    debugPrint("Opciya zapravki propanom obrabotana")
    return option
end

-- Функция для добавления опции "Слить топливо" (ПОЛНАЯ РЕАЛИЗАЦИЯ)
local function addDrainFuelOption(context, generator, player)
    debugPrint("Dobavlenie opcii 'Slit toplivo' (polnaya realizaciya)")

    local optionText = getText("ContextMenu_DrainFuel")
    
    -- ВАЖНО: передаем nil как worldobjects, обработчик сам получит их
    local option = context:addOption(optionText, nil, onDrainFuel, generator, player)

    local playerObj = getSpecificPlayer(player)

    -- Проверка 1: Может ли игрок подойти к генератору
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_CannotReach")
        option.toolTip = tooltip
        return option
    end

    -- Проверка 2: Есть ли топливо в генераторе
    if generator:getFuel() <= 0 then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_NoFuelToDrain")
        option.toolTip = tooltip
        return option
    end

    -- Проверка 4: Генератор не должен быть включен
    if generator:isActivated() then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_GeneratorActive")
        option.toolTip = tooltip
        return option
    end

    -- Все проверки пройдены - опция активна
    debugPrint("Opciya slivaniya topliva aktivna")
    return option
end

-- ====================================================================
-- ОСНОВНОЙ ОБРАБОТЧИК КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

local function onFillWorldObjectContextMenu(player, context, worldobjects)
    debugPrint("Obrabotka kontekstnogo menyu dlya generatora")

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    -- Поиск генератора среди объектов
    local generator = nil
	for i = 1, #worldobjects do
		local obj = worldobjects[i]
		if isOldGenerator(obj) then
			generator = obj
			break
		end
	end
    
    if not generator then
        debugPrint("Generator ne najden sredi ob'ektov")
        return
    end

    -- Получаем существующие опции из оригинального меню
    local originalOptionCount = #context.options
    debugPrint("Originalnyh opcij: " .. originalOptionCount)

    -- ====================================================================
    -- ВАЖНО: Вставляем наши опции ПОСЛЕ стандартных опций генератора
    -- но ПЕРЕД опцией "Информация"
    -- ====================================================================

    -- Ищем позицию опции "Информация" чтобы вставить перед ней
    local insertPosition = nil
    local infoOptionText = getText("ContextMenu_GeneratorInfo")

    for i, option in ipairs(context.options) do
        if option.name == infoOptionText then
            insertPosition = i
            debugPrint("Najdena opciya 'Informaciya' na pozicii: " .. i)
            break
        end
    end

    -- Если не нашли "Информацию", вставляем в конец
    if not insertPosition then
        insertPosition = #context.options + 1
    end

    -- ====================================================================
    -- ДОБАВЛЯЕМ НАШИ ОПЦИИ
    -- ====================================================================

    -- Опция "Заправить пропаном" 
    if isOldGenerator(generator) or isPropaneGenerator(generator) then
        addPropaneRefuelOption(context, generator, player)
        debugPrint("Opciya zapravki propanom dobavlena")
    end

    -- Опция "Слить топливо" (только если есть топливо)
    if generator:getFuel() > 0 and not generator:isActivated() then
        addDrainFuelOption(context, generator, player)
        debugPrint("Opciya slivaniya topliva dobavlena (s proverkami)")
    end

    debugPrint("Kontekstnoe menyu uspeshno obrabotano")
end

-- ====================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ====================================================================

local function initializeContextMenu()
    debugPrint("Inicializaciya kontekstnogo menyu dlya propane generatora")

    -- Регистрируем наш обработчик
    Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

    debugPrint("Kontekstnoe menyu inicializirovano")
end

-- Автоматическая инициализация при загрузке
Events.OnGameStart.Add(initializeContextMenu)

debugPrint("PropaneGeneratorContext.lua zagruzhen")