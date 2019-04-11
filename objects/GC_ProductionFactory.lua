--
-- GlobalCompany - Objects - GC_ProductionFactory
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX / kevink98
-- @Date: 22.03.2018
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.0.0 (??.??.2019):
-- 		- convert to fs19
--
-- 	v1.0.0.0 (22.03.2018):
-- 		- initial fs17 (GtX)
--
--
-- Notes:
--
--
-- ToDo:
-- 		- Finish main gui and trigger gui.
-- 		- Add missing triggers (Dynamic Pallet Input, Pallet-On-Demand Output, Animal Load / Unload).
--
--
--


GC_ProductionFactory = {};
local GC_ProductionFactory_mt = Class(GC_ProductionFactory, Object);
InitObjectClass(GC_ProductionFactory, "GC_ProductionFactory");

GC_ProductionFactory.debugIndex = g_company.debug:registerScriptName("GC_ProductionFactory");

getfenv(0)["GC_ProductionFactory"] = GC_ProductionFactory;

function GC_ProductionFactory:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");
	local farmlandId = getUserAttribute(transformId, "farmlandId");

	if indexName ~= nil and xmlFilename ~= nil and farmlandId ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;

		-- Create object 'instance' now so we can access 'debugData'.
		local object = GC_ProductionFactory:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);

		-- Do 'XML' and 'KEY' check and load if possible.
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.productionFactories.productionFactory", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);

				g_company.debug:writeOnCreate(object.debugData, "[FACTORY - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);

				local warningText = string.format("[FACTORY - %s]  Attribute 'farmlandId' is invalid! Factory will not operate correctly. 'farmlandId' should match area object is located at.", indexName);
				g_company.farmlandOwnerListener:addListener(object, farmlandId, warningText);
			else
				g_company.debug:writeOnCreate(object.debugData, "[FACTORY - %s]  Failed to load from '%s'!", indexName, xmlFilename);
				object:delete();
			end;

			delete(xmlFile);
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[FACTORY - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename);
			else
				g_company.debug:writeModding(object.debugData, "[FACTORY - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename);
			end;
		end;
	else
		print("  [LSMC - GlobalCompany] - [GC_ProductionFactory]");
		if indexName == nil then
			print(string.format("    ONCREATE: Trying to load 'FACTORY' with nodeId name %s, attribute 'indexName' could not be found.", getName(transformId)));
		else
			if xmlFilename == nil then
				print(string.format("    ONCREATE: [FACTORY - %s]  Attribute 'xmlFilename' is missing!", indexName));
			end;

			if farmlandId == nil then
				print(string.format("    ONCREATE: [FACTORY - %s]  Attribute 'farmlandId' is missing!", indexName));
			end;
		end;
	end;
end;

function GC_ProductionFactory:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or GC_ProductionFactory_mt);

	self.xmlFilename = xmlFilename;
	self.baseDirectory = baseDirectory;
	self.customEnvironment = customEnvironment;

	self.triggerIdToProduct = {};
	self.triggerIdToLineId = {};
	self.drawProductLineUI = {};

	self.productLines = {};
	self.inputProducts = {};
	self.outputProducts = {};
	
	self.inputProductNameToId = {};
	self.outputProductNameToId = {};
	
	self.numInputProducts = 0;
	self.numOutputProducts = 0;

	self.levelChangeTimer = -1;

	self.debugData = g_company.debug:getDebugData(GC_ProductionFactory.debugIndex, nil, customEnvironment);

	return self;
end;

function GC_ProductionFactory:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	local canLoad = true;

	self.nodeId  = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.triggerManager = GC_TriggerManager:new(self);
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "ProductionFactory_" .. indexName;
	end;

	local factoryTitle = getXMLString(xmlFile, xmlKey .. ".guiInformation#title");
	if factoryTitle ~= nil then
		factoryTitle = g_company.languageManager:getText(factoryTitle);
	else
		factoryTitle = indexName;
	end;

	local factoryImage; -- BACKUP IS STORED WITH GUI
	local factoryCamera = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. ".guiInformation#cameraFeed"), self.i3dMappings);
	if factoryCamera == nil then
		factoryImage = getXMLString(xmlFile, xmlKey .. ".guiInformation#imageFilename");
	end;

	local factoryDescription = Utils.getNoNil(getXMLString(xmlFile, xmlKey .. ".guiInformation#description"), "");
	if factoryDescription ~= "" then
		factoryDescription = g_company.languageManager:getText(factoryDescription);
	end;

	self.guiData = {factoryTitle = factoryTitle, factoryImage = factoryImage, factoryCamera = factoryCamera, factoryDescription = factoryDescription};

	local operationKey = string.format("%s.operation", xmlKey);
	self.showInTablet = Utils.getNoNil(getXMLBool(xmlFile, operationKey .. "#showInTablet"), true); -- FUTURE
	self.showInGlobalGUI = Utils.getNoNil(getXMLBool(xmlFile, operationKey .. "#showInGlobalGUI"), true); -- FUTURE
	self.updateDelay = math.max(Utils.getNoNil(getXMLInt(xmlFile, operationKey .. "#updateDelayMinutes"), 10), 1);
	self.updateCounter = self.updateDelay;

	self.canPurchaseInputs = Utils.getNoNil(getXMLBool(xmlFile, operationKey .. "#canPurchaseInputProducts"), true)

	----------------------------
	-- LOAD ANIMATION MANAGER --
	----------------------------

	if hasXMLProperty(xmlFile, xmlKey .. ".animations") then
		local animationManager = GC_AnimationManager:new(self.isServer, self.isClient);
		if animationManager:load(nodeId, self, xmlFile, xmlKey, true) then
			animationManager:register(true);
			self.animationManager = animationManager;
		else
			animationManager:delete();
		end;
	end;

	-----------------------------------------------------------------------------------------------------
	-- REGISTER LOADING TRIGGERS (This is done early to allow multiple output products in one silo ;-) --
	-----------------------------------------------------------------------------------------------------

	self.providedFillTypes = {};
	self.registeredLoadingTriggers = {};
	if hasXMLProperty(xmlFile, xmlKey .. ".registerLoadingTriggers") then
		local i = 0;
		while true do
			local loadingTriggerKey = string.format("%s.registerLoadingTriggers.loadingTrigger(%d)", xmlKey, i);
			if not hasXMLProperty(xmlFile, loadingTriggerKey) then
				break;
			end;

			local name = getXMLString(xmlFile, loadingTriggerKey .. "#name");
			if name ~= nil and self.registeredLoadingTriggers[name] == nil then
				local loadingTrigger = self.triggerManager:loadTrigger(GC_LoadingTrigger, self.nodeId , xmlFile, loadingTriggerKey, nil, false);
				if loadingTrigger ~= nil then
					local triggerId = loadingTrigger.managerId;
					loadingTrigger.extraParamater = triggerId;
					loadingTrigger.fillTypes = nil;
					loadingTrigger:setStationName(factoryTitle);
					self.registeredLoadingTriggers[name] = {trigger = loadingTrigger, isUsed = false, key = loadingTriggerKey};
					self.providedFillTypes[triggerId] = {};
					self.triggerIdToProduct[triggerId] = {};
				end;
			end;
			i = i + 1;
		end;
	end;

	-----------------------------
	-- REGISTER INPUT PRODUCTS --
	-----------------------------

	local i = 0;
	while true do
		local inputProductKey = string.format("%s.registerInputProducts.inputProduct(%d)", xmlKey, i);
		if not hasXMLProperty(xmlFile, inputProductKey) then
			break;
		end;

		local inputProductName = getXMLString(xmlFile, inputProductKey .. "#name");
		if inputProductName ~= nil and self.inputProductNameToId[name] == nil then
			local inputProduct = {};
			local concatTitles = {};
			local usedFillTypeNames = {};

			inputProduct.name = inputProductName;

			local j = 0;
			while true do
				local fillTypesKey = string.format("%s.fillTypes.fillType(%d)", inputProductKey, j);
				if not hasXMLProperty(xmlFile, fillTypesKey) then
					break;
				end;

				local fillTypeName = getXMLString(xmlFile, fillTypesKey .. "#name");
				if fillTypeName ~= nil then
					local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName);
					if fillType ~= nil and usedFillTypeNames[fillTypeName] == nil then
						usedFillTypeNames[fillTypeName] = inputProductName;

						if inputProduct.fillTypes == nil then
							inputProduct.fillTypes = {};
						end;

						inputProduct.fillTypes[fillType.index] = true;

						if inputProduct.lastFillTypeIndex == nil then
							inputProduct.lastFillTypeIndex = fillType.index;
						end;

						local fillTypeTitle = fillType.title;
						local customTitle = getXMLString(xmlFile, fillTypesKey .. "#title"); -- Use this to change fillType name. e.g WOODCHIPS > LOGS
						if customTitle ~= nil then
							fillTypeTitle = g_company.languageManager:getText(customTitle);
						end;

						table.insert(concatTitles, fillTypeTitle);
					else
						if fillType == nil then
							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Unknown fillType ( %s ) found in 'inputProduct' ( %s ) at %s, ignoring!", indexName, fillTypeName, fillTypesKey);
						else
							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Duplicate 'inputProduct' fillType ( %s ) in '%s', FillType already used at '%s'!", indexName, fillTypeName, inputProductName, usedFillTypeNames[fillTypeName]);
						end;
					end;
				end;

				j = j + 1;
			end;

			if inputProduct.fillTypes ~= nil then
				inputProduct.fillLevel = 0;
				inputProduct.concatedFillTypeTitles = table.concat(concatTitles, " | "); -- Maybe gui can use this.
				inputProduct.capacity = Utils.getNoNil(getXMLInt(xmlFile, inputProductKey .. "#capacity"), 1000);

				-- Only if modder allows product purchasing.
				if self.canPurchaseInputs then					
					local pricePerLiter = getXMLFloat(xmlFile, inputProductKey .. "#pricePerLiter");
					local deliveryCostMultiplier = Utils.getNoNil(getXMLInt(xmlFile, inputProductKey .. "#deliveryCostMultiplier"), 2);
					
					-- If no 'pricePerLiter' then take the most expensive product price.
					if pricePerLiter == nil or pricePerLiter <= 0.0 then
						pricePerLiter = 0;
						for fTypeIndex, _ in pairs (inputProduct.fillTypes) do
							local fillType = g_fillTypeManager:getFillTypeByIndex(fTypeIndex);
							if fillType.pricePerLiter > pricePerLiter then
								pricePerLiter = fillType.pricePerLiter;
							end;
						end;
					end;

					-- NEW FARMER = 3 | FARM MANAGER = 1.8 | START FROM SCRATCH = 1 --
					local multiplier = math.max(EconomyManager.PRICE_MULTIPLIER[g_currentMission.missionInfo.difficulty], 1);
					inputProduct.pricePerLiter = (pricePerLiter * multiplier) * math.max(deliveryCostMultiplier, 1);
				else
					inputProduct.pricePerLiter = 0;
				end;

				local productTitle = getXMLString(xmlFile, inputProductKey .. "#title");
				if productTitle ~= nil then
					inputProduct.title = g_company.languageManager:getText(productTitle);
				else
					inputProduct.title = string.format(g_company.languageManager:getText("GC_Input_Title_Backup"), self.numInputProducts + 1);
				end;

				if hasXMLProperty(xmlFile, inputProductKey .. ".inputMethods") then
					-- Rain Water (Server side only!)
					if self.isServer then
						if hasXMLProperty(xmlFile, inputProductKey .. ".inputMethods.rainWaterCollector") then
							if inputProduct.fillTypes[FillType.WATER] ~= nil then
								local litresPerHour = getXMLString(xmlFile, inputProductKey .. ".inputMethods.rainWaterCollector#litresPerHour");
								if litresPerHour ~= nil then
									if self.rainWaterCollector == nil then
										self.rainWaterCollector = {};
										self.rainWaterCollector.collected = 0;
										self.rainWaterCollector.updateCounter = 0;
										self.rainWaterCollector.input = inputProduct;
										self.rainWaterCollector.litresPerHour = litresPerHour;
									else
										g_company.debug:writeModding(self.debugData, "[FACTORY - %s] 'rainWaterCollector' is already added to 'inputProduct' %s! Only one 'rainWaterCollector' can be used for each factory.", indexName, self.rainWaterCollector.input.name);
									end;
								else
									g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'litresPerHour' given for 'rainWaterCollector' at 'inputProduct' %s! This will be ignored.", indexName, inputProductName);
								end;
							else
								g_company.debug:writeModding(self.debugData, "[FACTORY - %s] 'inputProduct' %s does not contain fillType 'WATER', <rainWaterCollector> has been disabled.", indexName, inputProductName);
							end;
						end;
					end;

					-- Wood Trigger
					local woodTriggerKey = inputProductKey .. ".inputMethods.woodTrigger";
					if hasXMLProperty(xmlFile, woodTriggerKey) then
						if inputProduct.fillTypes[FillType.WOODCHIPS] ~= nil then
							local trigger = self.triggerManager:loadTrigger(GC_WoodTrigger, self.nodeId , xmlFile, woodTriggerKey, "WOODCHIPS");
							if trigger ~= nil then
								trigger.extraParamater = trigger.managerId;
								self.triggerIdToProduct[trigger.managerId] = inputProduct;
							end;
						else
							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] 'inputProduct' %s does not contain fillType 'WOODCHIPS', <woodTrigger> has been disabled.", indexName, inputProductName);
						end;
					end;

					-- Unload Trigger (USER OPTIONS: Tipping, Pallet, Bale)
					local unloadTriggerKey = inputProductKey .. ".inputMethods.unloadTrigger";
					if hasXMLProperty(xmlFile, unloadTriggerKey) then
						local forcedFillTypes = {};
						for index, _ in pairs (inputProduct.fillTypes) do
							table.insert(forcedFillTypes, index)
						end;

						local trigger = self.triggerManager:loadTrigger(GC_UnloadingTrigger, self.nodeId , xmlFile, unloadTriggerKey, forcedFillTypes);
						if trigger ~= nil then
							trigger.extraParamater = trigger.managerId;
							self.triggerIdToProduct[trigger.managerId] = inputProduct;
						end;
					end;

					-- Dynamic Pallet Trigger
					local dynamicPalletAreaKey = inputProductKey .. ".inputMethods.dynamicPalletArea";
					if hasXMLProperty(xmlFile, dynamicPalletAreaKey) then
						-- Coming Soon
					end;

					-- Livestock Trigger
					local livestockTriggerKey = inputProductKey .. ".inputMethods.livestockTrigger";
					if hasXMLProperty(xmlFile, livestockTriggerKey) then
						-- Coming Soon
					end;
				end;

				-- Load Movers, VisNodes and FillVolume.
				self:loadProductParts(xmlFile, inputProductKey, inputProduct);
				
				-- Reset all items for the first time.
				self:updateFactoryLevels(0, inputProduct, nil, false);

				-- Add to 'inputProducts' table.				
				table.insert(self.inputProducts, inputProduct);
				self.numInputProducts = #self.inputProducts;
				self.inputProductNameToId[inputProductName] = self.numInputProducts;
			end;
		else
			if inputProductName == nil then
				g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No name found at %s", indexName, inputProductKey);
			else
				g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Duplicate name '%s' used %s", indexName, inputProductName, inputProductKey);
			end;
		end;

		i = i + 1;
	end;

	------------------------------
	-- REGISTER OUTPUT PRODUCTS --
	------------------------------

	i = 0;
	while true do
		local outputProductKey = string.format("%s.registerOutputProducts.outputProduct(%d)", xmlKey, i);
		if not hasXMLProperty(xmlFile, outputProductKey) then
			break;
		end;

		local outputProductName = getXMLString(xmlFile, outputProductKey .. "#name");
		if outputProductName ~= nil and self.outputProductNameToId[outputProductName] == nil then
			local outputProduct = {};
			outputProduct.name = outputProductName;

			local fillTypeName = getXMLString(xmlFile, outputProductKey .. "#fillType");
			if fillTypeName ~= nil then
				local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
				if fillTypeIndex ~= nil then
					outputProduct.fillLevel = 0;
					outputProduct.isUsed = false;
					outputProduct.fillTypeIndex = fillTypeIndex;
					outputProduct.lastFillTypeIndex = fillTypeIndex;
					outputProduct.capacity = Utils.getNoNil(getXMLInt(xmlFile, outputProductKey .. "#capacity"), 1000);

					local productTitle = getXMLString(xmlFile, outputProductKey .. "#title");
					if productTitle ~= nil then
						outputProduct.title =  g_company.languageManager:getText(productTitle);
					else
						outputProduct.title = string.format(g_company.languageManager:getText("GC_Output_Title_Backup"), self.numOutputProducts + 1);
					end;

					local outputMethodsKey = outputProductKey .. ".outputMethods";
					if hasXMLProperty(xmlFile, outputMethodsKey) then
						local triggersLoaded, invalidTriggers = {}, {};

						-- OnDemand Object Spawner
						local onDemandPalletSpawnerKey = outputMethodsKey .. ".objectSpawner";
						if hasXMLProperty(xmlFile, onDemandPalletSpawnerKey) then
							--[[Coming Soon
							local objectSpawner = self.triggerManager:loadTrigger(GC_ObjectSpawner, self.nodeId, xmlFile, outputMethodsKey);
							if objectSpawner ~= nil then
								objectSpawner.extraParamater = objectSpawner.managerId;
								outputProduct.objectSpawner = objectSpawner;
								self.triggerIdToProduct[objectSpawner.managerId] = outputProduct;
							end;]]
							table.insert(triggersLoaded, "objectSpawner");
						end;

						-- Loading Trigger (SILO)
						local loadingTriggerKey = outputMethodsKey .. ".loadingTrigger";
						if hasXMLProperty(xmlFile, loadingTriggerKey) then
							local name = getXMLString(xmlFile, loadingTriggerKey .. "#name");
							local stationName = getXMLString(xmlFile, loadingTriggerKey .. "#stationName");
							if self.registeredLoadingTriggers[name] ~= nil then
								self.registeredLoadingTriggers[name].isUsed = true;
								local trigger = self.registeredLoadingTriggers[name].trigger;
								local triggerId = trigger.extraParamater;
								if self.providedFillTypes[triggerId][fillTypeIndex] == nil then
									self.providedFillTypes[triggerId][fillTypeIndex] = true;
									if stationName ~= nil then
										trigger:setStationName(stationName);
									end;

									self.triggerIdToProduct[triggerId][fillTypeIndex] = outputProduct;

									table.insert(triggersLoaded, "loadingTrigger");
								else
									g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Can not add Output Product '%s' to Loading Trigger '%s'! FillType '%s' already exists.", indexName, outputProductName, name, fillTypeName);
								end;
							else
								g_company.debug:writeModding(self.debugData, "[FACTORY - %s] loadingTrigger '%s could not be found at 'productionFactory.registerLoadingTriggers'! You first need to register this trigger.", indexName, name)
							end;
						end;

						-- Dynamic Heap
						local dynamicHeapKey = outputMethodsKey .. ".dynamicHeap";
						if hasXMLProperty(xmlFile, dynamicHeapKey) then
							if #triggersLoaded == 0 then
								local dynamicHeap = self.triggerManager:loadTrigger(GC_DynamicHeap, self.nodeId, xmlFile, dynamicHeapKey, fillTypeName);
								if dynamicHeap ~= nil then
									-- These allow auto start/stop of factory and also instant update for 'GUI', 'Movers', 'VisNodes', 'Digital Displays' and FillVolume.
									if dynamicHeap.vehicleInteractionTrigger ~= nil then
										dynamicHeap.extraParamater = dynamicHeap.managerId;
										outputProduct.dynamicHeap = dynamicHeap;
										self.triggerIdToProduct[dynamicHeap.managerId] = outputProduct;

										table.insert(triggersLoaded, "dynamicHeap");
									else
										self.triggerManager:unregisterTrigger(dynamicHeap);
										g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'vehicleInteractionTrigger' found at '%s.dynamicHeap'", indexName, outputMethodsKey);
									end;
								end;
							else
								table.insert(invalidTriggers, "dynamicHeap");
							end;
						end;

						-- Pallet Creators
						if hasXMLProperty(xmlFile, outputMethodsKey .. ".palletCreators") then
							if #triggersLoaded == 0 then
								local palletCreator = self.triggerManager:loadTrigger(GC_PalletCreator, self.nodeId, xmlFile, outputMethodsKey, self.baseDirectory, outputProduct.fillTypeIndex);
								if palletCreator ~= nil then
									-- These allow auto start/stop of factory and also instant update for 'GUI', 'Movers', 'VisNodes', 'Digital Displays' and FillVolume.
									if palletCreator.palletInteractionTriggers ~= nil then
										palletCreator.extraParamater = palletCreator.managerId;
										palletCreator:setWarningText(factoryTitle);

										outputProduct.palletCreator = palletCreator;
										outputProduct.capacity = palletCreator:getTotalCapacity();

										self.triggerIdToProduct[palletCreator.managerId] = outputProduct;

										table.insert(triggersLoaded, "palletCreator");
									else
										self.triggerManager:unregisterTrigger(palletCreator);
										g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'palletInteractionTrigger(s)' found at '%s.palletCreators'", indexName, outputMethodsKey);
									end;
								end;
							else
								table.insert(invalidTriggers, "palletCreator");
							end;
						end;

						-- Print invalid combinations.
						if #invalidTriggers > 0 then
							triggersLoaded = table.concat(triggersLoaded, " or ");
							invalidTriggers = table.concat(invalidTriggers, " and ");

							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Invalid 'outputMethod' combinations, '%s' can not be combined with '%s'!", indexName, invalidTriggers, triggersLoaded);
						end;
					end;

					-- Load Movers, VisNodes, Digital Displays and FillVolume.
					self:loadProductParts(xmlFile, outputProductKey, outputProduct);					
					
					-- Reset all items for the first time.
					self:updateFactoryLevels(0, outputProduct, nil, false);

					-- Add to 'outputProduct' table.
					table.insert(self.outputProducts, outputProduct);
					self.numOutputProducts = #self.outputProducts;
					self.outputProductNameToId[outputProductName] = self.numOutputProducts;
				else
					g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Invalid fillType '%s' given at %s", indexName, fillTypeName, outputProductKey);
				end;
			else
				g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No fillType found at %s", indexName, outputProductKey);
			end;
		else
			if outputProductName == nil then
				g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No name found at %s", indexName, outputProductKey);
			else
				g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Duplicate name '%s' used %s", indexName, outputProductName, outputProductKey);
			end;
		end;

		i = i + 1;
	end;

	for regName, item in pairs (self.registeredLoadingTriggers) do
		if not item.isUsed then
			self.triggerManager:unregisterTrigger(item.trigger);
			g_company.debug:writeModding(self.debugData, "[FACTORY - %s] loadingTrigger '%s' found at '%s.loadingTrigger' is not in use! This should be removed.", indexName, regName, item.key);
		end;
	end;

	------------------------------------
	-- SETUP FACTORY PRODUCTION LINES --
	------------------------------------

	if self.numInputProducts > 0 and self.numOutputProducts > 0 then
		i = 0;
		while true do
			local productLineKey = string.format("%s.productLines.productLine(%d)", xmlKey, i);
			if not hasXMLProperty(xmlFile, productLineKey) then
				break;
			end;

			local productLine = {};
			local productLineId = #self.productLines + 1;

			productLine.active = false;
			productLine.userStopped = false;
			productLine.autoStart = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#autoLineStart"), false);
			productLine.outputPerHour = Utils.getNoNil(getXMLInt(xmlFile, productLineKey .. "#outputPerHour"), 1000);

			local productLineTitle = getXMLString(xmlFile, productLineKey .. "#title");
			if productLineTitle ~= nil then
				productLine.title = g_company.languageManager:getText(productLineTitle);
			else
				productLine.title = string.format(g_company.languageManager:getText("GC_Productline_Title_Backup"), productLineId);
			end;

			-- Inputs
			local inputKeyId = 0;
			local inputProductNameToInputId = {};
			while true do
				local inputKey = string.format("%s.inputs.inputProduct(%d)", productLineKey, inputKeyId);
				if not hasXMLProperty(xmlFile, inputKey) then
					break;
				end;

				local name = getXMLString(xmlFile, inputKey .. "#name");
				if self.inputProductNameToId[name] ~= nil then					
					if inputProductNameToInputId[name] == nil then
						local inputProductId = self.inputProductNameToId[name];
						local percent = Utils.getNoNil(getXMLInt(xmlFile, inputKey .. "#percent"), 100) / 100;

						if productLine.inputs == nil then
							productLine.inputs = {};
						end;

						local inputId = #productLine.inputs + 1;
						inputProductNameToInputId[name] = inputId;

						productLine.inputs[inputId] = self.inputProducts[inputProductId];
						productLine.inputs[inputId].percent = math.min(math.max(percent, 0.1), 1);
						
						productLine.inputs[inputId].id = inputId;
						productLine.inputs[inputId].lineId = productLineId;
					else
						g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Trying to add inputProduct '%s' twice at %s!", indexName, name, inputKey);
					end;
				else
					g_company.debug:writeModding(self.debugData, "[FACTORY - %s] inputProduct '%s' does not exist! You must first register inputProducts in factory XML.", indexName, name);
				end;

				inputKeyId = inputKeyId + 1;
			end;

			-- Outputs
			local outputKeyId = 0;
			local outputProductNameToOutputId = {};
			while true do
				local outputKey = string.format("%s.outputs.outputProduct(%d)", productLineKey, outputKeyId);
				if not hasXMLProperty(xmlFile, outputKey) then
					break;
				end;

				local name = getXMLString(xmlFile, outputKey .. "#name");
				if self.outputProductNameToId[name] ~= nil then
					if outputProductNameToOutputId[name] == nil then
						local outputProductId = self.outputProductNameToId[name];
						local percent = Utils.getNoNil(getXMLInt(xmlFile, outputKey .. "#percent"), 100) / 100;

						if productLine.outputs == nil then
							productLine.outputs = {};
						end;

						local outputId = #productLine.outputs + 1;
						outputProductNameToOutputId[name] = outputId;

						productLine.outputs[outputId] = self.outputProducts[outputProductId];
						productLine.outputs[outputId].percent = math.min(math.max(percent, 0.1), 1);
						
						productLine.outputs[outputId].id = outputId;
						productLine.outputs[outputId].lineId = productLineId;
						
						local out = productLine.outputs[outputId]
						if out.palletCreator ~= nil then
							self.triggerIdToLineId[out.palletCreator.extraParamater] = productLineId;
							out = nil;
						elseif productLine.outputs[outputId].dynamicHeap ~= nil then
							self.triggerIdToLineId[out.dynamicHeap.extraParamater] = productLineId;
							out = nil;
						end;

						local outputFillTypeIndex = self.outputProducts[outputProductId].fillTypeIndex

						-- Store title and image data for quick GUI access.
						local fillType = g_fillTypeManager:getFillTypeByIndex(outputFillTypeIndex);
						productLine.outputs[outputId].title = fillType.title;
						productLine.outputs[outputId].imageFilename = fillType.hudOverlayFilename;
					end;
				end;
				outputKeyId = outputKeyId + 1;
			end;			
			
			outputProductNameToOutputId = nil;

			-- Load operating parts for each product line.
			local operatingPartsKey = string.format("%s.operatingParts", productLineKey);
			self:loadOperatingParts(xmlFile, operatingPartsKey, productLine);

			-- Load player trigger for each product line. (These will show - mCompany - style UI when in trigger or open full GUI).
			local playerTriggerKey = string.format("%s.playerTrigger", productLineKey);
			if hasXMLProperty(xmlFile, playerTriggerKey) then
				local nextId = #self.productLines + 1;
				local playerTrigger = self.triggerManager:loadTrigger(GC_PlayerTrigger, self.nodeId, xmlFile, playerTriggerKey, nextId, true);
				if playerTrigger ~=  nil then
					productLine.playerTrigger = playerTrigger;
					self.drawProductLineUI[nextId] = Utils.getNoNil(getXMLBool(xmlFile, playerTriggerKey .. "#drawUI"), true);
				end;
			end;

			table.insert(self.productLines, productLine);

			i = i + 1;
		end;

		---------------------------
		-- LOAD OPERATING CLOCKS --
		---------------------------
		if hasXMLProperty(xmlFile, operationKey .. ".clocks") then
			local clocks = GC_Clock:new(self.isServer, self.isClient);
			if clocks:load(self.nodeId, self, xmlFile, operationKey) then
				self.operationClocks = clocks;
			end;
		end;

		---------------------------------------------------------------------
		-- LOAD SHARED OPERATING PARTS (ONLY WITH 2 OR MORE PRODUCT LINES) --
		---------------------------------------------------------------------

		if #self.productLines > 1 then
			local sharedOperatingPartsKey = string.format("%s.sharedOperatingParts", xmlKey);
			if hasXMLProperty(xmlFile, sharedOperatingPartsKey) then
				self.sharedOperatingParts = {};
				self.sharedOperatingParts.operatingState = false;
				self:loadOperatingParts(xmlFile, sharedOperatingPartsKey, self.sharedOperatingParts);
			end;
		end;

		-----------------------------------------------------------------------------------------------------------------------------------------
		-- LOAD SHARED PLAYER TRIGGER (This will be for opening the Factory GUI and future purchase, sell, and to display open / close times.) --
		-----------------------------------------------------------------------------------------------------------------------------------------

		local playerTriggerKey = string.format("%s.playerTrigger", xmlKey);
		if hasXMLProperty(xmlFile, playerTriggerKey) then
			local playerTrigger = self.triggerManager:loadTrigger(GC_PlayerTrigger, self.nodeId , xmlFile, playerTriggerKey, nil, true);
			if playerTrigger ~= nil then
				self.playerTrigger = playerTrigger;
			end;
		end;

		--------------------
		-- FINISH LOADING --
		--------------------

		if self.isServer and canLoad then
			g_currentMission.environment:addMinuteChangeListener(self);
		end;

		self.productionFactoryDirtyFlag = self:getNextDirtyFlag();
	else
		if self.numInputProducts <= 0 then
			g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'inputProducts' have been registered factory cannot be loaded!", indexName);
		end;

		if self.numOutputProducts <= 0 then
			g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'outputProducts' have been registered factory cannot be loaded!", indexName);
		end;

		canLoad = false;
	end;

	return canLoad;
