-- ====================================================================
-- PropaneGeneratorMod.lua - Мод для заправки генератора пропаном
-- Версия: 4.0 (Объединенная стабильная версия)
-- ====================================================================

-- ====================================================================
-- РАЗДЕЛ 1: НАСТРОЙКИ МОДА (ВЫНЕСЕНЫ В НАЧАЛО)
-- ====================================================================

-- Включить отладочные сообщения (true) или выключить (false)
ENABLE_DEBUG_PRINTS = true

-- Эффективность пропанового баллона:
-- Сколько единиц топлива генератора дает один ПОЛНЫЙ баллон пропана?
FUEL_PER_FULL_TANK = 50

-- Пороговые значения для смены типа генератора (в десятичных дробях):
-- Если в генераторе БОЛЬШЕ 70% пропана - становится пропановым
-- Если 70% или меньше - возвращается к бензину
PROPANE_MIN_TO_KEEP = 0.70  -- 70%

-- Минимальный уровень в баллоне для проверки "пустоты"
EMPTY_TANK_THRESHOLD = 0.001

-- Названия типов предметов (должны совпадать с items.txt)
GENERATOR_OLD = "Generator_Old"
GENERATOR_PROPANE = "Generator_Old_Propane"

-- ====================================================================
-- РАЗДЕЛ 2: ФУНКЦИИ ОТЛАДКИ
-- ====================================================================

-- Функция для вывода отладочных сообщений
function debugPrint(message)
    if ENABLE_DEBUG_PRINTS then
        print("[PROPAN_MOD] " .. tostring(message))
    end
end

debugPrint("=================================================================")
debugPrint("ZAGRUZKA PROPANE GENERATOR MOD - Obedinennaia versiia 4.0")
debugPrint("=================================================================")

-- ====================================================================
-- РАЗДЕЛ 3: PROPANE GENERATOR UTILS - ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ====================================================================

PropaneGenerator = {}

-- Конфигурация мода (для доступа из других модулей)
PropaneGenerator.config = {
    FUEL_PER_FULL_TANK = FUEL_PER_FULL_TANK,
    PROPANE_MIN_TO_KEEP = PROPANE_MIN_TO_KEEP,
    EMPTY_TANK_THRESHOLD = EMPTY_TANK_THRESHOLD
}

-- Проверка, является ли генератор пропановым
function PropaneGenerator.isPropaneGenerator(generator)
    if not generator then return false end
    local modData = generator:getModData()
    return modData.isPropaneGenerator == true
end

-- Получение строки типа генератора
function PropaneGenerator.getGeneratorTypeString(generator)
    if PropaneGenerator.isPropaneGenerator(generator) then
        return "Propanovyi generator"
    else
        return "Benzinovyi generator"
    end
end

-- Расчет передаваемого топлива
function PropaneGenerator.calculateFuelTransfer(generator, propaneTank)
    if not generator or not propaneTank then return 0 end
    
    local currentFuel = generator:getFuel()
    local maxFuel = generator:getMaxFuel()
    local currentUses = propaneTank:getCurrentUses()
    local maxUses = propaneTank:getMaxUses()
    local tankPercent = currentUses / maxUses
    
    local availableFuel = tankPercent * FUEL_PER_FULL_TANK
    local freeSpace = maxFuel - currentFuel
    
    return math.min(availableFuel, freeSpace)
end

-- Получение текста для подсказки
function PropaneGenerator.getTooltipText(generator)
    local text = ""
    
    if PropaneGenerator.isPropaneGenerator(generator) then
        text = text .. "Preimushchestva propanovogo generatora:\n"
        text = text .. "- Menshe shuma (-40%)\n"
        text = text .. "- Lomaetsia rezhe (+60%)\n"
    end
    
    return text
end

debugPrint("[UTILITY] Vspomogatelnye funkcii zagruzheny")

-- ====================================================================
-- РАЗДЕЛ 4: PROPANE GENERATOR UI - ФУНКЦИИ ИНТЕРФЕЙСА
-- ====================================================================

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"

-- Создание расширенного окна информации о генераторе
PropaneGeneratorInfoWindow = ISPanel:derive("PropaneGeneratorInfoWindow")

