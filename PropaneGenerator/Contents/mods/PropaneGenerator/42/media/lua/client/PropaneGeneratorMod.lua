-- ====================================================================
-- PropaneGeneratorMod.lua - Мод для заправки генератора пропаном
-- Версия: Стабильная (исправленная логика замены по проценту топлива)
-- Автоматическое восстановление подключения при замене
-- ====================================================================
require "TimedActions/ISBaseTimedAction"
require "PropaneGeneratorUtils"
require "PropaneGeneratorContext"  
require "PropaneGeneratorUI"       

-- ====================================================================
-- РАЗДЕЛ 1: НАСТРОЙКИ МОДА
-- ====================================================================

-- Эффективность пропанового баллона:
-- Сколько единиц топлива генератора дает один ПОЛНЫЙ баллон пропана?
local FUEL_PER_FULL_TANK = 50

-- Пороговые значения для смены типа генератора (в десятичных дробях):
-- Если в генераторе БОЛЬШЕ 70% пропана - становится пропановым
-- Если 70% или меньше - возвращается к бензину
local PROPANE_MIN_TO_KEEP = 0.70  -- 70%

-- Минимальный уровень в баллоне для проверки "пустоты"
local EMPTY_TANK_THRESHOLD = 0.001

-- Включить отладочные сообщения (true) или выключить (false)
local ENABLE_DEBUG_PRINTS = true

-- Названия типов предметов (должны совпадать с items.txt)
local GENERATOR_OLD = "Generator_Old"
local GENERATOR_PROPANE = "Generator_Old_Propane"

-- ====================================================================
-- РАЗДЕЛ 2: ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ====================================================================

-- Функция для вывода отладочных сообщений
local function debugPrint(message)
    if ENABLE_DEBUG_PRINTS then
        print("[PROPAN_MOD] " .. tostring(message))
    end
end

debugPrint("Zagruzka skripta PropaneGeneratorMod.lua...")

-- Получение типа генератора по спрайту (для проверки старого генератора)
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
    debugPrint("Imya spraita generatora: " .. tostring(spriteName))

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

-- Проверка, является ли генератор старым (бензиновым) по спрайту
local function isOldGenerator(generator)
    local genType = getGeneratorTypeBySprite(generator)
    local isOld = (genType == GENERATOR_OLD)

    debugPrint("Proverka starogo generatora: rezultat = " .. tostring(isOld))
    return isOld
end

-- Функция проверки типа генератора по ModData
-- Возвращает "propane" для пропанового, "gasoline" для бензинового
local function getGeneratorType(generator)
    if not generator then 
        debugPrint("Oshibka: generator = nil")
        return "unknown"
    end
    
    local modData = generator:getModData()
    
    -- Проверяем флаг в ModData
    if modData.isPropaneGenerator == true then
        return "propane"
    else
        return "gasoline"
    end
end