end;

function GC_ProductionFactory:loadProductParts(xmlFile, key, product)
	if self.isClient then
		local fillTypeName = g_fillTypeManager.indexToName[product.lastFillTypeIndex];
		local capacity = product.capacity;

		local visibilityNodes = GC_VisibilityNodes:new(self.isServer, self.isClient);
		if visibilityNodes:load(self.nodeId, self, xmlFile, key, self.baseDirectory, capacity, true) then
			product.visibilityNodes = visibilityNodes;
		end;

		local movers = GC_Movers:new(self.isServer, self.isClient);
		if movers:load(self.nodeId, self, xmlFile, key, self.baseDirectory, capacity, true) then
			product.movers = movers;
		end;

		local fillVolumes = GC_FillVolume:new(self.isServer, self.isClient);
		if fillVolumes:load(self.nodeId, self, xmlFile, key, capacity, true, fillTypeName) then
			product.fillVolumes = fillVolumes;
		end;

		local digitalDisplays = GC_DigitalDisplays:new(self.isServer, self.isClient);
		if digitalDisplays:load(self.nodeId, self, xmlFile, key, nil, true) then
			product.digitalDisplays = digitalDisplays;
		end;
	end;
end;

function GC_ProductionFactory:loadOperatingParts(xmlFile, key, parent)
	if self.isClient then
		local lightsKey = key .. ".lighting";
		if hasXMLProperty(xmlFile, lightsKey) then
			local lighting = GC_Lighting:new(self.isServer, self.isClient);
			if lighting:load(self.nodeId, self, xmlFile, lightsKey) then
				parent.operateLighting = lighting;
			end;
		end;

		local operateSounds = GC_Sounds:new(self.isServer, self.isClient);
		if operateSounds:load(self.nodeId, self, xmlFile, key) then
			parent.operateSounds = operateSounds;
		end;

		local shaders = GC_Shaders:new(self.isServer, self.isClient);
		if shaders:load(self.nodeId, self, xmlFile, key) then
			parent.operateShaders = shaders;
		end;

		local rotationNodes = GC_RotationNodes:new(self.isServer, self.isClient);
		if rotationNodes:load(self.nodeId, self, xmlFile, key) then
			parent.operateRotationNodes = rotationNodes;
		end;

		local particleEffects = GC_Effects:new(self.isServer, self.isClient);
		if particleEffects:load(self.nodeId, self, xmlFile, key) then
			parent.operateParticleEffects = particleEffects;
		end;

		if self.animationManager ~= nil then
			local xmlKey = string.format("%s.animations.animation", key);
			local warningExtra = string.format("[FACTORY - %s]", self.indexName);
			local operateAnimations = self.animationManager:loadAnimationNamesFromXML(xmlFile, xmlKey, warningExtra);
			if operateAnimations ~= nil then
				parent.operateAnimations = operateAnimations;
			end;
		end;

		local animationClips = GC_AnimationClips:new(self.isServer, self.isClient);
		if animationClips:load(self.nodeId, self, xmlFile, key) then
			parent.operateAnimationClips = animationClips;
		end;
	end;