function PropaneGeneratorInfoWindow:createChildren()
    -- Вызываем оригинальный метод если он есть
    if self.originalCreateChildren then
        self.originalCreateChildren(self)
    end
    
    -- Добавляем наши элементы
    local y = 100  -- Позиция после оригинальных элементов
    
    -- Индикатор типа генератора
    local generatorType = "Benzinovyi"
    if self.generator and self.generator:getModData().isPropaneGenerator then
        generatorType = "Propanovyi"
    end
    
    self.typeLabel = ISLabel:new(10, y, 20, generatorType, 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.typeLabel)
    y = y + 25
    
    -- Преимущества пропанового генератора
    if generatorType == "Propanovyi" then
        self.bonusLabel = ISLabel:new(10, y, 20, "Preimushchestva:", 0.8, 1, 0.8, 1, UIFont.Small, true)
        self:addChild(self.bonusLabel)
        y = y + 20
        
        self.bonus1 = ISLabel:new(20, y, 20, "- Menshe shuma (-40%)", 0.8, 1, 0.8, 1, UIFont.Small, true)
        self:addChild(self.bonus1)
        y = y + 18
        
        self.bonus2 = ISLabel:new(20, y, 20, "- Lomaetsia rezhe (+60%)", 0.8, 1, 0.8, 1, UIFont.Small, true)
        self:addChild(self.bonus2)
        y = y + 18
    end
end

function PropaneGeneratorInfoWindow:render()
    -- Оригинальный рендер
    if self.originalRender then
        self.originalRender(self)
    end
    
    -- Обновляем тип генератора если он изменился
    if self.generator then
        local modData = self.generator:getModData()
        local isPropane = modData.isPropaneGenerator == true
        
        if isPropane and self.typeLabel.title ~= "Propanovyi" then
            self.typeLabel.title = "Propanovyi"
            self.typeLabel:setColor(0.8, 1, 0.8)
            
            -- Показываем бонусы
            if self.bonusLabel then
                self.bonusLabel:setVisible(true)
                self.bonus1:setVisible(true)
                self.bonus2:setVisible(true)
            end
        elseif not isPropane and self.typeLabel.title ~= "Benzinovyi" then
            self.typeLabel.title = "Benzinovyi"
            self.typeLabel:setColor(1, 1, 1)
            
            -- Прячем бонусы
            if self.bonusLabel then
                self.bonusLabel:setVisible(false)
                self.bonus1:setVisible(false)
                self.bonus2:setVisible(false)
            end
        end
    end
end

-- Перехват создания окна генератора
local function overrideGeneratorWindow()
    debugPrint("[UI] Perekhvat okna generatora")
    
    -- Сохраняем оригинальные методы
    if ISGeneratorInfoWindow and not ISGeneratorInfoWindow.originalCreate then
        ISGeneratorInfoWindow.originalCreate = ISGeneratorInfoWindow.create
        ISGeneratorInfoWindow.originalCreateChildren = ISGeneratorInfoWindow.createChildren
        ISGeneratorInfoWindow.originalRender = ISGeneratorInfoWindow.render
        
        -- Переопределяем создание окна
        function ISGeneratorInfoWindow:create(x, y, width, height, generator)
            debugPrint("[UI] Sozdanie okna generatora s modifikaciiami")
            
            -- Вызываем оригинальный create
            local window = self.originalCreate(self, x, y, width, height, generator)
            
            -- Меняем класс на наш
            setmetatable(window, PropaneGeneratorInfoWindow)
            PropaneGeneratorInfoWindow.__index = PropaneGeneratorInfoWindow
            
            return window
        end
        
        debugPrint("[UI] Pereopredelenie okna generatora vypolneno")
    end
end

debugPrint("[UI] Funkcii interfeisa zagruzheny")

-- ====================================================================
-- РАЗДЕЛ 5: ОСНОВНЫЕ ФУНКЦИИ МОДА
-- ====================================================================

require "TimedActions/ISBaseTimedAction"

