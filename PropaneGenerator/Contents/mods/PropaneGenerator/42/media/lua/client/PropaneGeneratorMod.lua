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
if ISWorldObjectContextMenu and not originalOnAddFuelGenerator then
    originalOnAddFuelGenerator = ISWorldObjectContextMenu.onAddFuelGenerator
end

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
-- РАЗДЕЛ ОТЛАДКА
-- ====================================================================
-- Быстрая отладочная функция для проверки параметров генератора
function debugGeneratorProperties(generator, action)
    if not generator then
        debugPrint("OSHIbKA: generator = nil")
        return
    end
    
    print("=== OTLADKA GENERATORA ===")
    print("Deystvie: " .. tostring(action))
    print("Tip: " .. tostring(generator:getType()))
    print("Sprait: " .. tostring(generator:getSprite() and generator:getSprite():getName()))
    
    -- Proveryaem ModData
    local modData = generator:getModData()
    print("ModData.isPropaneGenerator: " .. tostring(modData.isPropaneGenerator))
    
    -- Proveryaem parametry iz items.txt
    print("\n--- Parametry iz items.txt ---")
    print("Dolzhny byt (dlya propanovogo):")
    print("- SoundRadius = 15")
    print("- ConditionLowerChanceOneIn = 40")
    
    -- Proveryaem, kakie metody est u generatora
    print("\n--- Dostupnye metody ---")
    if generator.getSoundRadius then
        local soundRadius = generator:getSoundRadius()
        print("getSoundRadius(): " .. tostring(soundRadius))
    else
        print("Metod getSoundRadius() otsutstvuet")
    end
    
    if generator.getConditionLowerChance then
        local conditionChance = generator:getConditionLowerChance()
        print("getConditionLowerChance(): " .. tostring(conditionChance))
    else
        print("Metod getConditionLowerChance() otsutstvuet")
    end
    
    -- Proveryaem drugie poleznye parametry
    print("\n--- Tekushchee sostoyanie ---")
    print("Fuel: " .. tostring(generator:getFuel()))
    print("MaxFuel: " .. tostring(generator:getMaxFuel()))
    print("Condition: " .. tostring(generator:getCondition()))
    print("Activated: " .. tostring(generator:isActivated()))
    
    print("=============================\n")
end


--------------------------------------------------------------
--------------------------------------------------------------

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
    generator:setFuel(0)
end

-- ====================================================================
-- ПЕРЕХВАТ ЗАПРАВКИ БЕНЗИНОМ (ФИНАЛЬНАЯ ВЕРСИЯ)
-- ====================================================================

-- Сохраняем оригинальную функцию заправки
local originalOnAddFuelGenerator = ISWorldObjectContextMenu.onAddFuelGenerator

-- Наша функция-перехватчик (точные параметры из ванильного кода)
local function onAddFuelGeneratorInterceptor(worldobjects, petrolCan, generator, player, context)
    debugPrint("=== PEREHVAT ZAPRAVKI BENZINOM ===")
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj or not generator then return end
    
    -- Проверяем, является ли генератор пропановым
    local isPropane = PropaneGenerator.isPropaneGenerator(generator)
    debugPrint("Generator propanoviy: " .. tostring(isPropane))
    
    if isPropane then
        -- Это пропановый генератор - делаем свои расчеты
        debugPrint("Propanoviy generator - zapravka benzinom!")
        
        -- Проверяем, выключен ли генератор
        if generator:isActivated() then
            playerObj:Say("Snachala vyklyuchite generator!")
            debugPrint("Generator vklyuchen - zapravka nevozmozhna")
            return
        end
        
        -- Получаем текущее топливо генератора
        local currentFuel = generator:getFuel()
        local maxFuel = generator:getMaxFuel()
        
        -- Получаем количество топлива в канистре
        local fluidAmount = 0
        if petrolCan and petrolCan.getFluidContainer then
            local fluidContainer = petrolCan:getFluidContainer()
            if fluidContainer then
                fluidAmount = fluidContainer:getAmount()
                debugPrint("Kolichestvo benzina v kanistre: " .. tostring(fluidAmount))
            end
        end
        
        -- Сколько топлива МАКСИМАЛЬНО может быть добавлено (если использовать всю канистру)
        local maxFuelToAdd = math.min(fluidAmount, maxFuel - currentFuel)
        
        -- Новый уровень топлива после заправки ВСЕЙ канистры
        local newFuel = currentFuel + maxFuelToAdd
        local propanePercentage = newFuel / maxFuel
        
        debugPrint(string.format("Tekushchee toplivo: %.1f", currentFuel))
        debugPrint(string.format("Max mozhno dobavit: %.1f", maxFuelToAdd))
        debugPrint(string.format("Max budet posle: %.1f", newFuel))
        debugPrint(string.format("Procent PROPANA: %.1f%%", propanePercentage * 100))
        
        -- Проверяем порог: если после ИСПОЛЬЗОВАНИЯ ВСЕЙ канистры пропана станет ≤70%
        if maxFuelToAdd > 0 and propanePercentage <= PROPANE_MIN_TO_KEEP then
            debugPrint("POSLE ZAPRAVKI VSey KANISTROY PROPAN ≤70%! MENYaEM GENERATOR ZARANEE")
            
            -- Запоминаем, что генератор нужно заменить
            local shouldReplace = true
            local fuelAfterReplace = currentFuel -- пока не меняем
            
            -- Создаем бензиновый генератор
            local newGenerator = replaceGeneratorWithNewType(generator, GENERATOR_OLD, playerObj)
            
            if newGenerator then
                -- Устанавливаем текущее топливо (без изменений)
                newGenerator:setFuel(currentFuel)
                
                -- Обновляем ModData
                local modData = newGenerator:getModData()
                modData.isPropaneGenerator = false
                
                debugPrint("Generator zamenen na benzinoviy, zapuskaem zapravku")
                
                -- Запускаем оригинальную функцию заправки для НОВОГО генератора
                if originalOnAddFuelGenerator then
                    originalOnAddFuelGenerator(worldobjects, petrolCan, newGenerator, player, context)
                end
            end
        else
            debugPrint("Propan ostaetsya >70% - zapuskaem obychmuyu zapravku")
            
            -- Просто запускаем оригинальную функцию
            if originalOnAddFuelGenerator then
                originalOnAddFuelGenerator(worldobjects, petrolCan, generator, player, context)
            end
        end
    else
        -- Обычный бензиновый генератор - просто вызываем оригинал
        debugPrint("Obychniy generator - vyzyvaem originalnuyu funkciyu")
        if originalOnAddFuelGenerator then
            originalOnAddFuelGenerator(worldobjects, petrolCan, generator, player, context)
        end
    end
    
    debugPrint("=== PEREHVAT ZAPRAVKI BENZINOM ZAVERShEN ===")
end

-- Переопределяем функцию в ISWorldObjectContextMenu
ISWorldObjectContextMenu.onAddFuelGenerator = onAddFuelGeneratorInterceptor

debugPrint("Perehvatchik zapravki benzinom ustanovlen (finalnaya versiya)")


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
    
    
    debugPrint("MOD USPEShNO ZAGRUZhEN I GOTOV K RABOTE")
    debugPrint("=================================================================")
end

-- Регистрация событий
Events.OnGameStart.Add(initializeMod)

debugPrint("PropaneGeneratorMod.lua ZAGRUZhEN USPEShNO!")
debugPrint("Ozhidanie zapuska igry dlia polnoi inicializacii...")