-- Функция для замены генератора на новый тип с сохранением всех параметров
local function replaceGeneratorWithNewType(oldGenerator, newGeneratorType, playerObj)
    if not oldGenerator or not oldGenerator:getSquare() then
        debugPrint("OSHIBKA: generator ili kvadrat ne sushestvuet")
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
    debugPrint(string.format("Staryj: toplivo=%.1f, sostoyanie=%d", currentFuel, currentCondition))
    debugPrint(string.format("Aktivirvan=%s, Podkluchen=%s", tostring(isActivated), tostring(isConnected)))

    -- Шаг 1: Создаём предмет нового генератора
    local newItem = instanceItem(newGeneratorType)
    if not newItem then
        debugPrint("OSHIBKA: ne udalos sozdat predmet " .. newGeneratorType)
        return nil
    end

    -- Копируем состояние из старого генератора
    if newItem.setCondition then
        newItem:setCondition(currentCondition)
        debugPrint("Sostoyanie skopirovano: " .. currentCondition)
    end

    -- Шаг 2: Удаляем старый генератор из мира
    debugPrint("Udalenie starogo generatora...")
    if square.transmitRemoveItemFromSquare then
        square:transmitRemoveItemFromSquare(oldGenerator)
        debugPrint("Staryj generator udalen")
    end

    -- Шаг 3: Создаём новый генератор в мире
    debugPrint("Sozdanie novogo generatora...")
    local newGenerator = IsoGenerator.new(newItem, cell, square)
    
    if not newGenerator then
        debugPrint("OSHIBKA: ne udalos sozdat novyj generator")
        return nil
    end

    -- Шаг 4: Восстанавливаем ВСЕ параметры
    newGenerator:setFuel(currentFuel)
    
    if isActivated and newGenerator.setActivated then
        newGenerator:setActivated(true)
        debugPrint("Aktivatsiya vosstanovlena")
    end
    
    if isConnected and playerObj and newGenerator.setConnected then
        newGenerator:setConnected(true)
        debugPrint("Podkluchenie vosstanovleno")
    end
    
    -- Шаг 5: Копируем ModData из старого генератора
    local newModData = newGenerator:getModData()
    for k, v in pairs(modData) do
        newModData[k] = v
    end
    
    -- Шаг 6: Устанавливаем правильный флаг в ModData
    newModData.isPropaneGenerator = (newGeneratorType == GENERATOR_PROPANE)
    
    -- Шаг 7: Синхронизируем изменения (важно для мультиплеера)
    if newGenerator.transmitCompleteItemToClients then
        newGenerator:transmitCompleteItemToClients()
        debugPrint("Sinhronizatsiya vypolnena")
    end

    debugPrint("=== ZAMENA ZAVERSHENA USPESHNO ===")
    debugPrint("Novyj tip: " .. newGeneratorType)
    return newGenerator
end

-- ====================================================================
-- РАЗДЕЛ 3: ОСНОВНОЙ КЛАСС ДЕЙСТВИЯ - ЗАПРАВКА ПРОПАНОМ
-- ====================================================================

ISAddPropaneToGenerator = ISBaseTimedAction:derive("ISAddPropaneToGenerator")

-- Метод получения длительности действия
function ISAddPropaneToGenerator:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 100
end

-- Конструктор класса
function ISAddPropaneToGenerator:new(character, generator, propaneTank)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    
    -- Сохраняем ссылки на объекты
    o.generator = generator
    o.propaneTank = propaneTank
    o.sound = nil
    
    debugPrint("Sozdano novoe deistvie dlya " .. character:getUsername())
    return o
end

-- Метод проверки возможности выполнения действия
function ISAddPropaneToGenerator:isValid()
    debugPrint("Proverka vozmozhnosti zapravki propanom...")

    -- Проверка 1: Генератор не должен быть полным
    if self.generator:getFuel() >= self.generator:getMaxFuel() then
        debugPrint("Generator polon - deistvie nevozmozhno")
        return false
    end

    -- Проверка 2: Генератор должен существовать в мире
    if not self.generator:getSquare() then
        debugPrint("Generator ne sushestvuet v mire")
        return false
    end

    -- Проверка 3: Генератор должен быть старым (бензиновым)
    if not isOldGenerator(self.generator) then
        debugPrint("Generator ne yavlyaetsya Generator_Old")
        return false
    end

    -- Проверка 4: Генератор не должен быть активирован
    if self.generator:isActivated() then
        debugPrint("Generator aktivirovan - zapravka nevozmozhna")
        return false
    end

    -- Проверка 5: Пропановый баллон должен быть в руках
    local hasTank = self.character:isPrimaryHandItem(self.propaneTank) or 
                    self.character:isSecondaryHandItem(self.propaneTank)

    debugPrint("Propanovyj ballon v rukah? - " .. tostring(hasTank))
    return hasTank
end

-- Метод ожидания начала действия
function ISAddPropaneToGenerator:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

-- Метод обновления во время выполнения
function ISAddPropaneToGenerator:update()
    -- Обновляем прогресс на баллоне для анимации
    if self.propaneTank and self.propaneTank.setJobDelta then
        self.propaneTank:setJobDelta(self:getJobDelta())
    end

    -- Поворачиваем персонажа к генератору
    self.character:faceThisObject(self.generator)

    -- Устанавливаем метаболическую цель
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

