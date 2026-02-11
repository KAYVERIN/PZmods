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
    debugPrint("Dobavlenie opcii 'Zapravit propanom'")

    local optionText = getText("ContextMenu_GeneratorAddPropane") or "Заправить пропаном"
    local option = context:addOption(optionText, nil, onAddPropaneToGenerator, generator, player)

    local playerObj = getSpecificPlayer(player)
    if not playerObj then
        option.notAvailable = true
        return option
    end

    -- Проверка 1: Может ли игрок подойти к генератору
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_CannotReach") or "Не могу дотянуться"
        option.toolTip = tooltip
        return option
    end

    -- Проверка 2: Наличие баллона с пропаном
    local hasTank = false
    local propaneTank = nil
    local primary = playerObj:getPrimaryHandItem()
    local secondary = playerObj:getSecondaryHandItem()

    if (primary and primary:getType() == "PropaneTank" and primary:getUsedDelta() > 0) or
       (secondary and secondary:getType() == "PropaneTank" and secondary:getUsedDelta() > 0) then
        hasTank = true
    end

    -- Проверка 3: Генератор не должен быть полным
    if generator:getFuel() >= generator:getMaxFuel() then
        hasTank = false
    end

    -- Проверка 4: Генератор не должен быть включен
    if generator:isActivated() then
        hasTank = false
    end

    -- Делаем опцию неактивной если нет баллона
    if not hasTank then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_NeedPropaneTank") or "Нужен пропановый баллон"
        option.toolTip = tooltip
    end

    debugPrint("Opciya zapravki propanom obrabotana")
    return option
end

-- Функция для добавления опции "Слить топливо" (ПОЛНАЯ РЕАЛИЗАЦИЯ)
local function addDrainFuelOption(context, generator, player)
    debugPrint("Dobavlenie opcii 'Slit toplivo' (polnaya realizaciya)")

    local optionText = getText("ContextMenu_GeneratorDrainFuel") or "Слить топливо"
    
    -- ВАЖНО: передаем nil как worldobjects, обработчик сам получит их
    local option = context:addOption(optionText, nil, onDrainFuel, generator, player)

    local playerObj = getSpecificPlayer(player)
    if not playerObj then
        option.notAvailable = true
        return option
    end

    -- Проверка 1: Может ли игрок подойти к генератору
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_CannotReach") or "Не могу дотянуться"
        option.toolTip = tooltip
        return option
    end

    -- Проверка 2: Есть ли топливо в генераторе
    if generator:getFuel() <= 0 then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_NoFuelToDrain") or "Нет топлива для слива"
        option.toolTip = tooltip
        return option
    end

    -- Проверка 3: Ищем пустую емкость в инвентаре (по аналогии с игровой логикой)
    local playerInv = playerObj:getInventory()
    local emptyContainers = playerInv:getAllEvalRecurse(function(item)
        if not item then return false end
        local fluidContainer = item:getFluidContainer()
        if not fluidContainer then return false end
        -- Ищем емкости, которые могут хранить топливо и пусты
        return fluidContainer:isEmpty() and not fluidContainer:isInputLocked()
    end)

    if emptyContainers:isEmpty() then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_NeedEmptyContainer") or "Нужна пустая канистра или другая емкость"
        option.toolTip = tooltip
        return option
    end

    -- Проверка 4: Генератор не должен быть включен
    if generator:isActivated() then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_GeneratorActive") or "Сначала выключи генератор"
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

    -- Находим генератор среди объектов
    local generator = nil
    for i = 1, #worldobjects do
        local obj = worldObjects[i]
        if obj and instanceof(obj, "IsoGenerator") then
            generator = obj
            break
        end
    end

    if not generator then return end

    -- Получаем существующие опции из оригинального меню
    local originalOptionCount = #context.options
    debugPrint("Originalnyh opcij: " .. originalOptionCount)

    -- ====================================================================
    -- ВАЖНО: Вставляем наши опции ПОСЛЕ стандартных опций генератора
    -- но ПЕРЕД опцией "Информация"
    -- ====================================================================

    -- Ищем позицию опции "Информация" чтобы вставить перед ней
    local insertPosition = nil
    local infoOptionText = getText("ContextMenu_GeneratorInfo") or "Информация"

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

    -- Разделитель перед нашими опциями
    context:insertOptionAfter(nil, nil, insertPosition)
    insertPosition = insertPosition + 1

    -- Опция "Заправить пропаном" (для всех типов генераторов)
    if not generator:isActivated() and generator:getFuel() < generator:getMaxFuel() then
        addPropaneRefuelOption(context, generator, player)
        debugPrint("Opciya zapravki propanom dobavlena")
    end

    -- Опция "Слить топливо" (только если есть топливо)
    if generator:getFuel() > 0 and not generator:isActivated() then
        addDrainFuelOption(context, generator, player)
        debugPrint("Opciya slivaniya topliva dobavlena (s proverkami)")
    end

    -- Разделитель после наших опций
    context:insertOptionAfter(nil, nil, insertPosition)

    debugPrint("Kontekstnoe menyu uspeshno obrabotano")
