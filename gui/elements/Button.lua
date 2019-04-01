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
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui-Button");

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
	self.isActivable = true;
	self.isActive = false;
	self.mouseDown = false;
	self.mouseEntered = false;
	self.isTableTemplate = false;
	self.isMultiSelect = false;
	self.checkParent = false;

	self.inputAction = nil;
	self.clickSound = nil;
	
    self.doubleClickInterval = 1000;
    self.doubleClickTime = 0;
	
	return self;
end;

function GC_Gui_button:loadTemplate(templateName, xmlFile, key)
	GC_Gui_button:superClass().loadTemplate(self, templateName, xmlFile, key);
	
	self.isActivable = g_company.gui:getTemplateValueBool(templateName, "isActivable", self.isActivable);
	self.canDeactivable = g_company.gui:getTemplateValueBool(templateName, "canDeactivable", self.canDeactivable);
	self.isRoundButton = g_company.gui:getTemplateValueBool(templateName, "isRoundButton", self.isRoundButton);		
	self.isMultiSelect = g_company.gui:getTemplateValueBool(templateName, "isMultiSelect", self.isMultiSelect);		
	self.checkParent = g_company.gui:getTemplateValueBool(templateName, "checkParent", self.checkParent);		
	self.clickZone = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "clickZone"), self.outputSize, nil);
		
	self.callback_onClick = g_company.gui:getTemplateValueXML(xmlFile, "onClick", key, nil);
	self.callback_onDoubleClick = g_company.gui:getTemplateValueXML(xmlFile, "onDoubleClick", key, nil);
	self.callback_onEnter = g_company.gui:getTemplateValueXML(xmlFile, "onEnter", key, nil);
	self.callback_onLeave = g_company.gui:getTemplateValueXML(xmlFile, "onLeave", key, nil);
	
	self.isTableTemplate = g_company.gui:getTemplateValueBool(templateName, "isTableTemplate", self.isTableTemplate);
	self.hasOverlay = g_company.gui:getTemplateValueBool(templateName, "hasOverlay", false);
	self.hasText = g_company.gui:getTemplateValueBool(templateName, "hasText", false);

	local inputAction = g_company.gui:getTemplateValue(templateName, "inputAction");
	inputAction = g_company.gui:getTemplateValueXML(xmlFile, "inputAction", key, inputAction);
	if inputAction ~= nil and InputAction[inputAction] ~= nil then
		self.inputAction = InputAction[inputAction];
		self.hasText = true;
	end;
	
	if self.hasOverlay then
		self.overlayElement = GC_Gui_overlay:new(self.gui);
		self.overlayElement:loadTemplate(templateName, xmlFile, key);
		self.overlayElement.position = { 0,0 };
		self:addElement(self.overlayElement);
		if id ~= nil and id ~= "" then
			self.gui[id] = self.overlayElement;
		end;
	end;

	if self.hasText then
		self.textElement = GC_Gui_text:new(self.gui);
		self.textElement:loadTemplate(templateName, xmlFile, key);
		self.textElement.position = { 0,0 };
		self:addElement(self.textElement);
		if id ~= nil and id ~= "" then
			self.gui[id] = self.textElement;
		end;
		
		if self.inputAction ~= nil then
			self.textElement:setText(g_inputDisplayManager:getKeyboardInputActionKey(self.inputAction));
		end;
	end;
	
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
	self.canDeactivable = src.canDeactivable;
	self.checkParent = src.checkParent;
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
			
		local clickZone = {};		
		if self.clickZone == nil then
			clickZone[1] = self.drawPosition[1] + self.margin[1];
			clickZone[2] = self.drawPosition[2] + self.size[2] + self.margin[4];
			clickZone[3] = self.drawPosition[1] + self.size[1] + self.margin[1];
			clickZone[4] = self.drawPosition[2] + self.size[2] + self.margin[4];
			clickZone[5] = self.drawPosition[1] + self.size[1]+ self.margin[1];
			clickZone[6] = self.drawPosition[2] + self.margin[4];
			clickZone[7] = self.drawPosition[1] + self.margin[1];
			clickZone[8] = self.drawPosition[2] + self.margin[4];
		else
			if self.isRoundButton then
				clickZone[1] = self.drawPosition[1] + self.clickZone[1] + self.margin[1];
				clickZone[2] = self.drawPosition[2] + self.clickZone[2] + self.margin[4];
				clickZone[3] = self.clickZone[3]
			else
				for i=1, table.getn(self.clickZone), 2 do
					clickZone[i] = self.drawPosition[1] + self.clickZone[i] + self.margin[1];
					clickZone[i+1] = self.drawPosition[2] + self.clickZone[i+1] + self.margin[4];
				end;			
			end;
		end;
		
		if not eventUsed then
			if g_company.gui:checkClickZone(posX, posY, clickZone, self.isRoundButton) then
				if not self.mouseEntered then
					self.mouseEntered = true;
					self:setSelected(true);
					if self.callback_onEnter ~= nil then
						self.gui[self.callback_onEnter](self.gui, self, self.parameter);
					end;
				end;
				
				if isDown and button == Input.MOUSE_BUTTON_LEFT then
					self.mouseDown = true;
				end;
				
				if isUp and button == Input.MOUSE_BUTTON_LEFT and self.mouseDown then
					self.mouseDown = false;
					if self.isActivable then
						if not self.canDeactivable then
							if not self.isActive then
								self:setActive(not self.isActive);
							end;
						else
							self:setActive(not self.isActive);
						end;
					end;
					if self.doubleClickTime <= 0 then
						self.doubleClickTime = self.doubleClickInterval;
					else
						if self.callback_onDoubleClick ~= nil then
							self.gui[self.callback_onDoubleClick](self.gui, self, self.parameter);
						end;
						self.doubleClickTime = 0;
					end;
					
					if self.callback_onClick ~= nil then
						self.gui[self.callback_onClick](self.gui, self, self.parameter);
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
						self.gui[self.callback_onLeave](self.gui, self, self.parameter);
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
	
	
	if self.debugEnabled then
		local xPixel = 1 / g_screenWidth;
		local yPixel = 1 / g_screenHeight;
		setOverlayColor(GuiElement.debugOverlay, 1, 0,0,1)
				
		if self.isRoundButton then
		
			local y = self.clickZone[3] * (g_screenWidth / g_screenHeight);
			renderOverlay(GuiElement.debugOverlay, self.drawPosition[1] + self.clickZone[1] + self.margin[1], self.drawPosition[2] + self.clickZone[2] + self.margin[4], self.clickZone[3],yPixel);
			renderOverlay(GuiElement.debugOverlay, self.drawPosition[1] + self.clickZone[1] + self.margin[1], self.drawPosition[2] + self.clickZone[2] + self.margin[4], xPixel,y);
		else
			local clickZone = {};		
			if self.clickZone == nil then
				clickZone[1] = self.drawPosition[1] + self.margin[1];
				clickZone[2] = self.drawPosition[2] + self.size[2] + self.margin[4];
				clickZone[3] = self.drawPosition[1] + self.size[1] + self.margin[1];
				clickZone[4] = self.drawPosition[2] + self.size[2] + self.margin[4];
				clickZone[5] = self.drawPosition[1] + self.size[1]+ self.margin[1];
				clickZone[6] = self.drawPosition[2] + self.margin[4];
				clickZone[7] = self.drawPosition[1] + self.margin[1];
				clickZone[8] = self.drawPosition[2] + self.margin[4];
			else
				for i=1, table.getn(self.clickZone), 2 do
					clickZone[i] = self.drawPosition[1] + self.clickZone[i] + self.margin[1];
					clickZone[i+1] = self.drawPosition[2] + self.clickZone[i+1] + self.margin[4];
				end;	
			end;	
			
			for i=1, table.getn(clickZone), 2 do
				renderOverlay(GuiElement.debugOverlay, clickZone[i], clickZone[i+1], xPixel*3,yPixel*3);
			end;
		end;
	end
	
	GC_Gui_button:superClass().draw(self);
end;

function GC_Gui_button:setActive(state, checkNotParent)
	if state == nil then
		state = false;
	end;

	if not checkNotParent and not self.isMultiSelect and state and (self.parent.name == "table" or self.checkParent) then
		self.parent:setActive(false, true);
	end;
	self.isActive = state;
	self:setSelected(state, true);
end;

function GC_Gui_button:getActive()
	return self.isActive;
end;

function GC_Gui_button:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter);
	end;
	GC_Gui_button:superClass().onOpen(self);
end;


function GC_Gui_button:setText(...)
	if self.inputAction ~= nil then
		return;
	end;
	for _,v in ipairs(self.elements) do
		if v.setText ~= nil then
			v:setText(...);
		end;
	end;
end;











