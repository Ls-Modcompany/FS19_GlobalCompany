-- 
-- Gui - Element - IngameMap 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.10.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui-IngameMap");

GC_Gui_ingameMap = {};

local GC_Gui_ingameMap_mt = Class(GC_Gui_ingameMap, GC_Gui_element);
-- getfenv(0)["GC_Gui_ingameMap"] = GC_Gui_ingameMap;
g_company.gui.inputElement = GC_Gui_ingameMap;

function GC_Gui_ingameMap:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_ingameMap_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "ingameMap";
	
	
	
	return self;
end;

function GC_Gui_ingameMap:loadTemplate(templateName, xmlFile, key)
	GC_Gui_ingameMap:superClass().loadTemplate(self, templateName, xmlFile, key);
    
    self.overlayElement = GC_Gui_overlay:new(self.gui);
    self.overlayElement:loadTemplate(string.format("%s_overlay", templateName), xmlFile, key);
    self.overlayElement:setImageFilename(g_currentMission.mapImageFilename)
    self:addElement(self.overlayElement);
	
	if self.isTableTemplate then
		self.parent:setTableTemplate(self);
	end;
	self:loadOnCreate();
end;

function GC_Gui_ingameMap:copy(src)
	GC_Gui_ingameMap:superClass().copy(self, src);
	

	self:copyOnCreate();
end;

function GC_Gui_ingameMap:delete()
	GC_Gui_ingameMap:superClass().delete(self);

end;

function GC_Gui_ingameMap:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	GC_Gui_slider:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end;

function GC_Gui_ingameMap:keyEvent(unicode, sym, modifier, isDown, eventUsed)   
	GC_Gui_ingameMap:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);
end;

function GC_Gui_ingameMap:update(dt)
    GC_Gui_ingameMap:superClass().update(self, dt);
end;

function GC_Gui_ingameMap:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index);	
	
	GC_Gui_ingameMap:superClass().draw(self);
end;








