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
--		- [Currently completing 24.02.2019 ]
--
--		- Create backup images for productLine, inputProducts, outputProducts and factory.
-- 		- Finish main gui and trigger gui.
--		- Finish MP Events and read / write functions.
-- 		- add missing triggers (Pallet Spawner, Loading (Silo / liquid), Pallet-On-Demand, Fuel Station, Animal Load / Unload).
-- 		- Finish farmID info for onCreate.
--
--


ProductionFactory = {};
ProductionFactory_mt = Class(ProductionFactory, Object);
InitObjectClass(ProductionFactory, "ProductionFactory");

ProductionFactory.debugIndex = g_company.debug:registerScriptName("ProductionFactory");

getfenv(0)["GC_ProductionFactory"] = ProductionFactory;

function ProductionFactory:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");

	if indexName ~= nil and xmlFilename ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;

		-- Create object 'instance' now so we can access 'debugData'.
		local object = ProductionFactory:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);

		-- Do 'XML' and 'KEY' check and load if possible.
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.productionFactories.productionFactory", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);

				g_company.debug:writeOnCreate(object.debugData, "[FACTORY - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);
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
	end;
end;

function ProductionFactory:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or ProductionFactory_mt);

	self.xmlFilename = xmlFilename;
	self.baseDirectory = baseDirectory;
	self.customEnvironment = customEnvironment;

	self.triggerIdToProduct = {};
	self.fillTypeIndexToOutput = {};

	self.productLines = {};
	self.inputProducts = {};
	self.outputProducts = {};

	self.levelChangeTimer = -1;

	self.debugData = g_company.debug:getDebugData(ProductionFactory.debugIndex, nil, customEnvironment);

	return self;
end;

