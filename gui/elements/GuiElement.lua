-- 
-- Gui - Element - ELEMENT 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.05.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui-Element");

GC_Gui_element = {};
local GC_Gui_element_mt = Class(GC_Gui_element);
-- getfenv(0)["GC_Gui_element"] = GC_Gui_element;
g_company.gui.elementElement = GC_Gui_element;

function GC_Gui_element:new(gui, custom_mt, isOnlyElement)	
	if custom_mt == nil then
        custom_mt = GC_Gui_element_mt;
    end;
	local self = setmetatable({}, custom_mt);
	self.name = "empty";
	self.elements = {};
	self.gui = gui;
	
	self.isOnlyElement = isOnlyElement or false;
	self.position = {0,0}; 
	self.drawPosition = {0,0}; 
	self.size = {1,1};
	self.margin = {0,0,0,0}; --left, top, right, bottom
	self.outputSize = g_company.gui:getOutputSize();
    self.imageSize = {1024, 1024};
	self.visible = true;
	self.disabled = false;
	self.selected = false;
	self.debugEnabled = false;
	self.parameter = false;
	
	self.newLayer = false;	
	
	return self;
end;

function GC_Gui_element:loadTemplate(templateName, xmlFile, key)
	self.anchor = g_company.gui:getTemplateAnchor(templateName);
	self.position = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "position"), self.outputSize, self.position);
	self.size = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "size"), self.outputSize, self.size);
	self.margin = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "margin"), self.outputSize, self.margin);
	self.imageSize = GuiUtils.get2DArray(g_company.gui:getTemplateValue(templateName, "imageSize"), self.imageSize);
	
	self.visible = g_company.gui:getTemplateValueBool(templateName, "visible", self.visible);
	self.disabled = g_company.gui:getTemplateValueBool(templateName, "disabled", self.disabled);
	self.debugEnabled = g_company.gui:getTemplateValueBool(templateName, "debugEnabled", self.debugEnabled);
	self.newLayer = g_company.gui:getTemplateValueBool(templateName, "newLayer", self.newLayer);
		
	if xmlFile ~= nil then
		self.visible = g_company.gui:getTemplateValueBoolXML(xmlFile, "visible", key, self.visible);
		self.disabled = g_company.gui:getTemplateValueBoolXML(xmlFile, "disabled", key, self.disabled);
		
		self.position = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValueXML(xmlFile, "position", key), self.outputSize, self.position);
		self.size = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValueXML(xmlFile, "size", key), self.outputSize, self.size);
		self.margin = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValueXML(xmlFile, "margin", key), self.outputSize, self.margin);
		
		self.anchor = g_company.gui:getTemplateValueXML(xmlFile, "anchor", key, self.anchor);
		self.parameter = g_company.gui:getTemplateValueXML(xmlFile, "parameter", key);
		
		self.callback_onOpen = g_company.gui:getTemplateValueXML(xmlFile, "onOpen", key);
		self.callback_onCreate = g_company.gui:getTemplateValueXML(xmlFile, "onCreate", key);
		self.callback_onDraw = g_company.gui:getTemplateValueXML(xmlFile, "onDraw", key);
	end
	
	if self.isOnlyElement then
		self:loadOnCreate();
	end;
end;

function GC_Gui_element:loadOnCreate()
	if self.callback_onCreate ~= nil then
		self.gui[self.callback_onCreate](self.gui, self, self.parameter);
	end;
end;

function GC_Gui_element:onOpen()
	if self.isOnlyElement and self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter);
	end;
	for _,v in ipairs(self.elements) do
		v:onOpen();
	end;
end;
	
function GC_Gui_element:copy(src)	
	self.anchor = src.anchor;
	self.position = src.position;
	self.size = src.size;
	self.margin = src.margin;
	self.imageSize = src.imageSize;
	
	self.visible = src.visible;
	self.disabled = src.disabled;
	self.debugEnabled = src.debugEnabled;
	
	self.visible = src.visible;
	self.disabled = src.disabled;
	
	self.callback_onCreate = src.callback_onCreate;
	
	--for k,element in pairs(self.elements) do
	--	element:copy(src.elements[k]);
	--end;
	if self.isOnlyElement then
		self:copyOnCreate();
	end;
end;

function GC_Gui_element:copyOnCreate()
	if self.callback_onCreate ~= nil then
		self.gui[self.callback_onCreate](self.gui, self, self.parameter);
	end;
