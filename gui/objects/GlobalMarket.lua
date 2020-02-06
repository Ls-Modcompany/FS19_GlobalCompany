--
-- GlobalCompany - Gui - GlobalMarket
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.01.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (26.01.2020):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
-- ToDo:
--

Gc_Gui_GlobalMarket = {}
Gc_Gui_GlobalMarket.xmlFilename = g_company.dir .. "gui/objects/GlobalMarket.xml"
Gc_Gui_GlobalMarket.debugIndex = g_company.debug:registerScriptName("Gc_Gui_GlobalMarket")

local Gc_Gui_GlobalMarket_mt = Class(Gc_Gui_GlobalMarket)

Gc_Gui_GlobalMarket.tabs = {}
Gc_Gui_GlobalMarket.tabs.STORAGE = 1
Gc_Gui_GlobalMarket.tabs.BUY = 2

function Gc_Gui_GlobalMarket:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_GlobalMarket_mt
    end
    local self = setmetatable({}, Gc_Gui_GlobalMarket_mt)	
        
	return self
end

function Gc_Gui_GlobalMarket:onOpen()
    g_depthOfFieldManager:setBlurState(true)
    local haveStorageItems = self:loadTableSell()
    self:loadTableBuy()

    if haveStorageItems then
        self:openTab(Gc_Gui_GlobalMarket.tabs.STORAGE) 
    else
        self:openTab(Gc_Gui_GlobalMarket.tabs.BUY) 
    end

    self.currentSelectedItem = nil
    self.gui_btn_sellBuy:setVisible(false)
    self.gui_btn_sellBuyText:setVisible(false)
    self.gui_btn_outsource:setVisible(false)
    self.gui_btn_outsourceText:setVisible(false)
    self.gui_btn_outsourceBale1:setVisible(false)
    self.gui_btn_outsourceBale1Text:setVisible(false)
    self.gui_btn_outsourceBale2:setVisible(false)
    self.gui_btn_outsourceBale2Text:setVisible(false)
end

function Gc_Gui_GlobalMarket:onClose() 
    g_depthOfFieldManager:setBlurState(false)
end

function Gc_Gui_GlobalMarket:onCreate() end

function Gc_Gui_GlobalMarket:keyEvent(unicode, sym, modifier, isDown, eventUsed)
    if sym == 120 and isDown then
        self:openTab(Gc_Gui_GlobalMarket.tabs.STORAGE) 
    elseif sym == 99 and isDown then
        self:openTab(Gc_Gui_GlobalMarket.tabs.BUY) 
    elseif sym == 13 and self.gui_btn_sellBuy:getVisible() then
        self:onClickSellBuy()
    elseif sym == 32 and self.gui_btn_outsource:getVisible() then
        self:onClickOutsource()
    elseif sym == 113 and self.gui_btn_outsourceBale1:getVisible() then
        self:onClickOutsourceBale1()
    elseif sym == 101 and self.gui_btn_outsourceBale2:getVisible() then
        self:onClickOutsourceBale2()
    end    
end

function Gc_Gui_GlobalMarket:setCloseCallback(target, func) 
    self.closeCallback = {target=target, func=func}
end

function Gc_Gui_GlobalMarket:setData(market)
    self.market = market       
end

function Gc_Gui_GlobalMarket:onClickClose() 
	g_company.gui:closeActiveGui()
end

function Gc_Gui_GlobalMarket:onClickStorageItem(element) 
    self.currentSelectedItem = element    
    self.gui_btn_sellBuy:setVisible(true)
    self.gui_btn_sellBuyText:setVisible(true)   
    
    local havePallet, haveBale1, haveBale2 = self:getCanOutsource()
    self.gui_btn_outsource:setVisible(self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE and havePallet)
    self.gui_btn_outsourceText:setVisible(self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE and havePallet)    
    self.gui_btn_outsourceBale1:setVisible(self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE and haveBale1)
    self.gui_btn_outsourceBale1Text:setVisible(self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE and haveBale1)    
    self.gui_btn_outsourceBale2:setVisible(self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE and haveBale2)
    self.gui_btn_outsourceBale2Text:setVisible(self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE and haveBale2)
