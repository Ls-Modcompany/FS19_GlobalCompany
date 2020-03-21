--
-- GlobalCompany - Gui - DynamicStorage
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 04.06.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (04.06.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--      - some parts from productionFactory
--
-- ToDo:
--
--
--


Gc_Gui_AnimalFeederWarning = {}
Gc_Gui_AnimalFeederWarning.xmlFilename = g_company.dir .. "gui/objects/AnimalFeederWarning.xml"
Gc_Gui_AnimalFeederWarning.debugIndex = g_company.debug:registerScriptName("Gc_Gui_AnimalFeederWarning")

local Gc_Gui_AnimalFeederWarning_mt = Class(Gc_Gui_AnimalFeederWarning)

function Gc_Gui_AnimalFeederWarning:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_AnimalFeederWarning_mt
    end
    local self = setmetatable({}, Gc_Gui_AnimalFeederWarning_mt);		
    
    self.warnings = {}
    self.warningCount = 0
    
    g_company.addRaisedUpdateable(self)

	return self
end

function Gc_Gui_AnimalFeederWarning:onOpen() 
    if g_company.gui.devVersion then
        self:setOnGui()
    end
end
function Gc_Gui_AnimalFeederWarning:onClose() end
function Gc_Gui_AnimalFeederWarning:onCreate() end
function Gc_Gui_AnimalFeederWarning:setData() end
function Gc_Gui_AnimalFeederWarning:keyEvent(unicode, sym, modifier, isDown, eventUsed) end

function Gc_Gui_AnimalFeederWarning:update(dt) 
    for _,warning in pairs(self.warnings) do
        warning.time = warning.time + dt
        if warning.time >= 120000 then -- 5 minutes
            self:removeWarning(warning.id)  
            break
        end
        self:raiseUpdate()
    end
end

function Gc_Gui_AnimalFeederWarning:addWarning(text, header)  
    self.warningCount = self.warningCount + 1  
    local warningText = string.format("(%02.f:%02.f) %s", g_currentMission.environment.currentHour, g_currentMission.environment.currentMinute, text)
    table.insert(self.warnings, {warningText=warningText, header=header, id=self.warningCount, time=0})
    self:setOnGui()         
    self:raiseUpdate()
end

function Gc_Gui_AnimalFeederWarning:removeWarning(id)  
    local toRemove
    for k,warning in pairs(self.warnings) do
        if warning.id == id then
            toRemove = k
        end
    end
    if toRemove ~= nil then
        table.remove(self.warnings, toRemove)
    end

    if g_company.utils.getTableLength(self.warnings) == 0 then
        g_company.animalFeederWarningGui = nil
        g_company.gui:closeGui("gc_animalFeederWarning");
    else
        self:setOnGui()
    end
end

function Gc_Gui_AnimalFeederWarning:setOnGui()    
    local index = 1
    local num = g_company.utils.getTableLength(self.warnings)

    for i=num, num -2, -1 do
        if self.warnings[i] ~= nil then
            self["gui_text" .. tostring(index)]:setVisible(true)
            self["gui_header" .. tostring(i)]:setVisible(true)
            self["gui_text" .. tostring(index)]:setText(self.warnings[i].warningText)
            self["gui_header" .. tostring(index)]:setText(self.warnings[i].header)
            index = index + 1
        end
    end

    for i = num + 1, 3 do
        self["gui_text" .. tostring(i)]:setVisible(false)
        self["gui_header" .. tostring(i)]:setVisible(false)
    end

    self.gui_header:setText(string.format(g_company.languageManager:getText("GC_animalFeeder_gui_warningHeader"), num))
end