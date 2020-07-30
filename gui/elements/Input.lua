-- 
-- Gui - Element - INPUT 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 21.04.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui-Input");

GC_Gui_input = {};

local GC_Gui_input_mt = Class(GC_Gui_input, GC_Gui_element);
-- getfenv(0)["GC_Gui_input"] = GC_Gui_input;
g_company.gui.inputElement = GC_Gui_input;

function GC_Gui_input:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_input_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "input";
	
	
	
	return self;
end;

function GC_Gui_input:loadTemplate(templateName, xmlFile, key)
	GC_Gui_input:superClass().loadTemplate(self, templateName, xmlFile, key);
	
	self.buttonElement = GC_Gui_button:new(self.gui);
	self.buttonElement:loadTemplate(templateName, xmlFile, key);

	self:addElement(self.buttonElement);
		        
    self.textElement = GC_Gui_text:new(self.gui);
    self.textElement:loadTemplate(string.format("%s_text", templateName), xmlFile, key);
    self:addElement(self.textElement);
        
	
	if self.isTableTemplate then
		self.parent:setTableTemplate(self);
	end;
	self:loadOnCreate();
end;

function GC_Gui_input:copy(src)
	GC_Gui_input:superClass().copy(self, src);
	

	self:copyOnCreate();
end;

function GC_Gui_input:delete()
	GC_Gui_input:superClass().delete(self);

end;

function GC_Gui_input:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	GC_Gui_input:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end;

function GC_Gui_input:keyEvent(unicode, sym, modifier, isDown, eventUsed)
    if self.buttonElement:getActive() and isDown then
		local currentText = self.textElement.text;
        if sym == Input.KEY_backspace then
			currentText = currentText:sub(0, currentText:len() - 1);
        else
            currentText = currentText .. unicodeToUtf8(unicode);
        end;
        self.textElement:setText(currentText);
    end;
	GC_Gui_input:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);
end;

function GC_Gui_input:update(dt)
    GC_Gui_input:superClass().update(self, dt);
end;

function GC_Gui_input:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index);	
	
	GC_Gui_input:superClass().draw(self);
end;








