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


Gc_Gui_AnimalFeeder = {};
Gc_Gui_AnimalFeeder.xmlFilename = g_company.dir .. "gui/objects/AnimalFeeder.xml";
Gc_Gui_AnimalFeeder.debugIndex = g_company.debug:registerScriptName("Gc_Gui_AnimalFeeder");

local Gc_Gui_AnimalFeeder_mt = Class(Gc_Gui_AnimalFeeder);

function Gc_Gui_AnimalFeeder:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_AnimalFeeder_mt;
    end;
	local self = setmetatable({}, Gc_Gui_AnimalFeeder_mt);			
	return self;
end;

function Gc_Gui_AnimalFeeder:onOpen() 
    g_depthOfFieldManager:setBlurState(true);

    if g_company.gui.devVersion and self.feeder ~= nil then
        self:setData(self.feeder, false)
    end

    self:setFeedingTimesElements() 
    self:setFeedingDemandPercentElements()
    self:setFeedingBunkerElements()
    self:setFeedingMixingRatioElements()
    self:setFeedingLiterPerDriveElements()

end;

function Gc_Gui_AnimalFeeder:onClose() 
    g_depthOfFieldManager:setBlurState(false);
end;

function Gc_Gui_AnimalFeeder:onCreate() end;

function Gc_Gui_AnimalFeeder:keyEvent(unicode, sym, modifier, isDown, eventUsed)
    if not g_company.gui.guis["gc_animalFeeder"].canExit and sym == 27 and not isDown then
        self:onClickClose();
    end;    
end;

function Gc_Gui_AnimalFeeder:setCloseCallback(target, func) 
    self.closeCallback = {target=target, func=func};
end;

function Gc_Gui_AnimalFeeder:setData(feeder, showFromMenu)
    self.feeder = feeder;
    self.closeCallback = nil;

    self.showFromMenu = showFromMenu or false
  
    self.gui_header:setText(feeder:getCustomTitle());
        

   
end

function Gc_Gui_AnimalFeeder:onClickClose() 
    if self.showFromMenu then
        g_company.gui:closeActiveGui("gc_main", false, 3);
        self.showFromMenu = false
    else
        g_company.gui:closeActiveGui();
    end
end;

function Gc_Gui_AnimalFeeder:onClickToggleFeedingTimeActive(element, parameter) 
    local id = tonumber(parameter)
    local feedingTime = self.feeder:getFeedingTimes()[id]
    self.feeder:setFeedingTimes(id, feedingTime.time, not feedingTime.active)
    self:setFeedingTimesElements() 
end

function Gc_Gui_AnimalFeeder:setFeedingTimesElements() 
    local i = 1
    for _,feedTime in pairs(self.feeder:getFeedingTimes()) do  
        self:setFeedTimeDisable(i, not feedTime.active) 
        self["gui_feedingTime" .. tostring(i) .. "_2"]:setText(string.format(g_company.languageManager:getText("GC_animalFeeder_gui_hist_time"), feedTime.time))
        i = i + 1
    end
end

function Gc_Gui_AnimalFeeder:setFeedingDemandPercentElements() 
    self.gui_feedingDemandPercent:setText(self.feeder:getFeedingDemandPercent() .. "%")
end

function Gc_Gui_AnimalFeeder:setFeedingLiterPerDriveElements() 
    self.gui_feedingLiterPerDrive:setText(string.format(g_company.languageManager:getText("GC_animalFeeder_gui_hist_val"), g_i18n:formatNumber(self.feeder:getFeedingLiterPerDrive(), 0)))
end

function Gc_Gui_AnimalFeeder:setFeedTimeDisable(i, state) 
    for j=1, 4 do
        self["gui_feedingTime" .. tostring(i) .. "_" .. tostring(j)]:setDisabled(state)
    end
    self["gui_feedingTime" .. tostring(i) .. "_0"]:setActive(not state)
end

function Gc_Gui_AnimalFeeder:onClickSetFeedingTimeDown(element, parameter) 
    local id = tonumber(parameter)
    local feedingTime = self.feeder:getFeedingTimes()[id]
    local newTime = feedingTime.time-1
    if newTime < 0 then newTime = 23 end
    self.feeder:setFeedingTimes(id, newTime, feedingTime.active)
    self:setFeedingTimesElements() 
end

function Gc_Gui_AnimalFeeder:onClickSetFeedingTimeUp(element, parameter) 
    local id = tonumber(parameter)
    local feedingTime = self.feeder:getFeedingTimes()[id]
    local newTime = feedingTime.time+1
    if newTime > 23 then newTime = 0 end
    self.feeder:setFeedingTimes(id, newTime, feedingTime.active)
    self:setFeedingTimesElements() 
end

function Gc_Gui_AnimalFeeder:onClickSetFeedingDemandDown() 
    local newValue = self.feeder:getFeedingDemandPercent() - 5
    if newValue < 0 then newValue = 100 end
    self.feeder:setFeedingDemandPercent(newValue)
    self:setFeedingDemandPercentElements()
end

function Gc_Gui_AnimalFeeder:onClickSetFeedingDemandUp()     
    local newValue = self.feeder:getFeedingDemandPercent() + 5
    if newValue > 100 then newValue = 0 end
    self.feeder:setFeedingDemandPercent(newValue)
    self:setFeedingDemandPercentElements()
