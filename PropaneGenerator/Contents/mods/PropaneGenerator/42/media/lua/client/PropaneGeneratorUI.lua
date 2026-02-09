-- PropaneGeneratorUI.lua
-- Улучшенное UI окно для пропановых генераторов

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"

PropaneGeneratorInfoWindow = ISPanel:derive("PropaneGeneratorInfoWindow")

function PropaneGeneratorInfoWindow:createChildren()
    -- Вызываем оригинальный метод если он есть
    if self.originalCreateChildren then
        self.originalCreateChildren(self)
    end
    
    -- Добавляем наши элементы
    local y = 100  -- Позиция после оригинальных элементов
    
    -- Индикатор типа генератора
    local generatorType = "Benzinovyj"
    if self.generator and self.generator:getModData().isPropaneGenerator then
        generatorType = "Propanovyj"
    end
    
    self.typeLabel = ISLabel:new(10, y, 20, generatorType, 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.typeLabel)
    y = y + 25
    
    -- Преимущества пропанового генератора
    if generatorType == "Propanovyj" then
        self.bonusLabel = ISLabel:new(10, y, 20, "Preimushchestva:", 0.8, 1, 0.8, 1, UIFont.Small, true)
        self:addChild(self.bonusLabel)
        y = y + 20
        
        self.bonus1 = ISLabel:new(20, y, 20, "- Men'she shuma (-40%)", 0.8, 1, 0.8, 1, UIFont.Small, true)
        self:addChild(self.bonus1)
        y = y + 18
        
        self.bonus2 = ISLabel:new(20, y, 20, "- Lomaetsya redshe (+60%)", 0.8, 1, 0.8, 1, UIFont.Small, true)
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
        
        if isPropane and self.typeLabel.title ~= "Propanovyj" then
            self.typeLabel.title = "Propanovyj"
            self.typeLabel:setColor(0.8, 1, 0.8)
            
            -- Показываем бонусы
            if self.bonusLabel then
                self.bonusLabel:setVisible(true)
                self.bonus1:setVisible(true)
                self.bonus2:setVisible(true)
            end
        elseif not isPropane and self.typeLabel.title ~= "Benzinovyj" then
            self.typeLabel.title = "Benzinovyj"
            self.typeLabel:setColor(1, 1, 1)
            
            -- Скрываем бонусы
            if self.bonusLabel then
                self.bonusLabel:setVisible(false)
                self.bonus1:setVisible(false)
                self.bonus2:setVisible(false)
            end
        end
    end
end

-- Перехватываем создание окна генератора
local function overrideGeneratorWindow()
    debugPrint("Perexvat okna generatora")
    
    -- Сохраняем оригинальную функцию если она есть
    if ISGeneratorInfoWindow and not ISGeneratorInfoWindow.originalCreate then
        ISGeneratorInfoWindow.originalCreate = ISGeneratorInfoWindow.create
        ISGeneratorInfoWindow.originalCreateChildren = ISGeneratorInfoWindow.createChildren
        ISGeneratorInfoWindow.originalRender = ISGeneratorInfoWindow.render
        
        -- Переопределяем создание окна
        function ISGeneratorInfoWindow:create(x, y, width, height, generator)
            debugPrint("Sozdanie okna generatora s nashimi modifikaciyami")
            
            -- Вызываем оригинальный create
            local window = self.originalCreate(self, x, y, width, height, generator)
            
            -- Меняем класс на наш
            setmetatable(window, PropaneGeneratorInfoWindow)
            PropaneGeneratorInfoWindow.__index = PropaneGeneratorInfoWindow
            
            return window
        end
    end
end

-- Инициализация
local function initializeUI()
    debugPrint("Inicializaciya UI dlya propane generatora")
    overrideGeneratorWindow()
end

Events.OnGameStart.Add(initializeUI)
debugPrint("PropaneGeneratorUI.lua zagruzhen")
