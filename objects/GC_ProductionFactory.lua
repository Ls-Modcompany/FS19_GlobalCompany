--
-- GlobalCompany - Objects - GC_ProductionFactory
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / GtX
-- @Date: 22.03.2018
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.1.0.0 (21.06.2019):
-- 		- release version
--
-- 	v1.0.0.0 (22.03.2018):
-- 		- initial fs17 (GtX)
--
--
-- Notes:
--
--
-- ToDo:
-- 		- Add missing triggers (Dynamic Pallet Input, Animal Load / Unload).
--
--


GC_ProductionFactory = {}
local GC_ProductionFactory_mt = Class(GC_ProductionFactory, Object)
InitObjectClass(GC_ProductionFactory, "GC_ProductionFactory")

-- This is for performance and GUI support! Even this is High.
GC_ProductionFactory.LIMIT = 10
GC_ProductionFactory.MAX_INT = 2147483647

GC_ProductionFactory.debugIndex = g_company.debug:registerScriptName("GC_ProductionFactory")

getfenv(0)["GC_ProductionFactory"] = GC_ProductionFactory

function GC_ProductionFactory:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName")
	local xmlFilename = getUserAttribute(transformId, "xmlFile")
	local farmlandId = getUserAttribute(transformId, "farmlandId")

	if indexName ~= nil and xmlFilename ~= nil and farmlandId ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName
		local baseDirectory = g_currentMission.loadingMapBaseDirectory

		local object = GC_ProductionFactory:new(g_server ~= nil, g_dedicatedServerInfo == nil, nil, xmlFilename, baseDirectory, customEnvironment)
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.productionFactories.productionFactory", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object)
				g_currentMission:addOnCreateLoadedObjectToSave(object)

				g_company.debug:writeOnCreate(object.debugData, "[FACTORY - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex)
				object:register(true)

				local warningText = string.format("[FACTORY - %s]  Attribute 'farmlandId' is invalid! Factory will not operate correctly. 'farmlandId' should match area object is located at.", indexName)
				g_company.farmlandOwnerListener:addListener(object, farmlandId, warningText)
			else
				g_company.debug:writeOnCreate(object.debugData, "[FACTORY - %s]  Failed to load from '%s'!", indexName, xmlFilename)
				object:delete()
			end

			delete(xmlFile)
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[FACTORY - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename)
			else
				g_company.debug:writeModding(object.debugData, "[FACTORY - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename)
			end
		end
	else
		g_company.debug:print("  [LSMC - GlobalCompany] - [GC_ProductionFactory]")
		if indexName == nil then
			g_company.debug:print("    ONCREATE: Trying to load 'FACTORY' with nodeId name %s, attribute 'indexName' could not be found.", getName(transformId))
		else
			if xmlFilename == nil then
				g_company.debug:print("    ONCREATE: [FACTORY - %s]  Attribute 'xmlFilename' is missing!", indexName)
			end

			if farmlandId == nil then
				g_company.debug:print("    ONCREATE: [FACTORY - %s]  Attribute 'farmlandId' is missing!", indexName)
			end
		end
	end
end

function GC_ProductionFactory:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or GC_ProductionFactory_mt)

	self.xmlFilename = xmlFilename
	self.baseDirectory = baseDirectory
	self.customEnvironment = customEnvironment

	self.triggerIdToInputProductId = {}
	self.triggerIdToOutputProductId = {}
	self.triggerIdToLineIds = {}
	self.drawProductLineUI = {}

	self.lineIdToConveyor = {}
	self.lineIdToConveyorEffect = {}

	self.productLines = {}
	self.inputProducts = {}
	self.outputProducts = {}
	self.factorMinuteUpdate = false

	self.factoryIsOwned = false
	self.hasProductSale = false

	self.inputProductNameToId = {}
	self.outputProductNameToId = {}

	self.productNameToProduct = {}

	self.numInputProducts = 0
	self.numOutputProducts = 0

	self.hourlyIncomeTotal = 0

	self.levelChangeTimer = -1

	self.factoryDeleteStarted = false

	self.debugData = g_company.debug:getDebugData(GC_ProductionFactory.debugIndex, nil, customEnvironment)

	return self
end

function GC_ProductionFactory:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	local canLoad, addMinuteChange, addHourChange = true, false, false

	self.rootNode = nodeId
	self.indexName = indexName
	self.isPlaceable = isPlaceable

	self.triggerManager = GC_TriggerManager:new(self)
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings")

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId")
	if self.saveId == nil then
		self.saveId = "ProductionFactory_" .. indexName
	end

	local factoryTitle = getXMLString(xmlFile, xmlKey .. ".guiInformation#title")
	if factoryTitle ~= nil then
		factoryTitle = g_company.languageManager:getText(factoryTitle)
	else
		factoryTitle = indexName
	end

	local factoryCamera = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, xmlKey .. ".guiInformation#cameraFeed"), self.i3dMappings)
	local factoryImage = getXMLString(xmlFile, xmlKey .. ".guiInformation#imageFilename")
	if factoryImage ~= nil then
		factoryImage = self.baseDirectory .. factoryImage
	end

	local factoryDescription = Utils.getNoNil(getXMLString(xmlFile, xmlKey .. ".guiInformation#description"), "")
	if factoryDescription ~= "" then
		factoryDescription = g_company.languageManager:getText(factoryDescription)
	end

	self.guiData = {
		factoryTitle = factoryTitle,
		factoryImage = factoryImage,
		factoryCamera = factoryCamera,
		factoryDescription = factoryDescription,
	}

	self.disableAllOutputGUI = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. ".operation#disableAllOutputGUI"), false)
	self.showInGlobalGUI = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. ".operation#showInGlobalGUI"), false) -- Possible future use.
	self.updateDelay = math.max(Utils.getNoNil(getXMLInt(xmlFile, xmlKey .. ".operation#updateDelayMinutes"), 10), 1)
	self.updateCounter = self.updateDelay

	if hasXMLProperty(xmlFile, xmlKey .. ".registerAnimations") then
		local animationManager = GC_AnimationManager:new(self.isServer, self.isClient)
		if animationManager:load(self.rootNode, self, xmlFile, xmlKey, true) then
			animationManager:register(true)
			self.animationManager = animationManager
		else
			animationManager:delete()
		end
	end

	self.registeredUnloadingTriggers = {}
	if hasXMLProperty(xmlFile, xmlKey .. ".registerUnloadingTriggers") then
		local i = 0
		while true do
			local unloadingTriggerKey = string.format("%s.registerUnloadingTriggers.unloadingTrigger(%d)", xmlKey, i)
			if not hasXMLProperty(xmlFile, unloadingTriggerKey) then
				break
			end

			local name = getXMLString(xmlFile, unloadingTriggerKey .. "#name")
			if name ~= nil and self.registeredUnloadingTriggers[name] == nil then
				local unloadingTrigger = self.triggerManager:addTrigger(GC_UnloadingTrigger, self.rootNode, self, xmlFile, unloadingTriggerKey, {})
				if unloadingTrigger ~= nil then
					local triggerId = unloadingTrigger.managerId
					unloadingTrigger.extraParamater = triggerId
					self.registeredUnloadingTriggers[name] = {trigger = unloadingTrigger, isUsed = false, key = unloadingTriggerKey}
					self.triggerIdToInputProductId[triggerId] = {}
				end
			end
			i = i + 1
		end
	end

	local inputHeader = getXMLString(xmlFile, xmlKey .. ".registerInputProducts#headerTitle")
	if inputHeader ~= nil then
		self.guiData.inputHeader = g_company.languageManager:getText(inputHeader)
	else
		self.guiData.inputHeader = g_company.languageManager:getText("GC_Input_Header_Backup")
	end

	local i = 0
	while true do
		local inputProductKey = string.format("%s.registerInputProducts.inputProduct(%d)", xmlKey, i)
		if not hasXMLProperty(xmlFile, inputProductKey) then
			break
		end

		local inputProductName = getXMLString(xmlFile, inputProductKey .. "#name")
		if inputProductName ~= nil and self.inputProductNameToId[name] == nil then
			local inputProduct = {}
			local concatTitles = {}
			local usedFillTypeNames = {}

			inputProduct.name = inputProductName
			inputProduct.canPurchaseProduct = false

			local j = 0
			while true do
				local fillTypesKey = string.format("%s.fillTypes.fillType(%d)", inputProductKey, j)
				if not hasXMLProperty(xmlFile, fillTypesKey) then
					break
				end

				local fillTypeName = getXMLString(xmlFile, fillTypesKey .. "#name")
				if fillTypeName ~= nil then
					local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName)
					if fillType ~= nil and usedFillTypeNames[fillTypeName] == nil then
						usedFillTypeNames[fillTypeName] = inputProductName

						if inputProduct.fillTypes == nil then
							inputProduct.fillTypes = {}
						end

						inputProduct.fillTypes[fillType.index] = true

						if inputProduct.lastFillTypeIndex == nil then
							inputProduct.lastFillTypeIndex = fillType.index
						end

						local fillTypeTitle = fillType.title
						local customTitle = getXMLString(xmlFile, fillTypesKey .. "#title") -- Use this to change fillType name. e.g WOODCHIPS > LOGS
						if customTitle ~= nil then
							fillTypeTitle = g_company.languageManager:getText(customTitle)
						end

						table.insert(concatTitles, fillTypeTitle)
					else
						if fillType == nil then
							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Unknown fillType ( %s ) found in 'inputProduct' ( %s ) at %s, ignoring!", indexName, fillTypeName, fillTypesKey)
						else
							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Duplicate 'inputProduct' fillType ( %s ) in '%s', FillType already used at '%s'!", indexName, fillTypeName, inputProductName, usedFillTypeNames[fillTypeName])
						end
					end
				end

				j = j + 1
			end

			if inputProduct.fillTypes ~= nil then
				inputProduct.fillLevel = 0
				inputProduct.concatedFillTypeTitles = table.concat(concatTitles, " | ")
				inputProduct.capacity = Utils.getNoNil(getXMLInt(xmlFile, inputProductKey .. "#capacity"), 1000)

				-- 'fixedPricePerLitre' This is the price per litre to purchase the product.
				-- 'useSellPointPrice' The highest sell point price for the given fillType will be used.
				-- 'purchaseMultiplier' (Default = 1.1) The multiplier to allow for transport and so it is not a easy cheat. (Min Value: 1)
				local fixedPricePerLitre = getXMLFloat(xmlFile, inputProductKey .. ".purchase#fixedPricePerLitre")
				if fixedPricePerLitre == nil or fixedPricePerLitre <= 0.0 then
					local sellPointFillType = g_fillTypeManager:getFillTypeIndexByName(getXMLString(xmlFile, inputProductKey .. ".purchase#useSellPointPrice"))
					if sellPointFillType ~= nil then
						inputProduct.canPurchaseProduct = true
						inputProduct.sellPointFillType = sellPointFillType
						inputProduct.purchaseMultiplier = math.max(Utils.getNoNil(getXMLFloat(xmlFile, inputProductKey .. ".purchase#purchaseMultiplier"), 1.1), 1)
					end
				else
					inputProduct.canPurchaseProduct = true
					inputProduct.fixedPricePerLitre = fixedPricePerLitre
				end

				local productTitle = getXMLString(xmlFile, inputProductKey .. "#title")
				if productTitle ~= nil then
					inputProduct.title = g_company.languageManager:getText(productTitle)
				else
					inputProduct.title = string.format(g_company.languageManager:getText("GC_Input_Title_Backup"), self.numInputProducts + 1)
				end

				local inputProductId = #self.inputProducts + 1
				inputProduct.id = inputProductId

				-- This is the lifetime limit for the inputProduct if maximumAccepted > 0
				-- When 'totalDelivered' >= this limit then it will never be accepted again. Nice option for building with a factory.
				inputProduct.maximumAccepted = Utils.getNoNil(getXMLInt(xmlFile, inputProductKey .. "#maximumAccepted"), 0)
				inputProduct.totalDelivered = 0
				
				if hasXMLProperty(xmlFile, inputProductKey .. ".inputMethods") then
					if self.isServer then
						if hasXMLProperty(xmlFile, inputProductKey .. ".inputMethods.rainWaterCollector") then
							if inputProduct.fillTypes[FillType.WATER] ~= nil then
								local litresPerHour = getXMLString(xmlFile, inputProductKey .. ".inputMethods.rainWaterCollector#litresPerHour")
								if litresPerHour ~= nil then
									if self.rainWaterCollector == nil then
										self.rainWaterCollector = {}
										self.rainWaterCollector.collected = 0
										self.rainWaterCollector.updateCounter = 0
										self.rainWaterCollector.input = inputProduct
										self.rainWaterCollector.litresPerHour = litresPerHour

										addMinuteChange = true
									else
										g_company.debug:writeModding(self.debugData, "[FACTORY - %s] 'rainWaterCollector' is already added to 'inputProduct' %s! Only one 'rainWaterCollector' can be used for each factory.", indexName, self.rainWaterCollector.input.name)
									end
								else
									g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'litresPerHour' given for 'rainWaterCollector' at 'inputProduct' %s! This will be ignored.", indexName, inputProductName)
								end
							else
								g_company.debug:writeModding(self.debugData, "[FACTORY - %s] 'inputProduct' %s does not contain fillType 'WATER', <rainWaterCollector> has been disabled.", indexName, inputProductName)
							end
						end
					end

					local woodTriggerKey = inputProductKey .. ".inputMethods.woodTrigger"
					if hasXMLProperty(xmlFile, woodTriggerKey) then
						if inputProduct.fillTypes[FillType.WOODCHIPS] ~= nil then
							local trigger = self.triggerManager:addTrigger(GC_WoodTrigger, self.rootNode, self, xmlFile, woodTriggerKey, "WOODCHIPS")
							if trigger ~= nil then
								trigger.extraParamater = trigger.managerId
								self.triggerIdToInputProductId[trigger.managerId] = {[FillType.WOODCHIPS] = inputProductId}
							end
						else
							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] 'inputProduct' %s does not contain fillType 'WOODCHIPS', <woodTrigger> has been disabled.", indexName, inputProductName)
						end
					end

					local unloadingTriggerKey = inputProductKey .. ".inputMethods.unloadingTrigger"
					if hasXMLProperty(xmlFile, unloadingTriggerKey) then
						local name = getXMLString(xmlFile, unloadingTriggerKey .. "#name")
						if self.registeredUnloadingTriggers[name] ~= nil then
							self.registeredUnloadingTriggers[name].isUsed = true
							local trigger = self.registeredUnloadingTriggers[name].trigger
							local triggerId = trigger.extraParamater

							local canAdd = true
							if trigger.fillTypes ~= nil then
								for index, _ in pairs (inputProduct.fillTypes) do
									if trigger.fillTypes[index] ~= nil then
										canAdd = false
										break
									end
								end
							end
							if canAdd then
								for index, _ in pairs (inputProduct.fillTypes) do
									trigger:setAcceptedFillTypeState(index, true)
									self.triggerIdToInputProductId[triggerId][index] = inputProductId
								end
							else
								g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Can not add Input Product '%s' to Unloading Trigger '%s'! FillType '%s' already exists.", indexName, outputProductName, name, fillTypeName)
							end
						else
							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] unloadingTrigger '%s could not be found at 'productionFactory.registerUnloadingTriggers'! You first need to register this trigger.", indexName, name)
						end
					end

					-- Dynamic Pallet Trigger
					--local dynamicPalletAreaKey = inputProductKey .. ".inputMethods.dynamicPalletArea"
					--if hasXMLProperty(xmlFile, dynamicPalletAreaKey) then

					--end

					-- Livestock Trigger
					--local livestockTriggerKey = inputProductKey .. ".inputMethods.livestockTrigger"
					--if hasXMLProperty(xmlFile, livestockTriggerKey) then

					--end
				end

				self:loadProductParts(xmlFile, inputProductKey, inputProduct)
				self:updateFactoryLevels(0, inputProduct, nil, false)

				self.numInputProducts = inputProductId

				self.inputProducts[inputProductId] = inputProduct
				self.inputProductNameToId[inputProductName] = inputProductId
				self.productNameToProduct[inputProductName] = inputProduct
			end
		else
			if inputProductName == nil then
				g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No name found at %s", indexName, inputProductKey)
			else
				g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Duplicate name '%s' used %s", indexName, inputProductName, inputProductKey)
			end
		end

		i = i + 1
	end

	for regName, item in pairs (self.registeredUnloadingTriggers) do
		if not item.isUsed then
			self.triggerManager:removeTrigger(item.trigger)
			g_company.debug:writeModding(self.debugData, "[FACTORY - %s] unloadingTrigger '%s' found at '%s.unloadingTrigger' is not in use! This should be removed from XML.", indexName, regName, item.key)
		end
	end

	if hasXMLProperty(xmlFile, xmlKey .. ".registerOutputProducts") then
		self.providedFillTypes = {}
		self.registeredLoadingTriggers = {}

		local keyId = 0
		while true do
			local loadingTriggerKey = string.format("%s.registerLoadingTriggers.loadingTrigger(%d)", xmlKey, keyId)
			if not hasXMLProperty(xmlFile, loadingTriggerKey) then
				break
			end

			local name = getXMLString(xmlFile, loadingTriggerKey .. "#name")
			if name ~= nil and self.registeredLoadingTriggers[name] == nil then
				local loadingTrigger = self.triggerManager:addTrigger(GC_LoadingTrigger, self.rootNode, self, xmlFile, loadingTriggerKey, {}, false, true)
				if loadingTrigger ~= nil then
					local triggerId = loadingTrigger.managerId
					loadingTrigger.extraParamater = triggerId
					loadingTrigger:setStationName(factoryTitle)
					self.registeredLoadingTriggers[name] = {trigger = loadingTrigger, isUsed = false, key = loadingTriggerKey}
					self.providedFillTypes[triggerId] = {}
					self.triggerIdToOutputProductId[triggerId] = {}
				end
			end
			keyId = keyId + 1
		end

		local outputHeader = getXMLString(xmlFile, xmlKey .. ".registerOutputProducts#headerTitle")
		if outputHeader ~= nil then
			self.guiData.outputHeader = g_company.languageManager:getText(outputHeader)
		else
			self.guiData.outputHeader = g_company.languageManager:getText("GC_Output_Header_Backup")
		end

		i = 0
		while true do
			local outputProductKey = string.format("%s.registerOutputProducts.outputProduct(%d)", xmlKey, i)
			if not hasXMLProperty(xmlFile, outputProductKey) then
				break
			end

			local outputProductName = getXMLString(xmlFile, outputProductKey .. "#name")
			if outputProductName ~= nil and self.outputProductNameToId[outputProductName] == nil and self.productNameToProduct[outputProductName] == nil then
				local outputProduct = {}
				outputProduct.name = outputProductName

				local fillTypeName = getXMLString(xmlFile, outputProductKey .. "#fillType")
				if fillTypeName ~= nil then
					local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName)
					if fillType ~= nil then
						local fillTypeIndex = fillType.index

						outputProduct.fillLevel = 0
						outputProduct.isUsed = false
						outputProduct.fillTypeIndex = fillTypeIndex
						outputProduct.lastFillTypeIndex = fillTypeIndex
						outputProduct.capacity = Utils.getNoNil(getXMLInt(xmlFile, outputProductKey .. "#capacity"), 1000)

						-- Using like a constructor this could be set false so the building remains.
						outputProduct.removeFillLevelOnSell = Utils.getNoNil(getXMLBool(xmlFile, outputProductKey .. "#removeFillLevelOnSell"), true)

						local productTitle = getXMLString(xmlFile, outputProductKey .. "#customTitle")
						if productTitle ~= nil then
							outputProduct.title =  g_company.languageManager:getText(productTitle)
						else
							outputProduct.title = fillType.title
							outputProduct.imageFilename = fillType.hudOverlayFilename
						end

						local outputProductId = #self.outputProducts + 1
						outputProduct.id = outputProductId

						local outputMethodsKey = outputProductKey .. ".outputMethods"
						if hasXMLProperty(xmlFile, outputMethodsKey) then
							local triggersLoaded, invalidTriggers = {}, {}

							local onDemandPalletSpawnerKey = outputMethodsKey .. ".objectSpawner"
							if hasXMLProperty(xmlFile, onDemandPalletSpawnerKey) then
								local defaultBulkPallet = "$data/objects/pallets/fillablePallet/fillablePallet.xml"
								local filename = Utils.getNoNil(getXMLString(xmlFile, onDemandPalletSpawnerKey .. "#xmlFilename"), defaultBulkPallet)
								local palletFilename = Utils.getFilename(filename, self.baseDirectory)
								if palletFilename ~= nil and palletFilename ~= "" then

									local palletValid = true
									if palletFilename == defaultBulkPallet:sub(2) then
										local categoryFillTypes = g_fillTypeManager.categoryNameToFillTypes["BULK"]
										if categoryFillTypes[fillTypeIndex] == nil then
											palletValid = false
											g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Invalid pallet! %s is not part of the 'BULK' category and can not be used with '%s'.", indexName, fillType.title, defaultBulkPallet)
										end
									end

									if palletValid then
										local palletFillUnitIndex = Utils.getNoNil(getXMLFloat(xmlFile, onDemandPalletSpawnerKey .. "#fillUnitIndex"), 1)
										local palletCapacity = Utils.getNoNil(getXMLFloat(xmlFile, onDemandPalletSpawnerKey .. "#capacity"), 1000)
										if palletCapacity ~= nil and palletCapacity > 0 then
											local width, length, _, _ = StoreItemUtil.getSizeValues(palletFilename, "vehicle", 0, {})
											if width ~= nil and length ~= nil then
												local objectSpawner = self.triggerManager:addTrigger(GC_ObjectSpawner, self.rootNode, self, xmlFile, outputMethodsKey)
												if objectSpawner ~= nil then
													local offsetFactor = getXMLFloat(xmlFile, onDemandPalletSpawnerKey .. "#offsetFactor")

													objectSpawner.object = {
														filename = palletFilename,
														fillUnitIndex = palletFillUnitIndex,
														fillLevel = palletCapacity,
														fillTypeIndex = fillTypeIndex,
														width = width,
														length = length,
														offset = offsetFactor
													}

													objectSpawner.extraParamater = objectSpawner.managerId
													outputProduct.objectSpawner = objectSpawner
													self.triggerIdToOutputProductId[objectSpawner.managerId] = {[fillTypeIndex] = outputProductId}
													table.insert(triggersLoaded, "objectSpawner")
												end
											end
										end
									end
								end
							end

							local loadingTriggerKey = outputMethodsKey .. ".loadingTrigger"
							if hasXMLProperty(xmlFile, loadingTriggerKey) then
								local name = getXMLString(xmlFile, loadingTriggerKey .. "#name")
								local stationName = getXMLString(xmlFile, loadingTriggerKey .. "#stationName")
								if self.registeredLoadingTriggers[name] ~= nil then
									self.registeredLoadingTriggers[name].isUsed = true
									local trigger = self.registeredLoadingTriggers[name].trigger
									local triggerId = trigger.extraParamater

									if self.providedFillTypes[triggerId][fillTypeIndex] == nil then
										self.providedFillTypes[triggerId][fillTypeIndex] = true
										if stationName ~= nil then
											trigger:setStationName(stationName)
										end

										self.triggerIdToOutputProductId[triggerId][fillTypeIndex] = outputProductId

										table.insert(triggersLoaded, "loadingTrigger")
									else
										g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Can not add Output Product '%s' to Loading Trigger '%s'! FillType '%s' already exists.", indexName, outputProductName, name, fillTypeName)
									end
								else
									g_company.debug:writeModding(self.debugData, "[FACTORY - %s] loadingTrigger '%s could not be found at 'productionFactory.registerLoadingTriggers'! You first need to register this trigger.", indexName, name)
								end
							end

							local shovelFillTriggerKey = outputMethodsKey .. ".shovelFillTrigger"
							if hasXMLProperty(xmlFile, shovelFillTriggerKey) then
								local shovelTrigger = self.triggerManager:addTrigger(GC_ShovelFillTrigger, self.rootNode, self, xmlFile, shovelFillTriggerKey, fillTypeIndex, "getProvidedFillLevel")
								if shovelTrigger ~= nil then
									outputProduct.shovelFillTrigger = shovelTrigger
									shovelTrigger.extraParamater = shovelTrigger.managerId
									self.triggerIdToOutputProductId[shovelTrigger.managerId] = {[fillTypeIndex] = outputProductId}

									table.insert(triggersLoaded, "shovelFillTrigger")
								end
							end

							local dynamicHeapKey = outputMethodsKey .. ".dynamicHeap"
							if hasXMLProperty(xmlFile, dynamicHeapKey) then
								if #triggersLoaded == 0 then
									local dynamicHeap = self.triggerManager:addTrigger(GC_DynamicHeap, self.rootNode, self, xmlFile, dynamicHeapKey, fillTypeName)
									if dynamicHeap ~= nil then
										if dynamicHeap.vehicleInteractionTrigger ~= nil then
											dynamicHeap.extraParamater = dynamicHeap.managerId
											outputProduct.dynamicHeap = dynamicHeap
											self.triggerIdToOutputProductId[dynamicHeap.managerId] = {[fillTypeIndex] = outputProductId}

											table.insert(triggersLoaded, "dynamicHeap")
										else
											self.triggerManager:removeTrigger(dynamicHeap)
											g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'vehicleInteractionTrigger' found at '%s.dynamicHeap'", indexName, outputMethodsKey)
										end
									end
								else
									table.insert(invalidTriggers, "dynamicHeap")
								end
							end

							if hasXMLProperty(xmlFile, outputMethodsKey .. ".palletCreators") then
								if #triggersLoaded == 0 then
									local palletCreator = self.triggerManager:addTrigger(GC_PalletCreator, self.rootNode, self, xmlFile, outputMethodsKey, self.baseDirectory, outputProduct.fillTypeIndex)
									if palletCreator ~= nil then
										if palletCreator.palletInteractionTriggers ~= nil then
											palletCreator.extraParamater = palletCreator.managerId
											palletCreator:setWarningText(factoryTitle)

											outputProduct.palletCreator = palletCreator
											outputProduct.capacity = palletCreator:getTotalCapacity()

											self.triggerIdToOutputProductId[palletCreator.managerId] = {[fillTypeIndex] = outputProductId}

											table.insert(triggersLoaded, "palletCreator")
										else
											self.triggerManager:removeTrigger(palletCreator)
											g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'palletInteractionTrigger(s)' found at '%s.palletCreators'", indexName, outputMethodsKey)
										end
									end
								else
									table.insert(invalidTriggers, "palletCreator")
								end
							end

							if #invalidTriggers > 0 then
								triggersLoaded = table.concat(triggersLoaded, " or ")
								invalidTriggers = table.concat(invalidTriggers, " and ")

								g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Invalid 'outputMethod' combinations, '%s' can not be combined with '%s'!", indexName, invalidTriggers, triggersLoaded)
							end
						end

						self:loadProductParts(xmlFile, outputProductKey, outputProduct)
						self:updateFactoryLevels(0, outputProduct, nil, false)

						self.outputProducts[outputProductId] = outputProduct
						self.numOutputProducts = outputProductId
						self.outputProductNameToId[outputProductName] = outputProductId

						self.productNameToProduct[outputProductName] = outputProduct

						self.factorMinuteUpdate = true
					else
						g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Invalid fillType '%s' given at %s", indexName, fillTypeName, outputProductKey)
					end
				else
					g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No fillType found at %s", indexName, outputProductKey)
				end
			else
				if outputProductName == nil then
					g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No name found at %s", indexName, outputProductKey)
				else
					g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Duplicate name '%s' used %s", indexName, outputProductName, outputProductKey)
				end
			end

			i = i + 1
		end

		for regName, item in pairs (self.registeredLoadingTriggers) do
			if not item.isUsed then
				self.triggerManager:removeTrigger(item.trigger)
				g_company.debug:writeModding(self.debugData, "[FACTORY - %s] loadingTrigger '%s' found at '%s.loadingTrigger' is not in use! This should be removed from XML.", indexName, regName, item.key)
			end
		end
	else
		self.outputProducts = nil
	end

	if self.numInputProducts > 0 then

		i = 0
		while true do
			local productLineKey = string.format("%s.productLines.productLine(%d)", xmlKey, i)
			if not hasXMLProperty(xmlFile, productLineKey) or i >= GC_ProductionFactory.LIMIT then
				break
			end

			local productLine = {}
			local productLineId = #self.productLines + 1

			productLine.active = false
			productLine.userStopped = false
			productLine.autoStart = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#autoLineStart"), false)
			productLine.outputPerHour = Utils.getNoNil(getXMLInt(xmlFile, productLineKey .. "#outputPerHour"), 1000)

			productLine.inputsPercent = {}
			productLine.inputsIncome = {}
			productLine.outputsPercent = {}

			productLine.showInGUI = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#showInGUI"), true)
			productLine.disableOutputGUI = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#disableOutputGUI"), false)

			local productLineTitle = getXMLString(xmlFile, productLineKey .. "#title")
			if productLineTitle ~= nil then
				productLine.title = g_company.languageManager:getText(productLineTitle)
			else
				productLine.title = string.format(g_company.languageManager:getText("GC_Productline_Title_Backup"), productLineId)
			end

			local inputKeyId = 0
			local inputProductNameToInputId = {}
			while true do
				local inputKey = string.format("%s.inputs.inputProduct(%d)", productLineKey, inputKeyId)
				if not hasXMLProperty(xmlFile, inputKey) or inputKeyId >= GC_ProductionFactory.LIMIT then
					break
				end

				local name = getXMLString(xmlFile, inputKey .. "#name")
				if self.inputProductNameToId[name] ~= nil then
					if inputProductNameToInputId[name] == nil then
						local inputProductId = self.inputProductNameToId[name]
						local inputPercent = Utils.getNoNil(getXMLInt(xmlFile, inputKey .. "#percent"), 100) / 100

						if productLine.inputs == nil then
							productLine.inputs = {}
						end

						local inputId = #productLine.inputs + 1
						inputProductNameToInputId[name] = inputId

						productLine.inputs[inputId] = self.inputProducts[inputProductId]
						productLine.inputsPercent[inputId] = math.min(math.max(inputPercent, 0.1), 1)

						-- Allow simple income as fillType is used. This is product line specific.
						local pricePerLiter = getXMLFloat(xmlFile, inputKey .. ".income#pricePerLiter")
						if pricePerLiter ~= nil and pricePerLiter > 0.0 then
							local usePriceMultiplier = Utils.getNoNil(getXMLBool(xmlFile, inputKey .. ".income#usePriceMultiplier"), true)
							productLine.inputsIncome[inputId] = {pricePerLiter = pricePerLiter, usePriceMultiplier = usePriceMultiplier}
							addHourChange = true
						end
					else
						g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Trying to add inputProduct '%s' twice at %s!", indexName, name, inputKey)
					end
				else
					g_company.debug:writeModding(self.debugData, "[FACTORY - %s] inputProduct '%s' does not exist! You must first register inputProducts in factory XML.", indexName, name)
				end

				inputKeyId = inputKeyId + 1
			end

			if self.numOutputProducts > 0 then
				local outputKeyId = 0
				local outputProductNameToOutputId = {}
				while true do
					local outputKey = string.format("%s.outputs.outputProduct(%d)", productLineKey, outputKeyId)
					if not hasXMLProperty(xmlFile, outputKey) or outputKeyId >= GC_ProductionFactory.LIMIT then
						break
					end

					local name = getXMLString(xmlFile, outputKey .. "#name")
					if self.outputProductNameToId[name] ~= nil then
						if outputProductNameToOutputId[name] == nil then
							local outputProductId = self.outputProductNameToId[name]
							local outputPercent = Utils.getNoNil(getXMLInt(xmlFile, outputKey .. "#percent"), 100) / 100

							if productLine.outputs == nil then
								productLine.outputs = {}
							end

							local outputId = #productLine.outputs + 1
							outputProductNameToOutputId[name] = outputId

							productLine.outputs[outputId] = self.outputProducts[outputProductId]
							productLine.outputsPercent[outputId] = math.min(math.max(outputPercent, 0.1), 1)

							local out = productLine.outputs[outputId]
							if out.palletCreator ~= nil then
								if self.triggerIdToLineIds[out.palletCreator.extraParamater] == nil then
									self.triggerIdToLineIds[out.palletCreator.extraParamater] = {}
								end

								table.insert(self.triggerIdToLineIds[out.palletCreator.extraParamater], productLineId)
								out = nil
							elseif productLine.outputs[outputId].dynamicHeap ~= nil then
								if self.triggerIdToLineIds[out.dynamicHeap.extraParamater] == nil then
									self.triggerIdToLineIds[out.dynamicHeap.extraParamater] = {}
								end

								table.insert(self.triggerIdToLineIds[out.dynamicHeap.extraParamater], productLineId)
								out = nil
							end
						end
					end

					outputKeyId = outputKeyId + 1
				end

				addMinuteChange = true
				outputProductNameToOutputId = nil
			end

			if productLine.outputs == nil then
				local productSaleKey = productLineKey .. ".productSale"
				if hasXMLProperty(xmlFile, productSaleKey) then
					local productTitle = getXMLString(xmlFile, productSaleKey .. "#title")
					if productTitle ~= nil then
						productTitle =  g_company.languageManager:getText(productTitle)

						local incomeEasy = Utils.getNoNil(getXMLFloat(xmlFile, productSaleKey..".incomePerHour#newFarmer"), 90.0)
						local incomeMed = Utils.getNoNil(getXMLFloat(xmlFile, productSaleKey..".incomePerHour#farmManager"), 60.0)
						local incomeHard = Utils.getNoNil(getXMLFloat(xmlFile, productSaleKey..".incomePerHour#startFromScratch"), 40.0)
						local incomeTypes = {incomeEasy, incomeMed, incomeHard}
						if #incomeTypes == 3 then
							local difficulty = math.min(math.max(g_currentMission.missionInfo.difficulty, 1), 3)
							local productivityHours = 24 - g_currentMission.environment.currentHour
							productLine.productSale = {title = productTitle, incomePerHour = incomeTypes[difficulty], lifeTimeIncome = 0, productivityHours = productivityHours}

							addHourChange = true
							self.hasProductSale = true
						else
							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] 'incomePerHour' is incomplete at %s!", indexName, productSaleKey)
						end
					else
						g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Can not use productLine 'productSale'! 'title' is missing at %s", indexName, productSaleKey)
					end
				else
					addMinuteChange = true
				end
			end

			self:loadOperatingParts(xmlFile, productLineKey .. ".operatingParts", productLine)

			-- Load player trigger for each product line. (These will show small UI (showPopupUI = true) when in trigger or open full GUI if 'productLine.showInGUI' is true).
			local linePlayerTriggerKey = productLineKey .. ".playerTrigger"
			if hasXMLProperty(xmlFile, linePlayerTriggerKey) then
				local nextId = #self.productLines + 1
				local activateText = g_company.languageManager:getText("GC_Open_Product_Menu")
				local playerTrigger = self.triggerManager:addTrigger(GC_PlayerTrigger, self.rootNode, self, xmlFile, linePlayerTriggerKey, nextId, productLine.showInGUI, activateText)
				if playerTrigger ~=  nil then
					productLine.playerTrigger = playerTrigger
					self.drawProductLineUI[nextId] = Utils.getNoNil(getXMLBool(xmlFile, linePlayerTriggerKey .. "#showPopupUI"), true)
				end
			end

			table.insert(self.productLines, productLine)

			i = i + 1
		end

		if #self.productLines > 1 then
			local sharedOperatingPartsKey = xmlKey .. ".sharedOperatingParts"
			if hasXMLProperty(xmlFile, sharedOperatingPartsKey) then
				self.sharedOperatingParts = {}
				self.sharedOperatingParts.operatingState = false
				self:loadOperatingParts(xmlFile, sharedOperatingPartsKey, self.sharedOperatingParts)
			end
		end

		local playerTriggerKey = xmlKey .. ".playerTrigger"
		if hasXMLProperty(xmlFile, playerTriggerKey) then
			local activateText = g_company.languageManager:getText("GC_Open_Overview_Menu")
			local playerTrigger = self.triggerManager:addTrigger(GC_PlayerTrigger, self.rootNode, self, xmlFile, playerTriggerKey, nil, true, activateText)
			if playerTrigger ~= nil then
				self.playerTrigger = playerTrigger
			end
		end

		if self.isServer and canLoad then
			if addMinuteChange then
				g_currentMission.environment:addMinuteChangeListener(self)
			end

			if addHourChange then
				g_currentMission.environment:addHourChangeListener(self)
			end
		end

		self.productionFactoryDirtyFlag = self:getNextDirtyFlag()
	else
		g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'inputProducts' have been registered factory cannot be loaded!", indexName)
		canLoad = false
	end

	return canLoad