end;

function GC_ProductionFactory:delete()
	if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self);
	end;

	if self.isServer then
		g_currentMission.environment:removeMinuteChangeListener(self);
	end;
	
	if self.triggerManager ~= nil then
		self.triggerManager:unregisterAllTriggers();
	end;

	if self.animationManager ~= nil then
		self.animationManager:delete();
	end;

	if self.isClient then		
		for _, product in ipairs (self.inputProducts) do
			if product.visibilityNodes ~= nil then
				product.visibilityNodes:delete();
			end;

			if product.fillVolumes ~= nil then
				product.fillVolumes:delete();
			end;
		end;
		
		for _, product in ipairs (self.outputProducts) do
			if product.visibilityNodes ~= nil then
				product.visibilityNodes:delete();
			end;

			if product.fillVolumes ~= nil then
				product.fillVolumes:delete();
			end;
		end;
		
		for _, productLine in ipairs (self.productLines) do
			self:deleteOperatingParts(productLine);
		end;

		if self.sharedOperatingParts ~= nil then
			self:deleteOperatingParts(self.sharedOperatingParts);
		end;

		if self.operationClocks ~= nil then
			self.operationClocks:delete();
		end;
	end;

	GC_ProductionFactory:superClass().delete(self);
end;

function GC_ProductionFactory:deleteOperatingParts(parent)
	if parent.operateLighting ~= nil then
		parent.operateLighting:delete();
	end;

	if parent.operateSounds ~= nil then
		parent.operateSounds:delete();
	end;
	
	if parent.operateShaders ~= nil then
		parent.operateShaders:delete();
	end;

	if parent.operateRotationNodes ~= nil then
		parent.operateRotationNodes:delete();
	end;

	if parent.operateParticleEffects ~= nil then
		parent.operateParticleEffects:delete();
	end;

	if parent.operateAnimationClips ~= nil then
		parent.operateAnimationClips:delete();
	end;