end

function Gc_Gui_AnimalFeeder:onClickSetFeedingLiterPerDriveDown() 
    local newValue = self.feeder:getFeedingLiterPerDrive() - 2000
    local capacity = self.feeder:getRoboterDriveCapacity()
    if newValue < 0 then newValue = capacity end
    self.feeder:setFeedingLiterPerDrive(newValue)
    self:setFeedingLiterPerDriveElements()
end

function Gc_Gui_AnimalFeeder:onClickSetFeedingLiterPerDriveUp()     
    local newValue = self.feeder:getFeedingLiterPerDrive() + 2000
    local capacity = self.feeder:getRoboterDriveCapacity()
    if newValue > capacity then newValue = 0 end
    self.feeder:setFeedingLiterPerDrive(newValue)
    self:setFeedingLiterPerDriveElements()
end

function Gc_Gui_AnimalFeeder:setFeedingBunkerElements() 
    local index = 1
    local completHist = 0
    local bunkers = self.feeder:getFeedingBunker()
    for _,bunker in pairs(bunkers) do
        self["gui_bunker_name" .. tostring(index)]:setVisible(true)
        self["gui_bunker_level" .. tostring(index)]:setVisible(true)
        self["gui_history_" .. tostring(index) .. "_text"]:setVisible(true)
        self["gui_history_" .. tostring(index)]:setVisible(true)

        self["gui_bunker_name" .. tostring(index)]:setText(bunker.title)
        self["gui_bunker_level" .. tostring(index)]:setText(string.format(g_company.languageManager:getText("GC_animalFeeder_gui_hist_val"), g_i18n:formatNumber(bunker.fillLevel, 0)))
        self["gui_history_" .. tostring(index) .. "_text"]:setText(string.format(g_company.languageManager:getText("GC_animalFeeder_gui_hist_text2"), bunker.title))
        self["gui_history_" .. tostring(index)]:setText(string.format(g_company.languageManager:getText("GC_animalFeeder_gui_hist_val"), g_i18n:formatNumber(bunker.history, 0)))

        completHist = completHist + bunker.history
        index = index + 1
    end
    self.gui_history_full:setText(string.format(g_company.languageManager:getText("GC_animalFeeder_gui_hist_val"), g_i18n:formatNumber(completHist, 0)))
    
    for i = g_company.utils.getTableLength(bunkers) + 1, 4 do
        self["gui_bunker_name" .. tostring(i)]:setVisible(false)
        self["gui_bunker_level" .. tostring(i)]:setVisible(false)
        self["gui_history_" .. tostring(i) .. "_text"]:setVisible(false)
        self["gui_history_" .. tostring(i)]:setVisible(false)
    end
end

function Gc_Gui_AnimalFeeder:setFeedingMixingRatioElements() 
    local index = 1
    local completRatio = 0
    local bunkers = self.feeder:getFeedingBunker()
    for _,bunker in pairs(bunkers) do
        self["gui_mixingRatio" .. tostring(index) .. "_title"]:setVisible(true)
        self["gui_mixingRatio" .. tostring(index) .. "_value"]:setVisible(true)
        self["gui_mixingRatio" .. tostring(index) .. "_btn1"]:setVisible(true)
        self["gui_mixingRatio" .. tostring(index) .. "_btn2"]:setVisible(true)
        self["gui_mixingRatio" .. tostring(index) .. "_title"]:setText(bunker.fillTypeTitle)
        self["gui_mixingRatio" .. tostring(index) .. "_value"]:setText(bunker.mixingRatio.value .. "%")
        completRatio = completRatio + bunker.mixingRatio.value
        index = index + 1
    end
    self.gui_mixingRatioWarning:setVisible(completRatio ~= 100)

    for i = g_company.utils.getTableLength(bunkers) + 1, 4 do
        self["gui_mixingRatio" .. tostring(i) .. "_title"]:setVisible(false)
        self["gui_mixingRatio" .. tostring(i) .. "_value"]:setVisible(false)
        self["gui_mixingRatio" .. tostring(i) .. "_btn1"]:setVisible(false)
        self["gui_mixingRatio" .. tostring(i) .. "_btn2"]:setVisible(false)
    end    
end

function Gc_Gui_AnimalFeeder:onClickSetMixingRatioDown(element, parameter) 
    local id = tonumber(parameter)    
    local bunker = self.feeder:getFeedingBunker()[id]
    local newValue = bunker.mixingRatio.value-1
    if newValue < bunker.mixingRatio.min then 
        newValue = bunker.mixingRatio.max
    end    
    
    self.feeder:setFeedingMixingRatio(id, newValue)
    self:setFeedingMixingRatioElements() 
end

function Gc_Gui_AnimalFeeder:onClickSetMixingRatioUp(element, parameter) 
    local id = tonumber(parameter)    
    local bunker = self.feeder:getFeedingBunker()[id]
    local newValue = bunker.mixingRatio.value+1
    if newValue > bunker.mixingRatio.max then 
        newValue = bunker.mixingRatio.min
    end    
    
    self.feeder:setFeedingMixingRatio(id, newValue)
    self:setFeedingMixingRatioElements() 
end
