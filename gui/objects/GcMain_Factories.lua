
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

	return self
end

function Gc_Gui_Factories:onOpen()
	self.gui_factoryListTable:removeElements()

	if g_company.loadedFactories ~= nil then
		for _, factory in pairs (g_company.loadedFactories) do
			if factory.showInGlobalGUI and g_currentMission.accessHandler:canFarmAccess(g_currentMission:getFarmId(), factory) then				
				self.currentSetupFactory = factory
				local item = self.gui_factoryListTable:createItem()
				item.factory = factory
			end
		end
		
		self.currentSetupFactory = nil
	end
	
	self.canChangeName = g_server ~= nil	
	if not self.canChangeName then
		local userId = g_currentMission.playerUserId
		local userFarm = g_farmManager:getFarmByUserId(userId)
		self.canChangeName = userFarm:isUserFarmManager(userId)
	end

	if self.currentSelectedFactory == nil then
		self.gui_factoryVisitButton:setDisabled(true)
		self.gui_factoryImageLarge:setImageFilename(self.backupImage)
		
		self.gui_factoryTitleText:setText(self.backupText)
		self.gui_factoryTitleText:setTextColor(1, 1, 1, 1)
		
		self.gui_factoryRenameButton:setDisabled(true)
	else
		self.gui_factoryRenameButton:setDisabled(not self.canChangeName)
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

function Gc_Gui_Factories:onCreateFactoryTitle1(element)
    if self.currentSetupFactory ~= nil then
		if self.currentSetupFactory.guiData.factoryTitle ~= nil then
			element:setText(self.currentSetupFactory.guiData.factoryTitle)
		end
    end
end

function Gc_Gui_Factories:onCreateFactoryTitle2(element)
    if self.currentSetupFactory ~= nil then
		local customTitle = self.currentSetupFactory.guiData.factoryCustomTitle
		if customTitle ~= nil and customTitle ~= "" then
			element:setText(customTitle)
		end
    end
end

function Gc_Gui_Factories:onClickSelectFactory(element)
	self.gui_factoryVisitButton:setDisabled(element.factory == true)
	self.gui_factoryRenameButton:setDisabled(not self.canChangeName)
	self.currentSelectedFactory = element.factory
	
	self:setOverviewBox()
end

function Gc_Gui_Factories:setOverviewBox()
	local factory = self.currentSelectedFactory
	
	if factory ~= nil and factory.guiData ~= nil then
		if factory.guiData.factoryImage ~= nil then
			self.gui_factoryImageLarge:setImageFilename(factory.guiData.factoryImage)
		end
		
		if factory.guiData.factoryTitle ~= nil then
			self.gui_factoryTitleText:setText(factory.guiData.factoryTitle)
			
			if factory.isPlaceable then
				self.gui_factoryTitleText:setTextColor(1, 1, 1, 1)
			else
				-- Set 'onCreate' blue so it is easy to tell the difference. This will also be top of list.
				self.gui_factoryTitleText:setTextColor(0.0742, 0.4341, 0.6939, 1)
			end
		end
	end
end

function Gc_Gui_Factories:onClickOpenOverview()
	local factory = self.currentSelectedFactory
	if factory ~= nil then
		-- Close GC GUI first so we can open the Giants one.
		self.doSelectedReset = false
		g_company.gui:closeActiveGui()
		
		-- Try and open the Factory GUI.
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
		
		-- Close GC GUI first so we can open the Giants one.
		self.doSelectedReset = false
		g_company.gui:closeActiveGui()
		
		-- Open Text dialogue
		g_gui:showTextInputDialog({
			text = self.changeTitleText,
			defaultText = defaultText,
			maxCharacters = 20,
			disableFilter = false,
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

	-- Try and open the GC GUI again
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