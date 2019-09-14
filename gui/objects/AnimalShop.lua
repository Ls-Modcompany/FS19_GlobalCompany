--
-- GlobalCompany - Gui - AnimalShop
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 25.08.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (25.08.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
--
-- ToDo:
--
--
--


Gc_Gui_AnimalShop = {};
Gc_Gui_AnimalShop.xmlFilename = g_company.dir .. "gui/objects/AnimalShop.xml";
Gc_Gui_AnimalShop.debugIndex = g_company.debug:registerScriptName("Gc_Gui_AnimalShop");

local Gc_Gui_AnimalShop_mt = Class(Gc_Gui_AnimalShop, GuiScreen);

function Gc_Gui_AnimalShop:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_AnimalShop_mt;
    end;
	local self = setmetatable({}, Gc_Gui_AnimalShop_mt);			
	return self;
end;

function Gc_Gui_AnimalShop:onOpen() 
    Gc_Gui_AnimalShop:superClass().onOpen(self);
    
    if self.currentPage == nil then
        self:setPage(1, self.page_1);
    end;
end;

function Gc_Gui_AnimalShop:onClose() 
    Gc_Gui_AnimalShop:superClass().onClose(self);
    
end;

function Gc_Gui_AnimalShop:onCreate() 
    Gc_Gui_AnimalShop:superClass().onCreate(self);

    self.texts.page_1 = g_company.languageManager:getText("GC_animalShop_page_1");
    self.texts.page_2_1 = g_company.languageManager:getText("GC_animalShop_page_2_1");
    self.texts.page_2_2 = g_company.languageManager:getText("GC_animalShop_page_2_2");
    self.texts.page_2_3 = g_company.languageManager:getText("GC_animalShop_page_2_3");
    self.texts.page_2_4 = g_company.languageManager:getText("GC_animalShop_page_2_4");

end;

function Gc_Gui_AnimalShop:setCloseCallback(target, func) 
    self.closeCallback = {target=target, func=func};
end;

function Gc_Gui_AnimalShop:setData(animalShop)
    self.animalShop = animalShop;
    
    
end