end

function GC_ProductionFactory:loadProductParts(xmlFile, key, product)
	if self.isClient then
		local fillTypeName = g_fillTypeManager.indexToName[product.lastFillTypeIndex]
		local capacity = product.capacity

		local visibilityNodes = GC_VisibilityNodes:new(self.isServer, self.isClient)
		if visibilityNodes:load(self.rootNode, self, xmlFile, key, self.baseDirectory, capacity, true) then
			product.visibilityNodes = visibilityNodes
		end

		local movers = GC_Movers:new(self.isServer, self.isClient)
		if movers:load(self.rootNode, self, xmlFile, key, self.baseDirectory, capacity, true) then
			product.movers = movers
		end

		local fillVolumes = GC_FillVolume:new(self.isServer, self.isClient)
		if fillVolumes:load(self.rootNode, self, xmlFile, key, capacity, true, fillTypeName) then
			product.fillVolumes = fillVolumes
		end

		local digitalDisplays = GC_DigitalDisplays:new(self.isServer, self.isClient)
		if digitalDisplays:load(self.rootNode, self, xmlFile, key, nil, true) then
			product.digitalDisplays = digitalDisplays
		end
	end
end

function GC_ProductionFactory:loadOperatingParts(xmlFile, key, parent, isProductLine, isInput)
	if self.isClient then
		local lightsKey = key .. ".lighting"
		if hasXMLProperty(xmlFile, lightsKey) then
			local lighting = GC_Lighting:new(self.isServer, self.isClient)
			if lighting:load(self.rootNode, self, xmlFile, lightsKey) then
				parent.operateLighting = lighting
			end
		end

		local operateSounds = GC_Sounds:new(self.isServer, self.isClient)
		if operateSounds:load(self.rootNode, self, xmlFile, key) then
			parent.operateSounds = operateSounds
		end

		local shaders = GC_Shaders:new(self.isServer, self.isClient)
		if shaders:load(self.rootNode, self, xmlFile, key) then
			parent.operateShaders = shaders
		end

		local rotationNodes = GC_RotationNodes:new(self.isServer, self.isClient)
		if rotationNodes:load(self.rootNode, self, xmlFile, key) then
			parent.operateRotationNodes = rotationNodes
		end

		local particleEffects = GC_Effects:new(self.isServer, self.isClient)
		if particleEffects:load(self.rootNode, self, xmlFile, key) then
			parent.operateParticleEffects = particleEffects
		end

		if self.animationManager ~= nil then
			local xmlKey = string.format("%s.animations.animation", key)
			local warningExtra = string.format("[FACTORY - %s]", self.indexName)
			local operateAnimations = self.animationManager:loadAnimationNamesFromXML(xmlFile, xmlKey, warningExtra)
			if operateAnimations ~= nil then
				parent.operateAnimations = operateAnimations
			end
		end

		local animationClips = GC_AnimationClips:new(self.isServer, self.isClient)
		if animationClips:load(self.rootNode, self, xmlFile, key) then
			parent.operateAnimationClips = animationClips
		end

		if isProductLine then
			if hasXMLProperty(xmlFile, key .. ".conveyor") then
				local conveyor = GC_Conveyor:new(self.isServer, self.isClient)
				if conveyor:load(self.rootNode, self, xmlFile, key, "conveyor") then
					parent.conveyor = conveyor
				end
			end

			if hasXMLProperty(xmlFile, key .. ".conveyorEffect") then
				local conveyorEffect = GC_ConveyorEffekt:new(self.isServer, self.isClient)
				if conveyorEffect:load(self.rootNode, self, xmlFile, key, "conveyorEffect") then
					for i, shader in pairs (conveyorEffect.shaders) do
						if shader.productName ~= nil then
							local product = self.productNameToProduct[shader.productName]
							if product ~= nil then
								if product.conveyorEffects == nil then
									product.conveyorEffects = {}
								end

								table.insert(product.conveyorEffects, shader)
							else
								g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Invalid productName %s given at %s.conveyorEffect! Using default 'WHEAT' for fill effect instead.", self.indexName, shader.productName, key)
							end
						end
					end

					parent.conveyorEffect = conveyorEffect
				end
			end
		end
	end