-- Метод начала действия
function ISAddPropaneToGenerator:start()
    debugPrint("Nachalo zapravki propanom, igrok: " .. self.character:getUsername())

    -- Устанавливаем анимацию
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")

    -- Настраиваем отображение прогресса на баллоне
    if self.propaneTank and self.propaneTank.setJobType then
        self.propaneTank:setJobType(getText("IGUI_PlayerText_Refueling"))
        self.propaneTank:setJobDelta(0.0)
    end

    -- Воспроизводим звук заправки
    self.sound = self.character:playSound("GeneratorAddFuel")
    debugPrint("Zvuk zapravki vosproizveden")
end

-- Метод остановки действия
function ISAddPropaneToGenerator:stop()
    debugPrint("Deistvie zapravki prervano")

    -- Останавливаем звук
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end

    -- Сбрасываем прогресс на баллоне
    if self.propaneTank and self.propaneTank.setJobDelta then
        self.propaneTank:setJobDelta(0.0)
    end

    -- Вызываем родительский метод
    ISBaseTimedAction.stop(self)
end

-- Метод выполнения
function ISAddPropaneToGenerator:perform()
    debugPrint("Deistvie zapravki vypolneno")

    -- Останавливаем звук
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end

    -- Сбрасываем прогресс на баллоне
    if self.propaneTank and self.propaneTank.setJobDelta then
        self.propaneTank:setJobDelta(0.0)
    end

    -- Вызываем родительский метод
    ISBaseTimedAction.perform(self)
end

-- ====================================================================
-- ОСНОВНАЯ ЛОГИКА ЗАПРАВКИ С ПРАВИЛЬНОЙ ПОСЛЕДОВАТЕЛЬНОСТЬЮ
-- ВАЖНО: Сначала проверяем процент пропана, потом меняем генератор, потом заправляем
-- ====================================================================
function ISAddPropaneToGenerator:complete()
    debugPrint("=== OSNOVNAIA LOGIKA ZAPRAVKI PROPANOM ===")

    -- Шаг 1: Получаем текущие значения ПЕРЕД заправкой
    local currentFuel = self.generator:getFuel()
    local maxFuel = self.generator:getMaxFuel()
    local currentTankPercent = self.propaneTank:getUsedDelta() or 1.0

    -- Шаг 2: Рассчитываем, сколько топлива МОЖНО добавить из баллона
    local availableFuelFromTank = currentTankPercent * FUEL_PER_FULL_TANK
    local freeSpace = maxFuel - currentFuel
    local fuelToTransfer = math.min(availableFuelFromTank, freeSpace)

    debugPrint(string.format("TEKUSHEE toplivo: %.1f", currentFuel))
    debugPrint(string.format("Mozhno dobavit: %.1f", fuelToTransfer))

    -- Шаг 3: ОПРЕДЕЛЯЕМ, сколько топлива БУДЕТ после заправки
    local fuelAfterRefuel = currentFuel + fuelToTransfer
    local propanePercentageAfter = fuelAfterRefuel / maxFuel

    debugPrint(string.format("BUDET posle zapravki: %.1f", fuelAfterRefuel))
    debugPrint(string.format("PROCENT propana posle: %.1f%%", propanePercentageAfter * 100))

    -- Шаг 4: ПРОВЕРКА ПЕРЕД ЗАПРАВКОЙ - определяем нужный тип генератора
    -- Это КЛЮЧЕВАЯ ЛОГИКА: проверяем какой процент пропана будет ПОСЛЕ заправки
    local needsPropaneGenerator = (propanePercentageAfter > PROPANE_MIN_TO_KEEP)
    local currentType = getGeneratorType(self.generator)
    local needsConversion = false
    local targetGeneratorType = nil
    
    -- Определяем, нужна ли замена типа генератора
    if needsPropaneGenerator and currentType ~= "propane" then
        debugPrint("RESHENIE: Nuzhen propanovyj generator (>70%)")
        needsConversion = true
        targetGeneratorType = GENERATOR_PROPANE
    elseif not needsPropaneGenerator and currentType ~= "gasoline" then
        debugPrint("RESHENIE: Nuzhen benzinovyj generator (<=70%)")
        needsConversion = true
        targetGeneratorType = GENERATOR_OLD
    else
        debugPrint("RESHENIE: Tip generatora ne menyaem")
    end

    -- Шаг 5: ЕСЛИ НУЖНА ЗАМЕНА - заменяем генератор ПЕРЕД заправкой
    local targetGenerator = self.generator
    if needsConversion and targetGeneratorType then
        debugPrint("VYPOLNYAEM ZAMENU GENERATORA...")
        local newGenerator = replaceGeneratorWithNewType(self.generator, targetGeneratorType, self.character)
        
        if newGenerator then
            targetGenerator = newGenerator
            debugPrint("Generator uspeshno zamenen")
        else
            debugPrint("OSHIBKA ZAMENY - prodolzhaem so starym generatorom")
        end
    end

    -- Шаг 6: ВЫПОЛНЯЕМ ЗАПРАВКУ в правильный генератор
    debugPrint("VYPOLNYAEM ZAPRAVKU...")
    
    -- Уменьшаем уровень в баллоне пропорционально использованному топливу
    local percentUsed = fuelToTransfer / FUEL_PER_FULL_TANK
    local newTankPercent = currentTankPercent - percentUsed

    if newTankPercent < EMPTY_TANK_THRESHOLD then
        newTankPercent = 0
        debugPrint("Ballon teper pustoi")
    end

    -- Обновляем уровень в баллоне (баллон остается в инвентаре даже когда пустой)
    self.propaneTank:setUsedDelta(newTankPercent)
    debugPrint(string.format("Novyi uroven v ballone: %.1f%%", newTankPercent * 100))

    -- Увеличиваем топливо в генераторе
    if targetGenerator and targetGenerator.setFuel then
        targetGenerator:setFuel(fuelAfterRefuel)
        debugPrint(string.format("Novyi uroven topliva v generatore: %.1f", fuelAfterRefuel))
        
        -- Обновляем ModData с правильным типом генератора
        local modData = targetGenerator:getModData()
        modData.isPropaneGenerator = needsPropaneGenerator
        debugPrint(string.format("ModData: isPropaneGenerator = %s", tostring(needsPropaneGenerator)))
    else
        debugPrint("OSHIBKA: Ne udalos zapravit generator")
    end

    -- Шаг 7: Если баллон пуст - оставляем его в инвентаре (не удаляем)
    if newTankPercent == 0 then
        debugPrint("Ballon pustoj, ostavlyaem v inventare")
        -- Баллон остается в инвентаре как пустой пропановый баллон
    end
    
    debugPrint("=== ZAPRAVKA ZAVERSHENA ===")
