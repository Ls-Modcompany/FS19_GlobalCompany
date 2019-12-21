-- 
-- GlobalCompany 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 03.08.2019
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.1.0.0 (03.08.2019):
-- 		- fix output size at hight width resolution (3840:1080)
--
-- 	v1.0.0.0 ():
-- 		- initial fs19
-- 
-- Notes:
-- 
-- 
-- ToDo:
-- 		xmlIinformations at fakegui (kevin)
-- 		declare better when input only work on walk or in vehicle or booth

GlobalCompanyGui = {};
g_company.gui = GlobalCompanyGui;

GlobalCompanyGui.debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui");
GlobalCompanyGui.debugData = g_company.debug:getDebugData(GlobalCompanyGui.debugIndex, g_company);

GlobalCompanyGui.DevelopementVersionTemplatesFilename = {};
addModEventListener(GlobalCompanyGui);

GlobalCompanyGui.devVersion = false;

GlobalCompanyGui.guis = {};
GlobalCompanyGui.smallGuis = {};
GlobalCompanyGui.toInit_actionEvents = {};

GlobalCompanyGui.template = {};
GlobalCompanyGui.template.colors = {};
GlobalCompanyGui.template.uvs = {};
GlobalCompanyGui.template.templates = {};
GlobalCompanyGui.template.uiElements = {};

GlobalCompanyGui.gcMenuModSites = {}

GlobalCompanyGui.MULTIDIALOG_MODE_OK = 0;
GlobalCompanyGui.MULTIDIALOG_MODE_YES_NO = 1;
GlobalCompanyGui.MULTIDIALOG_MODE_INPUT = 2;
GlobalCompanyGui.MULTIDIALOG_SIGN_Non = 0;
GlobalCompanyGui.MULTIDIALOG_SIGN_EXCLAMATION = 1;
GlobalCompanyGui.MULTIDIALOG_SIGN_QUESTION = 2;

source(g_currentModDirectory .. "gui/elements/Gui.lua");
source(g_currentModDirectory .. "gui/elements/GuiElement.lua");
source(g_currentModDirectory .. "gui/elements/Text.lua");
source(g_currentModDirectory .. "gui/elements/Overlay.lua");
source(g_currentModDirectory .. "gui/elements/FlowLayout.lua");
source(g_currentModDirectory .. "gui/elements/Button.lua");
source(g_currentModDirectory .. "gui/elements/Borders.lua");
source(g_currentModDirectory .. "gui/elements/Table.lua");
source(g_currentModDirectory .. "gui/elements/Slider.lua");
source(g_currentModDirectory .. "gui/elements/Input.lua");
source(g_currentModDirectory .. "gui/elements/Page.lua");
source(g_currentModDirectory .. "gui/elements/PageSelector.lua");
source(g_currentModDirectory .. "gui/elements/GuiScreen.lua");
source(g_currentModDirectory .. "gui/elements/IngameMap.lua");
source(g_currentModDirectory .. "gui/elements/TableSort.lua");

source(g_currentModDirectory .. "gui/FakeGui.lua");
source(g_currentModDirectory .. "gui/MultiDialog.lua");
--source(g_currentModDirectory .. "gui/objects/Baler.lua");
source(g_currentModDirectory .. "gui/objects/ObjectInfo.lua");
source(g_currentModDirectory .. "gui/objects/GcMain.lua");
source(g_currentModDirectory .. "gui/objects/DynamicStorage.lua");
source(g_currentModDirectory .. "gui/objects/PlaceableDigitalDisplay.lua");

function GlobalCompanyGui:init()	
	for _,inAc in pairs(self.toInit_actionEvents) do
		g_gui.inputManager:registerActionEvent(inAc.inputAction, GlobalCompanyGui, inAc.func, false, true, false, true);
	end;
	FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, GlobalCompanyGui.registerActionEventsVehicle);
end;

function GlobalCompanyGui:registerActionEventsPlayer()
	if g_company.gui.toInit_actionEvents ~= nil then
		for _,inAc in pairs(g_company.gui.toInit_actionEvents) do
			g_gui.inputManager:registerActionEvent(inAc.inputAction, GlobalCompanyGui, inAc.func, false, true, false, true);
		end;
	end;
end;

function GlobalCompanyGui:registerActionEventsVehicle()
	if g_company.gui.toInit_actionEvents ~= nil then
		for _,inAc in pairs(g_company.gui.toInit_actionEvents) do
			if g_currentMission.controlledVehicle ~= nil then
				if inAc.inVehicle then
					g_gui.inputManager:registerActionEvent(inAc.inputAction, GlobalCompanyGui, inAc.func, false, true, false, true);
				end
			else
				g_gui.inputManager:registerActionEvent(inAc.inputAction, GlobalCompanyGui, inAc.func, false, true, false, true);
			end
		end;
	end;
