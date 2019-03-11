-- 
-- GlobalCompany - Objects - ParticleEffects
-- 
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 13.12.2018
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
-- 	v1.1.0.0 (13.12.2018):
--		- convert in fs19 (kevink98)
--		
-- 	v1.0.0.0 (20.11.2018):
-- 		- initial fs17 (GtX)
-- 
-- Notes:
-- 	This operates Client side only
-- 
-- 
-- ToDo:
--  can we remove this file? its include in Effects.lua?

local debugIndex = g_debug.registerMod("GlobalCompany-GC_ParticleEffects");

GC_ParticleEffects = {};
getfenv(0)["GC_ParticleEffects"] = GC_ParticleEffects;

GC_ParticleEffects_mt = Class(GC_ParticleEffects);
InitObjectClass(GC_ParticleEffects, "GC_ParticleEffects");

function GC_ParticleEffects:new(isServer, isClient)
	local self = {};

	setmetatable(self, GC_ParticleEffects_mt);

	self.isServer = isServer;
	self.isClient = isClient;
	
	print("", "", "GLOBAL COMPANY - DEVELOPMENT INFORMATION:  'GC_ParticleEffects' has been depreciated. Use 'GC_Effects' instead!", "", "");

	return self;
end;

function GC_ParticleEffects:load(id, xmlFile, baseKey)
	self.effectsRunning = false;

	local loaded = false;
	if self.isClient then
		if xmlFile ~= nil and baseKey ~= nil then
			if hasXMLProperty(xmlFile, baseKey..".particleSystem") then
				local i=0;
				while true do
					local key = string.format("%s.particleSystem.effect(%d)", baseKey, i);
					if not hasXMLProperty(xmlFile, key) then
						break;
					end;
	
					local nodeIndex = I3DUtil.indexToObject(id, getXMLString(xmlFile, key.."#node"));
					local psFile = getXMLString(xmlFile, key.."#particleSystemFilename");
					if nodeIndex ~= nil and psFile ~= nil then
						local nodeEffects = {};
	
						local psData = {};
						psData.psFile = psFile;
						psData.posX, psData.posY, psData.posZ = getTranslation(nodeIndex);
						psData.rotX, psData.rotY, psData.rotZ = getRotation(nodeIndex);
						psData.worldSpace = false;
	
						ParticleUtil.loadParticleSystemFromData(psData, nodeEffects, nil, false, nil, g_currentMission.baseDirectory, getParent(nodeIndex));
	
						local operatingInterval = Utils.getNoNil(getXMLFloat(xmlFile, key.."#operatingIntervalSeconds"), 0); -- On / Off delay (e.g ON = 60sec | OFF = 60sec)
						if operatingInterval > 0 then
							local delayStart = Utils.getNoNil(getXMLBool(xmlFile, key.."#delayedStart"), false); -- Apply the 'operatingIntervalSeconds' at the start when the effect is called?
							local operatingTime = 0;
							if delayStart then
								operatingTime = operatingInterval * 1000;
							end;
	
							nodeEffects.delayTime = operatingTime;
							nodeEffects.operatingInterval = operatingInterval * 1000;
							nodeEffects.operatingTime = operatingTime;
	
							if self.intervalNodeEffects == nil then
								self.intervalNodeEffects = {};
							end;
	
							table.insert(self.intervalNodeEffects, nodeEffects);
						else
							if self.standardNodeEffects == nil then
								self.standardNodeEffects = {};
							end;
	
							table.insert(self.standardNodeEffects, nodeEffects);
						end;
	
						loaded = true;
						self.disableNodeEffects = false;
					end;
					i = i + 1;
				end;
			end;
	
			-- This method acts in the same way as a silo, belt, mower etc by using the materialHolder.i3d and the 'materialType' you want to use.
			if hasXMLProperty(xmlFile, baseKey..".materialHolder") then
				local i=0;
				while true do
					local key = string.format("%s.materialHolder.effects(%d)", baseKey, i);
					if not hasXMLProperty(xmlFile, key) then
						break;
					end;
	
					local effectsToLoad = EffectManager:loadEffect(xmlFile, key, id, self);
	
					if effectsToLoad ~= nil then
						local effects = {};
						effects.effects = effectsToLoad;
	
						local operatingInterval = Utils.getNoNil(getXMLFloat(xmlFile, key.."#operatingIntervalSeconds"), 0);
						local fillTypesStr = getXMLString(xmlFile, key.."#fillTypes"); -- Using 'fillTypes' with 'operatingIntervalSeconds' cycles through the fillTypes at each interval change.
						if operatingInterval > 0 and fillTypesStr ~= nil then		   -- Good for a mixing effect where you would add a little of each product as you mix, one at a time ;-)	
							effects.fillTypes = {};
							local splitFillTypes = Utils.splitString(" ", fillTypesStr);
							for _, fTypeStr in pairs(splitFillTypes) do
							
								local fillType = g_fillTypeManager.nameToIndex[fTypeStr]
								if fillType ~= nil then
									table.insert(effects.fillTypes, fillType);
								end;
							end;
							effects.numFillTypes = #effects.fillTypes;
							effects.nextFillType = 1;
	
							if next(effects.fillTypes) == nil then
								effects.fillTypes = nil;
							end;
						end;
	
						if effects.fillTypes == nil then
							local fillTypeStr = getXMLString(xmlFile, key.."#fillType"); -- Single product to use for the effect.
							local fillType = g_fillTypeManager.nameToIndex[fillTypeStr] 
							if fillType ~= nil then
								effects.fillType = fillType;
							else
								effects.fillType = 1; -- Keep 'wheat' as a backup in case nothing is listed..
							end;
						end;
	
						if operatingInterval > 0 then
							local delayStart = Utils.getNoNil(getXMLBool(xmlFile, key.."#delayedStart"), false);
							local operatingTime = 0;
							if delayStart then
								operatingTime = operatingInterval * 1000;
							end;
	
							effects.operatingInterval = operatingInterval * 1000;
							effects.operatingTime = operatingTime;
							effects.active = false;
							effects.delayTime = operatingTime;
	
							if self.intervalEffects == nil then
								self.intervalEffects = {};
							end;
	
							table.insert(self.intervalEffects, effects);
						else
							if self.standardEffects == nil then
								self.standardEffects = {};
							end;
	
							table.insert(self.standardEffects, effects);
						end;
	
						loaded = true;
						self.disableEffects = false;
					end;
					i = i + 1;
				end;
			end;
			
			if hasXMLProperty(xmlFile, baseKey..".materials") then
				local filename = getXMLString(xmlFile, baseKey..".materials#filename");
				matFile = Utils.getFilename(filename, g_currentMission.baseDirectory);
				local rootNodeFile = loadI3DFile(matFile, true, true, false);	
				
				self.materials = {};
				local i=0;
				while true do
					local key = string.format("%s.materials.material(%d)", baseKey, i);
					if not hasXMLProperty(xmlFile, key) then
						break;
					end;
					local index = getXMLInt(xmlFile, key.."#index");
					local fillTypeA = getXMLString(xmlFile, key.."#fillType");
					
					if index ~= nil and fillTypeA ~= nil then					
						local fillType = g_fillTypeManager.nameToIndex[fillTypeA] ;
						if fillType ~= nil then
							local obj = getChildAt(rootNodeFile, index);
							if self.materials[fillType] == nil then
								self.materials[fillType] = getMaterial(obj, 0);
							else
								Debug.writeBlock(debugIndex, Debug.ERROR, Debug.TEXT, "ParticleEffects: Material already exist for %s in %s", fillTypeA, getName(id));
							end;
						else
							Debug.writeBlock(debugIndex, Debug.ERROR, Debug.TEXT, "ParticleEffects: Invalid fillType %s in %s", fillTypeA, getName(id));
						end
					else
						Debug.writeBlock(debugIndex, Debug.ERROR, Debug.TEXT, "ParticleEffects: Index or fillType is nil in %s", getName(id));
					end;					
					
					i = i + 1;
				end;
			end;
			
			if self.intervalNodeEffects ~= nil or self.intervalEffects ~= nil then
				g_company.addUpdateable(self, self.update); -- Add this here so we only use the update loop when needed.
			end;
		end;
	else
		loaded = true;
	end;

	return loaded;