function ProductionFactory:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	local canLoad = true;

	self.nodeId  = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable; -- Possible future GUI use.

	self.triggerManager = GC_TriggerManager:new(self); -- 'init' Trigger Manager.

	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");	-- Activate i3dMappings support.

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "ProductionFactory_" .. indexName;
	end;

	self.showInGlobalGUI = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. ".operation#showInGlobalGUI"), true);
	self.updateDelay = math.max(Utils.getNoNil(getXMLInt(xmlFile, xmlKey .. ".operation#updateDelayMinutes"), 10), 1);
	self.updateCounter = self.updateDelay;

	-------------------------------
	-- REGISTER LOADING TRIGGERS --
	-------------------------------

	self.registeredLoadingTriggers = {}; -- This is done now so that we can use one trigger for all outputs if required by the user.
	if hasXMLProperty(xmlFile, xmlKey .. ".registerLoadingTriggers") then
		local i = 0;
		while true do
			local loadingTriggerKey = string.format("%s.registerLoadingTriggers.loadingTrigger(%d)", xmlKey, i);
			if not hasXMLProperty(xmlFile, loadingTriggerKey) then
				break;
			end;

			local name = getXMLString(xmlFile, loadingTriggerKey .. "#name");
			if name ~= nil and self.registeredLoadingTriggers[name] == nil then
				local trigger = nil; -- TO DO

				--[[
				local trigger = self.triggerManager:loadTrigger(GC_LoadingTrigger, self.nodeId , xmlFile, loadingTriggerKey);
				if trigger ~= nil then
					trigger.extraParamater = trigger.managerId;
					self.registeredLoadingTriggers[name] = trigger;
				end;
				]]--
			end;
		end;
		i = i + 1;
	end;


	local registeredProducts = {output = 0, input = 0};

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
		if inputProductName ~= nil and self.inputProducts[name] == nil then
			local inputProduct = {};
			local concatTitles = {};

			inputProduct.name = inputProductName;

			local usedFillTypeNames = {};

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
						local customTitle = getXMLString(xmlFile, fillTypesKey .. "#title");
						if customTitle ~= nil then
							fillTypeTitle = g_company.languageManager:getText(customTitle);
						end;

						table.insert(concatTitles, fillTypeTitle);
					else
						if fillType == nil then
							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Unknown fillType ( %s ) found in 'inputProduct' ( %s ) in '%s', ignoring!", indexName, fillTypeName, inputProductName);
						else
							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Duplicate 'inputProduct' fillType ( %s ) in '%s', FillType already used at '%s'!", indexName, fillTypeName, inputProductName, usedFillTypeNames[fillTypeName]);
						end;
					end;
				end;

				j = j + 1;
			end;

			if inputProduct.fillTypes ~= nil then
				registeredProducts.input = registeredProducts.input + 1;

				inputProduct.fillLevel = 0;
				inputProduct.concatedFillTypeTitles = table.concat(concatTitles, " | ");
				inputProduct.capacity = Utils.getNoNil(getXMLInt(xmlFile, inputProductKey .. "#capacity"), 1000);

				inputProduct.title = tostring(registeredProducts.input) .. ":";
				local productTitle = getXMLString(xmlFile, inputProductKey .. "#title");
				if productTitle ~= nil then
					inputProduct.title = g_company.languageManager:getText(productTitle) .. ":";
				end;

				if hasXMLProperty(xmlFile, inputProductKey .. ".inputMethods") then
					-- Rain Water
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

					-- Dynamic Pallet Trigger  -- TO DO
					local dynamicPalletTriggerKey = inputProductKey .. ".inputMethods.dynamicPalletTrigger";
					if hasXMLProperty(xmlFile, dynamicPalletTriggerKey) then

					end;
				end;

				-- Load Movers, VisNodes and FillVolume.
				self:loadProductParts(xmlFile, inputProductKey, inputProduct);

				-- Add to 'inputProducts' table.
				self.inputProducts[inputProductName] = inputProduct;
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
		if outputProductName ~= nil and self.outputProducts[outputProductName] == nil then
			local outputProduct = {};

			outputProduct.name = outputProductName;

			local fillTypeName = getXMLString(xmlFile, outputProductKey .. "#fillType");
			if fillTypeName ~= nil then
				local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
				if fillTypeIndex ~= nil then
					registeredProducts.output = registeredProducts.output + 1;

					outputProduct.fillLevel = 0;
					outputProduct.isUsed = false;
					outputProduct.fillTypeIndex = fillTypeIndex;
					outputProduct.lastFillTypeIndex = fillTypeIndex;
					outputProduct.capacity = Utils.getNoNil(getXMLInt(xmlFile, outputProductKey .. "#capacity"), 1000);

					outputProduct.title = tostring(registeredProducts.output) .. ":";
					local productTitle = getXMLString(xmlFile, outputProductKey .. "#title");
					if productTitle ~= nil then
						outputProduct.title =  g_company.languageManager:getText(productTitle) .. ":";
					end;

					-- We only use this on outputs as they are single fillypes only.
					self.fillTypeIndexToOutput[fillTypeIndex] = outputProduct

					local outputMethodsKey = outputProductKey .. ".outputMethods";
					if hasXMLProperty(xmlFile, outputMethodsKey) then
						local triggersLoaded, invalidTriggers = {}, {};

						-- OnDemand Pallet Spawner  -- TO DO
						local onDemandPalletSpawnerKey = outputMethodsKey .. ".onDemandPalletSpawner";
						if hasXMLProperty(xmlFile, onDemandPalletSpawnerKey) then
							-- TO DO (This will allow pallets to be spawned on demand from GUI.)

							table.insert(triggersLoaded, "onDemandPalletSpawner");
						end;

						-- Loading Trigger (SILO)  -- TO DO
						local loadingTriggerKey = outputMethodsKey .. ".loadTrigger";
						if hasXMLProperty(xmlFile, loadingTriggerKey) then
							local name = getXMLString(xmlFile, loadingTriggerKey .. "#name");
							local trigger = self.registeredLoadingTriggers[name];
							if trigger ~= nil then
								-- Add fillType to trigger if it does not exist already or give warning.
								if trigger:addFillType(fillTypeIndex) ~= nil then
									-- table.insert(self.triggerIdToProduct[trigger.managerId], outputProduct);
									table.insert(triggersLoaded, "loadTrigger");
								end;
							else
								-- Trigger does not exist.
							end;
						end;

						-- Dynamic Heap
						local dynamicHeapKey = outputMethodsKey .. ".dynamicHeap";
						if hasXMLProperty(xmlFile, dynamicHeapKey) then
							if triggersLoaded ~= nil then
								local trigger = self.triggerManager:loadTrigger(GC_DynamicHeap, self.nodeId , xmlFile, dynamicHeapKey, fillTypeName);
								if trigger ~= nil then
									trigger.extraParamater = trigger.managerId;
									outputProduct.dynamicHeap = trigger;
									--self.triggerIdToProduct[trigger.managerId] = outputProduct;

									table.insert(triggersLoaded, "dynamicHeap");
								end;
							else
								table.insert(invalidTriggers, "dynamicHeap");
							end;
						end;

						-- Pallet Fill Trigger  -- TO DO
						local palletFillAreaKey = outputMethodsKey .. ".palletFillArea";
						if hasXMLProperty(xmlFile, palletFillAreaKey) then
							if not triggersLoaded then
								-- TO DO (This will fill the pallet as the factory works.)

								outputProduct.palletFillArea = nil;
								table.insert(triggersLoaded, "palletFillArea");
							else
								table.insert(invalidTriggers, "palletFillArea");
							end;
						end;

						-- Print invalid combinations.
						if #invalidTriggers > 0 then
							triggersLoaded = table.concat(triggersLoaded, " or ");
							invalidTriggers = table.concat(invalidTriggers, " and ");

							g_company.debug:writeModding(self.debugData, "[FACTORY - %s] Invalid 'outputMethod' combinations, '%s' can not be combined with '%s'!", indexName, invalidTriggers, triggersLoaded);
						end;
					end;

					-- Load Movers, VisNodes and FillVolume.
					self:loadProductParts(xmlFile, outputProductKey, outputProduct);

					-- Add to 'outputProduct' table.
					self.outputProducts[outputProductName] = outputProduct;
				else

				end;
			end;
		end;

		i = i + 1;
	end;

	------------------------------------
	-- SETUP FACTORY PRODUCTION LINES --
	------------------------------------

	if registeredProducts.input > 0 and registeredProducts.output > 0 then
		i = 0;
		while true do
			local productLineKey = string.format("%s.productLines.productLine(%d)", xmlKey, i);
			if not hasXMLProperty(xmlFile, productLineKey) then
				break;
			end;

			local productLine = {};
			local productLineId = #self.productLines + 1;

			productLine.active = false;
			productLine.autoStart = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#autoLineStart"), false);
			productLine.outputPerHour = Utils.getNoNil(getXMLInt(xmlFile, productLineKey .. "#outputPerHour"), 1000);

			-- Need to fix these and make backup images.
			productLine.name = string.format("Production Line %d", productLineId);
			productLine.imageFilename = nil;

			local productLineName = getXMLString(xmlFile, productLineKey .. "#name");
			if productLineName ~= nil and productLineName ~= "DEFAULT" then
				productLine.name = g_company.languageManager:getText(productLineName);
			end;

			local productLineImage = getXMLString(xmlFile, productLineKey .. "imageFilename");
			if productLineImage ~= nil and productLineImage ~= "DEFAULT" then
				productLine.imageFilename = Utils.getFilename(productLineImage, self.baseDirectory); -- Need to test!!
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
				if self.inputProducts[name] ~= nil then
					if inputProductNameToInputId[name] == nil then

						local percent = Utils.getNoNil(getXMLInt(xmlFile, inputKey .. "#percent"), 100) / 100;

						if productLine.inputs == nil then
							productLine.inputs = {};
						end;

						local inputId = #productLine.inputs + 1;
						inputProductNameToInputId[name] = inputId;

						productLine.inputs[inputId] = self.inputProducts[name];
						productLine.inputs[inputId].percent = math.min(math.max(percent, 0.1), 1);
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
				if self.outputProducts[name] ~= nil then
					if outputProductNameToOutputId[name] == nil then
						local percent = Utils.getNoNil(getXMLInt(xmlFile, outputKey .. "#percent"), 100) / 100;

						if productLine.outputs == nil then
							productLine.outputs = {};
						end;

						local outputId = #productLine.outputs + 1;
						outputProductNameToOutputId[name] = outputId;

						productLine.outputs[outputId] = self.outputProducts[name];
						productLine.outputs[outputId].percent = math.min(math.max(percent, 0.1), 1);

						-- Store title and image data for quick GUI access.
						local fillType = g_fillTypeManager:getFillTypeByIndex(self.outputProducts[name].fillTypeIndex);
						productLine.outputs[outputId].title = fillType.title;
						productLine.outputs[outputId].imageFilename = fillType.hudOverlayFilename;
					end;
				end;
				outputKeyId = outputKeyId + 1;
			end;

			-- Load operating parts for each product line.
			local operatingPartsKey = string.format("%s.operatingParts", productLineKey);
			self:loadOperatingParts(xmlFile, operatingPartsKey, productLine);

			-- Load player trigger for each product line. (These will show - mCompany - style UI when in trigger or open full GUI).
			local playerTriggerKey = string.format("%s.playerTrigger", productLineKey);
			if hasXMLProperty(xmlFile, playerTriggerKey) then
				local nextId = #self.productLines + 1;
				productLine.playerTrigger = self.triggerManager:loadTrigger(GC_PlayerTrigger, self.nodeId , xmlFile, playerTriggerKey, nextId, true);
			end;

			table.insert(self.productLines, productLine);

			i = i + 1;
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

		------------------------------------------------------------------------
		-- LOAD SHARED PLAYER TRIGGER (This will only be for opening the Factory GUI)--
		------------------------------------------------------------------------

		local playerTriggerKey = xmlKey .. ".playerTrigger";
		if hasXMLProperty(xmlFile, playerTriggerKey) then
			self.playerTrigger = self.triggerManager:loadTrigger(GC_PlayerTrigger, self.nodeId , xmlFile, playerTriggerKey, nil, true);
		end;

		--------------------
		-- FINISH LOADING --
		--------------------

		if self.isServer and canLoad then
			g_currentMission.environment:addMinuteChangeListener(self);
		end;

		self.productionFactoryDirtyFlag = self:getNextDirtyFlag();
	else
		if registeredProducts.input <= 0 then
			g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'inputProducts' have been registered factory cannot be loaded!", indexName);
		end;

		if registeredProducts.output <= 0 then
			g_company.debug:writeModding(self.debugData, "[FACTORY - %s] No 'outputProducts' have been registered factory cannot be loaded!", indexName);
		end;

		canLoad = false;
	end;

	return canLoad;