end

-- ====================================================================
-- ОБРАБОТЧИКИ ДЕЙСТВИЙ (исправленный формат для интеграции с игрой)
-- ====================================================================

-- Обработчик для заправки пропаном (теперь соответствует игровому формату)
function onAddPropaneToGenerator(worldobjects, generator, player)
    debugPrint("Vyzov zapravki propanom (novyj format)")

    local playerObj = getSpecificPlayer(player)
    if not playerObj or not generator then return end

    -- Проверяем, может ли игрок подойти к генератору (как в игровых функциях)
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        debugPrint("Igrok ne mozhet podojti k generatoru")
        return
    end

    -- Поиск баллона в руках
    local propaneTank = nil
    local primary = playerObj:getPrimaryHandItem()
    local secondary = playerObj:getSecondaryHandItem()

    if primary and primary:getType() == "PropaneTank" and primary:getUsedDelta() > 0 then
        propaneTank = primary
    elseif secondary and secondary:getType() == "PropaneTank" and secondary:getUsedDelta() > 0 then
        propaneTank = secondary
    end

    if not propaneTank then
        playerObj:Say(getText("IGUI_PlayerText_NeedPropaneTank") or "Нужен пропановый баллон")
        debugPrint("Net propanoogo ballona v rukah")
        return
    end

    -- Проверяем, не полон ли генератор
    if generator:getFuel() >= generator:getMaxFuel() then
        playerObj:Say(getText("IGUI_PlayerText_GeneratorFull") or "Генератор полон")
        debugPrint("Generator polon")
        return
    end

    -- Создаем и добавляем действие
    local action = ISAddPropaneToGenerator:new(playerObj, generator, propaneTank)
    ISTimedActionQueue.add(action)
    debugPrint("Deistvie zapravki dobavleno v ochered")
end

-- Обработчик для слива топлива (теперь соответствует игровому формату)
function onDrainFuel(worldobjects, generator, player)
    debugPrint("Vyzov slivaniya topliva (novyj format)")

    local playerObj = getSpecificPlayer(player)
    if not playerObj or not generator then return end

    -- Проверяем, может ли игрок подойти к генератору
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        debugPrint("Igrok ne mozhet podojti k generatoru dlya slivaniya")
        return
    end

    -- Проверяем, есть ли топливо
    if generator:getFuel() <= 0 then
        playerObj:Say(getText("IGUI_PlayerText_NoFuelToDrain") or "Нет топлива для слива")
        debugPrint("Net topliva dlya slivaniya")
        return
    end

    -- Ищем пустую емкость (можно выбрать первую подходящую или реализовать выбор)
    local playerInv = playerObj:getInventory()
    local emptyContainers = playerInv:getAllEvalRecurse(function(item)
        if not item then return false end
        local fluidContainer = item:getFluidContainer()
        if not fluidContainer then return false end
        return fluidContainer:isEmpty() and not fluidContainer:isInputLocked()
    end)

    if emptyContainers:isEmpty() then
        playerObj:Say(getText("IGUI_PlayerText_NeedEmptyContainer") or "Нужна пустая емкость")
        debugPrint("Net pustoj emkosti")
        return
    end

    -- Здесь будет логика создания действия для слива топлива
    -- TODO: Создать класс ISDrainGeneratorFuel
    playerObj:Say("Сливаем топливо...")
    debugPrint("Slivanie topliva - trebuetsya sozdanie klassa ISDrainGeneratorFuel")
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