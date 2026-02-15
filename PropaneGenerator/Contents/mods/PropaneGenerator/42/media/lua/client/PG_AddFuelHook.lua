-- ====================================================================
-- PG_AddFuelHook.lua - Перехват заправки бензином
-- Версия: 1.0 (простая логика)
-- ====================================================================

require "PropaneGeneratorMod"

local function debugPrint(message)
    if ENABLE_DEBUG_PRINTS then
        print("[PG_FUEL] " .. tostring(message))
    end
end

debugPrint("==========================================================")
debugPrint("ZAGRUZKA PEREHVATCHIKA ZAPRAVKI BENZINOM")
debugPrint("==========================================================")

-- Сохраняем оригинальную функцию
local originalISAddFuel_complete = ISAddFuel.complete

function ISAddFuel:complete()
    debugPrint("=== ZAPRAVKA BENZINOM (perekhvat) ===")
    
    local generator = self.generator
    local currentFuel = generator:getFuel()
    
    debugPrint(string.format("Toplivo DO: %.2f", currentFuel))
    
    -- Вызываем оригинальную функцию (сама заправка)
    local result = originalISAddFuel_complete(self)
    
    local newFuel = generator:getFuel()
    debugPrint(string.format("Toplivo POSLE: %.2f", newFuel))
    
    -- Если топливо не изменилось - выходим
    if math.abs(newFuel - currentFuel) < 0.01 then
        debugPrint("Toplivo ne izmenilos")
        return result
    end
    
    -- ЗАПРАВКА БЕНЗИНОМ - генератор становится БЕНЗИНОВЫМ
    local isPropane = PropaneGenerator.isPropaneGenerator(generator)
    
    if isPropane then
        debugPrint(">>> ZAMENA: PROPANOVIY -> BENZINOVIY")
        local newGenerator = replaceGeneratorWithNewType(generator, GENERATOR_OLD, self.character)
        if newGenerator then
            newGenerator:setFuel(newFuel)
        end
    else
        debugPrint(">>> Generator uzhe benzinovyy")
    end
    
    debugPrint("=== ZAPRAVKA BENZINOM ZAVERSHENA ===")
    return result
end

debugPrint("Perehvatchik ISAddFuel.complete ustanovlen")
debugPrint("PG_AddFuelHook.lua ZAGRUZhEN")
debugPrint("==========================================================")