end

function GC_ProductionFactory:delete()
	self.factoryDeleteStarted = true

	if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self)
	end

	if self.isServer then
		g_currentMission.environment:removeMinuteChangeListener(self)
		g_currentMission.environment:removeHourChangeListener(self)
	end

	if self.triggerManager ~= nil then
		self.triggerManager:removeAllTriggers()
	end

	if g_company.fillLevelsDisplay ~= nil then
		g_company.fillLevelsDisplay:removeCurrentObject(self)
	end

	if self.animationManager ~= nil then
		self.animationManager:delete()
	end

	if self.isClient then
		for _, product in ipairs (self.inputProducts) do
			if product.visibilityNodes ~= nil then
				product.visibilityNodes:delete()
			end

			if product.fillVolumes ~= nil then
				product.fillVolumes:delete()
			end

			if product.conveyorEffects ~= nil then
				product.conveyorEffects = nil
			end
		end

		if self.outputProducts ~= nil then
			for _, product in ipairs (self.outputProducts) do
				if product.visibilityNodes ~= nil then
					product.visibilityNodes:delete()
				end

				if product.fillVolumes ~= nil then
					product.fillVolumes:delete()
				end

				if product.conveyorEffects ~= nil then
					product.conveyorEffects = nil
				end
			end
		end

		for _, productLine in ipairs (self.productLines) do
			self:deleteOperatingParts(productLine)

			if productLine.conveyor ~= nil then
				productLine.conveyor:delete()
			end

			if productLine.conveyorEffect ~= nil then
				productLine.conveyorEffect:delete()
			end
		end

		if self.sharedOperatingParts ~= nil then
			self:deleteOperatingParts(self.sharedOperatingParts)
		end
	end

	GC_ProductionFactory:superClass().delete(self)