end;

function GlobalCompanyGui:getIsDev()
	return g_company.debug:getIsDev() and GlobalCompanyGui.devVersion;
end;

function GlobalCompanyGui:loadMap()
	if g_company.debug:getIsDev() then
		addConsoleCommand("gcGuiReload", "Reload all templates.", "consoleCommandReloadTemplates", g_company.gui);
		addConsoleCommand("gcGuiDevMode", "Set the state GUI Development Mode. [state]", "consoleCommandEnableDevVersion", g_company.gui);
	end;
end;

function GlobalCompanyGui:load()	
	-- self.fakeGui = GC_Gui_FakeGui:new();
	self.fakeGui = g_company.gui.fakeGui:new();
	g_gui:loadGui(g_company.dir .. self.fakeGui.guiInformations.guiXml, "gc_fakeGui", self.fakeGui);
	
	g_company.gui:registerUiElements("g_factoryDefault", g_company.dir .. "images/factoryDefault.dds");
	g_company.gui:registerUiElements("g_gcUi2", g_company.dir .. "images/ui_elements_2.dds");
	
	self.mainGui = g_company.gui:registerGui("gc_main", InputAction.GC_MAIN, Gc_Gui_MainGui, true, true, true).classGui;
	g_company.gui:registerGui("gc_multiDialog", nil, GC_Gui_MultiDialog, true, true);
	--g_company.gui:registerGui("gcPlaceable_baler", nil, Gc_Gui_Baler, true, true);
	g_company.gui:registerGui("gcObjectInfo", nil, Gc_Gui_ObjectInfo, false, false, false);
	g_company.gui:registerGui("gc_dynamicStorage", nil, Gc_Gui_DynamicStorage, true, true, true);
	g_company.gui:registerGui("gc_placeableDigitalDisplay", nil, Gc_Gui_PlaceableDigitalDisplay, true, true, false);
	
	self.activeGuiDialogs = {};
	self.registeredActonEvents = false;
end;

function GlobalCompanyGui:update(dt)
	if GlobalCompanyGui:getIsDev() then
		if self.DevelopementVersionTimer == nil or self.DevelopementVersionTimer <= 0 then
			for _, fileName in pairs(GlobalCompanyGui.DevelopementVersionTemplatesFilename) do				
				self:loadGuiTemplates(fileName);
			end;
			for name,gui in pairs(self.guis) do		
				gui.gui:deleteElements();
				gui.gui:loadFromXML();
			end;
			if self.activeGui ~= nil then
				self.guis[self.activeGui].gui:openGui();
			else
				for name, open in pairs(self.smallGuis) do
					if open then
						self.guis[name].gui:openGui();
					end;
				end; 
			end;
			if self.activeGuiDialog ~= nil then
				self.guis[self.activeGuiDialog].gui:openGui();
			end;
			self.DevelopementVersionTimer = 70;
		else
			self.DevelopementVersionTimer = self.DevelopementVersionTimer - 1;
		end;		
	end;
	
	if self.activeGui == nil then
		for name, open in pairs(self.smallGuis) do
			if open then
				self.guis[name].gui:update(dt);
			end;
		end;
	else
		if g_gui:getIsDialogVisible() then
			self:closeGui(self.activeGui);
		else
			self.guis[self.activeGui].gui:update(dt);
		end;
	end;
	for _, name in pairs(GlobalCompanyGui.activeGuiDialogs) do
		GlobalCompanyGui.guis[name].gui:update(dt);
	end;
end;

function GlobalCompanyGui:mouseEvent(posX, posY, isDown, isUp, button) 
	if self.activeGuiDialog ~= nil then
		GlobalCompanyGui.guis[self.activeGuiDialog].gui:mouseEvent(posX, posY, isDown, isUp, button);
	elseif self.activeGui == nil then
		--for name, open in pairs(self.smallGuis) do
		--	if open then
		--		self.guis[name].gui:mouseEvent(posX, posY, isDown, isUp, button);
		--	end;
		--end;
	else
		self.guis[self.activeGui].gui:mouseEvent(posX, posY, isDown, isUp, button);
	end;
end;

function GlobalCompanyGui:keyEvent(unicode, sym, modifier, isDown) 
	if self.activeGuiDialog ~= nil then
		GlobalCompanyGui.guis[self.activeGuiDialog].gui:keyEvent(unicode, sym, modifier, isDown);
	elseif self.activeGui == nil then
		for name, open in pairs(self.smallGuis) do
			if open then
				self.guis[name].gui:keyEvent(unicode, sym, modifier, isDown);
			end;
		end;
	else
		self.guis[self.activeGui].gui:keyEvent(unicode, sym, modifier, isDown);
	end;
end;

