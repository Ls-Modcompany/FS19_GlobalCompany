--
-- GlobalCompany - Objects - GC_Effects
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX / kevink98
-- @Date: 24.02.2019
-- @Version: 1.2.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.2.0.0 (24.02.2019):
--		- update to same format as all other 'addon' scripts.
--		- add 'exhaustSystems'.
--
-- 	v1.1.0.0 (13.12.2018):
--		- convert in fs19 (kevink98)
--
-- 	v1.0.0.0 (20.11.2018):
-- 		- initial fs17 (GtX)
--
-- Notes:
--		- Client Side Only.
--		- Parent script 'MUST' call delete()
--
--
-- ToDo:
--		- May add sounds option for 'materialHolder.effects' e.g Silo flowing sound.
--


GC_Effects = {};

local GC_Effects_mt = Class(GC_Effects);
InitObjectClass(GC_Effects, "GC_Effects");

GC_Effects.debugIndex = g_company.debug:registerScriptName("Effects");

g_company.effects = GC_Effects;

function GC_Effects:new(isServer, isClient, customMt)
	local self = {};
	setmetatable(self, customMt or GC_Effects_mt);

	self.isServer = isServer;
	self.isClient = isClient;

	self.exhaustSystems = nil;

	self.standardParticleSystems = nil;
	self.intervalParticleSystems = nil;

	self.standardEffects = nil;
	self.intervalEffects = nil;

	self.disableEffects = false;
	self.disableParticleSystems = false;

	self.customMaterials = nil;
	self.customMaterialsFilename = nil;

	self.effectsActive = false;

	return self;
end;