end

function GC_ProductionFactory:deleteOperatingParts(parent)
	if parent.operateLighting ~= nil then
		parent.operateLighting:delete()
	end

	if parent.operateSounds ~= nil then
		parent.operateSounds:delete()
	end

	if parent.operateShaders ~= nil then
		parent.operateShaders:delete()
	end

	if parent.operateRotationNodes ~= nil then
		parent.operateRotationNodes:delete()
	end

	if parent.operateParticleEffects ~= nil then
		parent.operateParticleEffects:delete()
	end

	if parent.operateAnimationClips ~= nil then
		parent.operateAnimationClips:delete()
	end
end

function GC_ProductionFactory:readStream(streamId, connection)
	GC_ProductionFactory:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:readStream(streamId, connection)
		end

		for _, inputProduct in ipairs (self.inputProducts) do
			local fillLevel = 0
			if streamReadBool(streamId) then
				fillLevel = streamReadFloat32(streamId)
			end

			self:updateFactoryLevels(fillLevel, inputProduct, nil, false)

			if streamReadBool(streamId) then
				inputProduct.totalDelivered = streamReadFloat32(streamId)
			end
		end

		if self.outputProducts ~= nil then
			for _, outputProduct in ipairs (self.outputProducts) do
				local fillLevel = 0
				if streamReadBool(streamId) then
					fillLevel = streamReadFloat32(streamId)
				end
				self:updateFactoryLevels(fillLevel, outputProduct, nil, false)
			end
		end

		for lineId, productLine in ipairs (self.productLines) do
			local active = streamReadBool(streamId)
			local userStopped = streamReadBool(streamId)
			self:setFactoryState(lineId, active, userStopped, true)

			if productLine.productSale ~= nil then
				productLine.productSale.productivityHours = streamReadUInt8(streamId)
				productLine.productSale.lifeTimeIncome = streamReadInt32(streamId)
			end
		end
	end
