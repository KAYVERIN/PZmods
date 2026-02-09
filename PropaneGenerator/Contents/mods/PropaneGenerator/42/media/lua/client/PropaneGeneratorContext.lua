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
    local option = context:addOption(optionText, generator, onAddPropaneToGenerator, player)
    
    -- Проверка наличия баллона
    local playerObj = getSpecificPlayer(player)
    local hasTank = false
    
    if playerObj then
        local primary = playerObj:getPrimaryHandItem()
        local secondary = playerObj:getSecondaryHandItem()
        
        if (primary and primary:getType() == "PropaneTank" and primary:getUsedDelta() > 0) or
           (secondary and secondary:getType() == "PropaneTank" and secondary:getUsedDelta() > 0) then
            hasTank = true
        end
    end
    
    -- Делаем опцию неактивной если нет баллона
    if not hasTank then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_NeedPropaneTank") or "Нужен пропановый баллон"
        option.toolTip = tooltip
    end
    
    return option
end

-- Функция для добавления опции "Слить топливо"
local function addDrainFuelOption(context, generator, player)
    debugPrint("Dobavlenie opcii 'Slit toplivo'")
    
    local optionText = getText("ContextMenu_GeneratorDrainFuel") or "Слить топливо"
    local option = context:addOption(optionText, generator, onDrainFuel, player)
    
    -- Проверка наличия пустой канистры
    local playerObj = getSpecificPlayer(player)
    local hasContainer = false
    
    if playerObj then
        -- Проверка инвентаря на наличие пустых канистр
        -- Здесь должна быть логика проверки
    end
    
    -- Делаем неактивным если нет подходящей емкости
    if not hasContainer then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_NeedEmptyContainer") or "Нужна пустая канистра"
        option.toolTip = tooltip
    end
    
    return option
end

-- ====================================================================
-- ОСНОВНОЙ ОБРАБОТЧИК КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

local function onFillWorldObjectContextMenu(player, context, worldObjects)
    debugPrint("Obrabotka kontekstnogo menyu dlya generatora")
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    -- Находим генератор среди объектов
    local generator = nil
    for i = 1, #worldObjects do
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
        debugPrint("Opciya slivaniya topliva dobavlena")
    end
    
    -- Разделитель после наших опций
    context:insertOptionAfter(nil, nil, insertPosition)
    
    debugPrint("Kontekstnoe menyu uspeshno obrabotano")
end

-- ====================================================================
-- ОБРАБОТЧИКИ ДЕЙСТВИЙ
-- ====================================================================

-- Обработчик для заправки пропаном
function onAddPropaneToGenerator(generator, player)
    debugPrint("Vyzov zapravki propanom")
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj or not generator then return end
    
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
        return
    end
    
    -- Создаем и добавляем действие
    local action = ISAddPropaneToGenerator:new(playerObj, generator, propaneTank)
    ISTimedActionQueue.add(action)
    debugPrint("Deistvie zapravki dobavleno v ochered")
end

-- Обработчик для слива топлива
function onDrainFuel(generator, player)
    debugPrint("Vyzov slivaniya topliva")
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj or not generator then return end
    
    -- Здесь будет логика создания действия для слива топлива
    -- Нужно создать класс ISDrainGeneratorFuel
    playerObj:Say("Сливаем топливо...")
    debugPrint("Slivanie topliva (zatyshka)")
end

-- ====================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ====================================================================

local function initializeContextMenu()
    debugPrint("Inicializaciya kontekstnogo menyu dlya propane generatora")
    
    -- Регистрируем наш обработчик с ВЫСОКИМ приоритетом
    -- чтобы он выполнился ПОСЛЕ оригинального
    Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
    
    debugPrint("Kontekstnoe menyu inicializirovano")
end

-- Автоматическая инициализация при загрузке
Events.OnGameStart.Add(initializeContextMenu)
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

debugPrint("PropaneGeneratorContext.lua zagruzhen")