function GC_Effects:load(nodeId, target, xmlFile, xmlKey, baseDirectory, groupKey)
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' parameter = %s, 'target' parameter = %s 'xmlFile' parameter = %s, 'xmlKey' parameter = %s";
		g_company.debug:logWrite(GC_Effects.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil);
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_Effects.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;

	self.baseDirectory = GlobalCompanyUtils.getParentBaseDirectory(target, baseDirectory);

	local returnValue = false;
	if self.isClient then
		if groupKey == nil then
			groupKey = "effectTypes";
		end;

		--| Exhaust Systems |--
		local exhaustSystemsKey = string.format("%s.%s.exhaustSystems", xmlKey, groupKey);
		if hasXMLProperty(xmlFile, exhaustSystemsKey) then
			self.exhaustSystems = {};

			local i = 0;
			while true do
				local key = string.format("%s.exhaustEffect(%d)", exhaustSystemsKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local linkNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#linkNode"), self.target.i3dMappings);
				if linkNode ~= nil then
					local filename = Utils.getNoNil(getXMLString(xmlFile, key .. "#filename"), "$data/particleSystems/shared/exhaust.i3d");
					if filename ~= nil then
						local i3dNode = g_i3DManager:loadSharedI3DFile(filename, self.baseDirectory, false, false, false);
						if i3dNode ~= 0 then
							local node = getChildAt(i3dNode, 0);
							if getHasShaderParameter(node, "exhaustColor") then
								local baseParam = {0.2, 0.2, 0.2, 0.8};
								local particleColor = Utils.getNoNil(GlobalCompanyUtils.getNumbersFromString(xmlFile, key .. "#particleColor", 4, false, self.debugData), baseParam);

								link(linkNode, node);
								setVisibility(node, false);
								setShaderParameter(node, "param", 0, 0, 0, 0.4, false);
								setShaderParameter(node, "exhaustColor", particleColor[1], particleColor[2], particleColor[3], particleColor[4], false);

								if self.exhaustSystems == nil then
									self.exhaustSystems = {};
								end;

								table.insert(self.exhaustSystems, {node = node, linkNode = linkNode, filename = filename});

								returnValue = true;
								delete(i3dNode);
							else
								g_company.debug:writeModding(self.debugData, "shaderParameter 'exhaustColor' does not exist on node '%s' in I3DFile '%s'", getName(node), filename);
							end;
						end;
					end;
				end;

				i = i + 1;
			end;
		end;

		--| Particle Systems |--
		local particleSystemsKey = string.format("%s.%s.particleSystems", xmlKey, groupKey);
		if hasXMLProperty(xmlFile, particleSystemsKey) then
			local i = 0;
			while true do
				local key = string.format("%s.particleEffect(%d)", particleSystemsKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings);
				if node ~= nil then
					local particleSystem = {};

					local data = {};
					ParticleUtil.loadParticleSystemData(xmlFile, data, key)
					data.nodeStr = nil; -- Send 'nil' so we use the 'defaultLinkNode' paramater.
					ParticleUtil.loadParticleSystemFromData(data, particleSystem, nil, false, nil, self.baseDirectory, node)

					local operatingInterval = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#operatingIntervalSeconds"), 0);
					if operatingInterval > 0 then
						local stoppedInterval = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#stoppedIntervalSeconds"), operatingInterval);
						local delayStart = Utils.getNoNil(getXMLBool(xmlFile, key .. "#delayedStart"), false);
						local operatingTime = 0;
						if delayStart then
							operatingTime = stoppedInterval * 1000;
						end;

						particleSystem.delayTime = operatingTime;
						particleSystem.operatingInterval = operatingInterval * 1000;
						particleSystem.stoppedInterval = stoppedInterval * 1000;
						particleSystem.interval = operatingTime;
						particleSystem.operatingTime = operatingTime;

						if self.intervalParticleSystems == nil then
							self.intervalParticleSystems = {};
							returnValue = true;
						end;

						table.insert(self.intervalParticleSystems, particleSystem);
					else
						if self.standardParticleSystems == nil then
							self.standardParticleSystems = {};
							returnValue = true;
						end;

						table.insert(self.standardParticleSystems, particleSystem);
					end;

					particleSystem = nil;
				end;

				i = i + 1;
			end;
		end;

		--| Material Holder Effects |--
		local materialHolderEffectsKey = string.format("%s.%s.materialHolder", xmlKey, groupKey);
		if hasXMLProperty(xmlFile, materialHolderEffectsKey) then
			local i = 0;
			while true do
				local key = string.format("%s.effects(%d)", materialHolderEffectsKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local effectsToLoad = g_effectManager:loadEffect(xmlFile, key, nodeId, self, self.target.i3dMappings);
				if effectsToLoad ~= nil then
					local effects = {};
					effects.effects = effectsToLoad;

					local fillTypeNames = getXMLString(xmlFile, key .. "#fillTypes"); -- Using 'fillTypes' with 'operatingIntervalSeconds' cycles through the fillTypes at each interval change.
					if fillTypeNames == nil then
						local fillTypeName = getXMLString(xmlFile, key .. "#fillType"); -- Single product to use for the effect.
						local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
						if fillTypeIndex ~= nil then
							effects.fillTypeIndex = fillTypeIndex;
							effects.backupFillTypeIndex = fillTypeIndex;
						else
							effects.fillTypeIndex = FillType.WHEAT; -- Keep 'wheat' as a backup incase nothing is listed.
						end;
					end;

					local operatingInterval = Utils.getNoNil(getXMLFloat(xmlFile, key.."#operatingIntervalSeconds"), 0);
					if operatingInterval > 0 then
						if fillTypeNames ~= nil then
							effects.fillTypes = {};
							local splitFillTypeNames = StringUtil.splitString(" ", fillTypeNames);
							for _, fillTypeName in pairs(splitFillTypeNames) do
								local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
								if fillTypeIndex ~= nil then
									table.insert(effects.fillTypes, fillTypeIndex);
								else
									g_company.debug:writeModding(self.debugData, "fillType '%s' is not valid at %s#fillTypes", fillTypeName, key);
								end;
							end;

							effects.resetOnStart = Utils.getNoNil(getXMLBool(xmlFile, key .. "#resetFillTypesOnStart"), false);
							effects.numFillTypes = #effects.fillTypes;
							effects.nextFillType = 1;

							-- If the multi-fillTypes failed or there is only '1' then lets load the backup or set it to a single type.
							if effects.numFillTypes == 0 then
								effects.fillTypes = nil;
								effects.fillTypeIndex = FillType.WHEAT;
								effects.backupFillTypeIndex = FillType.WHEAT;
							elseif effects.numFillTypes == 1 then
								effects.fillTypeIndex = effects.fillTypes[1];
								effects.backupFillTypeIndex = effects.fillTypeIndex;
								effects.fillTypes = nil;
							end;
						end;

						local stoppedInterval = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#stoppedIntervalSeconds"), operatingInterval);
						local delayStart = Utils.getNoNil(getXMLBool(xmlFile, key .. "#delayedStart"), false);
						local operatingTime = 0;
						if delayStart then
							operatingTime = stoppedInterval * 1000;
						end;

						effects.active = false;
						effects.delayTime = operatingTime;
						effects.operatingInterval = operatingInterval * 1000;
						effects.stoppedInterval = stoppedInterval * 1000;
						effects.interval = operatingTime;
						effects.operatingTime = operatingTime;

						if self.intervalEffects == nil then
							self.intervalEffects = {};
							returnValue = true;
						end;

						table.insert(self.intervalEffects, effects);
					else
						if self.standardEffects == nil then
							self.standardEffects = {};
							returnValue = true;
						end;

						table.insert(self.standardEffects, effects);
					end;

					effects = nil;
				end;

				i = i + 1;
			end;
		end;

		--| Custom Materials |--
		local customMaterialsKey = string.format("%s.%s.customMaterials", xmlKey, groupKey);
		if hasXMLProperty(xmlFile, customMaterialsKey) then
			local filename = getXMLString(xmlFile, customMaterialsKey .. "#filename");
			local i3dNode = g_i3DManager:loadSharedI3DFile(filename, self.baseDirectory, false, false, false);
			if i3dNode ~= 0 then
				self.customMaterials = {};
				self.customMaterialsFilename = filename;

				local i = 0;
				while true do
					local key = string.format("%s.material(%d)", customMaterialsKey, i);
					if not hasXMLProperty(xmlFile, key) then
						break;
					end;

					local sharedI3dNode = Utils.getNoNil(getXMLString(xmlFile, key .. "#sharedI3dNode"), "0");
					local fillTypeName = getXMLString(xmlFile, key .. "#fillType");
					local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);

					if fillTypeIndex ~= nil then
						local sharedRootNode = I3DUtil.indexToObject(i3dNode, sharedI3dNode);
						if self.customMaterials[fillTypeIndex] == nil then
							self.customMaterials[fillTypeIndex] = getMaterial(sharedRootNode, 0);
						else
							g_company.debug:writeModding(self.debugData, "Duplicate material fillType '%s' given at %s#fillType", fillTypeName, key);
						end;
					else
						g_company.debug:writeModding(self.debugData, "fillType '%s' is not valid at %s#fillType", fillTypeName, key);
					end;

					i = i + 1;
				end;

				delete(i3dNode);
			else
				g_company.debug:writeWarning(self.debugData, "Could not load file '%s' at ( %s )", filename, customMaterialsKey .. "#filename");
			end;
		end;

		if self.intervalParticleSystems ~= nil or self.intervalEffects ~= nil then
			g_company.addRaisedUpdateable(self);
		end;
	else
		g_company.debug:writeDev(self.debugData, "Failed to load 'CLIENT ONLY' script on server!");
		returnValue = true; -- Send true so we can also print 'function' warnings if called by server.
	end;

	return returnValue;
end;

function GC_Effects:delete()
	if self.isClient then

		if self.exhaustSystems ~= nil then
			for _, exhaustEffect in pairs (self.exhaustSystems) do
				g_i3DManager:releaseSharedI3DFile(exhaustEffect.filename, self.baseDirectory, true);
			end;
			self.exhaustSystems = nil;
		end;

		if self.standardParticleSystems ~= nil then
			for _, particleSystem in pairs (self.standardParticleSystems) do
				ParticleUtil.deleteParticleSystem(particleSystem);
			end;
			self.standardParticleSystems = nil;
		end;

		if self.standardEffects ~= nil then
			for _, effects in pairs (self.standardEffects) do
				g_effectManager:deleteEffects(effects.effects);
			end;
			self.standardEffects = nil;
		end;

		if self.intervalParticleSystems ~= nil or self.intervalEffects ~= nil then
			if self.intervalParticleSystems ~= nil then
				for _, particleSystem in pairs (self.intervalParticleSystems) do
					ParticleUtil.deleteParticleSystem(particleSystem);
				end;
				self.intervalParticleSystems = nil;
			end;

			if self.intervalEffects ~= nil then
				for _, effects in pairs (self.intervalEffects) do
					g_effectManager:deleteEffects(effects.effects);
				end;
				self.intervalEffects = nil;
			end;

			g_company.removeRaisedUpdateable(self);
		end;

		if self.customMaterialsFilename ~= nil then
			g_i3DManager:releaseSharedI3DFile(self.customMaterialsFilename, self.baseDirectory, true);
			self.customMaterialsFilename = nil;
		end;
	end;
end;

function GC_Effects:update(dt)
	if self.isClient then
		if self.effectsActive then
			if self.intervalParticleSystems ~= nil then
				for _, particleSystem in pairs (self.intervalParticleSystems) do
					particleSystem.operatingTime = particleSystem.operatingTime - dt;
					if particleSystem.operatingTime <= 0 then
						if particleSystem.isEmitting then
							ParticleUtil.setEmittingState(particleSystem, false);
							particleSystem.interval = particleSystem.stoppedInterval;
						else
							ParticleUtil.setEmittingState(particleSystem, true);
							particleSystem.interval = particleSystem.operatingInterval;
						end;
						particleSystem.operatingTime = particleSystem.operatingTime + particleSystem.interval;
					end;
				end;

				if not self.disableParticleSystems then
					self.disableParticleSystems = true;
				end;
			end;

			if self.intervalEffects ~= nil then
				for _, effects in pairs (self.intervalEffects) do
					effects.operatingTime = effects.operatingTime - dt;
					if effects.operatingTime <= 0 then
						if effects.active then
							effects.active = false;
							g_effectManager:stopEffects(effects.effects);
							effects.interval = effects.stoppedInterval;
						else
							effects.active = true;
							if effects.fillTypes ~= nil then
								local nextFillTypeIndex = effects.fillTypes[effects.nextFillType];
								g_effectManager:setFillType(effects.effects, nextFillTypeIndex);
								g_effectManager:startEffects(effects.effects);

								if (effects.nextFillType + 1) <= effects.numFillTypes then
									effects.nextFillType = effects.nextFillType + 1;
								else
									effects.nextFillType = 1;
								end;
							else
								g_effectManager:setFillType(effects.effects, effects.fillTypeIndex);
								g_effectManager:startEffects(effects.effects);
							end;

							effects.interval = effects.operatingInterval;
						end;

						effects.operatingTime = effects.operatingTime + effects.interval;
					end;
				end;

				if not self.disableEffects  then
					self.disableEffects = true;
				end;
			end;

			self:raiseUpdate();
		else
			if self.intervalParticleSystems ~= nil then
				if self.disableParticleSystems then
					self.disableParticleSystems = false;
					for _, particleSystem in pairs (self.intervalParticleSystems) do
						if particleSystem.isEmitting then
							ParticleUtil.setEmittingState(particleSystem, false);
							particleSystem.operatingTime = particleSystem.delayTime;
						end;
					end;
				end;
			end;

			if self.intervalEffects ~= nil then
				if self.disableEffects then
					self.disableEffects = false;
					for _, effects in pairs (self.intervalEffects) do
						g_effectManager:stopEffects(effects.effects);
						effects.operatingTime = effects.delayTime;
						effects.active = false;

						if effects.resetOnStart then
							effects.nextFillType = 1;
						end;
					end;
				end;
			end;
		end;
	end;
end;

function GC_Effects:setEffectsState(state, forceState)
	if self.isClient then
		local setState = state or (not self.effectsActive);

		if self.effectsActive ~= setState or forceState == true then
			self.effectsActive = setState;

			if self.exhaustSystems ~= nil then
				for _, exhaustEffect in pairs (self.exhaustSystems) do
					setVisibility(exhaustEffect.node, setState);
				end;
			end;

			if self.standardParticleSystems ~= nil then
				for _, particleSystem in pairs (self.standardParticleSystems) do
					ParticleUtil.setEmittingState(particleSystem, setState);
				end;
			end;

			if self.standardEffects ~= nil then
				for _, effects in pairs (self.standardEffects) do
					if self.effectsActive then
						g_effectManager:setFillType(effects.effects, effects.fillTypeIndex);
						g_effectManager:startEffects(effects.effects);
					else
						g_effectManager:stopEffects(effects.effects);
					end;
				end;
			end;

			if self.intervalParticleSystems ~= nil or self.intervalEffects ~= nil then
				self:raiseUpdate();
			end;
		end;
	else
		g_company.debug:writeDev(self.debugData, "'setEffectsState' is a client only function!");
	end;
end;

function GC_Effects:getEffectsState()
	return self.effectsActive;
end;

function GC_Effects:replaceAllEffectsFillType(fillTypeIndex)
	local newFillTypeIndex;
	local isVaild = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex) ~= nil;

	if self.standardEffects ~= nil then
		for _, effects in pairs (self.standardEffects) do
			if isVaild then
				newFillTypeIndex = fillTypeIndex;
			else
				newFillTypeIndex = effects.backupFillTypeIndex;
			end;

			if newFillTypeIndex ~= nil and newFillTypeIndex ~= effects.fillTypeIndex then
				effects.fillTypeIndex = newFillTypeIndex;
				g_effectManager:setFillType(effects.effects, effects.fillTypeIndex);
			end;
		end;
	end;

	if self.intervalEffects ~= nil then
		for _, effects in pairs (self.intervalEffects) do
			-- This will only update single fillType 'effects'.
			if effects.fillTypeIndex ~= nil then
				if isVaild then
					newFillTypeIndex = fillTypeIndex;
				else
					newFillTypeIndex = effects.backupFillTypeIndex;
				end;

				if newFillTypeIndex ~= nil and newFillTypeIndex ~= effects.fillTypeIndex then
					effects.fillTypeIndex = newFillTypeIndex;
					g_effectManager:setFillType(effects.effects, effects.fillTypeIndex);
				end;
			end;
		end;
	end;
end;

function GC_Effects:setCustomMaterialToPS(fillTypeIndex)
	if self.isClient then
		if self.customMaterials == nil or self.customMaterials[fillTypeIndex] == nil then
			local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex);
			g_company.debug:writeDev(self.debugData, "'setCustomMaterialToPS' failed! No material exists for fillType '%s'.", fillTypeName);
			return;
		end;

		local material = self.customMaterials[fillTypeIndex];

		if self.standardParticleSystems ~= nil then
			for _, particleSystem in pairs (self.standardParticleSystems) do
				setMaterial(particleSystem.shape, material, 0);
			end;
		end;

		if self.standardEffects ~= nil then
			for _, effects in pairs (self.standardEffects) do
				setMaterial(nodeEffect.shape, material, 0);
			end;
		end;
	else
		g_company.debug:writeDev(self.debugData, "'setCustomMaterialToPS' is a client only function!");
	end;
end;





