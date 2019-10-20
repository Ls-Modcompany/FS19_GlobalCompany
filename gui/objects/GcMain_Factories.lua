
Gc_Gui_Factories = {}
local Gc_Gui_Factories_mt = Class(Gc_Gui_Factories)
Gc_Gui_Factories.xmlFilename = g_company.dir .. "gui/objects/GcMain_Factories.xml"
Gc_Gui_Factories.debugIndex = g_company.debug:registerScriptName("Gc_Gui_Factories")

function Gc_Gui_Factories:new()
	local self = setmetatable({}, Gc_Gui_Factories_mt)
    
	self.name = "factories"	
	
	self.canChangeName = false
	
	self.backupImage = g_company.dir .. "images/factoryDefault.dds"
	self.backupText = g_company.languageManager:getText("GC_gui_overview")
	self.changeTitleText = g_company.languageManager:getText("GC_gui_changeFactoryTitle")

	self.doSelectedReset = true
	self.canGoToOverview = false

	self.pdaWith = 2048
	if fileExists(g_currentMission.missionInfo.baseDirectory.."modDesc.xml") then
		local path = g_currentMission.missionInfo.baseDirectory .. g_currentMission.missionInfo.mapXMLFilename
		if fileExists(path) then
			local xml = loadXMLFile("map",path,"map")
			self.pdaWith = getXMLInt(xml, "map#width")
			delete(xml)
		end
	end

	self.time = 0

	return self
end

function Gc_Gui_Factories:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	if sym == 13 and isDown then
		self.canGoToOverview = true
	elseif sym == 13 and not isDown and self.canGoToOverview then
		self:onClickOpenOverview();
		self.canGoToOverview = false
	elseif sym == 117 and not isDown then
        self:onClickRenameFactory();
	end;    
end;

function Gc_Gui_Factories:onOpen()
	self.gui_factoryListTable:removeElements()
	local haveFactories = false
	if g_company.loadedFactories ~= nil then
		for _, factory in pairs (g_company.loadedFactories) do
			if factory.showInGlobalGUI and g_currentMission.accessHandler:canFarmAccess(g_currentMission:getFarmId(), factory) then				
				self.currentSetupFactory = factory
				local item = self.gui_factoryListTable:createItem()
				item.factory = factory
				haveFactories = true

				local customTitle = self.currentSetupFactory:getCustomTitle()		
				if customTitle ~= nil and customTitle ~= "" then
					item:setSortName(customTitle)
				else
					item:setSortName(self.currentSetupFactory.guiData.factoryTitle)
				end
			end
		end
		
		self.currentSetupFactory = nil
	end

	self.gui_pdaMarker:setVisible(haveFactories)

	self.gui_tableSort:setSortDirection(1)
	self.gui_tableSort:sortTable(self.gui_factoryListTable)
	self.gui_factoryListTable:selectFirstItem()
	
	self.canChangeName = g_server ~= nil	
	if not self.canChangeName then
		local userId = g_currentMission.playerUserId
		local userFarm = g_farmManager:getFarmByUserId(userId)
		self.canChangeName = userFarm:isUserFarmManager(userId)
	end
	
	self.doSelectedReset = true
end

function Gc_Gui_Factories:onCreateFactoryImageSmall(element)
    if self.currentSetupFactory ~= nil then
		if self.currentSetupFactory.guiData.factoryImage ~= nil then
			element:setImageFilename(self.currentSetupFactory.guiData.factoryImage)
		end
    end
end

function Gc_Gui_Factories:onCreateFactoryTitel(element)
    if self.currentSetupFactory ~= nil then
		local customTitle = self.currentSetupFactory:getCustomTitle()		
		if customTitle ~= nil and customTitle ~= "" then
			element:setText(customTitle, true)
		elseif self.currentSetupFactory.guiData.factoryTitle ~= nil and self.currentSetupFactory.guiData.factoryTitle ~= "" then
			element:setText(self.currentSetupFactory.guiData.factoryTitle, true)
		else
			element:setText("-", true)
		end
    end
end

function Gc_Gui_Factories:onCreateFactorySubTitel(element)
    if self.currentSetupFactory ~= nil then
		local customTitle = self.currentSetupFactory:getCustomTitle()		
		if customTitle ~= nil and customTitle ~= "" then
			element:setText(string.format(" (%s)", self.currentSetupFactory.guiData.factoryTitle), true)
		end
    end
end

