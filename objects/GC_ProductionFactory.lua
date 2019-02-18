
local debugIndex = g_debug.registerMod("GlobalCompany-ProductionFactory");

ProductionFactory = {};
getfenv(0)["ProductionFactory"] = ProductionFactory;
g_company.productionFactory = ProductionFactory; -- Link so we can be talked to by other non GC scripts.

ProductionFactory_mt = Class(ProductionFactory, Object);
InitObjectClass(ProductionFactory, "ProductionFactory");

local saveId = -1;
local function getNextSaveId() saveId = saveId + 1; return tostring(saveId); end;

function ProductionFactory.onCreate(nodeId)
	local object = ProductionFactory:new(g_server ~= nil, g_client ~= nil);
	if object:load(nodeId) then
		object.baseDirectory = g_currentMission.loadingMapModName;
		object.customEnvironment = g_currentMission.loadingMapBaseDirectory;
		g_currentMission:addOnCreateLoadedObject(object);
		g_currentMission:addOnCreateLoadedObjectToSave(object);
		object:register(true);
	else
		object:delete();
	end;
end;

function ProductionFactory:new(isServer, isClient, customMt)	
	return Object:new(isServer, isClient, customMt or ProductionFactory_mt);
end;

function ProductionFactory:load(nodeId, productionKey, indexName, parent)	
	self.nodeId = nodeId;	

	self.productionKey = productionKey;	
	self.indexName = indexName;	
	self.parent = parent;	
	self.isPlaceable = productionKey ~= nil and parent ~= nil;
		
	self.fillTypeIndexToInput = {};
	self.fillTypeIndexToOutput = {};

	self.levelChangeTimer = -1;

	if not self.isPlaceable then
		if not self:finalizePlacement() then return false; end;
	end;

	return true;
end;

