-- PropaneGeneratorContext.lua
-- Контекстное меню для пропановых генераторов
-- Только для старых (бензиновых) генераторов!

require "ISUI/ISContextMenu"
require "PropaneGeneratorMod"
require "PropaneGeneratorPickup"
require "PropaneGeneratorPlacement"

local function debugPrint(message)
    print("[PROPAN_CONTEXT] " .. tostring(message))
end

-- ====================================================================
-- ФУНКЦИИ ДЛЯ ПРОВЕРКИ ГЕНЕРАТОРА
-- ====================================================================

-- Проверка, является ли генератор старым
local function isOldGenerator(generator)
    if not generator then return false end
    -- Проверка по спрайту
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

-- Функция для создания тултипа с преимуществами пропанового генератора
local function createPropaneAdvantagesTooltip(optionText)
    local tooltip = ISToolTip:new()
    tooltip:setName(optionText)
    tooltip.description = string.format(
        "%s\n\n%s\n%s",
        getText("Tooltip_PropaneAdvantages") or "Propane Generator Advantages:",
        getText("Tooltip_PropaneNoise") or "-40% noise radius (quieter operation)",
        getText("Tooltip_PropaneReliability") or "+60% reliability (breaks less often)"
    )
    tooltip:setTexture("media/textures/PropaneTank.png") -- Иконка баллона
    return tooltip
end

-- Функция для добавления опции "Заправить пропаном"
local function addPropaneRefuelOption(context, generator, player)
	local optionText = getText("ContextMenu_RefuelPropane") or "Refuel with Propane"
    local option = context:addOption(optionText, nil, onAddPropaneToGenerator, generator, player)
    local playerObj = getSpecificPlayer(player)
	local playerInv = playerObj:getInventory()
	
    -- Добавляем тултип с преимуществами (даже если опция недоступна)
    local tooltip = createPropaneAdvantagesTooltip(optionText)
    option.toolTip = tooltip
	
    -- Проверка 1: Может ли игрок подойти к генератору
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        tooltip.description = getText("Tooltip_CannotReach") or "Cannot reach" .. "\n\n" .. tooltip.description
		return option
    end
	
	-- Проверка наличия баллона в инвентаре
	if not playerInv:contains("Base.PropaneTank") then
		option.notAvailable = true
        tooltip.description = (getText("Tooltip_NoPropaneTank") or "Need propane tank") .. "\n\n" .. tooltip.description
		return option
	end

    -- Проверка 3: Генератор не должен быть полным
    if generator:getFuel() >= generator:getMaxFuel() then
        option.notAvailable = true
        tooltip.description = (getText("Tooltip_GeneratorFull") or "Generator is full") .. "\n\n" .. tooltip.description
		return option
    end

    -- Проверка 4: Генератор не должен быть включен
    if generator:isActivated() then
        option.notAvailable = true
        tooltip.description = (getText("Tooltip_GeneratorActive") or "Turn off generator first") .. "\n\n" .. tooltip.description
		return option
    end	
	
    debugPrint("Opciya zapravki propanom obrabotana")
    return option
end

-- Функция для добавления опции "Слить топливо"
local function addDrainFuelOption(context, generator, player)
    debugPrint("Dobavlenie opcii 'Slit toplivo'")

    local optionText = getText("ContextMenu_DrainFuel") or "Drain Fuel"
    local option = context:addOption(optionText, nil, onDrainFuel, generator, player)

    local playerObj = getSpecificPlayer(player)

    -- Проверка 1: Может ли игрок подойти к генератору
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_CannotReach") or "Cannot reach"
        option.toolTip = tooltip
        return option
    end

    -- Проверка 2: Есть ли топливо в генераторе
    if generator:getFuel() <= 0 then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_NoFuelToDrain") or "No fuel to drain"
        option.toolTip = tooltip
        return option
    end

    -- Проверка 4: Генератор не должен быть включен
    if generator:isActivated() then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_GeneratorActive") or "Turn off generator first"
        option.toolTip = tooltip
        return option
    end

    debugPrint("Opciya slivaniya topliva aktivna")
    return option
end
--***************************************************************
---ОТЛАДКА------------------------------------------------------
local function addDebugOption(context, generator, player)
    if not ENABLE_DEBUG_PRINTS then return end -- Показываем только если отладка включена
    
    local optionText = "🔧 OTLADKA GENERATORA"
    local option = context:addOption(optionText, nil, function()
        debugGeneratorProperties(generator, "kontekstnoe menyu")
        local playerObj = getSpecificPlayer(player)
        if playerObj then
            playerObj:Say("Otladka generatora vypolnena, proverte console F11")
        end
    end)
    
    -- Dobavlyaem podskazku
    local tooltip = ISToolTip:new()
    tooltip:setName(optionText)
    tooltip.description = "Pokazat v console vse parametry generatora\n(Nazhmite F11 chtoby otkryt console)"
    option.toolTip = tooltip
    
    debugPrint("Opciya otladki dobavlena v menu")
    return option
end
-- ====================================================================
-- ОСНОВНОЙ ОБРАБОТЧИК КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

local function onFillWorldObjectContextMenu(player, context, worldobjects)
    debugPrint("Obrabotka kontekstnogo menyu dlya generatora")

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    -- Поиск ТОЛЬКО старого (бензинового) генератора среди объектов
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

    debugPrint("Staryj generator naiden!")
    
    -- Просто добавляем опции в конец меню
    addPropaneRefuelOption(context, generator, player)
    debugPrint("Opciya zapravki propanom dobavlena v konec")

    if generator:getFuel() > 0 and not generator:isActivated() then
        addDrainFuelOption(context, generator, player)
        debugPrint("Opciya slivaniya topliva dobavlena v konec")
    end

	
    -- Dobavlyaem opciyu otladki (tolko dlya testirovaniya)
    if ENABLE_DEBUG_PRINTS then
        addDebugOption(context, generator, player)
        debugPrint("Opciya otladki dobavlena v konec")
    end
	
    debugPrint("Kontekstnoe menyu uspeshno obrabotano. Vsego opciy: " .. #context.options)
end

-- ====================================================================
-- ДОБАВЛЯЕМ НОВЫЕ ТЕКСТЫ В СИСТЕМУ ЛОКАЛИЗАЦИИ
-- ====================================================================

-- Добавляем новые ключи локализации, если их нет
local function addLocalizationStrings()
    -- Английский (по умолчанию)
    if not getTextOrNull("Tooltip_PropaneAdvantages") then
        -- Это добавляется через файлы локализации, но на всякий случай оставим заглушку
    end
end

-- ====================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ====================================================================

local function initializeContextMenu()
    debugPrint("Inicializaciya kontekstnogo menyu dlya propane generatora")
    
    -- Добавляем локализацию
    addLocalizationStrings()

    -- Регистрируем наш обработчик
    Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

    debugPrint("Kontekstnogo menyu inicializirovano")
end








-- Автоматическая инициализация при загрузке
Events.OnGameStart.Add(initializeContextMenu)

debugPrint("PropaneGeneratorContext.lua zagruzhen")