end;

function ProductionFactory:loadProductParts(xmlFile, key, product)
	if self.isClient then
		local fillTypeName = g_fillTypeManager.indexToName[product.lastFillTypeIndex];
		local capacity = product.capacity;

		local visibilityNodes = GC_VisibilityNodes:new(self.isServer, self.isClient);
		if visibilityNodes:load(self.nodeId , self, xmlFile, key, self.baseDirectory, capacity, true) then
			product.visibilityNodes = visibilityNodes;
		end;

		local movers = GC_Movers:new(self.isServer, self.isClient);
		if movers:load(self.nodeId , self, xmlFile, key, self.baseDirectory, capacity, true) then
			product.movers = movers;
		end;

		local fillVolumes = GC_FillVolume:new(self.isServer, self.isClient);
		if fillVolumes:load(self.nodeId , self, xmlFile, key, capacity, true, fillTypeName) then
			product.fillVolumes = fillVolumes;
		end;
	end;
end;

function ProductionFactory:loadOperatingParts(xmlFile, key, parent)
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

		-- TO DO (Animations)

		-- TO DO (Animation Clips)
	end;
end;

function ProductionFactory:delete()
	g_currentMission:removeOnCreateLoadedObjectToSave(self)

	if self.triggerManager ~= nil then
		self.triggerManager:unregisterAllTriggers();
	end;
	
	if self.isServer then
		g_currentMission.environment:removeMinuteChangeListener(self);
	end;

	if self.isClient then
		local products = {self.inputProducts, self.outputProducts};
		for i = 1, 2 do
			for _, product in pairs (products[i]) do
				if product.visibilityNodes ~= nil then
					product.visibilityNodes:delete();
				end;

				if product.fillVolumes ~= nil then
					product.fillVolumes:delete();
				end;
			end;
		end;

		for i = 1, #self.productLines do
			local productLine = self.productLines[i];
			self:deleteOperatingParts(productLine);
		end;

		if self.sharedOperatingParts ~= nil then
			self:deleteOperatingParts(self.sharedOperatingParts);
		end;
	end;

	ProductionFactory:superClass().delete(self)