end;

function GC_ParticleEffects:delete()
	if self.isClient then

		if self.standardNodeEffects ~= nil then
			ParticleUtil.deleteParticleSystems(self.standardNodeEffects);
		end;

		if self.intervalNodeEffects ~= nil then
			ParticleUtil.deleteParticleSystems(self.intervalNodeEffects);
		end;
		
		if self.standardEffects ~= nil then
			for _, effects in pairs (self.standardEffects) do
				EffectManager:deleteEffects(effects.effects);
			end;
		end;

		if self.intervalEffects ~= nil then
			for _, effects in pairs (self.intervalEffects) do
				EffectManager:deleteEffects(effects.effects);
			end;
		end;
	
		if self.intervalNodeEffects ~= nil or self.intervalEffects ~= nil then
			g_company.removeUpdateable(self);
		end;
	end;
end;

function GC_ParticleEffects:update(dt)
	if self.isClient then

		-- If using Interval.
		if self.effectsRunning then
			if self.intervalNodeEffects ~= nil then
				for _, nodeEffect in pairs (self.intervalNodeEffects) do
					nodeEffect.operatingTime = nodeEffect.operatingTime - dt;
					if nodeEffect.operatingTime <= 0 then
						nodeEffect.operatingTime = nodeEffect.operatingTime + nodeEffect.operatingInterval;
						ParticleUtil.setEmittingState(nodeEffect, not nodeEffect.isEmitting);
					end;
				end;
				if not self.disableNodeEffects  then
					self.disableNodeEffects = true;
				end;
			end;

			if self.intervalEffects ~= nil then
				for _, effects in pairs (self.intervalEffects) do
					effects.operatingTime = effects.operatingTime - dt;
					if effects.operatingTime <= 0 then
						effects.operatingTime = effects.operatingTime + effects.operatingInterval;
						if effects.active then
							effects.active = false;
							EffectManager:stopEffects(effects.effects);
						else
							effects.active = true;
							if effects.fillTypes ~= nil then
								EffectManager:setFillType(effects.effects, effects.fillTypes[effects.nextFillType]);
								EffectManager:startEffects(effects.effects);

								if effects.nextFillType + 1 <= effects.numFillTypes then
									effects.nextFillType = effects.nextFillType + 1;
								else
									effects.nextFillType = 1;
								end;
							else
								EffectManager:setFillType(effects.effects, effects.fillType);
								EffectManager:startEffects(effects.effects);
							end;
						end;
					end;
				end;
				if not self.disableEffects  then
					self.disableEffects = true;
				end;
			end;

		else

			if self.intervalNodeEffects ~= nil then
				if self.disableNodeEffects then
					self.disableNodeEffects = false;
					for _, nodeEffect in pairs (self.intervalNodeEffects) do
						ParticleUtil.setEmittingState(nodeEffect, false);
						nodeEffect.operatingTime = nodeEffect.delayTime;
						nodeEffect.active = false;
					end;
				end;
			end;

			if self.intervalEffects ~= nil then
				if self.disableEffects then
					self.disableEffects = false;
					for _, effects in pairs (self.intervalEffects) do
						EffectManager:stopEffects(effects.effects);
						effects.operatingTime = effects.delayTime;
						effects.active = false;
					end;
				end;
			end;
		end;
	end;