end;

function GC_ProductionFactory:readStream(streamId, connection)
	GC_ProductionFactory:superClass().readStream(self, streamId, connection);

	if connection:getIsServer() then
		for _, inputProduct in ipairs (self.inputProducts) do
			local fillLevel = 0;
			if streamReadBool(streamId) then
                fillLevel = streamReadFloat32(streamId);
            end;
			self:updateFactoryLevels(fillLevel, inputProduct, nil, false);				
		end;

		for _, outputProduct in ipairs (self.outputProducts) do
			local fillLevel = 0;
			if streamReadBool(streamId) then
                fillLevel = streamReadFloat32(streamId);
            end;
			self:updateFactoryLevels(fillLevel, outputProduct, nil, false);				
		end;
	end;
end;

function GC_ProductionFactory:writeStream(streamId, connection)
	GC_ProductionFactory:superClass().writeStream(self, streamId, connection);

	if not connection:getIsServer() then
		for _, inputProduct in ipairs (self.inputProducts) do
            local fillLevel = inputProduct.fillLevel;
            if streamWriteBool(streamId, fillLevel > 0) then
                streamWriteFloat32(streamId, fillLevel);
            end
		end;
		
		for _, outputProduct in ipairs (self.outputProducts) do
            local fillLevel = outputProduct.fillLevel;
            if streamWriteBool(streamId, fillLevel > 0) then
                streamWriteFloat32(streamId, fillLevel);
            end
		end;
	end;