end;

function ProductionFactory:deleteOperatingParts(parent)
	if parent.operateLighting ~= nil then
		parent.operateLighting:delete();
		parent.operateLighting:delete();
	end;

	if parent.operateSounds ~= nil then
		parent.operateSounds:delete();
	end;

	if parent.operateRotationNodes ~= nil then
		parent.operateRotationNodes:delete();
	end;

	if parent.operateParticleEffects ~= nil then
		parent.operateParticleEffects:delete();
	end;

	if parent.operateAnimations ~= nil then
		parent.operateAnimations:delete();
	end;
end;

function ProductionFactory:readStream(streamId, connection)
	ProductionFactory:superClass().readStream(self, streamId, connection);

	if connection:getIsServer() then
		-- Code will be added when 'ProductionFactory.lua' is complete.
	end;
end;

function ProductionFactory:writeStream(streamId, connection)
	ProductionFactory:superClass().writeStream(self, streamId, connection);

	if not connection:getIsServer() then
		-- Code will be added when 'ProductionFactory.lua' is complete.
	end;
end;

function ProductionFactory:readUpdateStream(streamId, timestamp, connection)
	ProductionFactory:superClass().readUpdateStream(self, streamId, timestamp, connection);

	if connection:getIsServer() then
		if streamReadBool(streamId) then
			-- Code will be added when 'ProductionFactory.lua' is complete.
		end;
	end;