end;

function GC_ParticleEffects:setEffectsState(forceActive)
	if forceActive ~= nil then
		self.effectsRunning = forceActive;
	else
		self.effectsRunning = not self.effectsRunning;
	end;

	-- Standard Updates On / Off.
	if self.isClient then
		if self.standardNodeEffects ~= nil then
			for _, nodeEffect in pairs (self.standardNodeEffects) do
				if self.effectsRunning then
					ParticleUtil.setEmittingState(nodeEffect, true);
				else
					ParticleUtil.setEmittingState(nodeEffect, false);
				end;
			end;
		end;
	
		if self.standardEffects ~= nil then
			for _, effects in pairs (self.standardEffects) do
				if self.effectsRunning then
					EffectManager:setFillType(effects.effects, effects.fillType);
					EffectManager:startEffects(effects.effects);
				else
					EffectManager:stopEffects(effects.effects);
				end;
			end;
		end;
	end;
end;

function GC_ParticleEffects:getEffectsActive()
	return self.effectsRunning;
end;

function GC_ParticleEffects:setMaterialToPS(fillType)	
	if self.materials[fillType] == nil then
		Debug.write(debugIndex, Debug.ERROR, "Material not exist for fillType %s", fillType);
		return;
	end;
	
	if self.standardNodeEffects ~= nil then
		for _, nodeEffect in pairs (self.standardNodeEffects) do
			setMaterial(nodeEffect.shape, self.materials[fillType], 0);
		end;
	end;
	
	if self.standardEffects ~= nil then
		for _, effects in pairs (self.standardEffects) do
			setMaterial(nodeEffect.shape, self.materials[fillType], 0);
		end;
	end;	
end;