end;

function GC_ProductionFactory:readUpdateStream(streamId, timestamp, connection)
	GC_ProductionFactory:superClass().readUpdateStream(self, streamId, timestamp, connection);

	if connection:getIsServer() then
		if streamReadBool(streamId) then
            for _, inputProduct in ipairs (self.inputProducts) do
				local fillLevel = 0;
				if streamReadBool(streamId) then
                    fillLevel = streamReadFloat32(streamId);
                end;
				self:updateFactoryLevels(fillLevel, inputProduct, nil, false);				
			end;

			for _, outputProduct in ipairs (self.outputProducts) do
				local fillLevel = 0;
				if streamReadBool(streamId) then
                    fillLevel = streamReadFloat32(streamId);
                end;
				self:updateFactoryLevels(fillLevel, outputProduct, nil, false);				
			end;
        end;
	end;
end;

function GC_ProductionFactory:writeUpdateStream(streamId, connection, dirtyMask)
	GC_ProductionFactory:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);

	if not connection:getIsServer() then
		if streamWriteBool(streamId, bitAND(dirtyMask, self.productionFactoryDirtyFlag) ~= 0) then
			for _, inputProduct in ipairs (self.inputProducts) do
                local fillLevel = inputProduct.fillLevel;
                if streamWriteBool(streamId, fillLevel > 0) then
                    streamWriteFloat32(streamId, fillLevel);
                end
			end;
			
			for _, outputProduct in ipairs (self.outputProducts) do
                local fillLevel = outputProduct.fillLevel;
                if streamWriteBool(streamId, fillLevel > 0) then
                    streamWriteFloat32(streamId, fillLevel);
                end
			end;
		end;
	end;
end;

function GC_ProductionFactory:loadFromXMLFile(xmlFile, key)
	local factoryKey = key;
	if not self.isPlaceable then
		factoryKey = string.format("%s.productionFactory", key);
	end;
	
	local i = 0;
    while true do
        local inputProductKey = string.format(factoryKey .. ".inputProducts.inputProduct(%d)", i);
        if not hasXMLProperty(xmlFile, inputProductKey) then
            break;
        end;
		
		local name = getXMLString(xmlFile, inputProductKey .. "#name");
		if name ~= nil and self.inputProductNameToId[name] ~= nil then
			local inputProductId = self.inputProductNameToId[name];
			local inputProduct = self.inputProducts[inputProductId];
			
			local lastFillTypeIndex;
			local lastFillTypeName = getXMLString(xmlFile, inputProductKey .. "#lastFillTypeName");
			if lastFillTypeName ~= nil then
				lastFillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(lastFillTypeName);
				if lastFillTypeIndex ~= nil and inputProduct.fillTypes[lastFillTypeIndex] ~= true then
					lastFillTypeIndex = nil;
				end;
			end;

			local fillLevel = math.max(Utils.getNoNil(getXMLFloat(xmlFile, inputProductKey .. "#fillLevel"), 0), 0)
			self:updateFactoryLevels(fillLevel, inputProduct, lastFillTypeIndex, false);
		end;

		i = i + 1;
	end;
	
	i = 0;
    while true do
        local outputProductKey = string.format(factoryKey .. ".outputProducts.outputProduct(%d)", i);
        if not hasXMLProperty(xmlFile, outputProductKey) then
            break;
        end;
		
		local name = getXMLString(xmlFile, outputProductKey .. "#name");
		if name ~= nil and self.outputProductNameToId[name] ~= nil then
			local outputProductId = self.outputProductNameToId[name];
			local outputProduct = self.outputProducts[outputProductId];
			
			local fillLevel = 0;
			if outputProduct.dynamicHeap ~= nil then
				fillLevel = outputProduct.dynamicHeap:getHeapLevel();
			elseif outputProduct.palletCreator ~= nil then
				outputProduct.palletCreator:loadFromXMLFile(xmlFile, outputProductKey);
				fillLevel = outputProduct.palletCreator:getTotalFillLevel(false, true);
			else
				fillLevel = math.max(Utils.getNoNil(getXMLFloat(xmlFile, outputProductKey .. "#fillLevel"), 0), 0)
			end;

			self:updateFactoryLevels(fillLevel, outputProduct, nil, false);
		end;

		i = i + 1;
	end;

	if self.rainWaterCollector ~= nil then
		local updateCounter = getXMLInt(xmlFile, factoryKey..".rainWaterCollector#updateCounter");
		if updateCounter ~= nil then
			self.rainWaterCollector.updateCounter = updateCounter;
		end;

		local rainCollected = getXMLFloat(xmlFile, factoryKey..".rainWaterCollector#rainCollected");
		if rainCollected ~= nil then
			self.rainWaterCollector.collected = rainCollected;
		end;
	end;

	if self.productLines ~= nil then
		i = 0
		while true do
			local productLineKey = string.format("%s.productLines.productLine(%d)", factoryKey, i)
			if not hasXMLProperty(xmlFile, productLineKey) then
				break
			end

			local lineId = getXMLInt(xmlFile, productLineKey .. "#lineId");
			if lineId ~= nil and self.productLines[lineId] ~= nil then
				if self.productLines[lineId].autoStart then
					local state = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#state"), false);
					local userStopped = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#userStopped"), false);
	
					if state and not userStopped then
						self:setFactoryState(lineId, state);
					end;
				end;
			end;

			i = i + 1;
		end
	end;

	--if self.animationManager ~= nil then
		--self.animationManager:loadFromXMLFile(xmlFile, factoryKey)
	--end;

	return true;