end;

function ProductionFactory:writeUpdateStream(streamId, connection, dirtyMask)
	ProductionFactory:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);

	if not connection:getIsServer() then
		if streamWriteBool(streamId, bitAND(dirtyMask, self.productionFactoryDirtyFlag) ~= 0) then
			-- Code will be added when 'ProductionFactory.lua' is complete.
		end;
	end;
end;

function ProductionFactory:loadFromXMLFile(xmlFile, key)
	local factoryKey = key;
	if not self.isPlaceable then
		factoryKey = string.format("%s.productionFactory", key);
	end;

	if self.inputProducts ~= nil then
		for name, inputProduct in pairs (self.inputProducts) do
			local inputProductKey = string.format("%s.inputProducts.%s", factoryKey, name);

			local lastFillTypeName = getXMLString(xmlFile, inputProductKey .. "#lastFillTypeName");
			if lastFillTypeName ~= nil then
				local lastFillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(lastFillTypeName);
				if lastFillTypeIndex ~= nil and inputProduct.fillTypes[lastFillTypeIndex] == true then
					inputProduct.lastFillTypeIndex = lastFillTypeIndex;
				end;
			end;

			local fillLevel = getXMLFloat(xmlFile, inputProductKey .. "#fillLevel");
			if fillLevel ~= nil then
				local fillLevel = math.max(fillLevel, 0);
				local lastFillTypeIndex = inputProduct.lastFillTypeIndex;
				self:updateFactoryLevels(fillLevel, inputProduct, lastFillTypeIndex, false);
			end;
		end;
	end;

	if self.outputProducts ~= nil then
		for name, outputProduct in pairs (self.outputProducts) do
			local outputProductKey = string.format("%s.outputProducts.%s", factoryKey, name);

			local fillLevel = getXMLFloat(xmlFile, outputProductKey .. "#fillLevel");
			if fillLevel ~= nil then
				local fillLevel = math.max(fillLevel, 0);
				local lastFillTypeIndex = outputProduct.lastFillTypeIndex;
				self:updateFactoryLevels(fillLevel, outputProduct, lastFillTypeIndex, false);
			end;
		end;
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
		local i = 0
		while true do
			local productLineKey = string.format("%s.productLines.productLine(%d)", factoryKey, i)
			if not hasXMLProperty(xmlFile, productLineKey) then
				break
			end

			local lineId = i + 1;
			local productLine = self.productLines[lineId];

			if productLine ~= nil and productLine.autoStart then
				local state = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#state"), false);

				if state then
					self:setFactoryState(lineId, state);
				end;
			else
				break;
			end;

			i = i + 1;
		end
	end;

	if self.isClient then

	end;

	return true;