-- Получение типа генератора по спрайту
local function getGeneratorTypeBySprite(generator)
    if not generator then 
        debugPrint("Oshibka: generator = nil")
        return nil 
    end

    local sprite = generator:getSprite()
    if not sprite then 
        debugPrint("Oshibka: u generatora net spraita")
        return nil 
    end

    local spriteName = sprite:getName()
    debugPrint("Imia spraita generatora: " .. tostring(spriteName))

    -- Спрайты старых генераторов
    local oldGeneratorSprites = {
        "appliances_misc_01_4",
        "appliances_misc_01_5", 
        "appliances_misc_01_6",
        "appliances_misc_01_7"
    }

    -- Проверяем, является ли спрайт старым генератором
    for _, oldSprite in ipairs(oldGeneratorSprites) do
        if spriteName == oldSprite then
            return GENERATOR_OLD
        end
    end

    return "unknown"
end

-- Проверка, является ли генератор старым (бензиновым)
local function isOldGenerator(generator)
    local genType = getGeneratorTypeBySprite(generator)
    local isOld = (genType == GENERATOR_OLD)
    debugPrint("Proverka starogo generatora: rezultat = " .. tostring(isOld))
    return isOld
end

-- Функция проверки типа генератора по ModData
local function getGeneratorType(generator)
    if not generator then 
        debugPrint("Oshibka: generator = nil")
        return "unknown"
    end
    
    local modData = generator:getModData()
    if modData.isPropaneGenerator == true then
        return "propane"
    else
        return "gasoline"
    end
end

-- Функция для автоматической экипировки пропанового баллона
local function ensurePropaneTankInHands(character)
    if not character then return nil end
    
    -- Проверяем, есть ли уже баллон в руках
    local primary = character:getPrimaryHandItem()
    local secondary = character:getSecondaryHandItem()
    
    if primary and primary:getType() == "PropaneTank" and primary:getCurrentUses() > 0 then
        debugPrint("Ballon uzhe v osnovnoi ruke")
        return primary
    end
    
    if secondary and secondary:getType() == "PropaneTank" and secondary:getCurrentUses() > 0 then
        debugPrint("Ballon uzhe vo vtoroi ruke")
        return secondary
    end
    
    -- Ищем баллон с НАИМЕНЬШИМ количеством топлива
    local inventory = character:getInventory()
    local propaneTank = nil
    local lowestUses = math.huge
    
    for i = 1, inventory:getItems():size() do
        local item = inventory:getItems():get(i-1)
        if item and item:getType() == "PropaneTank" and item:getCurrentUses() > 0 then
            local uses = item:getCurrentUses()
            if uses < lowestUses then
                lowestUses = uses
                propaneTank = item
            end
        end
    end
    
    -- Если нашли баллон - экипируем
    if propaneTank then
        -- Убираем из основной руки текущий предмет
        if primary then
            character:removeFromHands(primary)
        end
        character:setPrimaryHandItem(propaneTank)
        debugPrint("Ekipirovan ballon v osnovnuiu ruku")
        
        if isServer() then
            sendServerCommand(character, 'ui', 'dirtyUI', {})
        else
            ISInventoryPage.dirtyUI()
        end
        return propaneTank
    end
    
    debugPrint("Ne naiden ballon s toplivom")
    return nil
end