end;

function GC_ProductionFactory:saveToXMLFile(xmlFile, key, usedModNames)
	local factoryKey = key;
	if not self.isPlaceable then
		factoryKey = string.format("%s.productionFactory", key);

		-- This only saved for 'onCreate'. May not need as farmlandManager seems to have it sorted.
		setXMLInt(xmlFile, factoryKey .. "#farmId", self:getOwnerFarmId());
	end;

	-- This is just for identification.
	setXMLString(xmlFile, factoryKey .. "#indexName", self.indexName);
	
	local index = 0;
    for _, inputProduct in ipairs(self.inputProducts) do        
		local fillLevel = inputProduct.fillLevel;

		if fillLevel > 0 then
			local inputProductKey = string.format("%s.inputProducts.inputProduct(%d)", factoryKey, index);
			
			setXMLString(xmlFile, inputProductKey .. "#name", inputProduct.name);
            setXMLFloat(xmlFile, inputProductKey .. "#fillLevel", fillLevel);
            
			local lastFillTypeName = g_fillTypeManager:getFillTypeNameByIndex(inputProduct.lastFillTypeIndex);
			if lastFillTypeName ~= nil then
				setXMLString(xmlFile, inputProductKey .. "#lastFillTypeName", lastFillTypeName);
			end;			
        end;
		
		index = index + 1;
    end;

	index = 0;
	for _, outputProduct in ipairs (self.outputProducts) do		
		local fillLevel = outputProduct.fillLevel;
		if fillLevel > 0 then
			local outputProductKey = string.format("%s.outputProducts.outputProduct(%d)", factoryKey, index);
			
			
			setXMLString(xmlFile, outputProductKey .. "#name", outputProduct.name);
			setXMLFloat(xmlFile, outputProductKey .. "#fillLevel", outputProduct.fillLevel);

			if outputProduct.palletCreator ~= nil then
				outputProduct.palletCreator:saveToXMLFile(xmlFile, outputProductKey, usedModNames)
			end;
		end;

		index = index + 1;
	end;

	if self.rainWaterCollector ~= nil then
		if self.rainWaterCollector.updateCounter > 0 and self.rainWaterCollector.collected > 0 then
			setXMLInt(xmlFile, factoryKey..".rainWaterCollector#updateCounter", self.rainWaterCollector.updateCounter);
			setXMLFloat(xmlFile, factoryKey..".rainWaterCollector#rainCollected", self.rainWaterCollector.collected);
		end;
	end;

	if self.productLines ~= nil then
		index = 0;
		for lineId, productLine in ipairs (self.productLines) do
			local productLineKey = string.format("%s.productLines.productLine(%d)", factoryKey, index);
			
			setXMLInt(xmlFile, productLineKey .. "#lineId", lineId);
			setXMLBool(xmlFile, productLineKey .. "#state", productLine.active);
			setXMLBool(xmlFile, productLineKey .. "#userStopped", productLine.userStopped);
			
			index = index + 1;
		end;		
	end;

	--if self.animationManager ~= nil then
		--self.animationManager:saveToXMLFile(xmlFile, factoryKey, usedModNames)
	--end;
end;

function GC_ProductionFactory:update(dt)
	if self.isServer and self.levelChangeTimer > 0 then
		self.levelChangeTimer = self.levelChangeTimer - 1;
		if self.levelChangeTimer <= 0 then
			self.lastCheckedFillType = nil;
			self.lastCheckedTrigger = nil;
		end;

		self:raiseActive();
	end;
end;

function GC_ProductionFactory:minuteChanged()
	if not g_currentMission:getIsServer() then
		return;
	end;
	
	local raiseFlags = false;

	-- We only update rain water collected to clients every 10 min or after rain stops to save on network traffic.
	if self.rainWaterCollector ~= nil then
		local rainLevel = 0;
		local input = self.rainWaterCollector.input;

		if g_currentMission.environment.weather:getIsRaining() then
			local rainToCollect = g_currentMission.environment.weather:getRainFallScale() * (self.rainWaterCollector.litresPerHour / 60);
			local newCollected = self.rainWaterCollector.collected + rainToCollect;
			if input.fillLevel + newCollected < input.capacity then
				self.rainWaterCollector.collected = newCollected;
				self.rainWaterCollector.updateCounter = self.rainWaterCollector.updateCounter + 1;
			end;

			if self.rainWaterCollector.updateCounter >= 10 then
				self.rainWaterCollector.updateCounter = 0;
				rainLevel = self.rainWaterCollector.collected;
			end;
		else
			if self.rainWaterCollector.updateCounter > 0 then
				self.rainWaterCollector.updateCounter = 0;
				rainLevel = self.rainWaterCollector.collected;
			end;
		end;

		if rainLevel > 0 then
			local amount = math.min(input.fillLevel + rainLevel, input.capacity);
			raiseFlags = true; -- Raise flags after we check if factory needs to update.
			self:updateFactoryLevels(amount, input, FillType.WATER, false);
			self.rainWaterCollector.collected = 0;
		end;
	end;

	self.updateCounter = self.updateCounter + 1;
	if self.updateCounter >= self.updateDelay then
		self.updateCounter = 0;

		for lineId, productLine in pairs (self.productLines) do
			if productLine.active then
				local stopProductLine = false;
				local productionFactor = (productLine.outputPerHour / 60) * self.updateDelay;
				local hasSpace, factor = self:getHasOutputSpace(productLine, productionFactor); -- Do we have space to store the new product?
				local hasProduct, producedFactor = self:getHasInputProducts(productLine, factor, true); -- Max amount we can produce with the space or input product available.

				if hasSpace and hasProduct then
					raiseFlags = true;

					for i = 1, #productLine.inputs do
						local input = productLine.inputs[i];
						local amount = producedFactor * input.percent;

						self:updateFactoryLevels(input.fillLevel - amount, input, input.lastFillTypeIndex, false);

						if input.fillLevel <= 0 then
							stopProductLine = true;
						end;
					end;

					for i = 1, #productLine.outputs do
						local output = productLine.outputs[i];
						local amount = producedFactor * output.percent;

						local newFillLevel = output.fillLevel + amount

						if output.dynamicHeap ~= nil then
							local dropped = output.dynamicHeap:updateDynamicHeap(amount, false);
							newFillLevel = output.dynamicHeap:getHeapLevel();
						elseif output.palletCreator ~= nil then
							newFillLevel, added = output.palletCreator:updatePalletCreators(amount, true);
							stopProductLine = not added;
							
							debugPrint("newFillLevel", newFillLevel)
							debugPrint("added", added)
						end;

						self:updateFactoryLevels(newFillLevel, output, output.fillTypeIndex,  false);

						if output.fillLevel >= output.capacity then
							stopProductLine = true;
						end;
					end;
				else
					stopProductLine = true;
				end;

				if stopProductLine and productLine.active then
					self:setFactoryState(lineId, false);
				end;
			end;
		end;
	end;

	if raiseFlags then
		-- Raise Dirty Flags here so we only push once for all lines.
		self:raiseDirtyFlags(self.productionFactoryDirtyFlag);
	end;