end;

function ProductionFactory:saveToXMLFile(xmlFile, key, usedModNames)
	local factoryKey = key;
	if not self.isPlaceable then
		factoryKey = string.format("%s.productionFactory", key);

		-- This only saved now for 'onCreate' for when the buy / sell feature is added and when used with farmland purchases.
		setXMLInt(xmlFile, factoryKey .. "#farmId", self:getOwnerFarmId());
	end;

	-- This is just for identification. We do not read it on load ;-)
	setXMLString(xmlFile, factoryKey .. "#indexName", self.indexName);

	if self.inputProducts ~= nil then
		for name, inputProduct in pairs (self.inputProducts) do
			local inputProductKey = string.format("%s.inputProducts.%s", factoryKey, name);
			setXMLFloat(xmlFile, inputProductKey .. "#fillLevel", inputProduct.fillLevel);

			local name = g_fillTypeManager:getFillTypeNameByIndex(inputProduct.lastFillTypeIndex);
			if name ~= nil then
				setXMLString(xmlFile, inputProductKey .. "#lastFillTypeName", name);
			end;
		end;
	end;

	if self.outputProducts then
		for name, outputProduct in pairs (self.outputProducts) do
			local outputProductKey = string.format("%s.outputProducts.%s", factoryKey, name);
			setXMLFloat(xmlFile, outputProductKey .. "#fillLevel", outputProduct.fillLevel);
		end;
	end;

	if self.rainWaterCollector ~= nil then
		if self.rainWaterCollector.updateCounter > 0 and self.rainWaterCollector.collected > 0 then
			setXMLInt(xmlFile, factoryKey..".rainWaterCollector#updateCounter", self.rainWaterCollector.updateCounter);
			setXMLFloat(xmlFile, factoryKey..".rainWaterCollector#rainCollected", self.rainWaterCollector.collected);
		end;
	end;

	if self.productLines ~= nil then
		for i = 1, #self.productLines do
			local productLineKey = string.format("%s.productLines.productLine(%d)", factoryKey, i - 1);
			setXMLString(xmlFile, productLineKey .. "#name", self.productLines[i].name);
			setXMLBool(xmlFile, productLineKey .. "#state", self.productLines[i].active);
		end;
	end;
end;

function ProductionFactory:update(dt)
	if self.isServer and self.levelChangeTimer > 0 then
		self.levelChangeTimer = self.levelChangeTimer - 1;
		if self.levelChangeTimer <= 0 then
			self.lastCheckedFillType = nil;
		end;

		self:raiseActive();
	end;
end;

function ProductionFactory:minuteChanged()
	if not g_currentMission:getIsServer() then
		return;
	end;

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
			self:updateFactoryLevels(amount, input, FillType.WATER, true);
			self.rainWaterCollector.collected = 0;
		end;
	end;

	local raiseFlags = false;
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
							output.dynamicHeap:updateDynamicHeap(amount, false);
							newFillLevel = output.dynamicHeap:getHeapLevel();
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

