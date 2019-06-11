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


Gc_Gui_DynamicStorage = {};
Gc_Gui_DynamicStorage.xmlFilename = g_company.dir .. "gui/objects/DynamicStorage.xml";
Gc_Gui_DynamicStorage.debugIndex = g_company.debug:registerScriptName("Gc_Gui_DynamicStorage");

local Gc_Gui_DynamicStorage_mt = Class(Gc_Gui_DynamicStorage);

function Gc_Gui_DynamicStorage:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_DynamicStorage_mt;
    end;
	local self = setmetatable({}, Gc_Gui_DynamicStorage_mt);			
	return self;
end;

function Gc_Gui_DynamicStorage:onOpen() 
    g_depthOfFieldManager:setBlurState(true);
end;

function Gc_Gui_DynamicStorage:onClose() 
    g_depthOfFieldManager:setBlurState(false);
end;

function Gc_Gui_DynamicStorage:onCreate() end;

function Gc_Gui_DynamicStorage:setCloseCallback(target, func) 
    self.closeCallback = {target=target, func=func};
end;

function Gc_Gui_DynamicStorage:setData(storage, isUnloading, activeUnloadingBox)
    self.storage = storage;
    self.isUnloading = isUnloading;
    self.closeCallback = nil;
  
    self.gui_table_places:removeElements();
    
    for _,place in pairs(self.storage.places) do
        self.tmp_place = place;
        local item = self.gui_table_places:createItem();
        item.parameter = place.number;

        if isUnloading then            
            if activeUnloadingBox == nil then        
                if place.number == 1 then
                    item:setActive(true);
                end;
            else
                if place.number == activeUnloadingBox then
                    item:setActive(true);
                end;
            end;
        else
            local trigger = storage.loadingTrigger;
            if not trigger.validFillableObject:getFillUnitAllowsFillType(trigger.validFillableFillUnitIndex, place.activeFillTypeIndex) then
               item:setDisabled(true);                
            end;
        end;
    end;
    self.tmp_place = nil;

    if self.isUnloading then
        self.gui_header:setText(g_company.languageManager:getText("GC_dynamicStorage_gui_header_unloading"));
        self.gui_info:setText(g_company.languageManager:getText("GC_dynamicStorage_gui_info_unloading"));
        self.gui_button_accept:setText(g_company.languageManager:getText("GC_dynamicStorage_gui_confirmBoxUnloading"));
    else
        self.gui_header:setText(g_company.languageManager:getText("GC_dynamicStorage_gui_header_loading"));
        self.gui_info:setText(g_company.languageManager:getText("GC_dynamicStorage_gui_info_loading"));
        self.gui_button_accept:setText(g_company.languageManager:getText("GC_dynamicStorage_gui_confirmBoxLoading"));
    end;
end

function Gc_Gui_DynamicStorage:onClickClose() 
	g_company.gui:closeActiveGui();
end;

function Gc_Gui_DynamicStorage:onCreateNumber(element)   
    if self.tmp_place ~= nil then
        element:setText(tostring(self.tmp_place.number));
    end;
end;

function Gc_Gui_DynamicStorage:onCreateContent(element)  
    if self.tmp_place ~= nil then
        if self.tmp_place.activeFillTypeIndex > -1 and self.tmp_place.fillLevel > 0 then
            element:setText(g_fillTypeManager:getFillTypeByIndex(self.tmp_place.activeFillTypeIndex).title);
        else
            element:setText(g_company.languageManager:getText("GC_dynamicStorage_gui_empty"));
        end;    
    end;    
end;

function Gc_Gui_DynamicStorage:onCreateFillLevel(element) 
    if self.tmp_place ~= nil and self.tmp_place.activeFillTypeIndex > -1 and self.tmp_place.fillLevel > 0 then
        element:setText(string.format(g_company.languageManager:getText("GC_dynamicStorage_gui_fillLevel"), g_i18n:formatNumber(self.tmp_place.fillLevel, 0), g_i18n:formatNumber(self.tmp_place.capacity, 0)));
    end;   
end;

function Gc_Gui_DynamicStorage:onCreateFillLevelBar(element)  
    if self.tmp_place ~= nil and self.tmp_place.activeFillTypeIndex > -1 and self.tmp_place.fillLevel > 0 then
        element:setVisible(true);
        element:setScale(self.tmp_place.fillLevel / self.tmp_place.capacity);   
    end;
end;

function Gc_Gui_DynamicStorage:onCreateFillLevelBarBg(element)  
    if self.tmp_place ~= nil and self.tmp_place.activeFillTypeIndex > -1 and self.tmp_place.fillLevel > 0 then
        element:setVisible(true);
    end;
end;

function Gc_Gui_DynamicStorage:onDoubleClickSetBox(element)  
    if self.isUnloading then
        self.storage:setActiveUnloadingBox(tonumber(element.parameter));
    else
        self.storage:setActiveLoadingBox(tonumber(element.parameter));
        if not self.isUnloading and self.closeCallback ~= nil then
            self.closeCallback.func(self.closeCallback.target);
        end;
    end;
	g_company.gui:closeActiveGui();
end;

function Gc_Gui_DynamicStorage:onClickSetBox(element)  
    if self.isUnloading then
        self.storage:setActiveUnloadingBox(tonumber(element.parameter));
    else
        self.storage:setActiveLoadingBox(tonumber(element.parameter));
    end;
end;

function Gc_Gui_DynamicStorage:onClickAccept(element)  
    if not self.isUnloading and not self.isUnloading and self.closeCallback ~= nil then
        self.closeCallback.func(self.closeCallback.target);
    end;
	g_company.gui:closeActiveGui();
end;

