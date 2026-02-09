local AxeTreeXP = {}

AxeTreeXP.Config = {
    EnableAxeXP = true,           -- Включает/выключает получение опыта для навыка Топор
    EnableStrengthXP = true,      -- Включает/выключает получение опыта для навыка Сила
    EnableFitnessXP = true,       -- Включает/выключает получение опыта для навыка Фитнес
    BaseAxeXP = 12,               -- Базовое количество опыта для навыка Топор (без учета множителя уровня)
    BaseStrengthXP = 8,           -- Базовое количество опыта для навыка Сила (без учета множителя уровня)
    BaseFitnessXP = 4,            -- Базовое количество опыта для навыка Фитнес (без учета множителя уровня)
    MultiplierPerLevel = 0.75,    -- Базовый множитель опыта за каждый уровень навыка
}

local function calculateXP(level, baseXP, multiplier)
    local adjustedMultiplier = multiplier
    
    if level >= 3 then
        local extraLevels = level - 2
        adjustedMultiplier = multiplier + (extraLevels * 0.15)
    end
    
    return math.max(1, math.floor(baseXP * (1 + (level * adjustedMultiplier))))
end

local function giveTreeChoppingXP(character, tree)
    if not character or not tree then
        return
    end

    local axeLevel = character:getPerkLevel(Perks.Axe)
    local strengthLevel = character:getPerkLevel(Perks.Strength)
    local fitnessLevel = character:getPerkLevel(Perks.Fitness)
    
    local axeXP = calculateXP(axeLevel, AxeTreeXP.Config.BaseAxeXP, AxeTreeXP.Config.MultiplierPerLevel)
    local strengthXP = calculateXP(strengthLevel, AxeTreeXP.Config.BaseStrengthXP, AxeTreeXP.Config.MultiplierPerLevel)
    local fitnessXP = calculateXP(fitnessLevel, AxeTreeXP.Config.BaseFitnessXP, AxeTreeXP.Config.MultiplierPerLevel)
    
    if AxeTreeXP.Config.EnableAxeXP and axeXP > 0 then
        addXp(character, Perks.Axe, axeXP)
    end
    
    if AxeTreeXP.Config.EnableStrengthXP and strengthXP > 0 then
        addXp(character, Perks.Strength, strengthXP)
    end
    
    if AxeTreeXP.Config.EnableFitnessXP and fitnessXP > 0 then
        addXp(character, Perks.Fitness, fitnessXP)
    end
end

local originalComplete = ISChopTreeAction.complete
function ISChopTreeAction:complete()
    originalComplete(self)
    
    local tree = rawget(self, 'tree')
    local character = rawget(self, 'character')

    if not tree or not character then
        return
    end

    giveTreeChoppingXP(character, tree)
end

local originalStop = ISChopTreeAction.stop
function ISChopTreeAction:stop()
    originalStop(self)

    local tree = rawget(self, 'tree')
    local character = rawget(self, 'character')

    if not tree or not character then
        return
    end

    local ok, idx = pcall(function()
        return tree:getObjectIndex()
    end)

    if ok and idx == -1 then
        giveTreeChoppingXP(character, tree)
    end
end