function ProductionFactory:finalizePlacement()		
	local xmlFile, xmlKey, indexName;
	local addKey = "";	
	if self.isPlaceable then
		xmlFile = loadXMLFile("ProductionFactory", self.parent.configFileName);
		addKey = "placeable.";
		xmlKey = self.productionKey
		indexName = self.indexName
	else
		indexName = getUserAttribute(self.nodeId, "indexName");
		local xmlFilenameAttribute = getUserAttribute(self.nodeId, "xmlFile");
		if indexName ~= nil and xmlFilenameAttribute ~= nil then
			xmlFile = loadXMLFile("ProductionFactory", Utils.getFilename(xmlFilenameAttribute, self.baseDirectory));
			xmlKey = g_company.xmlUtils:getXmlKey(xmlFile, "globalCompany.productionFactories", "productionFactory", indexName);
		end;
	end;

	local loaded = false;
	if xmlFile ~= nil and xmlFile ~= 0 then
		self.triggerManager = GC_TriggerManager:new(self); -- init trigger manager.
		self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, addKey .. "globalCompany.i3dMappings");	-- i3dMappings support.

		local saveId = Utils.getNoNil(getXMLString(xmlFile, xmlKey .. "#saveId"), "_");
		if saveId ~= "_" then
			self.saveId = string.format( "_%s_", saveId)
		end;
		self.saveId = "ProductionFactory" .. saveId .. getNextSaveId();

		self.showInGlobalGUI = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. ".operation#showInGlobalGUI"), true);
		self.drawFactoryInformation = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. ".operation#drawFactoryInformation"), true);
		self.updateDelay = math.max(Utils.getNoNil(getXMLInt(xmlFile, xmlKey .. ".operation#updateDelayMinutes"), 10), 1);
		self.updateCounter = self.updateDelay;

		self.triggerIdToProduct = {};
		
		-------------------------------
		-- REGISTER LOADING TRIGGERS --
		-------------------------------

		self.registeredLoadingTriggers = {}; -- This is done now so that we can use one trigger for all outputs if needed.
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
					self.registeredLoadingTriggers[name] = trigger;
				end;				
			end;
			i = i + 1;
		end;

		self.productLines = {};
		local registeredProducts = {output = 0, input = 0};
		
		-----------------------------
		-- REGISTER INPUT PRODUCTS --
		-----------------------------
		self.inputProducts = {};
	
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
		
							local fillTypeTitle = fillType.title;
							local customTitle = getXMLString(xmlFile, fillTypesKey .. "#title");
							if customTitle ~= nil then
								fillTypeTitle = g_company.languageManager:getText(customTitle);
							end;
		
							table.insert(concatTitles, fillTypeTitle);
						else
							if fillType == nil then
								g_debug.write(debugIndex, g_debug.ERROR, "[FACTORY - %s] Unknown fillType ( %s ) found in 'inputProduct' ( %s ) in '%s', ignoring!", indexName, fillTypeName, inputProductName);
							else
								g_debug.write(debugIndex, g_debug.ERROR, "[FACTORY - %s] Duplicate 'inputProduct' fillType ( %s ) in '%s', FillType already used at '%s'!", indexName, fillTypeName, inputProductName, usedFillTypeNames[fillTypeName]);
							end;
						end;
					end;
		
					j = j + 1;
				end;

				if inputProduct.fillTypes ~= nil then
					registeredProducts.input = registeredProducts.input + 1;
					
					inputProduct.fillLevel = 0;
					inputProduct.lastFillType = 0;
					inputProduct.concatedFillTypeTitles = table.concat(concatTitles, " | ");
					inputProduct.capacity = Utils.getNoNil(getXMLInt(xmlFile, inputProductKey .. "#capacity"), 1000);

					inputProduct.title = tostring(registeredProducts.input) .. ":";
					local productTitle = getXMLString(xmlFile, inputProductKey .. "#title");
					if productTitle ~= nil then
						inputProduct.title = g_company.languageManager:getText(productTitle) .. ":";
					end;	
					
					if hasXMLProperty(xmlFile, inputProductKey .. ".inputMethods") then					
						-- Rain Water
						if hasXMLProperty(xmlFile, inputProductKey .. ".inputMethods.collectRainWater") then
							if inputProduct.fillTypes[FillType.WATER] ~= nil then -- Only for WATER
								local litresPerHour = getXMLString(xmlFile, inputProductKey .. ".inputMethods.collectRainWater#litresPerHour");
								if litresPerHour ~= nil then
									if self.collectRainWater == nil then
										self.collectRainWater = {input = inputProduct, collected = 0, update = false, litresPerHour = litresPerHour};
									end;
								end;
							else
								g_debug.write(debugIndex, g_debug.ERROR, "[FACTORY - %s] 'inputProduct' %s does not contain fillType 'WATER', <collectRainWater> has been disabled.", indexName, inputProductName);
							end;
						end;
		
						-- Wood Trigger
						local woodTriggerKey = inputProductKey .. ".inputMethods.woodTrigger";
						if hasXMLProperty(xmlFile, woodTriggerKey) then
							if inputProduct.fillTypes[FillType.WOODCHIPS] ~= nil then -- Only for WOODCHIPS
								local trigger = self.triggerManager:loadTrigger(GC_WoodTrigger, self.nodeId, xmlFile, woodTriggerKey, "WOODCHIPS");
								if trigger ~= nil then
									trigger.extraParamater = trigger.managerId;
									self.triggerIdToProduct[trigger.managerId] = inputProduct;
								end;
							else
								g_debug.write(debugIndex, g_debug.ERROR, "[FACTORY - %s] 'inputProduct' %s does not contain fillType 'WOODCHIPS', <woodTrigger> has been disabled.", indexName, inputProductName);
							end;
						end;
		
						-- Unload Triggers
						local unloadTriggerKey = inputProductKey .. ".inputMethods.unloadTrigger";
						if hasXMLProperty(xmlFile, unloadTriggerKey) then		
							local forcedFillTypes = {};
							for index, _ in pairs (inputProduct.fillTypes) do
								table.insert(forcedFillTypes, index)
							end;
							
							local trigger = self.triggerManager:loadTrigger(GC_UnloadingTrigger, self.nodeId, xmlFile, unloadTriggerKey, forcedFillTypes);
							if trigger ~= nil then
								trigger.extraParamater = trigger.managerId;
								self.triggerIdToProduct[trigger.managerId] = inputProduct;
							end;
						end;
					end;

					self.inputProducts[inputProductName] = inputProduct;
				end;
			end;

			i = i + 1;
		end;
		
		------------------------------
		-- REGISTER OUTPUT PRODUCTS --
		------------------------------
		self.outputProducts = {};
		
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
						outputProduct.capacity = Utils.getNoNil(getXMLInt(xmlFile, outputProductKey .. "#capacity"), 1000);
						
						outputProduct.title = tostring(registeredProducts.output) .. ":";
						local productTitle = getXMLString(xmlFile, outputProductKey .. "#title");
						if productTitle ~= nil then
							outputProduct.title =  g_company.languageManager:getText(productTitle) .. ":";
						end;
						
						
						
						
						-- Need to rethink this and limit combinations.
						
						
						if hasXMLProperty(xmlFile, outputProductKey .. ".outputMethods") then					
							-- Pallet Fill Trigger
							local palletFillAreaKey = outputProductKey .. ".outputMethods.palletFillArea";
							if hasXMLProperty(xmlFile, palletFillAreaKey) then
								-- TO DO (This will fill the pallet as the factory works.)
								
								outputProduct.palletFillArea = nil;
							end;

							if outputProduct.palletFillArea == nil then
								-- Loading Trigger (SILO)
								local loadingTriggerKey = outputProductKey .. ".outputMethods.unloadTrigger";
								if hasXMLProperty(xmlFile, loadingTriggerKey) then
									local name = getXMLString(xmlFile, loadingTriggerKey .. "#name");
									local trigger = self.registeredLoadingTriggers[name];
									if trigger ~= nil then
										-- Add fillType to trigger if it does not exist already or give warning.
										trigger.extraParamater = trigger.managerId;
										self.triggerIdToProduct[trigger.managerId] = outputProduct;
									else
										-- Trigger does not exist.
									end;
								end;
								
								self.registeredLoadingTriggers = nil; -- Clear this table to clean up.

								-- Dynamic Heap
								local dynamicHeapKey = outputProductKey .. ".outputMethods.dynamicHeap";
								if hasXMLProperty(xmlFile, dynamicHeapKey) then
									local trigger = self.triggerManager:loadTrigger(GC_DynamicHeap, self.nodeId, xmlFile, dynamicHeapKey, fillTypeName);
									if trigger ~= nil then
										trigger.extraParamater = trigger.managerId;
										outputProduct.dynamicHeap = trigger;										
										self.triggerIdToProduct[trigger.managerId] = outputProduct;
									end;
								end;
		
								-- Pallet Spawner
								local palletSpawnerKey = outputProductKey .. ".outputMethods.palletSpawner";
								if hasXMLProperty(xmlFile, palletSpawnerKey) then
									-- TO DO (This will allow pallets to be spawned on demand from GUI. DynamicHeap and Loading Trigger level will be reduced if used.)
								end;
							end;
						end;
						
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
			
			-- Individual product lines.
			i = 0;
			while true do
				local productLineKey = string.format("%s.productLines.productLine(%d)", xmlKey, i);
				if not hasXMLProperty(xmlFile, productLineKey) then
					break;
				end;

				local productLine = {};
				
				productLine.active = false;
				productLine.autoStart = Utils.getNoNil(getXMLBool(xmlFile, productLineKey .. "#autoLineStart"), false);
				productLine.outputPerHour = Utils.getNoNil(getXMLInt(xmlFile, productLineKey .. "#outputPerHour"), 1000);

				-- Need to fix these and make backup images.
				productLine.name = "Production Line " .. i + 1;
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
							print("TRING TO USE TWICE in the same product line") -- Need to fix warning.
						end;
					else
						g_debug.write(debugIndex, g_debug.ERROR, "[FACTORY - %s] inputProduct '%s' does not exist! You must first register inputProducts in factory XML.", indexName, name);
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

				table.insert(self.productLines, productLine);
				loaded = true;

				i = i + 1;
			end;
		
			-------------------------
			-- LOAD PLAYER TRIGGER --
			-------------------------

			local playerTriggerKey = xmlKey .. ".playerTrigger";
			if hasXMLProperty(xmlFile, playerTriggerKey) then
				self.triggerManager:loadTrigger(GC_PlayerTrigger, self.nodeId, xmlFile, playerTriggerKey, "globalTrigger", true);
			end;

			---------------------------
			-- TRY TO FINISH LOADING --
			---------------------------

			if self.isServer and loaded then
				g_currentMission.environment:addMinuteChangeListener(self);
			end;

			self.factoryDirtyFlag = self:getNextDirtyFlag();
		else
			loaded = false;
			g_debug.write(debugIndex, g_debug.ERROR, "[FACTORY - %s] No 'inputProducts' or/and 'outputProducts' have been registered factory cannot be loaded!", indexName);
		end;
	end;

	return loaded;
