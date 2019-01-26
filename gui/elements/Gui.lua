-- 
-- Gui
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.05.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_debug.registerMod("GlobalCompany-Gui-Element");

GC_Gui = {};
GC_Gui_mt = Class(GC_Gui);
getfenv(0)["GC_Gui"] = GC_Gui;

function GC_Gui:new(name)	
	local self = setmetatable({}, GC_Gui_mt);
	self.name = name;
	self.rootElement = GC_Gui_element:new();
	
	return self;
end;

function GC_Gui:assignClass(class)
	if self.classGui == nil then
		self.classGui = class;
	end;
end;

function GC_Gui:loadFromXML()
	if self.classGui.xmlFilename == nil then
		g_debug.write(debugIndex, Debug.ERROR, "Gui %s haven't xmlFilename", self.name);
		return;
	end;	

	local xmlFile = loadXMLFile("Temp", self.classGui.xmlFilename);

	if xmlFile == nil or xmlFile == 0 then		
		g_debug.write(debugIndex, Debug.ERROR, "Gui can't load xml %s", self.classGui.xmlFilename);
		return;
	end;
	self:loadFromXMLRec(xmlFile, "GUI", self.rootElement);
	self.classGui:onCreate();
	delete(xmlFile);
end;

function GC_Gui:loadFromXMLRec(xmlFile, key, actGui)
	local i = 0;
	while true do
		local k = string.format("%s.GuiElement(%d)", key, i);
		if not hasXMLProperty(xmlFile, k) then
			break;
		end;
		
		local t = getXMLString(xmlFile, string.format("%s#type", k));		
		local id = getXMLString(xmlFile, string.format("%s#id", k));		
		local templateName = getXMLString(xmlFile, string.format("%s#template", k));			
		local guiElement = nil;
		
		if t == "text" then
			guiElement = GC_Gui_text:new(self.classGui);
		elseif t == "image" then
			guiElement = GC_Gui_overlay:new(self.classGui);
		elseif t == "flowLayout" then
			guiElement = GC_Gui_flowLayout:new(self.classGui);
		elseif t == "button" then
			guiElement = GC_Gui_button:new(self.classGui);
		elseif t == "table" then
			guiElement = GC_Gui_table:new(self.classGui);
		else
			guiElement = GC_Gui_element:new(self.classGui, nil, true);
		end;
		
		guiElement:setParent(actGui);
		guiElement:loadTemplate(templateName, xmlFile, k);
		actGui:addElement(guiElement);
		
		if id ~= nil and id ~= "" then
			self.classGui[id] = guiElement;
		end;
		
		self:loadFromXMLRec(xmlFile, k, guiElement);
		i = i + 1;
	end;
end;


function GC_Gui:delete()

end;


function GC_Gui:deleteElements()
	for _,element in pairs(self.rootElement.elements) do
		element:delete();
	end;
	self.rootElement.elements = {};
end;

function GC_Gui:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	if self.classGui.mouseEvent ~= nil then
		self.classGui:mouseEvent(posX, posY, isDown, isUp, button, eventUsed);
	end;
	self.rootElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed);
end;

function GC_Gui:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	if self.classGui.keyEvent ~= nil then
		self.classGui:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	end;
	self.rootElement:keyEvent(unicode, sym, modifier, isDown, eventUsed);
end;

function GC_Gui:update(dt)
	if self.classGui.update ~= nil then
		self.classGui:update(dt);
	end;
	self.rootElement:update(dt);
end;

function GC_Gui:draw()
	if self.classGui.draw ~= nil then
		self.classGui:draw();
	end;
	self.rootElement:draw();
end;

function GC_Gui:openGui()
	if self.classGui.onOpen ~= nil then
		self.classGui:onOpen();
	end;
	self.rootElement:onOpen();
end;

function GC_Gui:closeGui()
	if self.classGui.onClose ~= nil then
		self.classGui:onClose();
	end;
end;