function GlobalCompanyGui:draw() end;
function GlobalCompanyGui:drawB()
	if GlobalCompanyGui.activeGui == nil then
		-- if g_gui.currentGui == nil then
		if not g_gui:getIsGuiVisible() then
			for name, open in pairs(GlobalCompanyGui.smallGuis) do
				if open then
					GlobalCompanyGui.guis[name].gui:draw();
				end;
			end;
		end;
	else
		GlobalCompanyGui.guis[GlobalCompanyGui.activeGui].gui:draw();
	end;
	for _, name in pairs(GlobalCompanyGui.activeGuiDialogs) do
		GlobalCompanyGui.guis[name].gui:draw();
	end;
end;

function GlobalCompanyGui:consoleCommandReloadTemplates()
	for _, fileName in pairs(GlobalCompanyGui.DevelopementVersionTemplatesFilename) do				
		self:loadGuiTemplates(fileName, true);
	end;
	
	for name,gui in pairs(self.guis) do				
		gui.gui:deleteElements();
		gui.gui:loadFromXML();
	end;
	
	if self.activeGui ~= nil then
		self.guis[self.activeGui].gui:openGui();
	end

	return "[GlobalCompany > GlobalCompanyGui] - All Gui Templates reloaded successfully.";
end;

function GlobalCompanyGui:consoleCommandEnableDevVersion(state)	
	local value = Utils.stringToBoolean(state);
	GlobalCompanyGui.devVersion = value;

	if value then
		return "[GlobalCompany > GlobalCompanyGui] - Development mode enabled!";
	else
		return "[GlobalCompany > GlobalCompanyGui] - Development mode disabled!";
	end;
end;

function GlobalCompany:deleteMap() 
	self:delete();
end;

function GlobalCompanyGui:delete()
	if g_company.debug:getIsDev() then
		removeConsoleCommand("gcGuiReload");
		removeConsoleCommand("gcGuiDevMode");
	end;
end;

function GlobalCompanyGui:loadGui(class, name)
	if self.guis[name] ~= nil then
		g_company.debug.write(debugIndex, Debug.ERROR, "Gui %s already exist.", name);
		return;
	else 
		self.guis[name] = {};
	end;

	local classGui = class:new();
	local newGui = GC_Gui:new(name);
	newGui:assignClass(classGui);
	self.guis[name].gui = newGui;
	newGui:loadFromXML();
	return newGui;
end;

function GlobalCompanyGui:registerGui(name, inputAction, class, isFullGui, canExit, inVehicle)
	if self.guis[name] ~= nil then
		g_company.debug:writeError(g_company.gui.debugData, "Gui %s already exist.", name); --gui
		return;
	else 
		self.guis[name] = {};
	end;
	
	local classGui = class:new();
	local newGui = GC_Gui:new(name);
	newGui:assignClass(classGui);
	self.guis[name].gui = newGui;
	self.guis[name].isFullGui = Utils.getNoNil(isFullGui, true);
	self.guis[name].canExit = canExit;
	--self.guis[name].onWalkActive = onWalkActive;
		
	if not self.guis[name].isFullGui then
		self.smallGuis[name] = false;		
	end;
	
	if inputAction ~= nil then
		local func = function() GlobalCompanyGui:openGui(name) end;	
		table.insert(self.toInit_actionEvents, {inputAction=inputAction, func=func, inVehicle=inVehicle});
	end;
	
	newGui:loadFromXML();
	
	return newGui;
end;

function GlobalCompanyGui:setCanExit(name, canExit)
	if self.guis[name] ~= nil then
		self.guis[name].canExit = canExit
	end
end

function GlobalCompanyGui:unregisterGui()
	if self.guis[name] ~= nil then
		self.guis[name].gui:delete();
		self.guis[name] = nil;
	end;
end;

function GlobalCompanyGui:openGui(name, asDialog)
	if not asDialog then
		self:closeActiveGui();
	end;
	
	if self.guis[name] == nil then
		g_company.debug:writeError(g_company.gui.debugData, "Gui %s not exist.", name); --gui
		return;
	end;
	if self.guis[name].isFullGui then
		g_gui:showGui("gc_fakeGui");
		self.fakeGui:setExit(self.guis[name].canExit);
		
		if not asDialog then
			for nameG,_ in pairs(self.smallGuis) do
				self.guis[nameG].gui:closeGui();
			end;
			
			self.activeGui = name;
		end;
	else
		self.smallGuis[name] = true;
	end;
	self.guis[name].gui:openGui();
end;