end

-- ====================================================================
-- РАЗДЕЛ 4: ОБРАБОТЧИКИ КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

-- Функция вызываемая при выборе опции в меню
function onAddPropaneToGenerator(worldObjects, generator, playerNum)
    debugPrint("Vyzyv iz kontekstnogo menyu: zapravka propanom")
    
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then
        debugPrint("Oshibka: igrok ne najden")
        return
    end
    
    -- Поиск пропанового баллона в руках
    local propaneTank = nil
    local primaryItem = playerObj:getPrimaryHandItem()
    local secondaryItem = playerObj:getSecondaryHandItem()
    
    if primaryItem and primaryItem:getType() == "PropaneTank" then
        if primaryItem:getCurrentUsesFloat() > 0 then
            propaneTank = primaryItem
            debugPrint("Ballon najden v osnovnoj ruke")
        end
    elseif secondaryItem and secondaryItem:getType() == "PropaneTank" then
        if secondaryItem:getCurrentUsesFloat() > 0 then
            propaneTank = secondaryItem
            debugPrint("Ballon najden vo vtoroj ruke")
        end
    end
    
    -- Проверка наличия баллона с топливом
    if not propaneTank then
        playerObj:Say(getText("IGUI_PlayerText_NeedPropaneTank"))
        debugPrint("Net podhodyashego ballona")
        return
    end
    
    -- Проверка заполненности генератора
    if generator:getFuel() >= generator:getMaxFuel() then
        playerObj:Say(getText("IGUI_PlayerText_GeneratorFull"))
        debugPrint("Generator uzhe polon")
        return
    end
    
    -- Проверка активации генератора
    if generator:isActivated() then
        playerObj:Say("Snachala vyklyuchite generator")
        debugPrint("Generator aktivirovan - zapravka nevozmozhna")
        return
    end
    
    -- Добавление действия в очередь
    debugPrint("Dobavlenie deistviya v ochered...")
    local action = ISAddPropaneToGenerator:new(playerObj, generator, propaneTank)
    ISTimedActionQueue.add(action)