function ProductionFactory:getHasOutputSpace(productLine, factor)
	local hasSpace = true;

	if productLine ~= nil and productLine.outputs ~= nil and factor ~= nil then
		for i = 1, #productLine.outputs do
			local output = productLine.outputs[i];
			local outputWanted = output.percent * factor;
			local availableSpace = output.capacity - output.fillLevel;
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

function ProductionFactory:getHasInputProducts(productLine, factor)
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

function ProductionFactory:getCanOperate(lineId)
	local canOperate = true;

	if self.productLines[lineId] ~= nil and self.productLines[lineId].inputs ~= nil then
		for i = 1, #self.productLines[lineId].inputs do
			local input = self.productLines[lineId].inputs[i];

			if input.fillLevel <= 0 then
				canOperate = false;
				break;
			end;
		end;

		if canOperate and self.productLines[lineId].outputs ~= nil then
			for i = 1, #self.productLines[lineId].outputs do
				local output = self.productLines[lineId].outputs[i];

				if output.fillLevel >= output.capacity then
					canOperate = false;
					break;
				end;
			end;
		end;
	end;

	return canOperate;
end;

function ProductionFactory:updateFactoryLevels(fillLevel, product, fillTypeIndex, raiseFlags)
	if fillLevel == nil or product == nil then
		return;
	end;

	product.fillLevel = fillLevel;

	if product.visibilityNodes ~= nil then
		product.visibilityNodes:updateNodes(fillLevel);
	end;

	if product.movers ~= nil then
		product.movers:updateMovers(fillLevel)
	end;

	if product.fillVolumes ~= nil then
		if fillTypeIndex ~= product.fillVolumes.lastFillTypeIndex then
			product.fillVolumes:setFillType(fillTypeIndex);
		end;
		product.fillVolumes:addFillLevel(fillLevel);
	end;

	if self.isServer and raiseFlags then
		self:raiseDirtyFlags(self.productionFactoryDirtyFlag);
	end;
end;

function ProductionFactory:setFactoryState(lineId, state, noEventSend)
	--GC_ProductFactoryStateEvent.sendEvent(self, lineId, state, noEventSend);

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

function ProductionFactory:setOperatingParts(parent, state)
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

	if parent.operateAnimation ~= nil then
		-- Addon script to be added soon.
	end;

	if parent.operateAnimationClip ~= nil then
		-- Addon script to be added soon.
	end;
end;

function ProductionFactory:getIsFactoryLineOn(lineId)
	return self.productLines[lineId].active;
end;

function ProductionFactory:getAutoStart(lineId)
	return self.productLines[lineId].autoStart and not self.productLines[lineId].active;
end;

function ProductionFactory:doAutoStart(fillTypeIndex)
	if self.isServer then
		self.levelChangeTimer = 1000;
		if self.lastCheckedFillType ~= fillTypeIndex then
			self.lastCheckedFillType = fillTypeIndex;
			for lineId, _ in pairs (self.productLines) do
				if self:getAutoStart(lineId) and self:getCanOperate(lineId) then
					self:setFactoryState(lineId, true);
				end;
			end;

			self:raiseActive();
		end;
	end;
end;

-------------------------------------------------------------------
-- Heap vehicle interaction Requirement (Optional / Recommended) --
-------------------------------------------------------------------

function ProductionFactory:vehicleChangedHeapLevel(heapLevel, fillTypeIndex, heapId)
	if not self.isServer then
		return;
	end;

	local product = self.fillTypeIndexToOutput[fillTypeIndex];
	if product ~= nil then
		local stopFactory, startFactory = false, false;

		local isIncreasing = heapLevel > product.fillLevel;
		if isIncreasing then
			stopFactory = product.fillLevel < product.capacity and heapLevel >= product.capacity;
		else
			startFactory = product.fillLevel >= product.capacity and heapLevel < product.capacity;
		end;

		self:updateFactoryLevels(heapLevel, product, fillTypeIndex, true);

		-- If the level drops from a vehicle then try and start.
		if startFactory then
			self.lastCheckedFillType = nil; -- reset timer to make sure we start if we can.
			self:doAutoStart(fillTypeIndex);
		end;

		-- If someone is dumping fillType into output heap then stop if overfilled.
		if stopFactory then
			for lineId, _ in pairs (self.productLines) do
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