end;

function GC_ProductionFactory:getHasOutputSpace(productLine, factor)
	local hasSpace = true;

	if productLine ~= nil and productLine.outputs ~= nil and factor ~= nil then
		for i = 1, #productLine.outputs do
			local output = productLine.outputs[i];
			local outputWanted = output.percent * factor;
			local fillLevel = output.fillLevel;

			-- if output.palletCreator ~= nil then
				-- local areaFillLevel, blockedFillLevel = output.palletCreator:getTotalFillLevel(true, false);
				-- fillLevel = (areaFillLevel + blockedFillLevel);
			-- end;

			local availableSpace = output.capacity - fillLevel;
			local outputSpace = math.min(outputWanted, availableSpace);

			if outputSpace > 0 then
				if outputSpace < outputWanted then
					local adjustProduced = factor * (outputSpace / outputWanted);
					if adjustProduced < factor then
						factor = adjustProduced;
					end;
				end;
			else
				hasSpace = false;
				break;
			end;
		end;
	end;

	return hasSpace, factor;
end;

function GC_ProductionFactory:getHasInputProducts(productLine, factor)
	local hasProduct = true;

	if productLine ~= nil and productLine.inputs ~= nil and factor ~= nil then
		for i = 1, #productLine.inputs do
			local input = productLine.inputs[i];
			local productNeeded = input.percent * factor;
			local productToUse = math.min(productNeeded, input.fillLevel);

			if productToUse > 0 then
				if productToUse < productNeeded then
					local adjustProduced = factor * (productToUse / productNeeded);
					if adjustProduced < factor then
						factor = adjustProduced;
					end;
				end;
			else
				hasProduct = false;
				break;
			end;
		end;
	else
		hasProduct = false;
	end;

	return hasProduct, factor;
end;

function GC_ProductionFactory:getCanOperate(lineId, getWarning)
	if self.productLines[lineId] == nil or self.productLines[lineId].inputs == nil or self.productLines[lineId].outputs == nil then
		return false;
	end;

	for i = 1, #self.productLines[lineId].inputs do
		local input = self.productLines[lineId].inputs[i];

		if input.fillLevel <= 0 then
			if getWarning then
				local warning = "";
				return false, warning;
			end;

			return false
		end;
	end;

	for i = 1, #self.productLines[lineId].outputs do
		local output = self.productLines[lineId].outputs[i];

		if output.fillLevel >= output.capacity then
			if getWarning then
				local warning = "";
				return false, warning;
			end;

			return false
		end;
	end;

	return true;
end;

function GC_ProductionFactory:updateFactoryLevels(fillLevel, product, fillTypeIndex, raiseFlags)
	if fillLevel == nil or product == nil then
		return;
	end;

	product.fillLevel = fillLevel;

	if self.isClient then
		if product.visibilityNodes ~= nil then
			product.visibilityNodes:updateNodes(fillLevel);
		end;

		if product.movers ~= nil then
			product.movers:updateMovers(fillLevel)
		end;

		if product.fillVolumes ~= nil then
			if fillTypeIndex ~= nil and fillTypeIndex ~= product.fillVolumes.lastFillTypeIndex then
				product.fillVolumes:setFillType(fillTypeIndex);
			end;
			product.fillVolumes:addFillLevel(fillLevel);
		end;

		if product.digitalDisplays ~= nil then
			product.digitalDisplays:updateLevelDisplays(fillLevel, product.capacity)
		end;
	end;

	if self.isServer and raiseFlags ~= false then
		self:raiseDirtyFlags(self.productionFactoryDirtyFlag);
	end;
end;

function GC_ProductionFactory:setFactoryState(lineId, state, noEventSend)	
	GC_ProductionFactoryStateEvent.sendEvent(self, lineId, state, noEventSend);

	self.productLines[lineId].active = state;
	
	-- Force start / stop all operating parts.
	if self.isClient then
		self:setOperatingParts(self.productLines[lineId], state);
	
		if self.sharedOperatingParts ~= nil then
			if self.sharedOperatingParts.operatingState ~= state then
				local updateShared = true;
	
				if not state then
					for i = 1, #self.productLines do
						if self.productLines[i].active then
							updateShared = false; -- Only turn off shared parts if all other lines are stopped!
							break;
						end;
					end;
				end;
	
				if updateShared then
					self.sharedOperatingParts.operatingState = state;
					self:setOperatingParts(self.sharedOperatingParts, state);
				end;
			end;
		end;
	end;	
end;

function GC_ProductionFactory:setOperatingParts(parent, state)
	if parent.operateLighting ~= nil then
		parent.operateLighting:setAllLightsState(state)
	end;

	if parent.operateSounds ~= nil then
		parent.operateSounds:setSoundsState(state)
	end;

	if parent.operateShaders ~= nil then
		parent.operateShaders:setShadersState(state)
	end;

	if parent.operateRotationNodes ~= nil then
		parent.operateRotationNodes:setRotationNodesState(state)
	end;

	if parent.operateParticleEffects ~= nil then
		parent.operateParticleEffects:setEffectsState(state)
	end;

	if parent.operateAnimations ~= nil then
		for i = 1, #parent.operateAnimations do
			local name = parent.operateAnimations[i];
			-- No need to sync as this is client only.
			self.animationManager:setAnimationByState(name, state, true);
		end;
	end;

	if parent.operateAnimationClips ~= nil then
		parent.operateAnimationClips:setAnimationClipsState(state)
	end;
end;

function GC_ProductionFactory:getIsFactoryLineOn(lineId)
	return self.productLines[lineId].active;
end;

function GC_ProductionFactory:getAutoStart(lineId)
	return self.productLines[lineId].autoStart and not self.productLines[lineId].userStopped and not self.productLines[lineId].active;
end;

function GC_ProductionFactory:doAutoStart(fillTypeIndex, triggerId)
	if self.isServer then
		self.levelChangeTimer = 1000;
		if self.lastCheckedFillType ~= fillTypeIndex or self.lastCheckedTrigger ~= triggerId then
			self.lastCheckedFillType = fillTypeIndex;
			self.lastCheckedTrigger = triggerId;
			for lineId, _ in pairs (self.productLines) do
				if self:getAutoStart(lineId) and self:getCanOperate(lineId) then
					self:setFactoryState(lineId, true);
				end;
			end;

			self:raiseActive();
		end;
	end;
end;

function GC_ProductionFactory:getProductFromTriggerId(triggerId, fillTypeIndex, constant)
	-- 'fillTypeIndex' table value is used for 'unloadTriggers (SILO)' only.
	if self.triggerIdToProduct[triggerId] ~= nil then
		if fillTypeIndex == nil then
			return self.triggerIdToProduct[triggerId];
		else
			if self.triggerIdToProduct[triggerId][fillTypeIndex] ~= nil then
				return self.triggerIdToProduct[triggerId][fillTypeIndex];
			end;
		end;
	end;

	return constant;
end;

----------------------------
-- Pallet removal Trigger --
----------------------------

function GC_ProductionFactory:palletCreatorInteraction(level, blockedLevel, deltaWaiting, fillTypeIndex, triggerId)
	if not self.isServer then
		return;
	end;

	local product = self:getProductFromTriggerId(triggerId);
	if product ~= nil then
		-- Make sure we will have room to spawn.
		local totalLevel = level + blockedLevel;

		if totalLevel ~= product.fillLevel then
			self:updateFactoryLevels(totalLevel, product, fillTypeIndex, true);
		end;

		-- This is an output so we only want to try and start / stop it.
		local lineId = self.triggerIdToLineId[triggerId];
		if lineId ~= nil then
			if totalLevel < product.capacity then
				if self:getAutoStart(lineId) and self:getCanOperate(lineId) then
					self:setFactoryState(lineId, true);
				end;
			else
				if self.productLines[lineId].active and not self:getCanOperate(lineId) then
					self:setFactoryState(lineId, false);
				end;
			end;
		end;
	end;

end;

------------------------------------------
-- Heap vehicle interaction Requirement --
------------------------------------------