-- Функция для замены генератора на новый тип
local function replaceGeneratorWithNewType(oldGenerator, newGeneratorType, playerObj)
    if not oldGenerator or not oldGenerator:getSquare() then
        debugPrint("OSHIbKA: generator ili kvadrat ne sushchestvuet")
        return nil
    end

    local square = oldGenerator:getSquare()
    local cell = getWorld():getCell()

    -- Сохраняем ВСЕ параметры старого генератора
    local currentFuel = oldGenerator:getFuel()
    local currentCondition = oldGenerator:getCondition()
    local isActivated = oldGenerator:isActivated()
    local isConnected = oldGenerator:isConnected()
    local modData = oldGenerator:getModData()
    
    debugPrint("=== NACHALO ZAMENY GENERATORA ===")
    debugPrint(string.format("Staryi: toplivo=%.1f, sostoianie=%d", currentFuel, currentCondition))
    debugPrint(string.format("Aktivirovan=%s, Podkliuchen=%s", tostring(isActivated), tostring(isConnected)))

    -- Шаг 1: Создаём предмет нового генератора
    local newItem = instanceItem(newGeneratorType)
    if not newItem then
        debugPrint("OSHIbKA: ne udalos sozdat predmet " .. newGeneratorType)
        return nil
    end

    -- Копируем состояние
    if newItem.setCondition then
        newItem:setCondition(currentCondition)
    end

    -- Шаг 2: Удаляем старый генератор
    if square.transmitRemoveItemFromSquare then
        square:transmitRemoveItemFromSquare(oldGenerator)
    end

    -- Шаг 3: Создаём новый генератор
    local newGenerator = IsoGenerator.new(newItem, cell, square)
    if not newGenerator then
        debugPrint("OSHIbKA: ne udalos sozdat novyi generator")
        return nil
    end

    -- Шаг 4: Восстанавливаем параметры
    newGenerator:setFuel(currentFuel)
    
    if isActivated and newGenerator.setActivated then
        newGenerator:setActivated(true)
    end
    
    if isConnected and newGenerator.setConnected then
        newGenerator:setConnected(true)
    end
    
    -- Шаг 5: Копируем ModData
    local newModData = newGenerator:getModData()
    for k, v in pairs(modData) do
        newModData[k] = v
    end
    
    -- Шаг 6: Устанавливаем флаг
    newModData.isPropaneGenerator = (newGeneratorType == GENERATOR_PROPANE)
    
    -- Шаг 7: Синхронизируем
    if newGenerator.transmitCompleteItemToClients then
        newGenerator:transmitCompleteItemToClients()
    end

    debugPrint("=== ZAMENA ZAVERSHENA USPEShNO ===")
    return newGenerator
end

-- ====================================================================
-- РАЗДЕЛ 6: ОСНОВНОЙ КЛАСС ДЕЙСТВИЯ - ЗАПРАВКА ПРОПАНОМ
-- ====================================================================

ISAddPropaneToGenerator = ISBaseTimedAction:derive("ISAddPropaneToGenerator")

-- Конструктор класса
function ISAddPropaneToGenerator:new(character, generator, propaneTank)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 100
    
    o.generator = generator
    o.propaneTank = propaneTank
    o.sound = nil
    
    debugPrint("Sozdano novoe deistvie dlia " .. character:getUsername())
    return o
end

-- Метод получения длительности действия
function ISAddPropaneToGenerator:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 100
end

-- Метод проверки возможности выполнения действия
function ISAddPropaneToGenerator:isValid()
    debugPrint("Proverka vozmozhnosti zapravki propanom...")

    if not self.generator or not self.generator:getSquare() then
        debugPrint("Generator ne sushchestvuet")
        return false
    end

    if self.generator:getFuel() >= self.generator:getMaxFuel() then
        debugPrint("Generator polon")
        return false
    end

    if not isOldGenerator(self.generator) then
        debugPrint("Generator ne yavliaetsia Generator_Old")
        return false
    end

    if self.generator:isActivated() then
        debugPrint("Generator aktivirovan")
        return false
    end

    local hasTank = self.character:isPrimaryHandItem(self.propaneTank) or 
                    self.character:isSecondaryHandItem(self.propaneTank)
    
    if not hasTank then
        debugPrint("Propanovyi ballon ne v rukah")
        return false
    end

    return true
end

-- Метод ожидания начала действия
function ISAddPropaneToGenerator:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

-- Метод обновления
function ISAddPropaneToGenerator:update()
    if self.propaneTank and self.propaneTank.setJobDelta then
        self.propaneTank:setJobDelta(self:getJobDelta())
    end
    self.character:faceThisObject(self.generator)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

-- Метод начала действия
function ISAddPropaneToGenerator:start()
    debugPrint("Nachalo zapravki propanom")
    
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")

    if self.propaneTank and self.propaneTank.setJobType then
        self.propaneTank:setJobType(getText("IGUI_PlayerText_Refueling"))
        self.propaneTank:setJobDelta(0.0)
    end

    self.sound = self.character:playSound("GeneratorAddFuel")
end

-- Метод остановки
function ISAddPropaneToGenerator:stop()
    debugPrint("Deistvie zapravki prervano")
    
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end

    if self.propaneTank and self.propaneTank.setJobDelta then
        self.propaneTank:setJobDelta(0.0)
    end

    ISBaseTimedAction.stop(self)
end