end

-- Обработчик заполнения контекстного меню
function onFillWorldObjectContextMenu(player, context, worldObjects)
    debugPrint("Obrabotka kontekstnogo menyu...")
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj then
        debugPrint("Oshibka: igrok ne najden")
        return
    end
    
    -- Поиск генератора среди объектов
    local generator = nil
    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        if obj and obj.isActivated ~= nil and obj.getFuel ~= nil and obj.getMaxFuel ~= nil then
            generator = obj
            debugPrint("Generator najden")
            break
        end
    end
    
    if not generator then
        debugPrint("Generator ne najden sredi ob'ektov")
        return
    end
    
    -- Проверка типа генератора (только Generator_Old по спрайту)
    if not isOldGenerator(generator) then
        debugPrint("Eto ne Generator_Old")
        return
    end
    
    -- Проверка активации генератора (ВАЖНО!)
    if generator:isActivated() then
        debugPrint("Generator aktivirovan - ne pokazyvat' opciyu zapravki")
        return
    end
    
    -- Проверка заполненности генератора
    if generator:getFuel() >= generator:getMaxFuel() then
        debugPrint("Generator polon")
        return
    end
    
    -- Проверка наличия пропанового баллона в руках
    local hasPropaneTank = false
    local primaryItem = playerObj:getPrimaryHandItem()
    local secondaryItem = playerObj:getSecondaryHandItem()
    
    if (primaryItem and primaryItem:getType() == "PropaneTank" and 
        primaryItem:getCurrentUsesFloat() > 0) or
       (secondaryItem and secondaryItem:getType() == "PropaneTank" and 
        secondaryItem:getCurrentUsesFloat() > 0) then
        hasPropaneTank = true
        debugPrint("Propanovyj ballon v rukah najden")
    end
    
    -- Добавление опции в контекстное меню
    local optionText = getText("ContextMenu_GeneratorAddPropane")
    local option = context:addOption(optionText, worldObjects, onAddPropaneToGenerator, generator, player)
    
    -- Если нет баллона, делаем опцию неактивной
    if not hasPropaneTank then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_NeedPropaneTank")
        option.toolTip = tooltip
        debugPrint("Opciya sdelana neaktivnoj (net ballona)")
    else
        debugPrint("Opciya dobavlena i aktivna")
    end
end

-- ====================================================================
-- РАЗДЕЛ 5: ИНИЦИАЛИЗАЦИЯ МОДА
-- ====================================================================

-- Функция инициализации мода при старте игры
local function initializeMod()
    debugPrint("================================================")
    debugPrint("INICIALIZACIYA MODA PROPANE GENERATOR")
    debugPrint("================================================")
    debugPrint("Nastrojki moda:")
    debugPrint("  FUEL_PER_FULL_TANK: " .. FUEL_PER_FULL_TANK .. " edinic")
    debugPrint("  PROPANE_MIN_TO_KEEP: " .. (PROPANE_MIN_TO_KEEP * 100) .. "%")
    debugPrint("  EMPTY_TANK_THRESHOLD: " .. EMPTY_TANK_THRESHOLD)
    debugPrint("================================================")
    
    -- Регистрация обработчика контекстного меню
    Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
    
    debugPrint("MOD USPESHNO ZAGRUZHEN I GOTOV K RABOTE")
	-- Инициализация утилит
    if PropaneGenerator then
        debugPrint("Utility moda inicializirovany")
    end
end

-- Регистрация события инициализации
Events.OnGameStart.Add(initializeMod)

-- Регистрация обработчика меню (на случай если игра уже запущена)
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- Вывод сообщения о загрузке
debugPrint("PropaneGeneratorMod.lua ZAGRUZHEN USPESHNO!")
debugPrint("Ozhidanie zapuska igry dlya polnoj inicializacii...")
