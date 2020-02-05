--
-- GlobalCompany - Gui - GlobalMarket
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 27.01.2020
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

Gc_Gui_GlobalMarketLevelDialog = {}
Gc_Gui_GlobalMarketLevelDialog.xmlFilename = g_company.dir .. "gui/objects/GlobalMarketLevelDialog.xml"
Gc_Gui_GlobalMarketLevelDialog.debugIndex = g_company.debug:registerScriptName("Gc_Gui_GlobalMarketLevelDialog")

local Gc_Gui_GlobalMarketLevelDialog_mt = Class(Gc_Gui_GlobalMarketLevelDialog)

function Gc_Gui_GlobalMarketLevelDialog:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_GlobalMarketLevelDialog_mt
    end
    local self = setmetatable({}, Gc_Gui_GlobalMarketLevelDialog_mt)	
        
    self.numbers = {}
    for i=0,8 do
        self.numbers[i] = 0
    end

	return self
end

function Gc_Gui_GlobalMarketLevelDialog:onOpen()
    g_depthOfFieldManager:setBlurState(true)
    self.manualClose = false
end

function Gc_Gui_GlobalMarketLevelDialog:onClose() 
    g_depthOfFieldManager:setBlurState(false)
	g_company.gui:setCanExit("gc_globalMarketLevelDialog", true)
end

function Gc_Gui_GlobalMarketLevelDialog:onCreate() end

function Gc_Gui_GlobalMarketLevelDialog:keyEvent(unicode, sym, modifier, isDown, eventUsed)
    if sym == 120 and isDown then
        self:onClickMin()
    elseif sym == 99 and isDown then
        self:onClickMax()
    elseif sym == 13 and isDown then
        self:onClickSellBuy()
    elseif not g_company.gui.guis["gc_globalMarketLevelDialog"].canExit and sym == 27 and not isDown then
        self:onClickClose();
   end
end

function Gc_Gui_GlobalMarketLevelDialog:setCloseCallback(target, func) 
    self.closeCallback = {target=target, func=func}
end

function Gc_Gui_GlobalMarketLevelDialog:setData(market, fillLevel, fillTypeIndex, sell, isOutsource)
    self.market = market       
    self.fillTypeIndex = fillTypeIndex
    self.sell = sell
    self.maximum = fillLevel
    self.isOutsource = isOutsource

    if isOutsource then
        local path = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex).palletFilename
        local isPallet = true
        if path == nil then
            path = g_company.globalMarket.baleToFilename[string.upper(g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex))]
            isPallet = false
        end
        self.capacityPerPallet, self.numBales = g_company.globalMarket:getCapacityByStoreXml(path, isPallet)
        self.maximum = math.ceil(fillLevel / self.capacityPerPallet)       
        
        if not isPallet then
            if fillLevel < self.capacityPerPallet then
                self.maximum = 0
            --elseif self.maximum > self.numBales then
            --    self.maximum = self.numBales
            end
        end
    end

    self.gui_text_money:setVisible(not isOutsource)
    self.gui_text_moneyText:setVisible(not isOutsource)
    
    local lvlStr = g_company.utils.fillStringLeft(tostring(self.maximum), 9, "0")
    local isNull = true
    
    for i=0,8 do
        self["guiNumberPart" .. tostring(i)]:setVisible(true)
    end
    self.guiPoint1:setVisible(true)
    self.guiPoint2:setVisible(true)
    self.guiPoint1:setVisible(true)

    for i=0,8 do
        local num = tonumber(string.sub(lvlStr, i+1,i+1))
        self.numbers[i] = num

        if num ~= 0 then
            isNull = false
        end

        if isNull then
            self["guiNumberPart" .. tostring(i)]:setVisible(false)
            if i > 4 then
                self.guiPoint1:setVisible(false)
                self.guiPoint2:setVisible(false)
            elseif i > 1 then
                self.guiPoint1:setVisible(false)
            end
        end        
    end
    self:loadNumbers()
    self:setCorrectText()

    if isOutsource then
        if isPallet then
            self.gui_unit:setText(g_company.languageManager:getText("GC_globalMarket_tbl_header_pallets"))
        else
            self.gui_unit:setText(g_company.languageManager:getText("GC_globalMarket_tbl_header_bales"))
        end
    else
        self.gui_unit:setText(g_company.languageManager:getText("GC_globalMarket_tbl_header_level"))
    end
