-- 
-- GlobalCompany - Gui - MultiDialog
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.01.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 ():
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
-- 
-- 
-- ToDo:
-- 
-- 


GC_Gui_MultiDialog = {};
GC_Gui_MultiDialog.xmlFilename = g_company.dir .. "gui/MultiDialog.xml";
GC_Gui_MultiDialog.debugIndex = g_company.debug:registerScriptName("GC_Gui_MultiDialog");

local GC_Gui_MultiDialog_mt = Class(GC_Gui_MultiDialog);

function GC_Gui_MultiDialog:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_MultiDialog_mt;
    end;
	local self = setmetatable({}, custom_mt);
	
	
	
	return self;
end;

function GC_Gui_MultiDialog:onCreate()


end;

function GC_Gui_MultiDialog:onOpen()
    
end

function GC_Gui_MultiDialog:update(dt)

end

function GC_Gui_MultiDialog:onClose(element)

end



----------------------------------------------------------  onOpen  ----------------------------------------------------------



----------------------------------------------------------  onClick  ----------------------------------------------------------



----------------------------------------------------------  Utils  ----------------------------------------------------------
