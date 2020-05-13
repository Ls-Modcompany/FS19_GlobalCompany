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
-- Changelog:
--
-- 	v1.0.0.0 (28.10.2019):
-- 		- initial Script Fs19 (kevink98)
--
-- Notes:
--
--
-- ToDo:
-- 		Direction of slider (x or y) -> actually its y
--	
--
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui-Slider");

GC_Gui_slider = {};
local GC_Gui_slider_mt = Class(GC_Gui_slider, GC_Gui_element);
-- getfenv(0)["GC_Gui_slider"] = GC_Gui_slider;
g_company.gui.sliderElement = GC_Gui_slider;

function GC_Gui_slider:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_slider_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "slider";

	self.minHeight = GuiUtils.getNormalizedValues("20px", self.outputSize);	
	return self;
end;

function GC_Gui_slider:loadTemplate(templateName, xmlFile, key, overlayName)
	GC_Gui_slider:superClass().loadTemplate(self, templateName, xmlFile, key);	
	
	self.buttonElement = GC_Gui_button:new(self.gui);
	self.buttonElement:loadTemplate(templateName, xmlFile, key);

	self:addElement(self.buttonElement);
	
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

function GC_Gui_slider:setController(table)
	self.controller = table;
	self:updateItems();
end;

function GC_Gui_slider:setPosition(pos)	
	if self.stepsize ~= nil then
		self.buttonElement.sliderPosition[2] = self.stepsize * pos;
	end;
end;

function GC_Gui_slider:moveSlider(x, y)
	self.buttonElement.sliderPosition[2] = math.min(math.max(self.buttonElement.sliderPosition[2] + y, 0), self.size[2] - self.buttonElement.size[2]);	
	self.controller:setPosition(math.floor(self.buttonElement.sliderPosition[2] / self.stepsize));
end;

function GC_Gui_slider:updateItems()
	if self.controller ~= nil then
		if #self.controller.items <= self.controller.maxItemsX * self.controller.maxItemsY then
			self:setVisible(false);
		else
			self:setVisible(true);
			--self.stepsize = self.size[2] / ( 1 + (#self.controller.items - (self.controller.maxItemsX * self.controller.maxItemsY))); --set correct direction!
			if self.controller.maxItemsX > 1 then
				self.stepsize = self.size[2] / math.ceil( 1 + (math.ceil(#self.controller.items / self.controller.maxItemsX) / (self.controller.maxItemsY)));
			else
				self.stepsize = self.size[2] / ( 1 + (#self.controller.items - self.controller.maxItemsY));
			end 
			local size = math.max(self.stepsize, self.minHeight[1]);
			self.buttonElement.size[2] = size;
			if self.buttonElement.overlayElement ~= nil then
				self.buttonElement.overlayElement.size[2] = size;
			end;
		end;
	end;
end;