function GlobalCompanyGui:getGuiForOpen(name, asDialog)
	if self.guis[name] == nil then
		g_company.debug:writeError(g_company.gui.debugData, "Gui %s not exist.", name); --gui
		return;
	end;
	if self.guis[name].isFullGui then
		g_gui:showGui("gc_fakeGui");
		self.fakeGui:setExit(self.guis[name].canExit);
		
		if asDialog then
			table.insert(self.activeGuiDialogs, name);
			self.activeGuiDialog = name;
		else
			for nameG,_ in pairs(self.smallGuis) do
				self.guis[nameG].gui:closeGui();
			end;
			
			self.activeGui = name;
		end;
	else
		self.smallGuis[name] = true;
	end;
	return self.guis[name].gui;
end;

function GlobalCompanyGui:getGui(name)
	return self.guis[name].gui;
end;

function GlobalCompanyGui:openGuiWithData(guiName, asDialog, ...)
	local gui = self:getGuiForOpen(guiName, asDialog);
	gui.classGui:setData(...);
	gui:openGui();
	return gui;
end

function GlobalCompanyGui:updateGuiData(guiName, ...)
	if self.activeGui == guiName then
		self.guis[guiName].gui.classGui:updateData(...);
	end;
end

function GlobalCompanyGui:openMultiDialog(...)
	local gui = self:getGuiForOpen("gc_multiDialog", true);
	gui.classGui:setData(...);
	gui:openGui();
end


function GlobalCompanyGui:closeGui(name)
	if self.guis[name].isFullGui then
		for nameG,open in pairs(self.smallGuis) do
			if open then
				self.guis[nameG].gui:openGui();
			end;
		end;
		self.activeGui = nil;
		self.fakeGui:setExit(true);
		self.guis[name].gui:closeGui();
		g_gui:showGui("");
	else
		self.smallGuis[name] = false;
	end;	
end;

function GlobalCompanyGui:closeActiveGui(guiName, ...)
	if self.activeGui ~= nil then
		self:closeGui(self.activeGui);
	end;
	if guiName ~= nil then
		self:openGuiWithData(guiName, ...)
	end
end;

function GlobalCompanyGui:getGuiIsOpen(guiName)
	return self.activeGui ~= nil and self.activeGui == guiName;
end;

