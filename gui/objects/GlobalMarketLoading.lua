--
-- GlobalCompany - Gui - GlobalMarketLoading
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 01.02.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (01.02.2020):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
-- ToDo:
--

Gc_Gui_GlobalMarketLoading = {}
Gc_Gui_GlobalMarketLoading.xmlFilename = g_company.dir .. "gui/objects/GlobalMarketLoading.xml"
Gc_Gui_GlobalMarketLoading.debugIndex = g_company.debug:registerScriptName("Gc_Gui_GlobalMarketLoading")

local Gc_Gui_GlobalMarketLoading_mt = Class(Gc_Gui_GlobalMarketLoading)

function Gc_Gui_GlobalMarketLoading:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_GlobalMarketLoading_mt
    end
    local self = setmetatable({}, Gc_Gui_GlobalMarketLoading_mt)	
        
	return self
end

function Gc_Gui_GlobalMarketLoading:onOpen()
    g_depthOfFieldManager:setBlurState(true)
    
    local fillTypeIndex = self:loadTable()

    if fillTypeIndex ~= nil then
        self.market:onSetSelectedFillTypeIndex(self.trigger, fillTypeIndex) 
        if self.closeCallback ~= nil then
            self.closeCallback.func(self.closeCallback.target);
        end;
        g_company.gui:closeActiveGui();
    end

    self.gui_btn_loading:setVisible(false)
    self.gui_btn_loadingText:setVisible(false)  
end

function Gc_Gui_GlobalMarketLoading:onClose() 
    g_depthOfFieldManager:setBlurState(false)
end

function Gc_Gui_GlobalMarketLoading:onCreate() end

function Gc_Gui_GlobalMarketLoading:keyEvent(unicode, sym, modifier, isDown, eventUsed)
    if sym == 13 then
        self:onClickLoading()
    end
end

function Gc_Gui_GlobalMarketLoading:setCloseCallback(target, func) 
    self.closeCallback = {target=target, func=func}
end

function Gc_Gui_GlobalMarketLoading:setData(market, trigger)
    self.market = market       
    self.trigger = trigger
end

function Gc_Gui_GlobalMarketLoading:onClickClose() 
	g_company.gui:closeActiveGui()
end

function Gc_Gui_GlobalMarketLoading:onClickStorageItem(element) 
    self.currentSelectedItem = element    
    self.gui_btn_loading:setVisible(true)
    self.gui_btn_loadingText:setVisible(true)  
end

function Gc_Gui_GlobalMarketLoading:loadTable() 
    local items = {}
	self.gui_table_storage:removeElements()
    local farmId = g_currentMission:getFarmId()
    for fillTypeIndex, levels in pairs(self.market.fillLevels) do
        
        local triggerAllow = self.trigger.validFillableObject:getFillUnitAllowsFillType(self.trigger.validFillableFillUnitIndex, fillTypeIndex)      
        local isForTriggerAvailable = g_company.globalMarket:getIsFillTypeFromType(fillTypeIndex, self.trigger.extraParamater)      

        if levels[farmId] > 0 and triggerAllow and isForTriggerAvailable then
            self.currentFillTypeIndex = fillTypeIndex
            self.currentFillLevel = levels[farmId]
            local item = self.gui_table_storage:createItem()
            item.fillTypeIndex = fillTypeIndex
            self.currentFillTypeIndex = nil
            self.currentFillLevel = nil
            table.insert(items, item)
        end
    end
    if g_company.utils.getTableLength(items) == 1 then
        return items[1].fillTypeIndex
    end
end

function Gc_Gui_GlobalMarketLoading:onClickLoading()    
    self.market:onSetSelectedFillTypeIndex(self.trigger, self.currentSelectedItem.fillTypeIndex) 
    if self.closeCallback ~= nil then
        self.closeCallback.func(self.closeCallback.target, self.trigger);
    end;
    g_company.gui:closeActiveGui();
end

function Gc_Gui_GlobalMarketLoading:onCreateCol1(element)
    if self.currentFillTypeIndex ~= nil and self.currentFillLevel ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByIndex(self.currentFillTypeIndex)
        element:setText(fillType.title)
    end
end

function Gc_Gui_GlobalMarketLoading:onCreateCol2(element)
    if self.currentFillTypeIndex ~= nil and self.currentFillLevel ~= nil then
        element:setText(g_i18n:formatNumber(self.currentFillLevel, 0))
    end
end

function Gc_Gui_GlobalMarketLoading:onCreateCol3(element)
    if self.currentFillTypeIndex ~= nil and self.currentFillLevel ~= nil then
        local money = g_company.globalMarket:calculateActualPrice(self.currentFillTypeIndex, self.currentFillLevel)        
        element:setText(g_i18n:formatMoney(money, 0, true, true))
    end
end