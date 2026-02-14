-- ====================================================================
-- PropaneGeneratorPlacement.lua - МАКСИМАЛЬНО УПРОЩЕННАЯ ВЕРСИЯ
-- ====================================================================

if isClient() then return end

require "PropaneGeneratorMod"

local function debugPrint(message)
    if ENABLE_DEBUG_PRINTS then
        print("[PLACEMENT] " .. tostring(message))
    end
end

debugPrint("==========================================================")
debugPrint("ZAGRUZKA MODULYa RAZMESHCHENIYa GENERATOROV")
debugPrint("==========================================================")

-- ====================================================================
-- СОХРАНЯЕМ ОРИГИНАЛЬНЫЕ ФУНКЦИИ
-- ====================================================================

local originalTransferPerform = ISInventoryTransferAction.perform
local originalUnequipPerform = ISUnequipAction.perform

-- ====================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ====================================================================

local function isGeneratorItem(item)
    if not item then return false end
    local itemType = item:getType()
    return (itemType == GENERATOR_OLD or itemType == GENERATOR_PROPANE)
end

local function setGeneratorType(item)
    if not item then return end
    
    local isPropane = (item:getType() == GENERATOR_PROPANE) or 
                      (item:getModData().isPropaneGenerator == true)
    
    debugPrint("Ustanovka tipa generatora v ModData")
    debugPrint("Tip: " .. (isPropane and "PROPANOVIY" or "BENZINOVIY"))
    
    -- Просто устанавливаем тип в ModData предмета
    -- Этот предмет САМ станет объектом в мире
    local modData = item:getModData()
    modData.isPropaneGenerator = isPropane
    modData.generatorFullType = isPropane and GENERATOR_PROPANE or GENERATOR_OLD
end

-- ====================================================================
-- ПЕРЕХВАТ ISInventoryTransferAction (Drag & Drop)
-- ====================================================================

function ISInventoryTransferAction:perform()
    -- Проверяем, генератор ли это и кладется ли на пол
    if self.item and isGeneratorItem(self.item) and 
       self.destContainer and self.destContainer:getType() == "floor" then
        
        debugPrint("=== GENERATOR NA POL (drag & drop) ===")
        -- Устанавливаем тип прямо в ModData предмета
        setGeneratorType(self.item)
    end
    
    -- Вызываем оригинал - он положит предмет на пол
    return originalTransferPerform(self)
end

-- ====================================================================
-- ПЕРЕХВАТ ISUnequipAction (Place из рук)
-- ====================================================================

function ISUnequipAction:perform()
    -- Проверяем, генератор ли это
    if self.item and isGeneratorItem(self.item) then
        debugPrint("=== GENERATOR IZ RUK (place) ===")
        -- Устанавливаем тип прямо в ModData предмета
        setGeneratorType(self.item)
    end
    
    return originalUnequipPerform(self)
end

-- ====================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ====================================================================

local function initializePlacement()
    debugPrint("==========================================================")
    debugPrint("MODUL RAZMESHCHENIYa ZAGRUZhEN")
    debugPrint("Perekhvatyvaetsya:")
    debugPrint("  - Drag & drop na pol (ISInventoryTransferAction)")
    debugPrint("  - Place iz ruk (ISUnequipAction)")
    debugPrint("==========================================================")
end

Events.OnGameStart.Add(initializePlacement)

debugPrint("PropaneGeneratorPlacement.lua ZAGRUZhEN")
debugPrint("==========================================================")