end;

function ProductionFactory:delete()
	if self.triggerManager ~= nil then
		self.triggerManager:unregisterAllTriggers();
	end;
    unregisterObjectClassName(self)
    ProductionFactory:superClass().delete(self)
end;

function ProductionFactory:deleteFinal()
    ProductionFactory:superClass().deleteFinal(self)
end

function ProductionFactory:update(dt)
	local raiseActive = false;

	if self.isServer and self.levelChangeTimer > 0 then
		self.levelChangeTimer = self.levelChangeTimer - 1;
		if self.levelChangeTimer <= 0 then
			self.lastCheckedFillType = nil;
		end;

		raiseActive = true;
	end;

	if raiseActive then
		self:raiseActive();
	end;
end;


function ProductionFactory:minuteChanged()
	if not g_currentMission:getIsServer() then
		return;
	end;

	if self.collectRainWater ~= nil then
		local rainWater = self.collectRainWater;
		local rainToCollect = rainWater.litresPerHour / 60;

		if g_currentMission.environment.weather.timeSinceLastRain < 30 then
			if rainWater.input.fillLevel + (rainWater.collected + rainToCollect) < rainWater.input.capacity then
				rainWater.collected = rainWater.collected + rainToCollect;
			end;
		else
			if rainWater.collected > 0 then
				rainWater.update = true;
			end;
		end;

		-- Only update rain to clients every 10 min of game time??
		if rainWater.update or rainWater.collected >= (rainToCollect * 10) then
			local amount = math.min(rainWater.input.fillLevel + rainWater.collected, rainWater.input.capacity);
			self:updateFactoryLevels(amount, rainWater.input, FillType.WATER, true);
			rainWater.collected = 0;
			rainWater.update = false;
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

						self:updateFactoryLevels(input.fillLevel - amount, input, input.lastFillType, false);

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
		self:raiseDirtyFlags(self.factoryDirtyFlag);
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

	if self.isServer and raiseFlags then
		self:raiseDirtyFlags(self.factoryDirtyFlag);
	end;