end

function GC_ProductionFactory:writeStream(streamId, connection)
	GC_ProductionFactory:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:writeStream(streamId, connection)
		end

		for _, inputProduct in ipairs (self.inputProducts) do
			local fillLevel = inputProduct.fillLevel
			if streamWriteBool(streamId, fillLevel > 0) then
				streamWriteFloat32(streamId, fillLevel)
			end

			local totalDelivered = inputProduct.totalDelivered
			if streamWriteBool(streamId, totalDelivered > 0) then
				streamWriteFloat32(streamId, totalDelivered)
			end
		end

		if self.outputProducts ~= nil then
			for _, outputProduct in ipairs (self.outputProducts) do
				local fillLevel = outputProduct.fillLevel
				if streamWriteBool(streamId, fillLevel > 0) then
					streamWriteFloat32(streamId, fillLevel)
				end
			end
		end

		for _, productLine in ipairs (self.productLines) do
			streamWriteBool(streamId, productLine.active)
			streamWriteBool(streamId, productLine.userStopped)

			if productLine.productSale ~= nil then
				streamWriteUInt8(streamId, productLine.productSale.productivityHours)
				local lifeTimeIncome = math.max(math.min(productLine.productSale.lifeTimeIncome, GC_ProductionFactory.MAX_INT), 0)
				streamWriteInt32(streamId, lifeTimeIncome)
			end
		end
	end
end

function GC_ProductionFactory:readUpdateStream(streamId, timestamp, connection)
	GC_ProductionFactory:superClass().readUpdateStream(self, streamId, timestamp, connection)

	if connection:getIsServer() then
		if streamReadBool(streamId) then
			for _, inputProduct in ipairs (self.inputProducts) do
				local fillLevel = 0
				if streamReadBool(streamId) then
					fillLevel = streamReadFloat32(streamId)
				end
				self:updateFactoryLevels(fillLevel, inputProduct, nil, false)
			end

			if self.outputProducts ~= nil then
				for _, outputProduct in ipairs (self.outputProducts) do
					local fillLevel = 0
					if streamReadBool(streamId) then
						fillLevel = streamReadFloat32(streamId)
					end
					self:updateFactoryLevels(fillLevel, outputProduct, nil, false)
				end
			end

			if self.hasProductSale then
				for _, productLine in ipairs (self.productLines) do
					if productLine.productSale ~= nil then
						productLine.productSale.productivityHours = streamReadUInt8(streamId)
						productLine.productSale.lifeTimeIncome = streamReadInt32(streamId)
					end
				end
			end
		end
	end
end

function GC_ProductionFactory:writeUpdateStream(streamId, connection, dirtyMask)
	GC_ProductionFactory:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)

	if not connection:getIsServer() then
		if streamWriteBool(streamId, bitAND(dirtyMask, self.productionFactoryDirtyFlag) ~= 0) then
			for _, inputProduct in ipairs (self.inputProducts) do
				local fillLevel = inputProduct.fillLevel
				if streamWriteBool(streamId, fillLevel > 0) then
					streamWriteFloat32(streamId, fillLevel)
				end
			end

			if self.outputProducts ~= nil then
				for _, outputProduct in ipairs (self.outputProducts) do
					local fillLevel = outputProduct.fillLevel
					if streamWriteBool(streamId, fillLevel > 0) then
						streamWriteFloat32(streamId, fillLevel)
					end
				end
			end

			if self.hasProductSale then
				for _, productLine in ipairs (self.productLines) do
					if productLine.productSale ~= nil then
						streamWriteUInt8(streamId, productLine.productSale.productivityHours)
						local lifeTimeIncome = math.max(math.min(productLine.productSale.lifeTimeIncome, GC_ProductionFactory.MAX_INT), 0)
						streamWriteInt32(streamId, lifeTimeIncome)
					end
				end
			end
		end
	end
end

function GC_ProductionFactory:loadFromXMLFile(xmlFile, key)
	local factoryKey = key
	if not self.isPlaceable then
		factoryKey = string.format("%s.productionFactory", key)
	end

	local i = 0
	while true do
		local inputProductKey = string.format(factoryKey .. ".inputProducts.inputProduct(%d)", i)
		if not hasXMLProperty(xmlFile, inputProductKey) then
			break
		end

		local name = getXMLString(xmlFile, inputProductKey .. "#name")
		if name ~= nil and self.inputProductNameToId[name] ~= nil then
			local inputProductId = self.inputProductNameToId[name]
			local inputProduct = self.inputProducts[inputProductId]

			local lastFillTypeIndex
			local lastFillTypeName = getXMLString(xmlFile, inputProductKey .. "#lastFillTypeName")
			if lastFillTypeName ~= nil then
				lastFillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(lastFillTypeName)
				if lastFillTypeIndex ~= nil and inputProduct.fillTypes[lastFillTypeIndex] ~= true then
					lastFillTypeIndex = nil
				end
			end

			local fillLevel = math.max(Utils.getNoNil(getXMLFloat(xmlFile, inputProductKey .. "#fillLevel"), 0), 0)
			self:updateFactoryLevels(fillLevel, inputProduct, lastFillTypeIndex, false)

			-- Do this now so I can correct the value before updating players when joining.
			-- After this I can update without any extra data ;-)
			if inputProduct.maximumAccepted > 0 then
				inputProduct.totalDelivered = math.min(math.max(Utils.getNoNil(getXMLFloat(xmlFile, inputProductKey .. "#totalDelivered"), 0), 0), inputProduct.maximumAccepted)
			end
		end

		i = i + 1
	end

	if self.outputProducts ~= nil then
		i = 0
		while true do
			local outputProductKey = string.format(factoryKey .. ".outputProducts.outputProduct(%d)", i)
			if not hasXMLProperty(xmlFile, outputProductKey) then
				break
			end

			local name = getXMLString(xmlFile, outputProductKey .. "#name")
			if name ~= nil and self.outputProductNameToId[name] ~= nil then
				local outputProductId = self.outputProductNameToId[name]
				local outputProduct = self.outputProducts[outputProductId]

				local fillLevel = 0
				if outputProduct.dynamicHeap ~= nil then
					fillLevel = outputProduct.dynamicHeap:getHeapLevel()
				elseif outputProduct.palletCreator ~= nil then
					outputProduct.palletCreator:loadFromXMLFile(xmlFile, outputProductKey)
					fillLevel = outputProduct.palletCreator:getTotalFillLevel(false, true)
				else
					fillLevel = math.max(Utils.getNoNil(getXMLFloat(xmlFile, outputProductKey .. "#fillLevel"), 0), 0)
				end

				self:updateFactoryLevels(fillLevel, outputProduct, nil, false)
			end

			i = i + 1
		end
	end

	if self.rainWaterCollector ~= nil then
		local updateCounter = getXMLInt(xmlFile, factoryKey..".rainWaterCollector#updateCounter")
		if updateCounter ~= nil then
			self.rainWaterCollector.updateCounter = updateCounter
		end

		local rainCollected = getXMLFloat(xmlFile, factoryKey..".rainWaterCollector#rainCollected")
		if rainCollected ~= nil then
			self.rainWaterCollector.collected = rainCollected
		end
	end

	if self.productLines ~= nil then
		i = 0
		while true do
			local productLineKey = string.format("%s.productLines.productLine(%d)", factoryKey, i)
			if not hasXMLProperty(xmlFile, productLineKey) then
				break
			end

			local lineId = getXMLInt(xmlFile, productLineKey .. "#lineId")
			if lineId ~= nil and self.productLines[lineId] ~= nil then
				local productLine = self.productLines[lineId]

				if productLine.productSale ~= nil then
					local productivityHours = getXMLInt(xmlFile, productLineKey .. ".productSale#productivityHours")
					if productivityHours ~= nil then
						productLine.productSale.productivityHours = productivityHours
					end

					local lifeTimeIncome = getXMLInt(xmlFile, productLineKey .. ".productSale#lifeTimeIncome")
					if lifeTimeIncome ~= nil then
						productLine.productSale.lifeTimeIncome = math.max(math.min(lifeTimeIncome, GC_ProductionFactory.MAX_INT), 0)
					end
				end

				if productLine.autoStart then
					local state = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#state"), false)
					local userStopped = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#userStopped"), false)

					self:setFactoryState(lineId, state, userStopped, true)
				end
			end

			i = i + 1
		end
	end

	return true
end