-- Метод выполнения
function ISAddPropaneToGenerator:perform()
    debugPrint("Deistvie zapravki vypolneno")
    
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end

    if self.propaneTank and self.propaneTank.setJobDelta then
        self.propaneTank:setJobDelta(0.0)
    end

    ISBaseTimedAction.perform(self)
end

-- Основная логика заправки
function ISAddPropaneToGenerator:complete()
    debugPrint("=== OSNOVNAIa LOGIKA ZAPRAVKI PROPANOM ===")

    -- Получаем текущие значения
    local currentFuel = self.generator:getFuel()
    local maxFuel = self.generator:getMaxFuel()
    local currentUses = self.propaneTank:getCurrentUses()
    local maxUses = self.propaneTank:getMaxUses()
    local currentTankPercent = currentUses / maxUses

    -- Рассчитываем, сколько топлива можно добавить
    local availableFuelFromTank = currentTankPercent * FUEL_PER_FULL_TANK
    local freeSpace = maxFuel - currentFuel
    local fuelToTransfer = math.min(availableFuelFromTank, freeSpace)

    debugPrint(string.format("Tekushchee toplivo: %.1f", currentFuel))
    debugPrint(string.format("Mozhno dobavit: %.1f", fuelToTransfer))

    -- Сколько топлива будет после заправки
    local fuelAfterRefuel = currentFuel + fuelToTransfer
    local propanePercentageAfter = fuelAfterRefuel / maxFuel

    debugPrint(string.format("Budet posle zapravki: %.1f", fuelAfterRefuel))
    debugPrint(string.format("Procent propana posle: %.1f%%", propanePercentageAfter * 100))

    -- Определяем, нужна ли замена генератора
    local needsPropaneGenerator = (propanePercentageAfter > PROPANE_MIN_TO_KEEP)
    local currentType = getGeneratorType(self.generator)
    local targetGenerator = self.generator

    -- Если нужно заменить на пропановый И текущий не пропановый
    if needsPropaneGenerator and currentType ~= "propane" then
        debugPrint("ZAMENA: na propanovyi generator")
        local newGenerator = replaceGeneratorWithNewType(self.generator, GENERATOR_PROPANE, self.character)
        if newGenerator then
            targetGenerator = newGenerator
        end
    -- Если нужно заменить на бензиновый И текущий не бензиновый
    elseif not needsPropaneGenerator and currentType ~= "gasoline" then
        debugPrint("ZAMENA: na benzinovyi generator")
        local newGenerator = replaceGeneratorWithNewType(self.generator, GENERATOR_OLD, self.character)
        if newGenerator then
            targetGenerator = newGenerator
        end
    else
        debugPrint("ZAMENA: tip generatora ne meniaem")
    end

    -- Выполняем заправку
    debugPrint("VYPOLNIAEM ZAPRAVKU...")
    
    -- Уменьшаем уровень в баллоне
    local percentUsed = fuelToTransfer / FUEL_PER_FULL_TANK
    local newTankPercent = currentTankPercent - percentUsed

    if newTankPercent < EMPTY_TANK_THRESHOLD then
        newTankPercent = 0
        debugPrint("Ballon teper pustoi")
    end

    self.propaneTank:setUsedDelta(newTankPercent)
    debugPrint(string.format("Novyi uroven v ballone: %.1f%%", newTankPercent * 100))

    -- Увеличиваем топливо в генераторе
    if targetGenerator and targetGenerator.setFuel then
        targetGenerator:setFuel(fuelAfterRefuel)
        debugPrint(string.format("Novyi uroven topliva v generatore: %.1f", fuelAfterRefuel))
        
        -- Обновляем ModData
        local modData = targetGenerator:getModData()
        modData.isPropaneGenerator = needsPropaneGenerator
    end
    
    debugPrint("=== ZAPRAVKA ZAVERSHENA ===")
end

-- ====================================================================
-- РАЗДЕЛ 7: ОБРАБОТЧИКИ КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