end

function Gc_Gui_GlobalMarket:getCanOutsource(item)
    local havePallet = false
    local haveBale1 = false
    local haveBale2 = false
    if self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE then
        havePallet = g_company.globalMarket:getPalletFilenameFromFillTypeIndex(self.currentSelectedItem.fillTypeIndex) ~= nil
        local balePaths = g_company.globalMarket.baleToFilename[string.upper(g_fillTypeManager:getFillTypeNameByIndex(self.currentSelectedItem.fillTypeIndex))]
        haveBale = balePaths ~= nil

        if haveBale then
            if balePaths[1] ~= nil then
                local capacityPerPallet1, numBales1 = g_company.globalMarket:getCapacityByStoreXml(balePaths[1], false)
                haveBale1 = self.currentSelectedItem.fillTypeLevel >= capacityPerPallet1
            else
                haveBale1 = false
            end
            if balePaths[2] ~= nil then
                local capacityPerPallet2, numBales2 = g_company.globalMarket:getCapacityByStoreXml(balePaths[2], false)
                haveBale2 = self.currentSelectedItem.fillTypeLevel >= capacityPerPallet2
            else
                haveBale2 = false
            end
        end        
    end
    return havePallet, haveBale1, haveBale2
end

function Gc_Gui_GlobalMarket:onClickTabStorage(element) 
    self:openTab(Gc_Gui_GlobalMarket.tabs.STORAGE) 
end

function Gc_Gui_GlobalMarket:onClickTabBuy(element) 
    self:openTab(Gc_Gui_GlobalMarket.tabs.BUY) 
end

function Gc_Gui_GlobalMarket:openTab(tab) 
   if tab ==  Gc_Gui_GlobalMarket.tabs.STORAGE then
        self.activeTab = Gc_Gui_GlobalMarket.tabs.STORAGE
        self.gui_tab_storage:setVisible(true)
        self.gui_tab_buy:setVisible(false)
        self.gui_btn_tab_storage:setActive(true)
        self.gui_btn_tab_buy:setActive(false)
        self.gui_btn_outsource:setActive(false)
        self.gui_btn_sellBuyText:setText(g_company.languageManager:getText("GC_globalMarket_btn_sell"), true)
   else
        self.activeTab = Gc_Gui_GlobalMarket.tabs.BUY
        self.gui_tab_storage:setVisible(false)
        self.gui_tab_buy:setVisible(true)
        self.gui_btn_tab_storage:setActive(false)
        self.gui_btn_tab_buy:setActive(true)
        self.gui_btn_outsource:setActive(false)
        self.gui_btn_sellBuyText:setText(g_company.languageManager:getText("GC_globalMarket_btn_buy"), true)
   end
   if not self.manualSychRun then        
        self.gui_btn_manualSych:setVisible(tab ==  Gc_Gui_GlobalMarket.tabs.BUY)
        self.gui_btn_manualSychText:setVisible(tab ==  Gc_Gui_GlobalMarket.tabs.BUY)
   end
   self.gui_btn_sellBuy:setVisible(false)
   self.gui_btn_sellBuyText:setVisible(false)  
end

function Gc_Gui_GlobalMarket:loadTableSell() 
	self.gui_table_storage:removeElements()
    local haveStorageItems = false
    local farmId = g_currentMission:getFarmId()
    for fillTypeIndex, levels in pairs(self.market.fillLevels) do
        if levels[farmId] > 0 then
            self.currentFillTypeIndex = fillTypeIndex
            self.currentFillLevel = levels[farmId]
            local item = self.gui_table_storage:createItem()
            item.fillTypeIndex = fillTypeIndex
            item.fillTypeLevel = math.ceil(levels[farmId])
            haveStorageItems = true
            self.currentFillTypeIndex = nil
            self.currentFillLevel = nil
        end
    end
    return haveStorageItems
end