function GC_ProductionFactory:saveToXMLFile(xmlFile, key, usedModNames)
	local factoryKey = key
	if not self.isPlaceable then
		factoryKey = string.format("%s.productionFactory", key)

		-- This only saved for 'onCreate'. May not need as farmlandManager seems to have it sorted.
		setXMLInt(xmlFile, factoryKey .. "#farmId", self:getOwnerFarmId())
	end

	setXMLString(xmlFile, factoryKey .. "#indexName", self.indexName)

	local index = 0
	for _, inputProduct in ipairs(self.inputProducts) do
		local fillLevel = inputProduct.fillLevel

		local totalDelivered = 0
		if inputProduct.maximumAccepted > 0 then
			totalDelivered = inputProduct.totalDelivered
		end

		if fillLevel > 0 or totalDelivered > 0 then
			local inputProductKey = string.format("%s.inputProducts.inputProduct(%d)", factoryKey, index)

			setXMLString(xmlFile, inputProductKey .. "#name", inputProduct.name)
			setXMLFloat(xmlFile, inputProductKey .. "#fillLevel", fillLevel)

			if totalDelivered > 0 then
				setXMLFloat(xmlFile, inputProductKey .. "#totalDelivered", totalDelivered)
			end

			local lastFillTypeName = g_fillTypeManager:getFillTypeNameByIndex(inputProduct.lastFillTypeIndex)
			if lastFillTypeName ~= nil then
				setXMLString(xmlFile, inputProductKey .. "#lastFillTypeName", lastFillTypeName)
			end
		end

		index = index + 1
	end

	if self.outputProducts ~= nil then
		index = 0
		for _, outputProduct in ipairs (self.outputProducts) do
			local fillLevel = outputProduct.fillLevel
			if fillLevel > 0 then
				local outputProductKey = string.format("%s.outputProducts.outputProduct(%d)", factoryKey, index)

				setXMLString(xmlFile, outputProductKey .. "#name", outputProduct.name)
				setXMLFloat(xmlFile, outputProductKey .. "#fillLevel", outputProduct.fillLevel)

				if outputProduct.palletCreator ~= nil then
					outputProduct.palletCreator:saveToXMLFile(xmlFile, outputProductKey, usedModNames)
				end
			end

			index = index + 1
		end
	end

	if self.rainWaterCollector ~= nil then
		if self.rainWaterCollector.updateCounter > 0 and self.rainWaterCollector.collected > 0 then
			setXMLInt(xmlFile, factoryKey..".rainWaterCollector#updateCounter", self.rainWaterCollector.updateCounter)
			setXMLFloat(xmlFile, factoryKey..".rainWaterCollector#rainCollected", self.rainWaterCollector.collected)
		end
	end

	if self.productLines ~= nil then
		index = 0
		for lineId, productLine in ipairs (self.productLines) do
			local productLineKey = string.format("%s.productLines.productLine(%d)", factoryKey, index)

			setXMLInt(xmlFile, productLineKey .. "#lineId", lineId)
			setXMLBool(xmlFile, productLineKey .. "#state", productLine.active)
			setXMLBool(xmlFile, productLineKey .. "#userStopped", productLine.userStopped)

			if productLine.productSale ~= nil then
				setXMLInt(xmlFile, productLineKey .. ".productSale#productivityHours", productLine.productSale.productivityHours)
				setXMLInt(xmlFile, productLineKey .. ".productSale#lifeTimeIncome", productLine.productSale.lifeTimeIncome)
			end

			index = index + 1
		end
	end
end

function GC_ProductionFactory:update(dt)
	if self.isServer and self.levelChangeTimer > 0 then
		self.levelChangeTimer = self.levelChangeTimer - 1
		if self.levelChangeTimer <= 0 then
			self.lastCheckedFillType = nil
			self.lastCheckedTrigger = nil
		end

		self:raiseActive()
	end
end

function GC_ProductionFactory:hourChanged()
	if not self.factoryIsOwned then
		return
	end

	if self.isServer then
		if self.hasProductSale then
			local raiseFlags = false
			for lineId, productLine in pairs (self.productLines) do
				if productLine.productSale ~= nil then

					local currentHour = g_currentMission.environment.currentHour
					if currentHour == 0 then
						productLine.productSale.productivityHours = 24
					else
						if productLine.productSale.productivityHours <= 0 then
							productLine.productSale.productivityHours = 24 - currentHour
						end
					end

					if productLine.active then
						local stopProductLine = false
						local productPerHour = productLine.outputPerHour
						local hasProduct, producedFactor = self:getHasInputProducts(productLine, productPerHour)

						if hasProduct then
							raiseFlags = true

							for i = 1, #productLine.inputs do
								local input = productLine.inputs[i]
								local amount = producedFactor * productLine.inputsPercent[i]

								self:updateFactoryLevels(input.fillLevel - amount, input, input.lastFillTypeIndex, false)

								if input.fillLevel <= 0 then
									stopProductLine = true
								end
							end

							local income = math.floor(productLine.productSale.incomePerHour * (producedFactor / productPerHour))
							productLine.productSale.lifeTimeIncome = math.min(productLine.productSale.lifeTimeIncome + income, GC_ProductionFactory.MAX_INT)

							g_currentMission:addMoney(income, self:getOwnerFarmId(), MoneyType.PROPERTY_INCOME, true, false)
						else
							stopProductLine = true
							productLine.productSale.productivityHours = productLine.productSale.productivityHours - 1
						end

						if stopProductLine and productLine.active then
							self:setFactoryState(lineId, false, false)
						end
					else
						productLine.productSale.productivityHours = productLine.productSale.productivityHours - 1

						if productLine.autoStart and not productLine.userStopped and self:getCanOperate(lineId) then
							self:setFactoryState(lineId, true, false)
						end
					end
				end
			end

			if raiseFlags then
				self:raiseDirtyFlags(self.productionFactoryDirtyFlag)
			end
		end

		if self.hourlyIncomeTotal > 0 then
			g_currentMission:addMoney(self.hourlyIncomeTotal, self:getOwnerFarmId(), MoneyType.PROPERTY_INCOME, true, false)
			self.hourlyIncomeTotal = 0
		end
	end
end

function GC_ProductionFactory:minuteChanged()
	if not self.factoryIsOwned then
		return
	end

	if self.isServer then
		local raiseFlags = false

		if self.rainWaterCollector ~= nil then
			local rainLevel = 0
			local input = self.rainWaterCollector.input

			if g_currentMission.environment.weather:getIsRaining() then
				local rainToCollect = g_currentMission.environment.weather:getRainFallScale() * (self.rainWaterCollector.litresPerHour / 60)
				local newCollected = self.rainWaterCollector.collected + rainToCollect
				if input.fillLevel + newCollected <= input.capacity then
					self.rainWaterCollector.collected = newCollected
					self.rainWaterCollector.updateCounter = self.rainWaterCollector.updateCounter + 1
				end

				if self.rainWaterCollector.updateCounter >= 10 then
					self.rainWaterCollector.updateCounter = 0
					rainLevel = self.rainWaterCollector.collected
				end
			else
				if self.rainWaterCollector.updateCounter > 0 then
					self.rainWaterCollector.updateCounter = 0
					rainLevel = self.rainWaterCollector.collected
				end
			end

			if rainLevel > 0 then
				local amount = math.min(input.fillLevel + rainLevel, input.capacity)
				raiseFlags = true
				self:updateFactoryLevels(amount, input, FillType.WATER, false)
				self.rainWaterCollector.collected = 0
			end
		end

		if self.factorMinuteUpdate then
			local totalIncomeToPay = 0

			self.updateCounter = self.updateCounter + 1
			if self.updateCounter >= self.updateDelay then
				self.updateCounter = 0

				for lineId, productLine in pairs (self.productLines) do
					if productLine.productSale == nil then
						if productLine.active then
							local stopProductLine = false
							local productionFactor = (productLine.outputPerHour / 60) * self.updateDelay
							local hasSpace, factor = self:getHasOutputSpace(productLine, productionFactor)
							local hasProduct, producedFactor = self:getHasInputProducts(productLine, factor)

							if hasSpace and hasProduct then
								raiseFlags = true

								for i = 1, #productLine.inputs do
									local input = productLine.inputs[i]
									local amount = producedFactor * productLine.inputsPercent[i]

									self:updateFactoryLevels(input.fillLevel - amount, input, input.lastFillTypeIndex, false)

									local income = productLine.inputsIncome[i]
									if income ~= nil and income.pricePerLiter > 0.0 then
										local updateAmount = income.pricePerLiter * amount
										if income.usePriceMultiplier then
											updateAmount = updateAmount * EconomyManager.getPriceMultiplier()
										end

										self.hourlyIncomeTotal = self.hourlyIncomeTotal + updateAmount
									end

									if input.fillLevel <= 0 then
										stopProductLine = true
									end
								end

								if productLine.outputs ~= nil then
									for i = 1, #productLine.outputs do
										local output = productLine.outputs[i]
										local amount = producedFactor * productLine.outputsPercent[i]

										local newFillLevel = output.fillLevel + amount

										if output.dynamicHeap ~= nil then
											local dropped = output.dynamicHeap:updateDynamicHeap(amount, false)
											newFillLevel = output.dynamicHeap:getHeapLevel()
										elseif output.palletCreator ~= nil then
											local fillLevel, added = output.palletCreator:updatePalletCreators(amount, true)
											newFillLevel = fillLevel
											stopProductLine = not added
										end

										self:updateFactoryLevels(newFillLevel, output, output.fillTypeIndex,  false)

										if output.fillLevel >= output.capacity then
											stopProductLine = true
										end
									end
								end
							else
								stopProductLine = true
							end

							if stopProductLine and productLine.active then
								self:setFactoryState(lineId, false, false)
							end
						else
							if productLine.autoStart and not productLine.userStopped and self:getCanOperate(lineId, true) then
								self:setFactoryState(lineId, true, false)
							end
						end
					end
				end
			end
		end

		if raiseFlags then
			self:raiseDirtyFlags(self.productionFactoryDirtyFlag)
		end
	end
end

function GC_ProductionFactory:getHasOutputSpace(productLine, factor)
	local hasSpace = true

	if productLine ~= nil and productLine.outputs ~= nil and factor ~= nil then
		for i = 1, #productLine.outputs do
			local output = productLine.outputs[i]
			local outputWanted = productLine.outputsPercent[i] * factor
			local fillLevel = output.fillLevel
			local availableSpace = output.capacity - fillLevel
			local outputSpace = math.min(outputWanted, availableSpace)

			if outputSpace > 0 then
				if outputSpace < outputWanted then
					local adjustProduced = factor * (outputSpace / outputWanted)
					if adjustProduced < factor then
						factor = adjustProduced
					end
				end
			else
				hasSpace = false
				break
			end
		end
	end

	return hasSpace, factor
end

function GC_ProductionFactory:getHasInputProducts(productLine, factor)
	local hasProduct = false

	if productLine ~= nil and productLine.inputs ~= nil and factor ~= nil then
		for i = 1, #productLine.inputs do
			local input = productLine.inputs[i]
			local productNeeded = productLine.inputsPercent[i] * factor
			local productToUse = math.min(productNeeded, input.fillLevel)

			if productToUse > 0 then
				if productToUse < productNeeded then
					local adjustProduced = factor * (productToUse / productNeeded)
					if adjustProduced < factor then
						factor = adjustProduced
					end
				end

				hasProduct = true
			else
				hasProduct = false
				break
			end
		end
	end

	return hasProduct, factor
end

function GC_ProductionFactory:getCanOperate(lineId, checkPalletDelta)
	if self.productLines[lineId] ~= nil and self.productLines[lineId].inputs ~= nil then
		for i = 1, #self.productLines[lineId].inputs do
			local input = self.productLines[lineId].inputs[i]

			if input.fillLevel <= 0 then
				return false
			end
		end

		if self.productLines[lineId].outputs ~= nil then
			for i = 1, #self.productLines[lineId].outputs do
				local output = self.productLines[lineId].outputs[i]

				if output.fillLevel >= output.capacity then
					return false
				end

				if checkPalletDelta and output.palletCreator ~= nil then
					if output.palletCreator:getTotalSpace() <= 0 then
						return false
					end
				end
			end
		end

		return true
	end

	return false
end

