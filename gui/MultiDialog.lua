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

function GC_Gui_MultiDialog:setData(target, header, text, mode, sign)
    self.target = target;

    if mode == nil then
        mode = g_company.gui.MODE_OK;
    end;

    if sign == nil then
        sign = g_company.gui.SIGN_EXCLAMATION;
    end;

    if mode == g_company.gui.MULTIDIALOG_MODE_OK then
        self.gui_buttons_ok:setVisible(true);
        self.gui_buttons_yesNoExit:setVisible(false);
    elseif mode == g_company.gui.MULTIDIALOG_MODE_YES_NO then
        self.gui_buttons_ok:setVisible(false);
        self.gui_buttons_yesNoExit:setVisible(true);
    end;
    
    if sign == g_company.gui.MULTIDIALOG_SIGN_EXCLAMATION then
        self.gui_icon:setImageUv("icon_info");
    elseif sign == g_company.gui.MULTIDIALOG_SIGN_QUESTION then
        self.gui_icon:setImageUv("icon_question");
    end;

    self.gui_header:setText(header);
    self.gui_text:setText(text);
end

function GC_Gui_MultiDialog:onClick(element, parameter)
    if self.target ~= nil and self.target.multiDialogOnClick ~= nil then
        self.target.multiDialogOnClick(self.target, parameter == "1");
    end;
    g_company.gui:closeActiveDialog();
end;