function Gc_Gui_GlobalMarket:loadTableBuy() 
	self.gui_table_buy:removeElements()
    for type,fillTypes in pairs(g_company.globalMarket.fillTypes) do
        for _,fillType in pairs(fillTypes) do
            if fillType.fillLevel > 0 then
                self.currentFillType = fillType
                local item = self.gui_table_buy:createItem()
                item.fillType = fillType
                self.currentFillType = nil
            end
        end
    end
end

function Gc_Gui_GlobalMarket:onClickSellBuy()    
    if self.currentSelectedItem == nil then return end
    g_company.gui:setCanExit("gc_globalMarketLevelDialog", false)
    if self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE then
        g_company.gui:closeActiveGui("gc_globalMarketLevelDialog", false, self.market, self.currentSelectedItem.fillTypeLevel, self.currentSelectedItem.fillTypeIndex, true, false)
    else
        local maxDelta = math.min(self.market:getFreeCapacity(self.currentSelectedItem.fillType.index, g_currentMission:getFarmId()), self.currentSelectedItem.fillType.fillLevel)
        g_company.gui:closeActiveGui("gc_globalMarketLevelDialog", false, self.market, maxDelta, self.currentSelectedItem.fillType.index, false, false)
    end
    self:loadTableBuy()
    self:loadTableSell()
end

function Gc_Gui_GlobalMarket:onClickOutsource()    
    g_company.gui:setCanExit("gc_globalMarketLevelDialog", false)
    if self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE then
        g_company.gui:closeActiveGui("gc_globalMarketLevelDialog", false, self.market, self.currentSelectedItem.fillTypeLevel, self.currentSelectedItem.fillTypeIndex, true, true)
    end
    self:loadTableBuy()
    self:loadTableSell()
end

function Gc_Gui_GlobalMarket:onClickOutsourceBale1()    
    g_company.gui:setCanExit("gc_globalMarketLevelDialog", false)
    if self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE then
        g_company.gui:closeActiveGui("gc_globalMarketLevelDialog", false, self.market, self.currentSelectedItem.fillTypeLevel, self.currentSelectedItem.fillTypeIndex, true, true, true)
    end
    self:loadTableBuy()
    self:loadTableSell()
end

function Gc_Gui_GlobalMarket:onClickOutsourceBale2()    
    g_company.gui:setCanExit("gc_globalMarketLevelDialog", false)
    if self.activeTab == Gc_Gui_GlobalMarket.tabs.STORAGE then
        g_company.gui:closeActiveGui("gc_globalMarketLevelDialog", false, self.market, self.currentSelectedItem.fillTypeLevel, self.currentSelectedItem.fillTypeIndex, true, true, false)
    end
    self:loadTableBuy()
    self:loadTableSell()
end

function Gc_Gui_GlobalMarket:onClickSynch(button)
    self.gui_table_buy:removeElements()
    self.manualSychRun = true
    self.gui_btn_manualSych:setVisible(false)
    self.gui_btn_manualSychText:setVisible(false)
    g_company.globalMarket:doManualSynch(self, self.manualSynchIsFinish)
end

function Gc_Gui_GlobalMarket:manualSynchIsFinish(button)
    self:loadTableBuy()
    self:loadTableSell()
    self.manualSychRun = false
    self.gui_btn_manualSych:setVisible(true)
    self.gui_btn_manualSychText:setVisible(true)
end

function Gc_Gui_GlobalMarket:onCreateCol1(element)
    if self.currentFillTypeIndex ~= nil and self.currentFillLevel ~= nil then
        if self.currentFillTypeIndex == g_company.globalMarket.ownFillTypes.WOOD then
            element:setText(g_i18n:getText("configuration_valueWoodTrailer"))
        else
            local fillType = g_fillTypeManager:getFillTypeByIndex(self.currentFillTypeIndex)
            element:setText(fillType.title)
        end
    end
end