function GC_ProductionFactory:updateFactoryLevels(fillLevel, product, fillTypeIndex, raiseFlags)
	if fillLevel == nil or product == nil then
		return
	end

	if product.maximumAccepted ~= nil and product.maximumAccepted > 0 then
		if product.totalDelivered <= product.maximumAccepted then
			local levelToAdd = fillLevel - product.fillLevel
			if levelToAdd > 0 then
				product.totalDelivered = product.totalDelivered + levelToAdd
			end
		end
	end

	product.fillLevel = fillLevel

	if self.isClient then
		if product.visibilityNodes ~= nil then
			product.visibilityNodes:updateNodes(fillLevel)
		end

		if product.movers ~= nil then
			product.movers:updateMovers(fillLevel)
		end

		if product.fillVolumes ~= nil then
			if fillTypeIndex ~= nil and fillTypeIndex ~= product.fillVolumes.lastFillTypeIndex then
				product.fillVolumes:setFillType(fillTypeIndex)
			end

			product.fillVolumes:addFillLevel(fillLevel)
		end

		if product.conveyorEffects ~= nil then
			if fillTypeIndex ~= nil and fillTypeIndex ~= product.conveyorLastFillTypeIndex then
				product.conveyorLastFillTypeIndex = fillTypeIndex

				if fillTypeIndex ~= FillType.UNKNOWN then
					for _, shader in pairs (product.conveyorEffects) do
						if shader.materialType ~= nil and shader.materialTypeId ~= nil then
							local material = g_materialManager:getMaterial(fillTypeIndex, shader.materialType, shader.materialTypeId)
							if material ~= nil then
								setMaterial(shader.node, material, 0)
							end
						end
					end
				end
			end
		end

		if product.digitalDisplays ~= nil then
			product.digitalDisplays:updateLevelDisplays(fillLevel, product.capacity)
		end
	end

	if self.isServer and raiseFlags ~= false then
		self:raiseDirtyFlags(self.productionFactoryDirtyFlag)
	end
end

function GC_ProductionFactory:setFactoryState(lineId, state, userStopped, noEventSend)
	if userStopped == nil then
		userStopped = not state
	end

	GC_ProductionFactoryStateEvent.sendEvent(self, lineId, state, userStopped, noEventSend)

	self.productLines[lineId].active = state
	self.productLines[lineId].userStopped = userStopped

	if self.isClient then
		self:setOperatingParts(self.productLines[lineId], state, true)

		if self.sharedOperatingParts ~= nil then
			if self.sharedOperatingParts.operatingState ~= state then
				local updateShared = true

				if not state then
					for i = 1, #self.productLines do
						if self.productLines[i].active then
							updateShared = false
							break
						end
					end
				end

				if updateShared then
					self.sharedOperatingParts.operatingState = state
					self:setOperatingParts(self.sharedOperatingParts, state, false)
				end
			end
		end
	end
end

function GC_ProductionFactory:setOperatingParts(parent, state, isProductLine)
	if parent.operateLighting ~= nil then
		parent.operateLighting:setAllLightsState(state)
	end

	if parent.operateSounds ~= nil then
		parent.operateSounds:setSoundsState(state)
	end

	if parent.operateShaders ~= nil then
		parent.operateShaders:setShadersState(state)
	end

	if parent.operateRotationNodes ~= nil then
		parent.operateRotationNodes:setRotationNodesState(state)
	end

	if parent.operateParticleEffects ~= nil then
		parent.operateParticleEffects:setEffectsState(state)
	end

	if parent.operateAnimations ~= nil then
		for i = 1, #parent.operateAnimations do
			local name = parent.operateAnimations[i]
			self.animationManager:setAnimationByState(name, state, true)
		end
	end

	if parent.operateAnimationClips ~= nil then
		parent.operateAnimationClips:setAnimationClipsState(state)
	end

	if isProductLine then
		if parent.conveyor ~= nil then
			parent.conveyor:setState(state)
		end

		if parent.conveyorEffect ~= nil then
			parent.conveyorEffect:setState(state)
		end
	end
end

function GC_ProductionFactory:getIsFactoryLineOn(lineId)
	return self.productLines[lineId].active
end

function GC_ProductionFactory:getFactoryIsOwned()
	return self.factoryIsOwned
end

function GC_ProductionFactory:getAutoStart(lineId, ignoreActive)
	if self.productLines[lineId].autoStart then
		if ignoreActive == true then
			return not self.productLines[lineId].userStopped
		else
			return not self.productLines[lineId].userStopped and not self.productLines[lineId].active
		end
	end

	return false
end

function GC_ProductionFactory:doAutoStart(fillTypeIndex, triggerId, forceCheck)
	if self.isServer then
		self.levelChangeTimer = 1000
		if (self.lastCheckedFillType ~= fillTypeIndex) or (self.lastCheckedTrigger ~= triggerId) or forceCheck == true then
			self.lastCheckedFillType = fillTypeIndex
			self.lastCheckedTrigger = triggerId
			for lineId, _ in pairs (self.productLines) do
				if self:getAutoStart(lineId) and self:getCanOperate(lineId) then
					self:setFactoryState(lineId, true, false)
				end
			end

			self:raiseActive()
		end
	end
end

function GC_ProductionFactory:getProductFromTriggerId(triggerId, fillTypeIndex, isInput)
	if isInput then
		if self.triggerIdToInputProductId[triggerId] ~= nil then
			local inputProductId = self.triggerIdToInputProductId[triggerId][fillTypeIndex]
			if inputProductId ~= nil then
				return self.inputProducts[inputProductId]
			end
		end
	else
		if self.triggerIdToOutputProductId[triggerId] ~= nil then
			local outputProductId = self.triggerIdToOutputProductId[triggerId][fillTypeIndex]
			if outputProductId ~= nil then
				return self.outputProducts[outputProductId]
			end
		end
	end

	return
end

function GC_ProductionFactory:palletCreatorInteraction(level, blockedLevel, deltaWaiting, fillTypeIndex, triggerId)
	if not self.isServer then
		return
	end

	local product = self:getProductFromTriggerId(triggerId, fillTypeIndex, false)
	if product ~= nil then
		local totalLevel = level + blockedLevel

		if totalLevel ~= product.fillLevel then
			self:updateFactoryLevels(level, product, fillTypeIndex, true)
		end

		if self.triggerIdToLineIds[triggerId] ~= nil then
			for _, lineId in pairs (self.triggerIdToLineIds[triggerId]) do
				if totalLevel < product.capacity then
					if self:getAutoStart(lineId) and self:getCanOperate(lineId) then
						self:setFactoryState(lineId, true, false)
					end
				else
					if self.productLines[lineId].active and not self:getCanOperate(lineId, true) then
						self:setFactoryState(lineId, false, false)
					end
				end
			end
		end
	end

end

function GC_ProductionFactory:vehicleChangedHeapLevel(heapLevel, fillTypeIndex, heapId)
	if not self.isServer then
		return
	end

	local product = self:getProductFromTriggerId(heapId, fillTypeIndex, false)
	if product ~= nil then
		local stopFactory, startFactory = false, false

		local isIncreasing = heapLevel > product.fillLevel
		if isIncreasing then
			stopFactory = product.fillLevel < product.capacity and heapLevel >= product.capacity
		else
			startFactory = product.fillLevel >= product.capacity and heapLevel < product.capacity
		end

		self:updateFactoryLevels(heapLevel, product, fillTypeIndex, true)

		if self.triggerIdToLineIds[heapId] ~= nil then
			for _, lineId in pairs (self.triggerIdToLineIds[heapId]) do
				if startFactory then
					if self:getAutoStart(lineId) and self:getCanOperate(lineId) then
						self:setFactoryState(lineId, true, false)
					end
				end

				if stopFactory then
					if self.productLines[lineId].active and not self:getCanOperate(lineId) then
						self:setFactoryState(lineId, false, false)
					end
				end
			end
		end
	end
end

function GC_ProductionFactory:getFreeCapacity(fillTypeIndex, farmId, triggerId)
	-- This is ONLY used for input triggers!
	local product = self:getProductFromTriggerId(triggerId, fillTypeIndex, true)
	if product ~= nil then
		if product.maximumAccepted <= 0 then
			return product.capacity - product.fillLevel
		else
			return math.min(product.maximumAccepted - product.totalDelivered, product.capacity - product.fillLevel)
		end
	end

	return 0
end

function GC_ProductionFactory:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
	local product = self:getProductFromTriggerId(triggerId, fillTypeIndex, true)

	if product ~= nil then
		product.lastFillTypeIndex = fillTypeIndex
		self:updateFactoryLevels(product.fillLevel + fillLevelDelta, product, fillTypeIndex, true)

		self:doAutoStart(fillTypeIndex, triggerId)
	end
end

function GC_ProductionFactory:removeFillLevel(farmId, fillLevelDelta, fillTypeIndex, triggerId)
	local product = self:getProductFromTriggerId(triggerId, fillTypeIndex, false)

	if product ~= nil then
		self:updateFactoryLevels(product.fillLevel - fillLevelDelta, product, fillTypeIndex, true)
		self:doAutoStart(fillTypeIndex, triggerId)

		return product.fillLevel
	end

	return
end

function GC_ProductionFactory:getProvidedFillTypes(triggerId)
	return self.providedFillTypes[triggerId]
end

function GC_ProductionFactory:getAllProvidedFillLevels(farmId, triggerId)
	local fillLevels = {}

	if self.providedFillTypes[triggerId] ~= nil then
		for fillTypeIndex, _ in pairs(self.providedFillTypes[triggerId]) do
			local output = self:getProductFromTriggerId(triggerId, fillTypeIndex, false)
			if output ~= nil then
				fillLevels[fillTypeIndex] = Utils.getNoNil(fillLevels[fillTypeIndex], 0) + output.fillLevel
			end
		end
	end

	return fillLevels, 0
end

function GC_ProductionFactory:getProvidedFillLevel(fillTypeIndex, farmId, triggerId)
	local output = self:getProductFromTriggerId(triggerId, fillTypeIndex, false)
	if output ~= nil then
		return output.fillLevel
	end

	return 0
end

function GC_ProductionFactory:playerTriggerActivated(lineId)
	if lineId ~= nil then
		if self.productLines[lineId] ~= nil then
			if not self.productLines[lineId].showInGUI then
				return
			end
		else
			lineId = nil
		end
	end

	local dialog = g_gui:showDialog("GC_ProductionFactoryDialog")
	if dialog ~= nil then
		dialog.target:setupFactoryData(self, lineId)
	else
		g_company.debug:writeError(self.debugData, "[FACTORY - %s] Failed to open 'GC_ProductionFactoryDialog'!", self.indexName)
	end
end

function GC_ProductionFactory:playerTriggerOnEnterLeave(playerInTrigger, lineId)
	if g_company.fillLevelsDisplay == nil then
		return
	end

	if self.drawProductLineUI[lineId] == true then
		if playerInTrigger and not self.factoryDeleteStarted then
			if self.productLines[lineId] ~= nil then
				g_company.fillLevelsDisplay:setObject(self, self.productLines[lineId].title, self.guiData.inputHeader, self.guiData.outputHeader)
				self.guiLineId = lineId
			end
		else
			self.guiLineId = nil
		end
	end
end