end;

function ProductionFactory:setFactoryState(lineId, state, noEventSend)
	--ProductFactoryStateEvent.sendEvent(self, state, noEventSend);

	self.productLines[lineId].active = state;

	-- Force start / stop all used parts.
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

	--print("vehicleChangedHeapLevel ( " .. heapId .. " ) = " .. heapLevel);
	
	local product = self.triggerIdToProduct[heapId];
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

-------------------------
-- Trigger Requirements --
-------------------------

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
		self:updateFactoryLevels(product.fillLevel + fillLevelDelta, product, fillTypeIndex, true);

		-- Start the factory animations if using 'autoStart' if possible.
		self:doAutoStart(fillTypeIndex);
	end;
end;

--------------------
-- PLAYER TRIGGER --
--------------------

function ProductionFactory:playerTriggerActivated(triggerReference)
	local state = not self.productLines[1].active
	self:setFactoryState(1, state)
end;

function ProductionFactory:playerTriggerUpdate(dt, triggerReference)
	for i = 1, #self.productLines do
		local inputs = self.productLines[i].inputs
		local outputs = self.productLines[i].outputs

		g_currentMission:addExtraPrintText("Production Line " .. tostring(i) .." - INPUT:");
		for k, v in pairs (inputs) do
			local text = string.format("%s %s ", v.title, v.concatedFillTypeTitles.." [l]");
			
			local percent = math.min(math.max(v.fillLevel / v.capacity, 0), 1);			
			local percentage = math.abs(percent * 100);
			
			text = text.."  "..string.format("%d (%d%%)",v.fillLevel, percentage);
			g_currentMission:addExtraPrintText(text);
		end

		g_currentMission:addExtraPrintText("Production Line " .. tostring(i) .." - OUTPUT:");
		for k, v in pairs (outputs) do
			-- TEMP NEEDS TO BE A FUNCTION
			-- if v.dynamicHeap ~= nil then							
				-- v.fillLevel = v.dynamicHeap:getHeapLevel();
			-- end;

			local text = string.format("%s: %s ",  k, v.title.." [l]");
			
			local percent = math.min(math.max(v.fillLevel / v.capacity, 0), 1);			
			local percentage = math.abs(percent * 100);
			
			text = text.."  "..string.format("%d (%d%%)",v.fillLevel, percentage);
			g_currentMission:addExtraPrintText(text);
		end

		if self:getIsFactoryLineOn(i) then
			g_currentMission:addExtraPrintText("Factory is Running");
		else
			g_currentMission:addExtraPrintText("Factory is Stopped");
		end;
	end;
end;

g_onCreateUtil.addOnCreateFunction("ProductionFactory", ProductionFactory.onCreate);