function Gc_Gui_GlobalMarket:onCreateCol2(element)
    if self.currentFillTypeIndex ~= nil and self.currentFillLevel ~= nil then
        element:setText(g_i18n:formatNumber(self.currentFillLevel, 0))
    end
end

function Gc_Gui_GlobalMarket:onCreateCol3(element)
    if self.currentFillTypeIndex ~= nil and self.currentFillLevel ~= nil then
        local money = g_company.globalMarket:calculateActualPrice(self.currentFillTypeIndex, self.currentFillLevel)        
        element:setText(g_i18n:formatMoney(money, 0, true, false))
    end
end

function Gc_Gui_GlobalMarket:onCreateCol10(element)
    if self.currentFillType ~= nil then
        if self.currentFillType.index == g_company.globalMarket.ownFillTypes.WOOD then
            element:setText(g_i18n:getText("configuration_valueWoodTrailer"))
        else
            local fillType = g_fillTypeManager:getFillTypeByIndex(self.currentFillType.index)
            element:setText(fillType.title)
        end
    end
end

function Gc_Gui_GlobalMarket:onCreateCol11(element)
    if self.currentFillType ~= nil then
        element:setText(g_i18n:formatNumber(self.currentFillType.fillLevel, 0))
    end
end

function Gc_Gui_GlobalMarket:onCreateCol12(element)
    if self.currentFillType ~= nil then      
        element:setText(g_i18n:formatMoney(self.currentFillType.actualPrice * 1000, 0, true, false))
    end
end

function Gc_Gui_GlobalMarket:onCreatePriceIcon1(element)
    if self.currentFillTypeIndex ~= nil then  
        local priceTrend = g_company.globalMarket:getPriceTrendByFillType(self.currentFillTypeIndex)
        if priceTrend == g_company.globalMarket.priceTrends.DOWN then
            element:setRotation(0)
            element.imageColor = g_company.gui:getTemplateValueColor("gcGlobalMarketButtonsPriceIconDown", "imageColor_selected", element.imageColor)
	        element.imageColor_selected = g_company.gui:getTemplateValueColor("gcGlobalMarketButtonsPriceIconDown", "imageColor_selected", element.imageColor_selected);
	    elseif priceTrend == g_company.globalMarket.priceTrends.UP then
            element:setRotation(3.1)
            element.imageColor = g_company.gui:getTemplateValueColor("gcGlobalMarketButtonsPriceIconUp", "imageColor_selected", element.imageColor)
	        element.imageColor_selected = g_company.gui:getTemplateValueColor("gcGlobalMarketButtonsPriceIconUp", "imageColor_selected", element.imageColor_selected);
	    end
    end
end

function Gc_Gui_GlobalMarket:onCreatePriceIcon2(element)
    if self.currentFillType ~= nil then    
        local priceTrend = g_company.globalMarket:getPriceTrendByFillType(self.currentFillType.index)
        if priceTrend == g_company.globalMarket.priceTrends.DOWN then
            element:setRotation(0)
            element.imageColor = g_company.gui:getTemplateValueColor("gcGlobalMarketButtonsPriceIconDown", "imageColor_selected", element.imageColor)
	        element.imageColor_selected = g_company.gui:getTemplateValueColor("gcGlobalMarketButtonsPriceIconDown", "imageColor_selected", element.imageColor_selected)
	    elseif priceTrend == g_company.globalMarket.priceTrends.UP then
            element:setRotation(3.1)
            element.imageColor = g_company.gui:getTemplateValueColor("gcGlobalMarketButtonsPriceIconUp", "imageColor_selected", element.imageColor)
	        element.imageColor_selected = g_company.gui:getTemplateValueColor("gcGlobalMarketButtonsPriceIconUp", "imageColor_selected", element.imageColor_selected)
	    end
    end
end

function Gc_Gui_GlobalMarket:onClickStorageScreen()
    self:openTab(Gc_Gui_GlobalMarket.tabs.STORAGE) 
end

function Gc_Gui_GlobalMarket:onClickBuyScreen()
    self:openTab(Gc_Gui_GlobalMarket.tabs.BUY) 
end