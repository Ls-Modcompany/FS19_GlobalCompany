-- 
-- Gui - Element - SLIDER 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 06.04.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui-Slider");

GC_Gui_slider = {};
local GC_Gui_slider_mt = Class(GC_Gui_slider, GC_Gui_element);
getfenv(0)["GC_Gui_slider"] = GC_Gui_slider;

GC_Gui_slider.ORIENTATION_X = 1;
GC_Gui_slider.ORIENTATION_Y = 2;

GC_Gui_slider.TYP_TABLE = 1;
GC_Gui_slider.TYP_LIST = 2;

function GC_Gui_slider:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_slider_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "slider";
	
    
    
	
	return self;
end;

function GC_Gui_slider:loadTemplate(templateName, xmlFile, key, overlayName)
	GC_Gui_slider:superClass().loadTemplate(self, templateName, xmlFile, key);	
    
    
	self:loadOnCreate();
end;

function GC_Gui_slider:copy(src)
	GC_Gui_slider:superClass().copy(self, src);
	

    
	self:copyOnCreate();
end;

function GC_Gui_slider:delete()
	GC_Gui_slider:superClass().delete(self);
	
end;

function GC_Gui_slider:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)	
	if not self:getDisabled() then
		eventUsed = GC_Gui_slider:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
	
        
        
	end;
	return eventUsed;
end;

function GC_Gui_slider:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	GC_Gui_slider:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);
end;

function GC_Gui_slider:update(dt)
	GC_Gui_slider:superClass().update(self, dt);
end;

function GC_Gui_slider:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index);
	GC_Gui_slider:superClass().draw(self,index);
end;










