-- ====================================================================
-- PG_DrainFuel.lua - Слив топлива из генераторов
-- Версия: 1.0
-- ====================================================================

require "PropaneGeneratorMod"

local function debugPrint(message)
    if ENABLE_DEBUG_PRINTS then
        print("[PG_DRAIN] " .. tostring(message))
    end
end

debugPrint("==========================================================")
debugPrint("ZAGRUZKA MODULYa SLIVA TOPLIVA")
debugPrint("==========================================================")

-- ====================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ====================================================================

local HOSE_ITEMS = {
    "Base.RubberHose",
}

local function hasHoseInInventory(character)
    if not character then return false end
    local inv = character:getInventory()
    for _, hoseType in ipairs(HOSE_ITEMS) do
        if inv:contains(hoseType) then
            return true
        end
    end
    return false
end

-- ====================================================================
-- ДЕЙСТВИЕ: Слив бензина (с бензинового генератора)
-- ====================================================================

ISDrainGasoline = ISBaseTimedAction:derive("ISDrainGasoline")

function ISDrainGasoline:new(character, generator)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 120  -- дольше, нужно возиться со шлангом
    
    o.generator = generator
    o.sound = nil
    
    debugPrint("Sozdano deystvie sliva benzina")
    return o
end

function ISDrainGasoline:isValid()
    if not self.generator or not self.generator:getSquare() then return false end
    if self.generator:getFuel() <= 0 then return false end
    if self.generator:isActivated() then return false end
    -- Проверяем, что это бензиновый генератор
    if PropaneGenerator.isPropaneGenerator(self.generator) then return false end
    -- Проверяем наличие шланга
    if not hasHoseInInventory(self.character) then return false end
    return true
end

function ISDrainGasoline:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

function ISDrainGasoline:update()
    self.character:faceThisObject(self.generator)
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function ISDrainGasoline:start()
    debugPrint("Nachalo sliva benzina")
    
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    
    -- Звук переливания жидкости
    self.sound = self.character:playSound("TakeWater")
end

function ISDrainGasoline:stop()
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function ISDrainGasoline:perform()
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.perform(self)
end

function ISDrainGasoline:complete()
    debugPrint("=== SLIV BENZINA ===")
    
    local drainedFuel = self.generator:getFuel()
    self.generator:setFuel(0)
    
    -- Шланг имеет шанс сломаться
    if ZombRand(10) == 0 then  -- 10% шанс
        debugPrint("Shlan porvalsya!")
        self.character:Say(getText("IGUI_Propane_HoseBroke"))
    end
    
    debugPrint(string.format("Slito %.1f edinic benzina na zemlyu", drainedFuel))
    debugPrint("=== SLIV BENZINA ZAVERSHEN ===")
    
    return true
end

-- ====================================================================
-- ДЕЙСТВИЕ: Спуск газа (с пропанового генератора)
-- ====================================================================

ISDrainPropane = ISBaseTimedAction:derive("ISDrainPropane")

function ISDrainPropane:new(character, generator)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 60  -- быстрее, просто вентиль открыть
    
    o.generator = generator
    o.sound = nil
    
    debugPrint("Sozdano deystvie spuska gaza")
    return o
end

function ISDrainPropane:isValid()
    if not self.generator or not self.generator:getSquare() then return false end
    if self.generator:getFuel() <= 0 then return false end
    if self.generator:isActivated() then return false end
    -- Проверяем, что это пропановый генератор
    if not PropaneGenerator.isPropaneGenerator(self.generator) then return false end
    return true
end

function ISDrainPropane:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

function ISDrainPropane:update()
    self.character:faceThisObject(self.generator)
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function ISDrainPropane:start()
    debugPrint("Nachalo spuska gaza")
    
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    
    -- Звук газа (шипение)
    self.sound = self.character:playSound("GasLeak")
end

function ISDrainPropane:stop()
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function ISDrainPropane:perform()
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.perform(self)
end

function ISDrainPropane:complete()
    debugPrint("=== SPUSK GAZA ===")
    
    local drainedFuel = self.generator:getFuel()
    self.generator:setFuel(0)
    
    debugPrint(string.format("Spushcheno %.1f edinic gaza v vozduh", drainedFuel))
    debugPrint("=== SPUSK GAZA ZAVERSHEN ===")
    
    return true
end

-- ====================================================================
-- ОБРАБОТЧИКИ КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

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
    
    -- Проверка 1: Можно ли подойти
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        tooltip.description = "Ne mogu podoyti k generatoru"
        option.toolTip = tooltip
        return option
    end
    
    -- Проверка 2: Выключен ли генератор
    if generator:isActivated() then
        option.notAvailable = true
        tooltip.description = "Generator vklyuchen - snachala vyklyuchite"
        option.toolTip = tooltip
        return option
    end
    
    -- Проверка 3: Есть ли топливо
    if generator:getFuel() <= 0 then
        option.notAvailable = true
        tooltip.description = "V generatore net benzina"
        option.toolTip = tooltip
        return option
    end
    
    -- Проверка 4: Есть ли шланг
    if not hasHoseInInventory(playerObj) then
        option.notAvailable = true
        tooltip.description = "Nuzhen shlang"
        option.toolTip = tooltip
        return option
    end
    
    -- Все проверки пройдены
    tooltip.description = "Slivaet benzin na zemlyu. Shlang mozhet porvatsya (10% shans)."
    option.toolTip = tooltip
    debugPrint("Opciya sliva benzina dobavlena")
    return option
end

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
    
    -- Проверка 1: Можно ли подойти
    if not luautils.walkAdj(playerObj, generator:getSquare()) then
        option.notAvailable = true
        tooltip.description = "Ne mogu podoyti k generatoru"
        option.toolTip = tooltip
        return option
    end
    
    -- Проверка 2: Выключен ли генератор
    if generator:isActivated() then
        option.notAvailable = true
        tooltip.description = "Generator vklyuchen - snachala vyklyuchite"
        option.toolTip = tooltip
        return option
    end
    
    -- Проверка 3: Есть ли газ
    if generator:getFuel() <= 0 then
        option.notAvailable = true
        tooltip.description = "V generatore net gaza"
        option.toolTip = tooltip
        return option
    end
    
    -- Все проверки пройдены
    tooltip.description = "Vypuskaet gaz v atmosferu."
    option.toolTip = tooltip
    debugPrint("Opciya spuska gaza dobavlena")
    return option
end

-- ====================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ====================================================================

local function initializeDrainModule()
    debugPrint("Inicializaciya modulya sliva topliva")
    debugPrint("Modul sliva topliva inicializirovan")
end

Events.OnGameStart.Add(initializeDrainModule)

debugPrint("PG_DrainFuel.lua ZAGRUZhEN")
debugPrint("==========================================================")