function ProductionFactory:getFreeCapacity(fillTypeIndex, farmId, triggerId)
	local fillLevel, capacity = 0, 0;

	local product = self.triggerIdToProduct[triggerId];
	if product ~= nil then
		fillLevel = product.fillLevel;
		capacity = product.capacity;
	end;

	return capacity - fillLevel;
end;

function ProductionFactory:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
	local product = self.triggerIdToProduct[triggerId];

	if product ~= nil then
		product.lastFillTypeIndex = fillTypeIndex;
		self:updateFactoryLevels(product.fillLevel + fillLevelDelta, product, fillTypeIndex, true);

		-- Start the factory animations if using 'autoStart' if possible.
		self:doAutoStart(fillTypeIndex);
	end;
end;

function ProductionFactory:removeFillLevel(farmId, fillLevelDelta, fillTypeIndex, triggerId)
	local product = self.fillTypeIndexToOutput[fillTypeIndex];

	if product ~= nil then
		self:updateFactoryLevels(product.fillLevel - fillLevelDelta, product, fillTypeIndex, true);

		-- Start the factory animations if using 'autoStart' if possible.
		self:doAutoStart(fillTypeIndex);
	end;
end;

--------------------
-- PLAYER TRIGGER --
--------------------

function ProductionFactory:playerTriggerActivated(triggerReference)
	-- Each productLine trigger will open direct to its GUI page.
	-- Global Player Trigger: This will open to factory overview.

	if triggerReference == nil then
		g_currentMission:showBlinkingWarning("THIS WILL OPEN THE GUI ONLY!");
	else
		local state = not self.productLines[triggerReference].active
		-- local canStart = state == true and self:getCanOperate(triggerReference)
		local canStart = state -- Testing only..
		self:setFactoryState(triggerReference, canStart)
	end;
end;

function ProductionFactory:playerTriggerUpdate(dt, triggerReference)
	-- TEMP: This will be a self creating pop-up GUI like - mCompany -!

	if triggerReference ~= nil then
		if self.productLines[triggerReference] ~= nil then
			local inputs = self.productLines[triggerReference].inputs;
			local outputs = self.productLines[triggerReference].outputs;

			g_currentMission:addExtraPrintText("Production Line " .. tostring(triggerReference) .." - INPUT:");
			for k, v in pairs (inputs) do
				local text = string.format("%s %s ", v.title, v.concatedFillTypeTitles.." [l]");

				local percent = math.min(math.max(v.fillLevel / v.capacity, 0), 1);
				local percentage = math.abs(percent * 100);

				text = text.."  "..string.format("%d (%d%%)",v.fillLevel, percentage);
				g_currentMission:addExtraPrintText(text);
			end

			g_currentMission:addExtraPrintText("Production Line " .. tostring(triggerReference) .." - OUTPUT:");
			for k, v in pairs (outputs) do
				local text = string.format("%s: %s ",  k, v.title.." [l]");

				local percent = math.min(math.max(v.fillLevel / v.capacity, 0), 1);
				local percentage = math.abs(percent * 100);

				text = text.."  "..string.format("%d (%d%%)",v.fillLevel, percentage);
				g_currentMission:addExtraPrintText(text);
			end

			if self:getIsFactoryLineOn(triggerReference) then
				g_currentMission:addExtraPrintText(string.format("Production Line %d is Running", triggerReference));
			else
				g_currentMission:addExtraPrintText(string.format("Production Line %d is Stopped", triggerReference));
			end;
		end;
	end;
end;