function onAddPropaneToGenerator(worldObjects, generator, playerNum)
    debugPrint("Vyzov zapravki propanom iz kontekstnogo meniu")

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not generator then 
        debugPrint("Oshibka: igrok ili generator ne naiden")
        return 
    end

    -- Проверяем, выключен ли генератор
    if generator:isActivated() then
        playerObj:Say("Snachala vykliuchite generator")
        debugPrint("Generator aktivirovan - zapravka nevozmozhna")
        return
    end

    -- Экипируем баллон
    local propaneTank = ensurePropaneTankInHands(playerObj)
    if not propaneTank then
        playerObj:Say("Nuzhen propanovyi ballon")
        debugPrint("Ne udalos ekipirovat ballon")
        return
    end

    -- Создаем и добавляем действие
    local action = ISAddPropaneToGenerator:new(playerObj, generator, propaneTank)
    ISTimedActionQueue.add(action)
    debugPrint("Deistvie zapravki dobavleno v ochered")
end

function onDrainFuel(worldObjects, generator, playerNum)
    debugPrint("Vyzov sliva topliva")
    
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not generator then return end

    if generator:isActivated() then
        playerObj:Say("Snachala vykliuchite generator")
        return
    end

    if generator:getFuel() <= 0 then
        playerObj:Say("Net topliva dlia sliva")
        return
    end

    playerObj:Say("Funkciia sliva topliva v razrabotke")
    debugPrint("Sliv topliva - trebuetsia realizaciia")
end

function onFillWorldObjectContextMenu(player, context, worldObjects)
    debugPrint("Obrabotka kontekstnogo meniu...")
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    -- Ищем генератор
    local generator = nil
    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        if obj and obj.isActivated and obj.getFuel and obj.getMaxFuel then
            if isOldGenerator(obj) then
                generator = obj
                debugPrint("Naiden staryi generator")
                break
            end
        end
    end
    
    if not generator then
        debugPrint("Generator ne naiden")
        return
    end

    -- Проверяем, не активирован ли генератор
    if generator:isActivated() then
        debugPrint("Generator aktivirovan - ne pokazyvaem opcii")
        return
    end

    -- Проверяем, есть ли баллон в инвентаре
    local hasPropaneTank = false
    local inventory = playerObj:getInventory()
    
    for i = 1, inventory:getItems():size() do
        local item = inventory:getItems():get(i-1)
        if item and item:getType() == "PropaneTank" and item:getCurrentUses() > 0 then
            hasPropaneTank = true
            break
        end
    end

    -- Добавляем опцию заправки
    local optionText = "Zapravit propanom"
    local option = context:addOption(optionText, worldObjects, onAddPropaneToGenerator, generator, player)
    
    if not hasPropaneTank then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = "Net propanovogo ballona"
        option.toolTip = tooltip
        debugPrint("Opciia neaktivna - net ballona")
    else
        debugPrint("Opciia dobavlena i aktivna")
    end
    
    -- Добавляем опцию слива топлива
    if generator:getFuel() > 0 then
        local drainText = "Slit toplivo"
        context:addOption(drainText, worldObjects, onDrainFuel, generator, player)
    end
end

-- ====================================================================
-- РАЗДЕЛ 8: ИНИЦИАЛИЗАЦИЯ МОДА
-- ====================================================================

local function initializeMod()
    debugPrint("=================================================================")
    debugPrint("INICIALIZACIYa MODA PROPANE GENERATOR")
    debugPrint("=================================================================")
    debugPrint("Nastroiki moda:")
    debugPrint("  FUEL_PER_FULL_TANK: " .. FUEL_PER_FULL_TANK .. " edinic")
    debugPrint("  PROPANE_MIN_TO_KEEP: " .. (PROPANE_MIN_TO_KEEP * 100) .. "%")
    debugPrint("  EMPTY_TANK_THRESHOLD: " .. EMPTY_TANK_THRESHOLD)
    debugPrint("=================================================================")
    
    -- Инициализация UI
    overrideGeneratorWindow()
    
    -- Регистрируем обработчик контекстного меню
    Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
    
    debugPrint("MOD USPEShNO ZAGRUZhEN I GOTOV K RABOTE")
    debugPrint("=================================================================")
end

-- Регистрация событий
Events.OnGameStart.Add(initializeMod)
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

debugPrint("PropaneGeneratorMod.lua ZAGRUZhEN USPEShNO!")
debugPrint("Ozhidanie zapuska igry dlia polnoi inicializacii...")