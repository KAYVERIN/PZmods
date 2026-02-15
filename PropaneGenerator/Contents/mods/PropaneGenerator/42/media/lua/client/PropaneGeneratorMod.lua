-- ====================================================================
-- PropaneGeneratorMod.lua - Мод для заправки генератора пропаном
-- Версия: 5.2 (Оптимизация кода)
-- ====================================================================
require "PropaneGeneratorDebug"
require "PG_DrainFuel"
-- ====================================================================
-- РАЗДЕЛ 1: НАСТРОЙКИ МОДА
-- ====================================================================

-- Включить отладочные сообщения (true) или выключить (false)
ENABLE_DEBUG_PRINTS = true

-- Эффективность пропанового баллона:
-- Сколько единиц топлива генератора дает один ПОЛНЫЙ баллон пропана?
FUEL_PER_FULL_TANK = 50

-- Пороговые значения для смены типа генератора (в десятичных дробях):
-- Если в генераторе БОЛЬШЕ ИЛИ РАВНО 70% пропана - становится пропановым
-- Если в генераторе МЕНЬШЕ 70% пропана (т.е. БОЛЬШЕ 30% бензина) - становится бензиновым
PROPANE_THRESHOLD = 0.70  -- 70%

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
debugPrint("ZAGRUZKA PROPANE GENERATOR MOD - Versiya 5.2")
debugPrint("=================================================================")

-- ====================================================================
-- РАЗДЕЛ 3: PROPANE GENERATOR UTILS - ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ====================================================================
if ISWorldObjectContextMenu and not originalOnAddFuelGenerator then
    originalOnAddFuelGenerator = ISWorldObjectContextMenu.onAddFuelGenerator
end

PropaneGenerator = {}

-- Конфигурация мода (для доступа из других модулей)
PropaneGenerator.config = {
    FUEL_PER_FULL_TANK = FUEL_PER_FULL_TANK,
    PROPANE_THRESHOLD = PROPANE_THRESHOLD,
    EMPTY_TANK_THRESHOLD = EMPTY_TANK_THRESHOLD
}

-- Проверка, является ли генератор пропановым (ПО СПРАЙТУ!)
function PropaneGenerator.isPropaneGenerator(generator)
    if not generator then return false end
    local sprite = generator:getSprite()
    if not sprite then return false end
    local spriteName = sprite:getName()
    -- Пропановый генератор имеет спрайт 5
    return spriteName == "appliances_misc_01_5"
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
    local isPropane = false
    if self.generator then
        isPropane = PropaneGenerator.isPropaneGenerator(self.generator)
    end
    
    local generatorType = isPropane and "Propanovyi" or "Benzinovyi"
    
    if self then
        self.typeLabel = ISLabel:new(10, y, 20, generatorType, 1, 1, 1, 1, UIFont.Small, true)
        self:addChild(self.typeLabel)
        y = y + 25
        
        -- Преимущества пропанового генератора
        if isPropane then
            self.bonusLabel = ISLabel:new(10, y, 20, "Preimushchestva:", 0.8, 1, 0.8, 1, UIFont.Small, true)
            self:addChild(self.bonusLabel)
            y = y + 20
            
            self.bonus1 = ISLabel:new(20, y, 20, "- Menshe shuma (-40%)", 0.8, 1, 0.8, 1, UIFont.Small, true)
            self:addChild(self.bonus1)
            y = y + 18
            
            self.bonus2 = ISLabel:new(20, y, 20, "- Lomaetsia rezhe (+60%)", 0.8, 1, 0.8, 1, UIFont.Small, true)
            self:addChild(self.bonus2)
            y = y + 18
        else
            self.bonusLabel = nil
            self.bonus1 = nil
            self.bonus2 = nil
        end
    end
end

function PropaneGeneratorInfoWindow:render()
    -- Оригинальный рендер
    if self.originalRender then
        self.originalRender(self)
    end
    
    -- Обновляем тип генератора если он изменился
    if self.generator and self.typeLabel then
        local isPropane = PropaneGenerator.isPropaneGenerator(self.generator)
        
        local currentTitle = self.typeLabel.title
        local expectedTitle = isPropane and "Propanovyi" or "Benzinovyi"
        
        if currentTitle ~= expectedTitle then
            self.typeLabel.title = expectedTitle
            if isPropane then
                self.typeLabel:setColor(0.8, 1, 0.8)
            else
                self.typeLabel:setColor(1, 1, 1)
            end
            
            if self.bonusLabel then
                self.bonusLabel:setVisible(isPropane)
            end
            if self.bonus1 then
                self.bonus1:setVisible(isPropane)
            end
            if self.bonus2 then
                self.bonus2:setVisible(isPropane)
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
            
            -- Сохраняем generator в окне
            window.generator = generator
            
            return window
        end
        
        debugPrint("[UI] Pereopredelenie okna generatora vypolneno")
    end
end

-- ====================================================================
-- РАЗДЕЛ 5: ОСНОВНЫЕ ФУНКЦИИ МОДА
-- ====================================================================

require "TimedActions/ISBaseTimedAction"

