--
-- GlobalCompany - Gui - PlaceableDigitalDisplay
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.10.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (19.10.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
-- ToDo:
--

Gc_Gui_PlaceableDigitalDisplay = {}
Gc_Gui_PlaceableDigitalDisplay.xmlFilename = g_company.dir .. "gui/objects/PlaceableDigitalDisplay.xml"
Gc_Gui_PlaceableDigitalDisplay.debugIndex = g_company.debug:registerScriptName("Gc_Gui_PlaceableDigitalDisplay")

local Gc_Gui_PlaceableDigitalDisplay_mt = Class(Gc_Gui_PlaceableDigitalDisplay)

function Gc_Gui_PlaceableDigitalDisplay:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_PlaceableDigitalDisplay_mt
    end
	local self = setmetatable({}, Gc_Gui_PlaceableDigitalDisplay_mt)			
	return self
end

function Gc_Gui_PlaceableDigitalDisplay:onOpen()
    g_depthOfFieldManager:setBlurState(true)
end

function Gc_Gui_PlaceableDigitalDisplay:onClose() 
    g_depthOfFieldManager:setBlurState(false)
end

function Gc_Gui_PlaceableDigitalDisplay:onCreate() end

function Gc_Gui_PlaceableDigitalDisplay:keyEvent(unicode, sym, modifier, isDown, eventUsed)
     
end

function Gc_Gui_PlaceableDigitalDisplay:setCloseCallback(target, func) 
    self.closeCallback = {target=target, func=func}
end

function Gc_Gui_PlaceableDigitalDisplay:setData(placeableObject)
    self.placeableObject = placeableObject    
    for i=1, 8 do
        self[string.format("gui_input%s", i)]:setVisible(placeableObject.lineNums >= i)
        if self.placeableObject.lineNums >= i then
            if placeableObject.screenTexts[i] == nil then
                self[string.format("gui_input%s", i)].textElement:setText("")
            else
                self[string.format("gui_input%s", i)].textElement:setText(placeableObject.screenTexts[i])
            end
        end
    end    
end

function Gc_Gui_PlaceableDigitalDisplay:onClickClose() 
	g_company.gui:closeActiveGui()
end

function Gc_Gui_PlaceableDigitalDisplay:onClickSave() 
    local texts = {}
    for i=1, self.placeableObject.lineNums do
        texts[i] = self[string.format("gui_input%s", i)].textElement.text
    end
    self.placeableObject:setScreenTexts(texts, true)
	g_company.gui:closeActiveGui()
end

function Gc_Gui_PlaceableDigitalDisplay:onClickInput(input, parameter)
    for i=1, self.placeableObject.lineNums do
        if i ~= tonumber(parameter) then
            self[string.format("gui_input%s", i)].buttonElement:setActive(false)
        end
    end
end