function GlobalCompanyGui:closeActiveDialog()
	if self.activeGuiDialog ~= nil then
		self.guis[self.activeGuiDialog].gui:closeGui();
		table.remove(self.activeGuiDialogs, #self.activeGuiDialogs);
		self.activeGuiDialog = nil;	
		for _,dialogName in pairs(self.activeGuiDialogs) do
			self.activeGuiDialog = dialogName;
		end;
	end;
end;

function GlobalCompanyGui:getGuiFromName(name)
	return self.guis[name].gui;
end;

function GlobalCompanyGui:loadGuiTemplates(xmlFilename, noWarning)
    local showWarnings = true;
	if GlobalCompanyGui:getIsDev() or noWarning == true then
		showWarnings = false;
	end;
	
	local xmlFile = loadXMLFile("Temp", xmlFilename);

	if xmlFile == nil or xmlFile == 0 then		
		g_company.debug:writeError(g_company.gui.debugData, "Gui can't load templates %s", xmlFilename);--gui
		return;
	end;
	
	GlobalCompanyGui.DevelopementVersionTemplatesFilename[xmlFilename] = xmlFilename;
	
	local i = 0;
	while true do
		local key = string.format("guiTemplates.colors.color(%d)", i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;
		local name = getXMLString(xmlFile, string.format("%s#name", key));
		local value = getXMLString(xmlFile, string.format("%s#value", key));
		
		if name == nil or name == "" then			
			g_company.debug:writeError(g_company.gui.debugData, "Gui template haven't name at %s", key);--gui
			break;
		end;
		if GlobalCompanyGui.template.colors[name] ~= nil and showWarnings then	
			g_company.debug:writeError(g_company.gui.debugData, "Gui template colour %s already exist", name);--gui
			break;
		end;
		
		if value == nil or value == "" then			
			g_company.debug:writeError(g_company.gui.debugData, "Gui template haven't value at %s", key);--gui
			break;
		end;
		
		local r,g,b,a = unpack(g_company.utils.splitString(value, " "));
		if r == nil or g == nil or b == nil or a == nil then		
			g_company.debug:writeError(g_company.gui.debugData, "Gui template haven't correct color at %s", key); --gui
			break;
		end;
		
		GlobalCompanyGui.template.colors[name] = {tonumber(r), tonumber(g), tonumber(b), tonumber(a)};
		i = i + 1;
	end;
	
	if hasXMLProperty(xmlFile, "guiTemplates.uvs") then
		i = 0;
		while true do
			local key = string.format("guiTemplates.uvs.uv(%d)", i);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;
			local name = getXMLString(xmlFile, string.format("%s#name", key));
			local value = getXMLString(xmlFile, string.format("%s#value", key));
			
			if name == nil or name == "" then			
				g_company.debug:writeError(g_company.gui.debugData, "Gui template haven't name at %s", key);--gui
				break;
			end;
			if GlobalCompanyGui.template.uvs[name] ~= nil and showWarnings then	
				g_company.debug:writeError(g_company.gui.debugData, "Gui template uv %s already exist", name);--gui
				break;
			end;
			
			if value == nil or value == "" then			
				g_company.debug:writeError(g_company.gui.debugData, "Gui template haven't value at %s", key);--gui
				break;
			end;
			
			--local x,y,wX,wY = unpack(g_company.utils.splitString(value:replace(, " "));
			--if x == nil or y == nil or wX == nil or wY == nil then		
			--	g_debug.writeError(g_company.gui.debugData, "Gui template haven't correct uv at %s", key);
			--	break;
			--end;
			
			GlobalCompanyGui.template.uvs[name] = value;
		i = i + 1;
		end;
	end;
	
	i = 0;
	while true do
		local key = string.format("guiTemplates.templates.template(%d)", i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;
		local name = getXMLString(xmlFile, string.format("%s#name", key));
		local anchor = getXMLString(xmlFile, string.format("%s#anchor", key));
		local extends = getXMLString(xmlFile, string.format("%s#extends", key));
		
		if name == nil or name == "" then			
			g_company.debug:writeError(g_company.gui.debugData, "Gui template haven't name at %s", key); --gui
			break;
		end;
		if GlobalCompanyGui.template.templates[name] ~= nil and showWarnings then	
			g_company.debug:writeError(g_company.gui.debugData, "Gui template template %s already exist", name); --gui
			break;
		end;
		
		if anchor == nil or anchor == "" then			
			anchor = "middleCenter";
		end;
		
		GlobalCompanyGui.template.templates[name] = {};
		GlobalCompanyGui.template.templates[name].anchor = anchor;
		GlobalCompanyGui.template.templates[name].values = {};
		GlobalCompanyGui.template.templates[name].extends = {};		
		
		if extends ~= nil and extends ~= "" then
			GlobalCompanyGui.template.templates[name].extends = g_company.utils.splitString(extends, " ");
		end;
		
		local j = 0;
		while true do
			local key = string.format("guiTemplates.templates.template(%d).value(%d)", i, j);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;
			
			local nameV = getXMLString(xmlFile, string.format("%s#name", key));
			local valueV = getXMLString(xmlFile, string.format("%s#value", key));
			
			if nameV ~= nil and nameV ~= "" and valueV ~= nil and valueV ~= "" then
				if GlobalCompanyGui.template.templates[name].values[nameV] ~= nil and showWarnings then	
					g_company.debug:writeError(g_company.gui.debugData, "Gui template template %s already exist", nameV); --gui
					break;
				end;
				GlobalCompanyGui.template.templates[name].values[nameV] = valueV;
			else
				g_company.debug:writeError(g_company.gui.debugData, "Gui template template error at %s", key); --gui
			end;				
			j = j + 1;
		end;
		i = i + 1;
	end;
end;

function GlobalCompanyGui:registerUiElements(name, path)
	GlobalCompanyGui.template.uiElements[name] = path;
end;

function GlobalCompanyGui:getUiElement(name)
	return GlobalCompanyGui.template.uiElements[name];
end;

function GlobalCompanyGui:getTemplateValueParents(templateName, valueName)
	if GlobalCompanyGui.template.templates[templateName] ~= nil then
		local val;
		for _,extend in pairs(GlobalCompanyGui.template.templates[templateName].extends) do
			local rVal = self:getTemplateValue(extend, valueName, nil, true);
			if rVal ~= nil then
				val = rVal;
				break;
			end;
		end;
		if val ~= nil then
			return val;
		end;
		for _,extend in pairs(GlobalCompanyGui.template.templates[templateName].extends) do
			local rVal = self:getTemplateValueParents(extend, valueName, nil);
			if rVal ~= nil then
				val = rVal;
				break;
			end;
		end;
		return val;
	end;
	return nil;
end;

function GlobalCompanyGui:getTemplateValue(templateName, valueName, default, ignoreExtends)
	if GlobalCompanyGui.template.templates[templateName] ~= nil then
		if GlobalCompanyGui.template.templates[templateName].values[valueName] ~= nil then
			return GlobalCompanyGui.template.templates[templateName].values[valueName];
		elseif not ignoreExtends then
			local parentV = self:getTemplateValueParents(templateName, valueName);
			if parentV ~= nil then
				return parentV;
			else
				return default;
			end;
		else
			return default;
		end;
	else
		return default;
	end;
end;

function GlobalCompanyGui:getTemplateValueBool(templateName, valueName, default)
	local val = self:getTemplateValue(templateName, valueName)
	if val ~= nil then
		return val:lower() == "true";
	end;
	return default;
end;

function GlobalCompanyGui:getTemplateValueNumber(templateName, valueName, default)
	local val = self:getTemplateValue(templateName, valueName, default)
	if val ~= nil and val ~= "nil" then
		return tonumber(val);
	end;
	return default;
end;

function GlobalCompanyGui:getTemplateValueColor(templateName, valueName, default)
	local var = g_company.gui:getTemplateValue(templateName, valueName);
	
	if GlobalCompanyGui.template.colors[var] ~= nil then
		return GlobalCompanyGui.template.colors[var];
	else
		return GuiUtils.getColorArray(var, default);
	end;
end;

function GlobalCompanyGui:getTemplateValueUVs(templateName, valueName, imageSize, default)
	local var = g_company.gui:getTemplateValue(templateName, valueName);
	
	if GlobalCompanyGui.template.uvs[var] ~= nil then
		return GuiUtils.getUVs(GlobalCompanyGui.template.uvs[var], imageSize, default);
	else
		return GuiUtils.getUVs(var, imageSize, default);
	 end;
end;

function GlobalCompanyGui:getTemplateValueXML(xmlFile, name, key, default)
	local val = getXMLString(xmlFile, string.format("%s#%s", key, name));	
	if val ~= nil then
		return val;
	end;
	return default;
end;

function GlobalCompanyGui:getTemplateValueNumberXML(xmlFile, name, key, default)
	local val = getXMLString(xmlFile, string.format("%s#%s", key, name));	
	if val ~= nil then
		return tonumber(val);
	end;
	return default;
end;

function GlobalCompanyGui:getTemplateValueBoolXML(xmlFile, name, key, default)
	local val = getXMLString(xmlFile, string.format("%s#%s", key, name));	
	if val ~= nil then
		return val:lower() == "true";
	end;
	return default;
end;

function GlobalCompanyGui:getTemplateAnchor(templateName)
	if GlobalCompanyGui.template.templates[templateName] ~= nil then
		return GlobalCompanyGui.template.templates[templateName].anchor;
	else
		return "middleCenter";
	end;
end;

function GlobalCompanyGui:calcDrawPos(element, index)
	local x,y;	
	local anchor = element:getAnchor():lower();
	local isLeft = g_company.utils.find(anchor, "left");
	local isMiddle = g_company.utils.find(anchor, "middle");
	local isRight = g_company.utils.find(anchor, "right");
	local isTop = g_company.utils.find(anchor, "top");
	local isCenter = g_company.utils.find(anchor, "center");
	local isBottom = g_company.utils.find(anchor, "bottom");	
	
	if element.parent.name == "flowLayout" then
		if element.parent.orientation == GC_Gui_flowLayout.ORIENTATION_X then			
			if element.parent.alignment == GC_Gui_flowLayout.ALIGNMENT_LEFT then
				x = 0;
				for i, elementF in pairs(element.parent.elements) do
					if i == index then
						break;
					else
						x = x + elementF.size[1] + elementF.margin[1] + elementF.margin[3] + elementF.position[1];
					end;
				end;
				
				x = x + element.parent.drawPosition[1] + element.margin[1] + element.position[1];					
			elseif element.parent.alignment == GC_Gui_flowLayout.ALIGNMENT_MIDDLE then			
				local fullSize = 0;
				for i, elementF in pairs(element.parent.elements) do
					fullSize = fullSize + elementF.size[1] + elementF.margin[1] + elementF.margin[3] + elementF.position[1];
				end;	
				local leftToStart = (element.parent.size[1] - fullSize) / 2;
				
				x = 0;
				for i, elementF in pairs(element.parent.elements) do
					if i == index then
						break;
					else
						x = x + elementF.size[1] + elementF.margin[1] + elementF.margin[3];
					end;
				end;

				x = x + leftToStart + element.parent.drawPosition[1] + element.margin[1] + element.position[1];			
			elseif element.parent.alignment == GC_Gui_flowLayout.ALIGNMENT_RIGHT then			
				x = 0;
				local search = true;
				for i, elementF in pairs(element.parent.elements) do
					if search then
						if i == index then
							search = false;
						end;
					else
						x = x + elementF.size[1] + elementF.margin[1] + elementF.margin[3] + elementF.position[1];
					end;
				end;
				
				x = element.parent.drawPosition[1] + element.parent.size[1] - element.margin[3] - element.size[1] + element.position[1] - x;	
			end;
			
			if isTop then
				y = element.parent.drawPosition[2] + element.parent.size[2] - element.margin[2] - element.size[2] + element.position[2];
			elseif isCenter then
				y = element.parent.drawPosition[2] + (element.parent.size[2] * 0.5) + element.position[2] - (element.size[2] * 0.5);
			elseif isBottom then
				y = element.parent.drawPosition[2] + element.margin[4] + element.position[2];
			end;
		elseif element.parent.orientation == GC_Gui_flowLayout.ORIENTATION_Y then		
			if element.parent.alignment == GC_Gui_flowLayout.ALIGNMENT_TOP then
				y = 0;
				for i, elementF in pairs(element.parent.elements) do
					if i == index then
						break;
					else
						if elementF.name == "text" then							
							y = y + elementF:getTextHeight() + elementF.margin[2] + elementF.margin[4] + elementF.position[1];
						else
							y = y + elementF.size[2] + elementF.margin[2] + elementF.margin[4] + elementF.position[1];
						end;
					end;
				end;
				
				y = element.parent.drawPosition[2] + element.parent.size[2] - y - element.size[2] - element.margin[2] + element.position[2];	
			elseif element.parent.alignment == GC_Gui_flowLayout.ALIGNMENT_CENTER then
				local fullSize = 0;
				for i, elementF in pairs(element.parent.elements) do
					fullSize = fullSize + elementF.size[2] + elementF.margin[2] + elementF.margin[4];
				end;	
				local topToStart = (element.parent.size[2] - fullSize) / 2;
				
				y = 0;
				for i, elementF in pairs(element.parent.elements) do
					if i == index then
						break;
					else
						if elementF.name == "text" then							
							y = y + elementF:getTextHeight() + elementF.margin[2] + elementF.margin[4] + elementF.position[1];
						else
							y = y + elementF.size[2] + elementF.margin[2] + elementF.margin[4] + elementF.position[1];
						end;
					end;
				end;
				
				y = element.parent.drawPosition[2] + element.parent.size[2] - topToStart - y - element.size[2] - element.margin[2] + element.position[2];			
			elseif element.parent.alignment == GC_Gui_flowLayout.ALIGNMENT_BOTTOM then
				local fullSize = 0;
				for i, elementF in pairs(element.parent.elements) do
					fullSize = fullSize + elementF.size[2] + elementF.margin[2] + elementF.margin[4];
				end;	
				local topToStart = element.parent.size[2] - fullSize;
				
				y = 0;
				for i, elementF in pairs(element.parent.elements) do
					if i == index then
						break;
					else
						if elementF.name == "text" then							
							y = y + elementF:getTextHeight() + elementF.margin[2] + elementF.margin[4] + elementF.position[1];
						else
							y = y + elementF.size[2] + elementF.margin[2] + elementF.margin[4] + elementF.position[1];
						end;
					end;
				end;
				
				y = element.parent.drawPosition[2] + element.parent.size[2] - topToStart - y - element.size[2] - element.margin[2] + element.position[2];		
			end;
		
			if isLeft then
				x = element.parent.drawPosition[1] + element.margin[1] + element.position[1];
			elseif isMiddle then
				x = element.parent.drawPosition[1] + (element.parent.size[1] * 0.5) + element.position[1]  - (element.size[1] * 0.5);
			elseif isRight then
				x = element.parent.drawPosition[1] + element.parent.size[1] - element.margin[3] - element.size[1] + element.position[1];
			end;
		end;
	elseif element.parent.name == "table" and element.name ~= "slider" then
		if element.parent.orientation == GC_Gui_table.ORIENTATION_X then				
			local xRow = math.floor((index - 1) / element.parent.maxItemsY);
			local yRow = (index - 1) % element.parent.maxItemsY;
			
			x = element.parent.drawPosition[1] + xRow * (element.margin[1] + element.size[1] + element.margin[3]) + element.margin[1];
			y = element.parent.drawPosition[2] + element.parent.size[2] - (yRow) * (element.margin[2] + element.size[2] + element.margin[4]) - element.margin[2] - element.size[2];
		elseif element.parent.orientation == GC_Gui_table.ORIENTATION_Y then	
			
			local yRow = math.floor((index - 1) / element.parent.maxItemsX);
			local xRow = (index - 1) % element.parent.maxItemsX;
			
			x = element.parent.drawPosition[1] + xRow * (element.margin[1] + element.size[1] + element.margin[3]) + element.margin[1];
			y = element.parent.drawPosition[2] + element.parent.size[2] - (yRow) * (element.margin[2] + element.size[2] + element.margin[4]) - element.margin[2] - element.size[2];
			
			
		end;
	else
		if isLeft then
			x = element.parent.drawPosition[1] + element.margin[1] + element.position[1];
		elseif isMiddle then
			x = element.parent.drawPosition[1] + (element.parent.size[1] * 0.5) + element.position[1]  - (element.size[1] * 0.5) + element.margin[1];
		elseif isRight then
			x = element.parent.drawPosition[1] + element.parent.size[1] - element.margin[3] - element.size[1] + element.position[1];
		end;
		
		if isTop then
			y = element.parent.drawPosition[2] + element.parent.size[2] - element.margin[2] - element.size[2] + element.position[2];
		elseif isCenter then
			y = element.parent.drawPosition[2] + (element.parent.size[2] * 0.5) + element.position[2] - (element.size[2] * 0.5) + element.margin[2];
		elseif isBottom then
			y = element.parent.drawPosition[2] + element.margin[4] + element.position[2];
		end;
	end;
	
	
	if x == nil or y == nil then
		--error
		x = 0;
		y = 0;
	end;

	return x,y;
end;

function GlobalCompanyGui:getOutputSize()
	--[[
	if g_screenWidth == 640 then                                                     
		return GlobalCompanyGui:getSizeWithFactor(3);
	elseif g_screenWidth == 800 then                                                          
		return GlobalCompanyGui:getSizeWithFactor(2.4);
	elseif g_screenWidth == 1024 then                                                         
		return GlobalCompanyGui:getSizeWithFactor(1.875);
	elseif g_screenWidth == 1152 then                                                       
		return GlobalCompanyGui:getSizeWithFactor(1.6667);
	elseif g_screenWidth == 1280 then                                                        
		return GlobalCompanyGui:getSizeWithFactor(1.5);
	elseif g_screenWidth == 1360 then                                                        
		return GlobalCompanyGui:getSizeWithFactor(1.4117);
	elseif g_screenWidth == 1366 then                                                         
		return GlobalCompanyGui:getSizeWithFactor(1.4055);
	elseif g_screenWidth == 1400 then                                                        
		return GlobalCompanyGui:getSizeWithFactor(1.3714);
	elseif g_screenWidth == 1440 then                                                          
		return GlobalCompanyGui:getSizeWithFactor(1.3333);
	elseif g_screenWidth == 1600 then                                                          
		return GlobalCompanyGui:getSizeWithFactor(1.2);
	elseif g_screenWidth == 1680 then                                                          
		return GlobalCompanyGui:getSizeWithFactor(1.1428);
	elseif g_screenWidth == 1920 then                                                          
		return GlobalCompanyGui:getSizeWithFactor(1);
	end;
	]]--
	

	--old
	--local factor =  1920 / g_screenWidth;
	--return {g_screenWidth * factor, g_screenHeight * factor};
	
	local factor =  1920 / g_screenWidth;
	if g_screenWidth / 2 > g_screenHeight then
		factor =  1080 / g_screenHeight;
	end;
	return {g_screenWidth * factor, g_screenHeight * factor};





	--test
	--if g_screenWidth / g_screenHeight > 2.3333 then
	--	local factor =  g_screenWidth / g_screenHeight;
	--	return {g_screenWidth * factor, g_screenHeight * factor};
	--else
		--local factor =  1920 / g_screenWidth;
		--return {g_screenWidth * factor, g_screenHeight * factor};
	--end;
end

--[[
function GlobalCompanyGui:getSizeWithFactor(factor)
	return {g_screenWidth * factor, g_screenHeight * factor};
end
]]--

-- http://alienryderflex.com/polygon/
function GlobalCompanyGui:checkClickZone(x,y, clickZone, isRound)		
	if isRound then	
		local dx = math.abs(clickZone[1] - x);
		local dy = math.abs(clickZone[2] - y);	
		return math.sqrt(dx*dx + dy*dy) <= clickZone[3];		
	else	
		local polyX = {}
		local polyY = {};
		
		local num = table.getn(clickZone);
		
		for i=1, num do
			if i % 2 == 0 then
				table.insert(polyY, clickZone[i]);
			else
				table.insert(polyX, clickZone[i]);
			end;
		end;
		
		num = num / 2;
		
		local j = num;
		local insert = false;
		
		for i=1, num do
			if polyY[i]< y and polyY[j]>=y or polyY[j]< y and polyY[i]>=y then
				if polyX[i] + (y-polyY[i]) / (polyY[j]-polyY[i])*(polyX[j]-polyX[i]) < x then
					insert = not insert;
				end;
			end;
			j=i;
		end;		
		return insert;
	end;
end;

function GlobalCompanyGui:checkClickZoneNormal(x,y, drawX, drawY, sX, sY)
	return x > drawX and y > drawY and x < drawX + sX and y < drawY + sY;
end;

function GlobalCompanyGui:registerSiteForGcMenu(imageFilename, imageUVs, gui)
	table.insert(GlobalCompanyGui.gcMenuModSites, {imageFilename=imageFilename, imageUVs=imageUVs, gui=gui, added=false})
end

g_company.gui:loadGuiTemplates(g_company.dir .. "gui/guiTemplates.xml");
g_company.addInit(GlobalCompanyGui, GlobalCompanyGui.init);
BaseMission.draw = Utils.appendedFunction(BaseMission.draw, GlobalCompanyGui.drawB);