-- Проверка, является ли генератор старым (бензиновым)
local function isOldGenerator(generator)
    return not PropaneGenerator.isPropaneGenerator(generator)
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
function replaceGeneratorWithNewType(oldGenerator, newGeneratorType, playerObj)
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
    
    -- Шаг 5: Копируем ModData (на всякий случай)
    local newModData = newGenerator:getModData()
    for k, v in pairs(modData) do
        newModData[k] = v
    end
    
    -- Шаг 6: Синхронизируем
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

-- Основная логика заправки пропаном
function ISAddPropaneToGenerator:complete()
    debugPrint("=== ZAPRAVKA PROPANOM ===")

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
    debugPrint(string.format("Dobavleno propana: %.1f", fuelToTransfer))

    -- Сколько топлива будет после заправки
    local fuelAfterRefuel = currentFuel + fuelToTransfer

    debugPrint(string.format("Toplivo posle: %.1f", fuelAfterRefuel))

    -- Уменьшаем уровень в баллоне
    local percentUsed = fuelToTransfer / FUEL_PER_FULL_TANK
    local newTankPercent = currentTankPercent - percentUsed

    if newTankPercent < EMPTY_TANK_THRESHOLD then
        newTankPercent = 0
        debugPrint("Ballon teper pustoy")
    end

    self.propaneTank:setUsedDelta(newTankPercent)
    debugPrint(string.format("Ballon: %.1f%%", newTankPercent * 100))

    -- Устанавливаем топливо в генератор
    self.generator:setFuel(fuelAfterRefuel)

    -- ЗАПРАВКА ПРОПАНОМ - генератор становится ПРОПАНОВЫМ
    local isPropane = PropaneGenerator.isPropaneGenerator(self.generator)
    
    if not isPropane then
        debugPrint(">>> ZAMENA: BENZINOVIY -> PROPANOVIY")
        local newGenerator = replaceGeneratorWithNewType(self.generator, GENERATOR_PROPANE, self.character)
        if newGenerator then
            newGenerator:setFuel(fuelAfterRefuel)
        end
    else
        debugPrint(">>> Generator uzhe propanovyy")
    end
    
    debugPrint("=== ZAPRAVKA PROPANOM ZAVERSHENA ===")
end
-- ====================================================================
-- ДЕЙСТВИЕ: Слив топлива из генератора
-- ====================================================================

ISDrainFuelGenerator = ISBaseTimedAction:derive("ISDrainFuelGenerator")

function ISDrainFuelGenerator:new(character, generator)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 80  -- чуть быстрее заправки
    
    o.generator = generator
    o.sound = nil
    
    debugPrint("Sozdano deystvie sliva topliva")
    return o
end

function ISDrainFuelGenerator:isValid()
    return self.generator and self.generator:getSquare() and self.generator:getFuel() > 0
end

function ISDrainFuelGenerator:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

function ISDrainFuelGenerator:update()
    self.character:faceThisObject(self.generator)
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function ISDrainFuelGenerator:start()
    debugPrint("Nachalo sliva topliva")
    
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    
    -- ЗВУК: используем существующий звук переливания
    self.sound = self.character:playSound("GeneratorAddFuel")
end

function ISDrainFuelGenerator:stop()
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function ISDrainFuelGenerator:perform()
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.perform(self)
end

function ISDrainFuelGenerator:complete()
    debugPrint("=== SLIV TOPLIVA ===")
    
    local drainedFuel = self.generator:getFuel()
    self.generator:setFuel(0)
    
    debugPrint(string.format("Slito %.1f edinic topliva", drainedFuel))
    debugPrint("=== SLIV ZAVERSHEN ===")
    
    return true
end

-- ====================================================================
-- РАЗДЕЛ 7: ОБРАБОТЧИКИ КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

function onDrainFuel(worldObjects, generator, playerNum)
    debugPrint("Sliv topliva iz generatora")
    local playerObj = getSpecificPlayer(playerNum)

    -- Создаем действие
    local action = ISDrainFuelGenerator:new(playerObj, generator)
    ISTimedActionQueue.add(action)
    debugPrint("Deystvie sliva dobavleno v ochered")
end

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


-- ====================================================================
-- Быстрая отладочная функция для проверки параметров генератора
-- ====================================================================
function debugGeneratorProperties(generator, action)
    if not generator then
        debugPrint("OSHIbKA: generator = nil")
        return
    end
    
    print("=== OTLADKA GENERATORA ===")
    print("Deystvie: " .. tostring(action))
    print("Tip: " .. tostring(generator:getType()))
    print("Sprait: " .. tostring(generator:getSprite() and generator:getSprite():getName()))
    
    -- Проверяем тип по спрайту
    local isPropane = PropaneGenerator.isPropaneGenerator(generator)
    print("Tip po spratu: " .. (isPropane and "PROPANOVIY" or "BENZINOVIY"))
    
    -- Проверяем другие параметры
    print("\n--- Tekushchee sostoyanie ---")
    print("Fuel: " .. tostring(generator:getFuel()))
    print("MaxFuel: " .. tostring(generator:getMaxFuel()))
    print("Condition: " .. tostring(generator:getCondition()))
    print("Activated: " .. tostring(generator:isActivated()))
    
    print("=============================\n")
end

-- ====================================================================
-- РАЗДЕЛ 8: ИНИЦИАЛИЗАЦИЯ МОДА
-- ====================================================================

local function initializeMod()
    -- Инициализация UI
    overrideGeneratorWindow()
end

-- Регистрация событий
Events.OnGameStart.Add(initializeMod)