function GC_ProductionFactory:getFillLevelInformation(listRight, listLeft)
	local inputs = self:getInputs(self.guiLineId)
	if inputs ~= nil then
		for id, input in pairs (inputs) do
			listRight[id] = {title = input.title, fillLevel = input.fillLevel, capacity = input.capacity}

			if id >= GC_ProductionFactory.LIMIT then
				break
			end
		end

		local outputs = self:getOutputs(self.guiLineId)
		if outputs ~= nil then
			for id, output in pairs (outputs) do
				listLeft[id] = {title = output.title, fillLevel = output.fillLevel, capacity = output.capacity}

				if id >= GC_ProductionFactory.LIMIT then
					break
				end
			end
		end
	end
end

function GC_ProductionFactory:getInputs(lineId)
	if lineId ~= nil then
		local productLine = self.productLines[lineId]
		if productLine ~= nil and productLine.inputs ~= nil then
			return productLine.inputs
		end
	end

	return
end

function GC_ProductionFactory:getOutputs(lineId)
	if lineId ~= nil then
		local productLine = self.productLines[lineId]
		if productLine ~= nil and productLine.outputs ~= nil then
			return productLine.outputs
		end
	end

	return
end

function GC_ProductionFactory:getInputFreeCapacity(input)
	local fillLevel, capacity = 0, 0

	if input ~= nil then
		if input.maximumAccepted <= 0 then
			capacity = input.capacity
			fillLevel = input.fillLevel
		else
			fillLevel = input.totalDelivered
			capacity = input.maximumAccepted
		end
	end

	return capacity - fillLevel
end

function GC_ProductionFactory:getInputCapacity(input)
	if input ~= nil then
		if input.maximumAccepted > 0 then
			return math.max(input.maximumAccepted - input.totalDelivered, 0)
		end

		return input.capacity
	end

	return 0
end

function GC_ProductionFactory:canBuyProduct(input)
	local hasPermission = input ~= nil and input.canPurchaseProduct

	if hasPermission and g_currentMission.missionDynamicInfo.isMultiplayer then
		local userId = g_currentMission.playerUserId
		local permissions = g_farmManager:getFarmByUserId(userId):getUserPermissions(userId)
		if permissions.buyVehicle or
			permissions.transferMoney or
			permissions.tradeAnimals or
			permissions.buyPlaceable or
			permissions.updateFarm then

			return true
		else
			return false
		end
	end

	return hasPermission
end

function GC_ProductionFactory:changeBuyLiters(input, delta, currentBuyLiters, purchasePrice)
	local moneyAvailable = 0
	if g_currentMission ~= nil and g_currentMission.player ~= nil then
		local farm = g_farmManager:getFarmById(g_currentMission.player.farmId)
		moneyAvailable = farm.money
	end

	if moneyAvailable > 0 and (purchasePrice ~= nil and purchasePrice > 0) then
		local maxLitres = self:getInputFreeCapacity(input)
		local maxCanBuy = moneyAvailable / purchasePrice
		local maxToAdd = math.min(maxLitres, maxCanBuy)

		local newLiters = Utils.getNoNil(currentBuyLiters, 0) + delta
		if newLiters >= 0 then
			if maxToAdd >= newLiters then
				return newLiters, newLiters * purchasePrice
			else
				return 0, 0
			end
		else
			return maxToAdd, maxToAdd * purchasePrice
		end
	end

	return 0, 0
end

function GC_ProductionFactory:verifyPriceAndLitres(input, buyLiters, purchasePrice)
	local validLitres, price = 0, 0

	if input ~= nil and buyLiters ~= nil then
		local maxLitres = self:getInputFreeCapacity(input)
		validLitres = math.min(buyLiters, maxLitres)
		if validLitres > 0 then
			price = purchasePrice * validLitres
		end
	end

	return validLitres, price
end

function GC_ProductionFactory:doProductPurchase(input, buyLiters, purchasePrice)
	if input ~= nil and (buyLiters ~= nil and buyLiters > 0) and purchasePrice ~= nil then
		if g_currentMission:getIsServer() then
			local maxLitres = self:getInputFreeCapacity(input)
			local validLitres = math.min(buyLiters, maxLitres)
			local price = purchasePrice * Utils.getNoNil(validLitres, 0)
			if price > 0 then
				local newFillLevel = input.fillLevel + validLitres
				g_currentMission:addMoney(-price, self:getOwnerFarmId(), MoneyType.OTHER, true, true)
				self:updateFactoryLevels(newFillLevel, input, nil, true)
				self:doAutoStart(nil, nil, true)
			end
		else
			g_client:getServerConnection():sendEvent(GC_ProductionFactoryProductPurchaseEvent:new(self, input.id, buyLiters, purchasePrice))
		end
	end
end

function GC_ProductionFactory:spawnPalletFromOutput(output, numberToSpawn)
	if (output ~= nil and output.objectSpawner ~= nil) and (numberToSpawn ~= nil and numberToSpawn > 0) then
		if self.isServer then
			-- Only if we are full before spawn do we try and start after spawning.
			local autoStart = output.fillLevel >= output.capacity

			local object = output.objectSpawner.object
			local numberSpawned = output.objectSpawner:spawnByObjectInfo(object, numberToSpawn)

			local newFillLevel = output.fillLevel - (object.fillLevel * numberSpawned)
			self:updateFactoryLevels(newFillLevel, output, nil, true)

			if autoStart then
				self:doAutoStart(nil, nil, true)
			end

			return numberSpawned
		else
			g_client:getServerConnection():sendEvent(GC_ProductionFactorySpawnPalletEvent:new(self, output.id, numberToSpawn))
		end
	end
end

function GC_ProductionFactory:getFreePalletSpawnAreas(output)
	local availableAreas = 0

	if output ~= nil then
		if output.objectSpawner ~= nil then
			local object = output.objectSpawner.object
			local maxAvailable = math.floor(output.fillLevel / object.fillLevel)
			if maxAvailable > 0 then
				availableAreas = output.objectSpawner:getSpaceByObjectInfo(object, maxAvailable)
			end
		end
	end

	return availableAreas
end

function GC_ProductionFactory:changeNumberToSpawn(output, delta, numberToSpawn)
	local maxToSpawn = self:getFreePalletSpawnAreas(output)
	local newNumberToSpawn = Utils.getNoNil(numberToSpawn, 0) + delta

	if newNumberToSpawn >= 0 then
		if newNumberToSpawn > maxToSpawn then
			return 0
		else
			return newNumberToSpawn
		end
	elseif newNumberToSpawn < 0 then
		return maxToSpawn
	end
end

function GC_ProductionFactory:onSetFarmlandStateChanged(farmId)
	self:setOwnerFarmId(farmId, false)
end

function GC_ProductionFactory:setOwnerFarmId(ownerFarmId, noEventSend)
	GC_ProductionFactory:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend)

	self.factoryIsOwned = self:getIsValidFarmlandId()
	if self.factoryIsOwned then
		-- Just in-case it is lost before the sale.
		self.currentFarmOwnerId = ownerFarmId
	else
		for lineId, productLine in pairs (self.productLines) do
			self:setFactoryState(lineId, false, false, true)

			if self.isServer and self.currentFarmOwnerId ~= nil then
				if productLine.outputs ~= nil then
					for _, output in pairs (productLine.outputs) do
						if output.dynamicHeap ~= nil then
							local heapLevel = output.dynamicHeap:getHeapLevel()
							if heapLevel > 0 then
								output.dynamicHeap:removeFromHeap(heapLevel)
							end
						end
					end
				end
			end

			if productLine.productSale ~= nil then
				productLine.productSale.lifeTimeIncome = 0
			end
		end

		if self.isServer and self.currentFarmOwnerId ~= nil then
			self:doBulkProductSell(false)
		end

		self.currentFarmOwnerId = nil
	end

	self.hourlyIncomeTotal = 0

	if self.triggerManager ~= nil then
		self.triggerManager:setAllOwnerFarmIds(ownerFarmId, noEventSend)
	end
end

function GC_ProductionFactory:doBulkProductSell(getPrice)
	local totalSellPrice = 0

	for id, inputProduct in pairs (self.inputProducts) do
		if inputProduct.maximumAccepted <= 0 then
			local fillLevel = inputProduct.fillLevel

			if fillLevel > 100 then
				local lowestPrice = math.huge

				for fillTypeIndex, _ in pairs (inputProduct.fillTypes) do
					local fillTypePrice = self:getFillTypePrice(fillTypeIndex, true)
					if fillTypePrice < lowestPrice then
						lowestPrice = fillTypePrice
					end
				end

				if lowestPrice == math.huge then
					lowestPrice = 0.5
				end

				local price = fillLevel * lowestPrice
				totalSellPrice = totalSellPrice + price
			end

			if not getPrice then
				self:updateFactoryLevels(0.0, inputProduct, nil, false)
			end
		end
	end

	for _, outputProduct in pairs (self.outputProducts) do
		if outputProduct.removeFillLevelOnSell then
			local fillLevel = outputProduct.fillLevel
			if fillLevel > 100 then
				local lowestPrice = self:getFillTypePrice(outputProduct.fillTypeIndex, true)

				if lowestPrice == math.huge then
					lowestPrice = 0.5
				end

				local price = fillLevel * lowestPrice
				totalSellPrice = totalSellPrice + price
			end

			if not getPrice then
				self:updateFactoryLevels(0.0, outputProduct, nil, false)
			end
		end
	end

	if getPrice then
		return totalSellPrice
	else
		if totalSellPrice > 0 then
			g_currentMission:addMoney(totalSellPrice, self.currentFarmOwnerId, MoneyType.OTHER, true, true)
			self:raiseDirtyFlags(self.productionFactoryDirtyFlag)
		end
	end
end

function GC_ProductionFactory:getFillTypePrice(fillTypeIndex, lowest)
	local fillTypePrice = 0
	if lowest then
		fillTypePrice = math.huge
	end

	if fillTypeIndex ~= nil and (fillTypeIndex ~= FillType.UNKNOWN) and (fillTypeIndex ~= FillType.WATER) then
		for _, unloadingStation in pairs (g_currentMission.storageSystem.unloadingStations) do
			if unloadingStation.isSellingPoint and unloadingStation.fillTypePrices[fillTypeIndex] ~= nil and unloadingStation.fillTypePrices[fillTypeIndex] > 0 then
				local price = unloadingStation:getEffectiveFillTypePrice(fillTypeIndex)
				if price ~= nil then
					if lowest then
						if price < fillTypePrice then
							fillTypePrice = price
						end
					else
						if price > fillTypePrice then
							fillTypePrice = price
						end
					end
				end
			end
		end
	end

	return fillTypePrice
end

function GC_ProductionFactory:getIsValidFarmlandId(playerFarmId)
	local currentId = self:getOwnerFarmId()
	if currentId ~= AccessHandler.EVERYONE and currentId ~= AccessHandler.NOBODY then
		if playerFarmId ~= nil then
			return playerFarmId == currentId
		end

		return true
	end

	return false
end