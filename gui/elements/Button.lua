-- 
-- Gui - Element - BUTTON 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.05.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_debug.registerMod("GlobalCompany-Gui-Button");

GC_Gui_button = {};

local GC_Gui_button_mt = Class(GC_Gui_button, GC_Gui_element);
getfenv(0)["GC_Gui_button"] = GC_Gui_button;

function GC_Gui_button:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_button_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "button";
	
	self.data = {};
	self.isRoundButton = false;	
	self.isActivable = false;
	self.isActive = false;
	self.mouseDown = false;
	self.mouseEntered = false;
	self.isTableTemplate = false;
	self.isMultiSelect = false;
	
    self.doubleClickInterval = 1000;
    self.doubleClickTime = 0;
	
	return self;
end;

function GC_Gui_button:loadTemplate(templateName, xmlFile, key)
	GC_Gui_button:superClass().loadTemplate(self, templateName, xmlFile, key);
	
	self.isActivable = g_company.gui:getTemplateValueBool(templateName, "isActivable", self.isActivable);
	self.isRoundButton = g_company.gui:getTemplateValueBool(templateName, "isRoundButton", self.isRoundButton);		
	self.isMultiSelect = g_company.gui:getTemplateValueBool(templateName, "isMultiSelect", self.isMultiSelect);		
	self.clickZone = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "clickZone"), self.outputSize, {0,0,0,0,0,0,0,0});
		
	self.callback_onClick = g_company.gui:getTemplateValueXML(xmlFile, "onClick", key, nil);
	self.callback_onDoubleClick = g_company.gui:getTemplateValueXML(xmlFile, "onDoubleClick", key, nil);
	self.callback_onEnter = g_company.gui:getTemplateValueXML(xmlFile, "onEnter", key, nil);
	self.callback_onLeave = g_company.gui:getTemplateValueXML(xmlFile, "onLeave", key, nil);
	
	self.isTableTemplate = g_company.gui:getTemplateValueBoolXML(xmlFile, "isTableTemplate", key, self.isTableTemplate);
	
	if self.isTableTemplate then
		self.parent:setTableTemplate(self);
	end;
	self:loadOnCreate();
end;

function GC_Gui_button:copy(src)
	GC_Gui_button:superClass().copy(self, src);
	
	self.isActivable = src.isActivable;
	self.isRoundButton = src.isRoundButton;
	self.isMultiSelect = src.isMultiSelect;
	self.clickZone = src.clickZone;
	
	self.callback_onClick = src.callback_onClick;
	self.callback_onDoubleClick = src.callback_onDoubleClick;
	self.callback_onEnter = src.callback_onEnter;
	self.callback_onLeave = src.callback_onLeave;
	
	--self.isTableTemplate = src.isTableTemplate;
	self:copyOnCreate();
end;

function GC_Gui_button:delete()
	GC_Gui_button:superClass().delete(self);

end;

function GC_Gui_button:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	if not self:getDisabled() then
		eventUsed = GC_Gui_button:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
				
		local clickZone = {
			self.drawPosition[1] + self.clickZone[1] + self.margin[1], self.drawPosition[2] + self.clickZone[2] + self.margin[4],
			self.drawPosition[1] + self.clickZone[3] + self.margin[1], self.drawPosition[2] + self.clickZone[4] + self.margin[4],
			self.drawPosition[1] + self.clickZone[5] + self.margin[1], self.drawPosition[2] + self.clickZone[6] + self.margin[4], 
			self.drawPosition[1] + self.clickZone[7] + self.margin[1], self.drawPosition[2] + self.clickZone[8] + self.margin[4]
		}
		
		if not eventUsed then
			if g_company.gui:checkClickZone(posX, posY, clickZone, self.isRoundButton) then
				if not self.mouseEntered then
					self.mouseEntered = true;
					self:setSelected(true);
					if self.callback_onEnter ~= nil then
						self.gui[self.callback_onEnter](self.gui, self);
					end;
				end;
				
				if isDown and button == Input.MOUSE_BUTTON_LEFT then
					self.mouseDown = true;
				end;
				
				if isUp and button == Input.MOUSE_BUTTON_LEFT and self.mouseDown then
					self.mouseDown = false;
					if self.isActivable then
						self:setActive(not self.isActive);
					end;
					if self.doubleClickTime <= 0 then
						self.doubleClickTime = self.doubleClickInterval;
					else
						if self.callback_onDoubleClick ~= nil then
							self.gui[self.callback_onDoubleClick](self.gui, self);
						end;
						self.doubleClickTime = 0;
					end;
					
					if self.callback_onClick ~= nil then
						self.gui[self.callback_onClick](self.gui, self);
					end;
				end;
			else
				if self.mouseEntered then
					self.mouseEntered = false;
					if self.isActivable then
						if not self.isActive then
							self:setSelected(false);
						end;
					else
						self:setSelected(false);
					end;					
					if self.callback_onLeave ~= nil then
						self.gui[self.callback_onLeave](self.gui, self);
					end;
				end;
			
			end;
		end;		
	end;	
	return eventUsed;
end;

function GC_Gui_button:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	GC_Gui_button:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);
end;

function GC_Gui_button:update(dt)
	GC_Gui_button:superClass().update(self, dt);
	if self.doubleClickTime > 0 then
		self.doubleClickTime = self.doubleClickTime - dt;
	end;
end;

function GC_Gui_button:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index);	
	GC_Gui_button:superClass().draw(self);
end;

function GC_Gui_button:setActive(state, checkNotParent)
	if state == nil then
		state = false;
	end;
	if not checkNotParent and not self.isMultiSelect and state and self.parent.name == "table" then
		self.parent:setActive(false, self);
	end;
	self.isActive = state;
	self:setSelected(state, true);
end;













