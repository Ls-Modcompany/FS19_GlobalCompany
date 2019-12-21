
Gc_Gui_DynamicStorages = {}
local Gc_Gui_DynamicStorages_mt = Class(Gc_Gui_DynamicStorages)
Gc_Gui_DynamicStorages.xmlFilename = g_company.dir .. "gui/objects/GcMain_DynamicStorages.xml"
Gc_Gui_DynamicStorages.debugIndex = g_company.debug:registerScriptName("Gc_Gui_DynamicStorages")

function Gc_Gui_DynamicStorages:new()
	local self = setmetatable({}, Gc_Gui_DynamicStorages_mt)
    
	self.name = "factories"	
	
	self.canChangeName = false
	
	self.changeTitleText = g_company.languageManager:getText("GC_gui_changeDynamicStorageTitle")

	self.doSelectedReset = true
	self.canGoToOverview = false

	self.time = 0

	return self
end

function Gc_Gui_DynamicStorages:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	if sym == 13 and isDown then
		self.canGoToOverview = true
	elseif sym == 13 and not isDown and self.canGoToOverview then
		self:onClickOpenOverview();
		self.canGoToOverview = false
	elseif sym == 117 and not isDown then
        self:onClickRenameStorage();
	end;    
end;

function Gc_Gui_DynamicStorages:onOpen()
	self.gui_storageListTable:removeElements()
	local haveStorages = false
	if g_company.loadedDynamicStorages ~= nil then
		for _, storage in pairs (g_company.loadedDynamicStorages) do
			if g_currentMission.accessHandler:canFarmAccess(g_currentMission:getFarmId(), storage) then				
				self.currentSetupStorage = storage
				local item = self.gui_storageListTable:createItem()
				item.storage = storage
				haveStorages = true
				local customTitle = self.currentSetupStorage:getCustomTitle()		
				if customTitle ~= nil and customTitle ~= "" then
					item:setSortName(customTitle)
				else
					item:setSortName(self.currentSetupStorage.guiData.dynamicStorageTitle)
				end
			end
		end
		
		self.currentSetupStorage = nil
	end

	self.gui_pdaMarker:setVisible(haveStorages)

	self.gui_tableSort:setSortDirection(1)
	self.gui_tableSort:sortTable(self.gui_storageListTable)
	self.gui_storageListTable:selectFirstItem()
	
	self.canChangeName = g_server ~= nil	
	if not self.canChangeName then
		local userId = g_currentMission.playerUserId
		local userFarm = g_farmManager:getFarmByUserId(userId)
		self.canChangeName = userFarm:isUserFarmManager(userId)
	end
	
	self.doSelectedReset = true
end

function Gc_Gui_DynamicStorages:onCreateStorageImageSmall(element)
    if self.currentSetupStorage ~= nil then
		if self.currentSetupStorage.guiData.dynamicStorageImage ~= nil then
			element:setImageFilename(self.currentSetupStorage.guiData.dynamicStorageImage)
		end
    end
end

function Gc_Gui_DynamicStorages:onCreateStorageTitel(element)
    if self.currentSetupStorage ~= nil then
		local customTitle = self.currentSetupStorage:getCustomTitle()		
		if customTitle ~= nil and customTitle ~= "" then
			element:setText(customTitle, true)
		elseif self.currentSetupStorage.guiData.dynamicStorageTitle ~= nil and self.currentSetupStorage.guiData.dynamicStorageTitle ~= "" then
			element:setText(self.currentSetupStorage.guiData.dynamicStorageTitle, true)
		else
			element:setText("-", true)
		end
    end
end

function Gc_Gui_DynamicStorages:onCreateFreeSlots(element)
	if self.currentSetupStorage ~= nil then
		local v1 = 0
		for _,line in pairs(self.currentSetupStorage.places) do
			if line.fillLevel == 0 then
				v1 = v1 + 1
			end
		end
		local v2 = table.getn(self.currentSetupStorage.places)
		element:setText(string.format("%s / %s", v1, v2))
	end	
end

function Gc_Gui_DynamicStorages:onClickSelectStorage(element)
	self.currentSelectedDynamicStorage = element.storage	

	local x,_,y = getWorldTranslation(self.currentSelectedDynamicStorage.rootNode)
	self.gui_ingameMap:setPdaMarkerPosition(self.ingamemap_pdaMarker_pos, x,y)
end

function Gc_Gui_DynamicStorages:onClickOpenOverview()
	local storage = self.currentSelectedDynamicStorage
	if storage ~= nil then
		self.doSelectedReset = false
		g_company.gui:setCanExit("gc_dynamicStorage", false)
		g_company.gui:closeActiveGui()
		g_company.gui:openGuiWithData("gc_dynamicStorage", false, storage, true, storage.activeUnloadingBox, true);
	end
end

function Gc_Gui_DynamicStorages:onClickRenameStorage()
	local storage = self.currentSelectedDynamicStorage
	
	if self.canChangeName and storage ~= nil then
		local defaultText = storage:getCustomTitle()
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

function Gc_Gui_DynamicStorages:setCustomTitle(text, applyTitle)
	if applyTitle and self.currentSelectedDynamicStorage ~= nil then
		if text == nil or text == "" then
			text = GC_DynamicStorage.BACKUP_TITLE
		end

		self.currentSelectedDynamicStorage:setCustomTitle(text)
	end

	g_company.gui:openGui("gc_main")
end

function Gc_Gui_DynamicStorages:onClose()
	self.canChangeName = false
	
	if self.doSelectedReset then
		self.currentSelectedDynamicStorage = nil
		
		self.gui_storageListTable:setPosition(0)
		if self.gui_storageListTable.slider ~= nil then
			self.gui_storageListTable.slider:setPosition(0)
		end
	end

	g_company.gui:setCanExit("gc_dynamicStorage", true)
end

function Gc_Gui_DynamicStorages:onCreate()
	self.ingamemap_pdaMarker_pos = self.gui_ingameMap:addPdaMarker(self.gui_pdaMarker)
end

function Gc_Gui_DynamicStorages:onClickClose()
    g_company.gui:closeActiveGui()
end

function Gc_Gui_DynamicStorages:update(dt)
	self.time = self.time + dt
	if self.time > 1000 then
		self.time = self.time - 1000
	end

	local delta = self.time / 500 * 10
	local sizePx = 10 + delta
	self.gui_pdaMarker.size = GuiUtils.getNormalizedValues(string.format("%spx %spx", sizePx, sizePx), self.gui_pdaMarker.outputSize, self.gui_pdaMarker.size)
end

function Gc_Gui_DynamicStorages:onClickChangeSortDirection()
	self.gui_tableSort:changeSortDirection()
	self.gui_tableSort:sortTable(self.gui_storageListTable)
	self.gui_storageListTable:scrollTable()
	self.gui_storageListTable:updateVisibleItems()
	self.gui_storageListTable.slider:setPosition(0)
end