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

Gc_Gui_GlobalMarketVehicleDialog = {}
Gc_Gui_GlobalMarketVehicleDialog.xmlFilename = g_company.dir .. "gui/objects/GlobalMarketVehicleDialog.xml"
Gc_Gui_GlobalMarketVehicleDialog.debugIndex = g_company.debug:registerScriptName("Gc_Gui_GlobalMarketVehicleDialog")

local Gc_Gui_GlobalMarketVehicleDialog_mt = Class(Gc_Gui_GlobalMarketVehicleDialog)

function Gc_Gui_GlobalMarketVehicleDialog:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_GlobalMarketVehicleDialog_mt
    end
    local self = setmetatable({}, Gc_Gui_GlobalMarketVehicleDialog_mt)	
        
	return self
end

function Gc_Gui_GlobalMarketVehicleDialog:onOpen()
    g_depthOfFieldManager:setBlurState(true)
    self.manualClose = false
end

function Gc_Gui_GlobalMarketVehicleDialog:onClose() 
    g_depthOfFieldManager:setBlurState(false)
	g_company.gui:setCanExit("gc_globalMarketVehicleDialog", true)
end

function Gc_Gui_GlobalMarketVehicleDialog:onCreate() end

function Gc_Gui_GlobalMarketVehicleDialog:keyEvent(unicode, sym, modifier, isDown, eventUsed)
    if sym == 13 and isDown then
        self:onClickSellBuy()
    elseif not g_company.gui.guis["gc_globalMarketVehicleDialog"].canExit and sym == 27 and not isDown then
        self:onClickClose();
   end
end

function Gc_Gui_GlobalMarketVehicleDialog:setCloseCallback(target, func) 
    self.closeCallback = {target=target, func=func}
end

function Gc_Gui_GlobalMarketVehicleDialog:setData(market, vehicle, buy)
    self.market = market       
    self.vehicle = vehicle
    self.buy = buy
    

    
    
    self.gui_unit:setText(g_company.languageManager:getText("GC_globalMarket_tbl_header_level"))
end

function Gc_Gui_GlobalMarketVehicleDialog:onClickClose() 
    self.manualClose = true
    g_company.gui:closeActiveGui("gc_globalMarket", false, self.market)
end

function Gc_Gui_GlobalMarketVehicleDialog:onClickSellBuy()
    if self.buy then
        --self.market:spawnPallets(self.fillTypeIndex, self:getCurrentAmount(), g_currentMission:getFarmId(), self.capacityPerPallet, self.numBales, self.asRoundBale)
        
        g_company.gui:closeActiveGui("gc_globalMarket", false, self.market)
    else
        --self.market:sellBuyOnMarket(self.fillTypeIndex, self:getCurrentAmount(), g_currentMission:getFarmId(), self.sell)
        
        g_company.gui:closeActiveGui("gc_globalMarket", false, self.market)
    end
end