end;

function GC_Gui_element:setParent(parent)
	self.parent = parent;
	if self.isOnlyElement then
		self:copy(parent);
		self.position = {0,0}; 
		self.margin = {0,0,0,0};
	end;
end;

function GC_Gui_element:delete()
	for _,v in ipairs(self.elements) do
		v:delete();
	end;
end;

function GC_Gui_element:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	for _,v in ipairs(self.elements) do
		if v:getVisible() then
			v:mouseEvent(posX, posY, isDown, isUp, button, eventUsed);
		end;
	end;
end;

function GC_Gui_element:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	for _,v in ipairs(self.elements) do
		if v:getVisible() then
			v:keyEvent(unicode, sym, modifier, isDown, eventUsed);
		end;
	end;
end;

function GC_Gui_element:update(dt)
	for _,v in ipairs(self.elements) do
		if v:getVisible() then
			v:update(dt);
		end;
	end;
end;

function GC_Gui_element:draw(index, gui)
	if self.isOnlyElement then
		self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index, gui);
	end;
	if self.newLayer then
		new2DLayer()
	end
	
	if self.debugEnabled then
		local xPixel = 1 / g_screenWidth;
		local yPixel = 1 / g_screenHeight;
		setOverlayColor(GuiElement.debugOverlay, 1, 0,0,1)
		renderOverlay(GuiElement.debugOverlay, self.drawPosition[1]-xPixel, self.drawPosition[2]-yPixel, self.size[1]+2*xPixel, yPixel);
		renderOverlay(GuiElement.debugOverlay, self.drawPosition[1]-xPixel, self.drawPosition[2]+self.size[2], self.size[1]+2*xPixel, yPixel);
		renderOverlay(GuiElement.debugOverlay, self.drawPosition[1]-xPixel, self.drawPosition[2], xPixel, self.size[2]);
		renderOverlay(GuiElement.debugOverlay, self.drawPosition[1]+self.size[1], self.drawPosition[2], xPixel, self.size[2]);
	end

	if self.callback_onDraw ~= nil then
		self.gui[self.callback_onDraw](self.gui, self, self.parameter);
	end;

	for k,v in ipairs(self.elements) do
		if v:getVisible() then
			v:draw(k);
		end;
	end;
end;

function GC_Gui_element:addElement(element)
	if element.parent ~= nil then
		element.parent:removeElement(element)
	end;
	table.insert(self.elements, element)
	element.parent = self;
end;

function GC_Gui_element:removeElement(element)
	for k,e in pairs(self.elements) do
		if e == element then
			table.remove(self.elements, k);
			element.parent = nil;
			break;
		end;
	end;
end;

function GC_Gui_element:removeElements()
	for k,e in pairs(self.elements) do
		e.parent = nil;
	end;
	self.elements = {};
end;

function GC_Gui_element:setDisabled(state)
	if state == nil then
		state = false;
	end;
	self.disabled = state;
	for _,element in pairs(self.elements) do
		element:setDisabled(state);
	end;
end;

function GC_Gui_element:getDisabled()
	return self.disabled;
end;

function GC_Gui_element:setVisible(state)
	if state == nil then
		state = false;
	end;
	self.visible = state;
	for _,element in pairs(self.elements) do
		element:setVisible(state);
	end;
end;

function GC_Gui_element:getVisible()
	return self.visible;
end;

function GC_Gui_element:setSelected(state, noCheckButton)
	if state == nil then
		state = false;
	end;
	self.selected = state;
	for _,element in pairs(self.elements) do
		if noCheckButton then
			if element.name ~= "button" then
				element:setSelected(state);
			end;
		else
			element:setSelected(state);
		end;
	end;
end;

function GC_Gui_element:getIsSelected()
	return self.selected
end;

function GC_Gui_element:getAnchor()
	return self.anchor;
end;

function GC_Gui_element:setPosition(str)
	self.position = GuiUtils.getNormalizedValues(str, self.outputSize, self.position)
end





function GC_Gui_element:getXleft()
	return self.position[1] + self.margin[1];
end;

function GC_Gui_element:getXright()
	return self.position[1] + self.margin[1] + self.size[1];
end;

function GC_Gui_element:getYbottom()
	return self.position[2] + self.margin[2];
end;

function GC_Gui_element:getYtop()
	return self.position[2] + self.margin[2] + self.size[2];
end;

function GC_Gui_element:setSortName(sortName)
	self.sortName = sortName
end















