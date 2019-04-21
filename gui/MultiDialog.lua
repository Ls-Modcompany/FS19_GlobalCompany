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
    if self.mode == nil then
        self.mode = g_company.gui.MODE_OK;
    end;

    if self.sign == nil then
        self.sign = g_company.gui.SIGN_NONE;
    end;

    self.gui_header:setText(self.header);
    
    self.gui_buttons_ok:setVisible(false);
    self.gui_buttons_okBack:setVisible(false);
    self.gui_buttons_yesNoExit:setVisible(false);

    if self.mode == g_company.gui.MULTIDIALOG_MODE_INPUT then
        self.mode_text:setVisible(false);
        self.gui_input:setVisible(true);
        self.gui_input_text:setText(self.text);
    else
        self.mode_text:setVisible(true);
        self.mode_input:setVisible(false);
        self.gui_text_text:setText(self.text);
    end;

    if self.mode == g_company.gui.MULTIDIALOG_MODE_OK then
        self.gui_buttons_ok:setVisible(true);
    elseif self.mode == g_company.gui.MULTIDIALOG_MODE_YES_NO then
        self.gui_buttons_yesNoExit:setVisible(true);
    elseif self.mode == g_company.gui.MULTIDIALOG_MODE_INPUT then
        self.gui_buttons_okBack:setVisible(true);
    end;
    
    if self.sign == g_company.gui.MULTIDIALOG_SIGN_NONE then
        self.gui_icon:setVisible(false);
    elseif self.sign == g_company.gui.MULTIDIALOG_SIGN_EXCLAMATION then
        self.gui_icon:setImageUv("icon_info");
    elseif self.sign == g_company.gui.MULTIDIALOG_SIGN_QUESTION then
        self.gui_icon:setImageUv("icon_question");
    end;
end

function GC_Gui_MultiDialog:update(dt)

end

function GC_Gui_MultiDialog:onClose(element)

end

function GC_Gui_MultiDialog:setData(target, header, text, reference, mode, sign)
    self.target = target;
    self.header = header;
    self.text = text;
    self.reference = reference;
    self.mode = mode;
    self.sign = sign;
end

function GC_Gui_MultiDialog:onClick(element, parameter)
    if self.target ~= nil and self.target.multiDialogOnClick ~= nil then
        if self.mode == g_company.gui.MULTIDIALOG_MODE_INPUT then
            self.target.multiDialogOnClick(self.target, parameter == "1", self.reference, self.gui_input.textElement.text);
        else
            self.target.multiDialogOnClick(self.target, parameter == "1", self.reference);
        end;
    end;
    g_company.gui:closeActiveDialog();
end;