end

function Gc_Gui_GlobalMarketLevelDialog:onClickClose() 
    self.manualClose = true
    g_company.gui:closeActiveGui("gc_globalMarket", false, self.market)
end

function Gc_Gui_GlobalMarketLevelDialog:onClickValueUp(button, parameter) 
    local backup = self.numbers[tonumber(parameter)]

    self.numbers[tonumber(parameter)] = self.numbers[tonumber(parameter)] + 1
    if self.numbers[tonumber(parameter)] > 9 then
        self.numbers[tonumber(parameter)] = 0
    end

    if self:checkMaximum() then
        self:loadNumbers()
        self:setCorrectText()
    else
        self.numbers[tonumber(parameter)] = backup
    end
end

function Gc_Gui_GlobalMarketLevelDialog:onClickValueDown(button, parameter) 
    local backup = self.numbers[tonumber(parameter)]

    self.numbers[tonumber(parameter)] = self.numbers[tonumber(parameter)] - 1
    if self.numbers[tonumber(parameter)] < 0 then
        self.numbers[tonumber(parameter)] = 9
    end

    if self:checkMaximum() then
        self:loadNumbers()
        self:setCorrectText()
    else
        self.numbers[tonumber(parameter)] = backup
    end
end

function Gc_Gui_GlobalMarketLevelDialog:loadNumbers() 
    for i,v in pairs(self.numbers) do
        self["gui_numbers_" .. tostring(i)]:setText(tostring(v));
    end
end

function Gc_Gui_GlobalMarketLevelDialog:getCurrentAmount() 
    local stringNum = ""
    for i=0,8 do
        stringNum = stringNum ..  tostring(self.numbers[i])
    end
    
    return tonumber(stringNum)
end

function Gc_Gui_GlobalMarketLevelDialog:checkMaximum() 
    return self:getCurrentAmount() <= self.maximum
end

function Gc_Gui_GlobalMarketLevelDialog:setCorrectText() 
    local currentAmount = self:getCurrentAmount()
    self.gui_text_amount:setText(g_i18n:formatNumber(currentAmount, 0))

    local money = g_company.globalMarket:calculateActualPrice(self.fillTypeIndex, currentAmount)   
    self.gui_text_money:setText(g_i18n:formatMoney(money, 0, true, true))
end

function Gc_Gui_GlobalMarketLevelDialog:onClickSellBuy()
    if self.isOutsource then
        self.market:spawnPallets(self.fillTypeIndex, self:getCurrentAmount(), g_currentMission:getFarmId(), self.capacityPerPallet, self.numBales)
        g_company.gui:closeActiveGui("gc_globalMarket", false, self.market)
    else
        self.market:sellBuyOnMarket(self.fillTypeIndex, self:getCurrentAmount(), g_currentMission:getFarmId(), self.sell)
        g_company.gui:closeActiveGui("gc_globalMarket", false, self.market)
    end
end

function Gc_Gui_GlobalMarketLevelDialog:onClickMin(element)
    for i=0,8 do
        self.numbers[i] = 0
    end
    self:loadNumbers()
    self:setCorrectText()
end

function Gc_Gui_GlobalMarketLevelDialog:onClickMax(element)
    local lvlStr = g_company.utils.fillStringLeft(tostring(self.maximum), 9, "0")
    for i=0,8 do
        local num = tonumber(string.sub(lvlStr, i+1,i+1))
        self.numbers[i] = num
    end
    self:loadNumbers()
    self:setCorrectText()
end