function Gc_Gui_Factories:onCreateActiveProductLines(element)
	if self.currentSetupFactory ~= nil then
		local v1 = 0
		for _,line in pairs(self.currentSetupFactory.productLines) do
			if line.active then
				v1 = v1 + 1
			end
		end
		local v2 = table.getn(self.currentSetupFactory.productLines)
		element:setText(string.format("%s / %s", v1, v2))
	end	
end

function Gc_Gui_Factories:onCreateEmptyInputs(element)
	if self.currentSetupFactory ~= nil then
		local v1 = 0
		for _,input in pairs(self.currentSetupFactory.inputProducts) do
			if input.fillLevel == 0 then
				v1 = v1 + 1
			end
		end
		local v2 = table.getn(self.currentSetupFactory.inputProducts)
		element:setText(string.format("%s / %s", v1, v2))
	end	
end

function Gc_Gui_Factories:onCreateFullOutputs(element)
	if self.currentSetupFactory ~= nil then
		local v1 = 0
		for _,output in pairs(self.currentSetupFactory.outputProducts) do
			if output.fillLevel == output.capacity then
				v1 = v1 + 1
			end
		end
		local v2 = table.getn(self.currentSetupFactory.outputProducts)
		element:setText(string.format("%s / %s", v1, v2))
		if v1 > 0 then
			element:setTextColor(1, 0, 0, 1)
			element:setTextColorSelected(1, 0, 0, 1)
		end
	end	
end

function Gc_Gui_Factories:onClickSelectFactory(element)
	self.currentSelectedFactory = element.factory	

	local x,_,y = getWorldTranslation(self.currentSelectedFactory.rootNode)
	local posX = 440 / (self.pdaWith / 2) * x 
	local posY = 440 / (self.pdaWith / 2) * -y
	self.gui_pdaMarker.position = GuiUtils.getNormalizedValues(string.format("%spx %spx", posX, posY), self.gui_pdaMarker.outputSize, self.gui_pdaMarker.position)
end

function Gc_Gui_Factories:onClickOpenOverview()
	local factory = self.currentSelectedFactory
	if factory ~= nil then
		self.doSelectedReset = false
		g_company.gui:closeActiveGui()

		local dialog = g_gui:showDialog("GC_ProductionFactoryDialog")
		if dialog ~= nil then
			dialog.target:setupFactoryData(factory, nil, true)
		end
	end
end

function Gc_Gui_Factories:onClickRenameFactory()
	local factory = self.currentSelectedFactory
	
	if self.canChangeName and factory ~= nil then
		local defaultText = factory:getCustomTitle()
		local confirmText = g_i18n:getText("button_confirm")

		self.doSelectedReset = false
		g_company.gui:closeActiveGui()

		g_gui:showTextInputDialog({
			text = self.changeTitleText,
			defaultText = defaultText,
			maxCharacters = 20,
			disableFilter = false,
			confirmText = confirmText,
			callback = self.setCustomTitle,
			target = self
		})
	end
end

function Gc_Gui_Factories:setCustomTitle(text, applyTitle)
	if applyTitle and self.currentSelectedFactory ~= nil then
		if text == nil or text == "" then
			text = GC_ProductionFactory.BACKUP_TITLE
		end

		self.currentSelectedFactory:setCustomTitle(text)
	end

	g_company.gui:openGui("gc_main")
end

function Gc_Gui_Factories:onClose()
	self.canChangeName = false
	
	if self.doSelectedReset then
		self.currentSelectedFactory = nil
		
		self.gui_factoryListTable:setPosition(0)
		if self.gui_factoryListTable.slider ~= nil then
			self.gui_factoryListTable.slider:setPosition(0)
		end
	end
end

function Gc_Gui_Factories:onCreate()
end

function Gc_Gui_Factories:onClickClose()
    g_company.gui:closeActiveGui()
end

function Gc_Gui_Factories:update(dt)
	self.time = self.time + dt
	if self.time > 1000 then
		self.time = self.time - 1000
	end

	local delta = self.time / 500 * 10
	local sizePx = 10 + delta
	self.gui_pdaMarker.size = GuiUtils.getNormalizedValues(string.format("%spx %spx", sizePx, sizePx), self.gui_pdaMarker.outputSize, self.gui_pdaMarker.size)
end

function Gc_Gui_Factories:onClickChangeSortDirection()
	self.gui_tableSort:changeSortDirection()
	self.gui_tableSort:sortTable(self.gui_factoryListTable)
	self.gui_factoryListTable:scrollTable()
	self.gui_factoryListTable:updateVisibleItems()
	self.gui_factoryListTable.slider:setPosition(0)
end