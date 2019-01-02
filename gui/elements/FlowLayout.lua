-- 
-- Gui - Element - TEXT 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.05.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_debug.registerMod("GlobalCompany-Gui-Text");

GC_Gui_flowLayout = {};

GC_Gui_flowLayout.ORIENTATION_X = 1;
GC_Gui_flowLayout.ORIENTATION_Y = 2;

GC_Gui_flowLayout.ALIGNMENT_LEFT = 1;
GC_Gui_flowLayout.ALIGNMENT_MIDDLE = 2;
GC_Gui_flowLayout.ALIGNMENT_RIGHT = 3;
GC_Gui_flowLayout.ALIGNMENT_TOP = 4;
GC_Gui_flowLayout.ALIGNMENT_CENTER = 5;
GC_Gui_flowLayout.ALIGNMENT_BOTTOM = 6;

local GC_Gui_flowLayout_mt = Class(GC_Gui_flowLayout, GC_Gui_element);
getfenv(0)["GC_Gui_flowLayout"] = GC_Gui_flowLayout;

function GC_Gui_flowLayout:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_flowLayout_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "flowLayout";
	
	self.orientation = GC_Gui_flowLayout.ORIENTATION_X;
	self.alignment = GC_Gui_flowLayout.ALIGNMENT_LEFT;
	
	return self;
end;

function GC_Gui_flowLayout:loadTemplate(templateName, xmlFile, key)
	GC_Gui_flowLayout:superClass().loadTemplate(self, templateName, xmlFile, key);
	
	local orientation = g_company.gui:getTemplateValue(templateName, "orientation");
	local alignment = g_company.gui:getTemplateValue(templateName, "alignment");
	
	if orientation == "x" then
		self.orientation = GC_Gui_flowLayout.ORIENTATION_X;
	elseif orientation == "y" then
		self.orientation = GC_Gui_flowLayout.ORIENTATION_Y;
	end;
	
	if alignment == "left" then
		self.alignment = GC_Gui_flowLayout.ALIGNMENT_LEFT;
	elseif alignment == "middle" then
		self.alignment = GC_Gui_flowLayout.ALIGNMENT_MIDDLE;
	elseif alignment == "right" then
		self.alignment = GC_Gui_flowLayout.ALIGNMENT_RIGHT;
	elseif alignment == "top" then
		self.alignment = GC_Gui_flowLayout.ALIGNMENT_TOP;
	elseif alignment == "center" then
		self.alignment = GC_Gui_flowLayout.ALIGNMENT_CENTER;
	elseif alignment == "bottom" then
		self.alignment = GC_Gui_flowLayout.ALIGNMENT_BOTTOM;
	end;	
	self:loadOnCreate();
end;

function GC_Gui_flowLayout:copy(src)
	GC_Gui_flowLayout:superClass().copy(self, src);
	
	self.orientation = src.orientation;
	self.alignment = src.alignment;
	self:copyOnCreate();
end;

function GC_Gui_flowLayout:delete()
	GC_Gui_flowLayout:superClass().delete(self);

end;

function GC_Gui_flowLayout:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	GC_Gui_flowLayout:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed);
end;

function GC_Gui_flowLayout:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	GC_Gui_flowLayout:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);

end;

function GC_Gui_flowLayout:update(dt)
	GC_Gui_flowLayout:superClass().update(self, dt);

end;

function GC_Gui_flowLayout:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index);
	GC_Gui_flowLayout:superClass().draw(self);
end;