function GC_ProductionFactory:vehicleChangedHeapLevel(heapLevel, fillTypeIndex, heapId)
	if not self.isServer then
		return;
	end;

	local product = self:getProductFromTriggerId(heapId);
	if product ~= nil then
		local stopFactory, startFactory = false, false;

		local isIncreasing = heapLevel > product.fillLevel;
		if isIncreasing then
			stopFactory = product.fillLevel < product.capacity and heapLevel >= product.capacity;
		else
			startFactory = product.fillLevel >= product.capacity and heapLevel < product.capacity;
		end;

		self:updateFactoryLevels(heapLevel, product, fillTypeIndex, true);
		local lineId = self.triggerIdToLineId[heapId];
		if lineId ~= nil then
			-- If the level drops from a vehicle then try and start.
			if startFactory then
				if self:getAutoStart(lineId) and self:getCanOperate(lineId) then
					self:setFactoryState(lineId, true);
				end;
			end;

			-- If someone is dumping fillType into output heap then stop if overfilled.
			if stopFactory then
				if self.productLines[lineId].active and not self:getCanOperate(lineId) then
					self:setFactoryState(lineId, false);
				end;
			end;
		end;
	end;
end;

--------------------------
-- Trigger Requirements --
--------------------------

function GC_ProductionFactory:getFreeCapacity(fillTypeIndex, farmId, triggerId)
	local fillLevel, capacity = 0, 0;

	local product = self.triggerIdToProduct[triggerId];
	if product ~= nil then
		fillLevel = product.fillLevel;
		capacity = product.capacity;
	end;

	return capacity - fillLevel;
end;

function GC_ProductionFactory:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
	local product = self.triggerIdToProduct[triggerId];

	if product ~= nil then
		product.lastFillTypeIndex = fillTypeIndex;
		self:updateFactoryLevels(product.fillLevel + fillLevelDelta, product, fillTypeIndex, true);

		-- Start the factory animations if using 'autoStart' if possible.
		self:doAutoStart(fillTypeIndex, triggerId);
	end;
end;

function GC_ProductionFactory:removeFillLevel(farmId, fillLevelDelta, fillTypeIndex, triggerId)
	local product = self:getProductFromTriggerId(triggerId, fillTypeIndex);

	if product ~= nil then
		self:updateFactoryLevels(product.fillLevel - fillLevelDelta, product, fillTypeIndex, true);

		-- Start the factory animations if using 'autoStart' if possible.
		self:doAutoStart(fillTypeIndex, triggerId);

		return product.fillLevel;
	end;
end;

function GC_ProductionFactory:getProvidedFillTypes(triggerId)
	return self.providedFillTypes[triggerId];
end;

function GC_ProductionFactory:getAllProvidedFillLevels(farmId, triggerId)
	local fillLevels = {};
	local capacity = 0;

	if self.providedFillTypes[triggerId] ~= nil then
		for fillTypeIndex, _ in pairs(self.providedFillTypes[triggerId]) do
			local output = self:getProductFromTriggerId(triggerId, fillTypeIndex);
			if output ~= nil then
				fillLevels[fillTypeIndex] = Utils.getNoNil(fillLevels[fillTypeIndex], 0) + output.fillLevel;
				capacity = capacity + output.capacity;
			end;
		end;
	end;

	return fillLevels, capacity;
end;

function GC_ProductionFactory:getProvidedFillLevel(fillTypeIndex, farmId, triggerId)
	local output = self:getProductFromTriggerId(triggerId, fillTypeIndex);
	if output ~= nil then
		return output.fillLevel;
	end;

	return 0;
end;

-------------------------------
-- PLAYER TRIGGER (GUI / UI) --
-------------------------------

function GC_ProductionFactory:playerTriggerActivated(lineId)
	-- NOTES:
	
	-- If 'lineId' is ~= nil we will open the gui directly to this page. (ProductLine).
	
	-- If 'lineId' is == nil (Global Player Trigger) This will open to factory overview (Home Page).

	
	--g_company.gui:openGuiWithData("gc_factoryBig", false, self, lineId);

	g_currentMission:showBlinkingWarning("@kevink98 - THIS INPUT OPENS THE GUI");
end;

function GC_ProductionFactory:playerTriggerUpdate(dt, playerInTrigger, lineId)
	-- This will open the small UI.
	-- if self.drawProductLineUI[lineId] == true then
		-- if playerInTrigger == true then
			-- if lineId ~= nil and self.productLines[lineId] ~= nil then
				-- if self.infoGui == nil then
					-- self.infoGui = g_company.gui:openGuiWithData("gc_factorySmall", false, self.guiData.factoryTitle, self.productLines[lineId]);
				-- else
					-- self.infoGui.classGui:setData(self.guiData.factoryTitle, self.productLines[lineId]);
				-- end;
			-- end;
		-- elseif self.infoGui ~= nil then
			-- g_company.gui:closeGui("gc_factorySmall"); -- gcProductionFactoryInfo
			-- self.infoGui = nil;
		-- end;
	-- end;
end;

---------------------------------
-- GUI / UI Possible Functions --
---------------------------------

function GC_ProductionFactory:getGuiData(lineId)
	local data = self.guiData;
	return data.factoryTitle, data.factoryImage, data.factoryCamera, data.factoryDescription;
end;

function GC_ProductionFactory:getInput(lineId, inputId)
	if lineId ~= nil and inputId ~= nil then
		local productLine = self.productLines[lineId];
		if productLine ~= nil and productLine.inputs ~= nil then
			return productLine.inputs[inputId];
		end;
	end;

	return;
end;

function GC_ProductionFactory:getOutput(lineId, outputId)
	if lineId ~= nil and outputId ~= nil then
		local productLine = self.productLines[lineId];
		if productLine ~= nil and productLine.outputs ~= nil then
			return productLine.outputs[outputId];
		end;
	end;

	return;
end;

function GC_ProductionFactory:getProductBuyPrice(input, litres)
	local validLitres, price = 0, 0;

	if input ~= nil and litres > 0 then
		validLitres = math.min(litres, math.floor(input.capacity - input.fillLevel));
		if validLitres > 0 then
			price = input.pricePerLiter * validLitres;
		end;
	end;

	return validLitres, price
end;

function GC_ProductionFactory:doProductPurchase(input, litres)	
	if input ~= nil and litres > 0 then		
		if g_currentMission:getIsServer() then
			local validLitres = math.min(litres, math.floor(input.capacity - input.fillLevel));
			local price = input.pricePerLiter * Utils.getNoNil(validLitres, 0);
			if price > 0 then
				local newFillLevel = input.fillLevel + validLitres;
				g_currentMission:addMoney(-price, self:getOwnerFarmId(), MoneyType.BOUGHT_MATERIALS, true, true);
				self:updateFactoryLevels(newFillLevel, input, nil, true);
			end;
		else		
			g_client:getServerConnection():sendEvent(GC_ProductionFactoryProductPurchaseEvent:new(self, input.lineId, input.id, litres));
		end;
	end;
end;

function GC_ProductionFactory:spawnPalletFromOutput(output, numPallets)
	if output ~= nil and numPallets > 0 then
	
	end;
	
	return 0;
end;

function GC_ProductionFactory:getFreePalletSpawnAreas(output)
	if output ~= nil then
	
	end;
	
	return 0;
end;

--------------------
-- Farmland Owner --
--------------------

function GC_ProductionFactory:onSetFarmlandStateChanged(farmId) -- This is only onCreate as GIANTS do not do it for us ;-).
	self:setOwnerFarmId(farmId, false);
end;

function GC_ProductionFactory:setOwnerFarmId(ownerFarmId, noEventSend)
	GC_ProductionFactory:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend);

	-- Shutdown if the land is sold.
	if not self:getIsValidFarmlandId() then
		for lineId, _ in pairs (self.productLines) do
			self:setFactoryState(lineId, false);
		end;
	end;

	-- Push to child objects here.
	if self.triggerManager ~= nil then
		self.triggerManager:setAllOwnerFarmIds(ownerFarmId, noEventSend)
	end;
end;

-- Check if the player can access factory or if the factory is owned.
function GC_ProductionFactory:getIsValidFarmlandId(playerId)
	local currentId = self:getOwnerFarmId();
	if currentId ~= AccessHandler.EVERYONE and currentId ~= AccessHandler.NOBODY then
		if playerId ~= nil then
			if playerId == currentId then
				return true;
			end;

			return false;
		end;

		return true;
	end;

	return false;
end;





