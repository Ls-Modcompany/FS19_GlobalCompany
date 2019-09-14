-- 
-- Gui - Element - GuiScreen 
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
--      - some parts from productionFactory
--
-- ToDo:
--
--
--


GuiScreen = {};
local GuiScreen_mt = Class(GuiScreen);

GuiScreen.debugIndex = g_company.debug:registerScriptName("GlobalCompany-GuiScreen");


function GuiScreen:new()	
	if custom_mt == nil then
        custom_mt = GuiScreen_mt;
    end;
    local self = setmetatable({}, custom_mt);	
    
    self.texts = {};
    
	return self;
end;

function GuiScreen:onOpen()
    g_depthOfFieldManager:setBlurState(true);
end;

function GuiScreen:onClose()
    g_depthOfFieldManager:setBlurState(false);
end;

function GuiScreen:onOpen()
    
end;

function GuiScreen:onCreate()
    self.gui_headerLocationSep_1:setVisible(false);
    self.gui_headerLocationSep_2:setVisible(false);
end;

function GuiScreen:onClickClose()
	g_company.gui:closeActiveGui();
end;


function GuiScreen:setPage(num, text)
    local goToPage = num or 1;
    if goToPage ~= self.currentPage and goToPage > 0 and goToPage < 4 then
        
        self["gui_headerLocationText_" .. goToPage]:setText(text);
        if self.currentPage ~= nil then
            if goToPage > self.currentPage then
                self["gui_headerLocationSep_" .. goToPage]:setVisible(true);
            end;
            if goToPage < self.currentPage then
                self["gui_headerLocationSep_" .. (goToPage + 1)]:setVisible(false);
                self["gui_headerLocationText_" .. (goToPage + 1)]:setText("");
            end;
        end;
        self.currentPage = goToPage;        
    end;
end;



