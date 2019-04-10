--
-- GlobalCompany - Objects - GC_AnimationManager
--
-- @Interface: --
-- @Author: LS-Modcompany
-- @Date: 02.01.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (02.01.2019):
-- 		- initial fs19 (Giants, GtX, kevink98)
--		- Original code by 'Giants GMBH' from AnimatedVehicle.lua
--		- https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=70&class=8762
--		- Adapted for use with Global Company. All Rights Giants GMBH.
--
-- Notes:
--		- Parent script 'MUST' call delete()
--
--		- Optional target functions.
--			- animationStartedPlaying(animationName)
--			- animationFinishedPlaying(animationName)
--
--
-- ToDo:
--		- Save game support need testing or we remove it??!!
--
--

GC_AnimationManager = {};

local GC_AnimationManager_mt = Class(GC_AnimationManager, Object);
InitObjectClass(GC_AnimationManager, "GC_AnimationManager");

GC_AnimationManager.debugIndex = g_company.debug:registerScriptName("GC_AnimationManager");

g_company.animationManager = GC_AnimationManager;

function GC_AnimationManager:new(isServer, isClient, customMt)
	local self = Object:new(isServer, isClient, customMt or GC_AnimationManager_mt);

	self.animations = {};
	self.animationNameToId = {};
	self.animationIdToName = {};
	self.numLoadedAnimations = 0;

	self.activeAnimations = {};
	self.numActiveAnimations = 0;

	return self;
end;

function GC_AnimationManager:load(nodeId, target, xmlFile, xmlKey, allowLooping, baseDirectory)
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' parameter = %s, 'target' parameter = %s 'xmlFile' parameter = %s, 'xmlKey' parameter = %s";
		g_company.debug:logWrite(GC_AnimationManager.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil);
		return false;
	end;

	self.rootNode = nodeId;
	self.target = target;

	self.debugData = g_company.debug:getDebugData(GC_AnimationManager.debugIndex, target);
	
	self.baseDirectory = GlobalCompanyUtils.getParentBaseDirectory(target, baseDirectory);

	if allowLooping == nil then
		allowLooping = true;
	end;

	local i = 0;
	while true do
		local key = string.format("%s.registerAnimations.animation(%d)", xmlKey, i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;

		local animation = {};
		if self:loadAnimation(xmlFile, key, animation, allowLooping) then
			self.numLoadedAnimations = self.numLoadedAnimations + 1;
			
			animation.id = self.numLoadedAnimations;
			self.animations[animation.name] = animation;

			self.animationNameToId[animation.name] = animation.id;
			self.animationIdToName[animation.id] = animation.name;
		end;

		i = i + 1;
	end;

	if self.numLoadedAnimations > 0 then
		for name, animation in pairs(self.animations) do
			if animation.resetOnStart then
				self:playAnimation(name, -1, nil, true);
				self:updateAnimationByName(name, 9999999, false);
			end;
		end;

		return true;
	end;

	return false;
end;

function GC_AnimationManager:loadAnimation(xmlFile, key, animation, allowLooping)
	local name = getXMLString(xmlFile, key .. "#name");
	if name ~= nil and self.animations[name] == nil then
		animation.name = name;
		animation.parts = {};
		animation.currentTime = 0;
		animation.currentSpeed = 1;
		local looping = false;
		if allowLooping then
			looping = Utils.getNoNil(getXMLBool(xmlFile, key .. "#looping"), false);
		end;
		animation.looping = looping;
		animation.resetOnStart = Utils.getNoNil(getXMLBool(xmlFile, key .. "#resetOnStart"), true);

		local partI = 0;
		while true do
			local partKey = string.format("%s.part(%d)", key, partI)
			if not hasXMLProperty(xmlFile, partKey) then
				break;
			end;

			local animationPart = {};
			if self:loadAnimationPart(xmlFile, partKey, animationPart) then
				table.insert(animation.parts, animationPart);
			end;

			partI = partI + 1;
		end;
		table.sort(animation.parts, GC_AnimationManager.animPartSorter);

		animation.partsReverse = {};
		for _, part in ipairs(animation.parts) do
			table.insert(animation.partsReverse, part);
		end;
		table.sort(animation.partsReverse, GC_AnimationManager.animPartSorterReverse);

		self:initializeAnimationParts(animation);

		animation.currentPartIndex = 1;
		animation.duration = 0;

		for i = 1, #animation.parts do
			local part = animation.parts[i];
			animation.duration = math.max(animation.duration, part.startTime + part.duration);
		end;

		if self.isClient then
			-- Allow custom AudioGroup. Needs testing.
			local audioGroup = getXMLString(xmlFile, key .. ".sound#audioGroup");
			if audioGroup ~= nil and (audioGroup == "VEHICLE" or audioGroup == "ENVIRONMENT") then
				audioGroupType = audioGroup;
			else
				audioGroupType = "ENVIRONMENT";
			end;
			animation.sample = g_soundManager:loadSampleFromXML(xmlFile, key, "sound", self.baseDirectory, self.rootNode, 0, AudioGroup[audioGroupType], self.target.i3dMappings, self);
		end;

		return true;
	else
		if name == nil then
			g_company.debug:writeModding(self.debugData, "Failed to load animation! No name has been given. ( %s )", key);
		else
			g_company.debug:writeModding(self.debugData, "Failed to load animation '%s'! Name is already in use. ( %s )", name, key);
		end;
	end;

	return false;
end;

function GC_AnimationManager:loadAnimationPart(xmlFile, partKey, part)
	local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, partKey .. "#node"), self.target.i3dMappings);
	local startTime = getXMLFloat(xmlFile, partKey .. "#startTime");
	local duration = getXMLFloat(xmlFile, partKey .. "#duration");
	local endTime = getXMLFloat(xmlFile, partKey .. "#endTime");

	if node ~= nil and (startTime ~= nil and (duration ~= nil or endTime ~= nil)) then
		local direction = MathUtil.sign(Utils.getNoNil(getXMLInt(xmlFile, partKey .. "#direction"), 0));
		
		local startRot = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, partKey .. "#startRot", 3, true, self.debugData);
		local endRot = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, partKey .. "#endRot", 3, true, self.debugData);
		local startTrans = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, partKey .. "#startTrans", 3, false, self.debugData);
		local endTrans = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, partKey .. "#endTrans", 3, false, self.debugData);
		local startScale = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, partKey .. "#startScale", 3, false, self.debugData);
		local endScale = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, partKey .. "#endScale", 3, false, self.debugData);		
		local visibility = getXMLBool(xmlFile, partKey .. "#visibility");
		local shaderParameter = getXMLString(xmlFile, partKey .. "#shaderParameter");		
		local shaderStartValues = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, partKey .. "#shaderStartValues", 4, false, self.debugData);
		local shaderEndValues = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, partKey .. "#shaderEndValues", 4, false, self.debugData);
		local animationClip = getXMLString(xmlFile, partKey .. "#animationClip");
		local clipStartTime = getXMLFloat(xmlFile, partKey .. "#clipStartTime");
		local clipEndTime = getXMLFloat(xmlFile, partKey .. "#clipEndTime");

		if endTime ~= nil then
			duration = endTime - startTime;
		end;

		part.node = node;
		part.startTime = startTime * 1000;
		part.duration = duration * 1000;
		part.direction = direction;

		if endTrans ~= nil then
			part.startTrans = startTrans;
			part.endTrans = endTrans;
		end;

		if endRot ~= nil then
			part.startRot = startRot;
			part.endRot = endRot;
		end;

		if endScale ~= nil then
			part.startScale = startScale;
			part.endScale = endScale;
		end;

		part.visibility = visibility;

		if shaderParameter ~= nil and shaderEndValues ~= nil and shaderStartValues ~= nil then
			if getHasClassId(node, ClassIds.SHAPE) and getHasShaderParameter(node, shaderParameter) then
				part.shaderParameter = shaderParameter;
				part.shaderStartValues = shaderStartValues;
				part.shaderEndValues = shaderEndValues;
			else
				g_company.debug:writeModding(self.debugData, "Node '%s' has no shaderParameter '%s' for animation part '%s'!", getName(node), shaderParameter, partKey);
			end;
		end;

		if animationClip ~= nil and clipStartTime ~= nil and clipEndTime ~= nil then
			part.animationClip = animationClip;
			part.animationCharSet = getAnimCharacterSet(node);
			part.animationClipIndex = getAnimClipIndex(part.animationCharSet, animationClip);
			part.clipStartTime = clipStartTime;
			part.clipEndTime = clipEndTime;
		end;

		return true;
	end;

	return false
end

function GC_AnimationManager:initializeAnimationParts(animation)
	local numParts = #animation.parts;

	for i = 1, numParts do
		local part = animation.parts[i];

		self:initializeAnimationPart(animation, part, i + 1, numParts, "nextRotPart",    "prevRotPart",    "startRot",          "endRot",          "rotation");
		self:initializeAnimationPart(animation, part, i + 1, numParts, "nextTransPart",  "prevTransPart",  "startTrans",        "endTrans",        "translation");
		self:initializeAnimationPart(animation, part, i + 1, numParts, "nextScalePart",  "prevScalePart",  "startScale",        "endScale",        "scale");
		self:initializeAnimationPart(animation, part, i + 1, numParts, "nextShaderPart", "prevShaderPart", "shaderStartValues", "shaderEndValues", "shaderParameter");
		self:initializeAnimationPart(animation, part, i + 1, numParts, "nextClipPart",   "prevClipPart",   "clipStartTime",     "clipEndTime",     "animation clip");

		if part.endTrans ~= nil and part.startTrans == nil then
			local tx, ty, tz = getTranslation(part.node);
			part.startTrans = {tx, ty, tz};
		end;
		
		if part.endRot ~= nil and part.startRot == nil then
			local rx, ry, rz = getRotation(part.node);
			part.startRot = {rx, ry, rz};
		end;

		if part.endScale ~= nil and part.startScale == nil then
			local sx, sy, sz = getScale(part.node);
			part.startScale = {sx, sy, sz};
		end;
	end;
end;

function GC_AnimationManager:initializeAnimationPart(animation, part, i, numParts, nextName, prevName, startName, endName, warningName)
	if part[endName] ~= nil then
		for j = i, numParts do
			local part2 = animation.parts[j];
			if part.direction == part2.direction and part.node == part2.node and part2[endName] ~= nil then
				if part.direction == part2.direction and part.startTime + part.duration > part2.startTime + 0.001 then
					g_company.debug:writeModding(self.debugData, "Overlapping %s parts for node '%s' in animation '%s'", warningName, getName(part.node), animation.name);
				end;

				part[nextName] = part2;
				part2[prevName] = part;

				if part2[startName] == nil then
					part2[startName] = {unpack(part[endName])};
				end;

				break;
			end;
		end;
	end;
end;

function GC_AnimationManager:delete()
	for name, animation in pairs(self.animations) do
		if self.isClient then
			g_soundManager:deleteSample(animation.sample)
		end
	end

	GC_AnimationManager:superClass().delete(self);
end

function GC_AnimationManager:update(dt)
	self:updateAnimations(dt);
	if self.numActiveAnimations > 0 then
		self:raiseActive();
	end;
end;

function GC_AnimationManager:playAnimation(name, speed, animTime, noEventSend)
	local animation = self.animations[name];
	if animation ~= nil then
		if speed == nil then
			speed = animation.currentSpeed;
		end;

		-- skip animation if speed is not set or 0 to allow skipping animations per xml speed attribute set to 0
		if speed == nil or speed == 0 then
			return;
		end;
		
		if animation.looping then
			speed = math.abs(speed); -- Looping should be > only.
		end;

		if animTime == nil then
			if self:getIsAnimationPlaying(name) then
				animTime = self:getAnimationTime(name);
			elseif speed > 0 then
				animTime = 0;
			else
				animTime = 1;
			end;
		end;

		if true or noEventSend == nil or noEventSend == false then
			local animationId = self.animationNameToId[name];
			if g_server ~= nil then
				g_server:broadcastEvent(GC_AnimationManagerStartEvent:new(self, animationId, speed, animTime), nil, nil, self);
			else
				g_client:getServerConnection():sendEvent(GC_AnimationManagerStartEvent:new(self, animationId, speed, animTime));
			end;
		end;

		if self.activeAnimations[name] == nil then
			self.activeAnimations[name] = animation;
			self.numActiveAnimations = self.numActiveAnimations + 1;
			
			GC_AnimationManager.raiseTargetFunction(self, "animationStartedPlaying", name);
		end;

		animation.currentSpeed = speed;
		animation.currentTime = animTime * animation.duration;
		self:resetAnimationValues(animation);

		if self.isClient then
			g_soundManager:playSample(animation.sample);
		end;

		self:raiseActive();
	end;
end;

function GC_AnimationManager:stopAnimation(name, noEventSend)
	if noEventSend == nil or noEventSend == false then
		local animationId = self.animationNameToId[name];
		if g_server ~= nil then
			g_server:broadcastEvent(GC_AnimationManagerStopEvent:new(self, animationId), nil, nil, self);
		else
			g_client:getServerConnection():sendEvent(GC_AnimationManagerStopEvent:new(self, animationId));
		end;
	end;

	local animation = self.animations[name];
	if animation ~= nil then
		animation.stopTime = nil;

		if self.isClient then
			g_soundManager:stopSample(animation.sample);
		end;
	end;
	if self.activeAnimations[name] ~= nil then
		self.numActiveAnimations = self.numActiveAnimations - 1;
		self.activeAnimations[name] = nil;

		GC_AnimationManager.raiseTargetFunction(self, "animationFinishedPlaying", name);
	end;
end;

function GC_AnimationManager:setAnimationByState(name, state, noEventSend)
	local animation = self.animations[name];
	if animation ~= nil then	
		if animation.looping then
			if state then
				self:playAnimation(name, 1, nil, noEventSend);
			else
				self:stopAnimation(name, noEventSend);
			end;
		else
			if state then
				self:playAnimation(name, 1, nil, noEventSend);
			else
				self:playAnimation(name, -1, nil, noEventSend);
			end;
		end;
	end;
end;

function GC_AnimationManager:getAnimationExists(name)
	return self.animations[name] ~= nil;
end;

function GC_AnimationManager:getIsAnimationPlaying(name)
	return self.activeAnimations[name] ~= nil;
end;

function GC_AnimationManager:getRealAnimationTime(name)
	local animation = self.animations[name];
	if animation ~= nil then
		return animation.currentTime;
	end;

	return 0;
end;

function GC_AnimationManager:setRealAnimationTime(name, animTime, update)
	local animation = self.animations[name];
	if animation ~= nil then
		if update == nil or update then
			local currentSpeed = animation.currentSpeed;
			animation.currentSpeed = 1;			
			if animation.currentTime > animTime then
				animation.currentSpeed = -1;
			end;
			
			self:resetAnimationValues(animation);
			
			local dtToUse, _ = self:updateAnimationCurrentTime(animation, 99999999, animTime);			
			self:updateAnimation(animation, dtToUse, false);
			animation.currentSpeed = currentSpeed;
		else
			animation.currentTime = animTime;
		end;
	end;
end;

function GC_AnimationManager:getAnimationTime(name)
	local animation = self.animations[name];
	if animation ~= nil then
		return animation.currentTime / animation.duration;
	end;

	return 0;
end;

function GC_AnimationManager:setAnimationTime(name, animTime, update)
	local animation = self.animations[name];
	if animation ~= nil then
		self:setRealAnimationTime(name, animTime * animation.duration, update);
	end;
end;

function GC_AnimationManager:getAnimationDuration(name)
	local animation = self.animations[name];
	if animation ~= nil then
		return animation.duration;
	end;

	return 1;
end;

function GC_AnimationManager:setAnimationSpeed(name, speed)
	local animation = self.animations[name];
	if animation ~= nil then
		local speedReversed = false;
		if (animation.currentSpeed > 0) ~= (speed > 0) then
			speedReversed = true;
		end;

		animation.currentSpeed = speed;

		if self:getIsAnimationPlaying(name) and speedReversed then
			self:resetAnimationValues(animation);
		end;
	end;
end;

function GC_AnimationManager:setAnimationStopTime(name, stopTime)
	local animation = self.animations[name];
	if animation ~= nil then
		animation.stopTime = stopTime * animation.duration;
	end;
end;

function GC_AnimationManager:resetAnimationValues(animation)
	self:findCurrentPartIndex(animation);
	for _, part in ipairs(animation.parts) do
		self:resetAnimationPartValues(part);
	end;
end;

function GC_AnimationManager:resetAnimationPartValues(part)
	part.curRot = nil;
	part.speedRot = nil;
	part.curTrans = nil;
	part.speedTrans = nil;
	part.curScale = nil;
	part.speedScale = nil;
	part.curVisibility = nil;
	part.shaderCurValues = nil;
	part.curClipTime = nil;
end;

function GC_AnimationManager:getMovedLimitedValue(currentValue, destValue, speed, dt)
	local limitF = math.min;
	if destValue < currentValue then
		limitF = math.max;
	elseif destValue == currentValue then
		return currentValue;
	end

	local ret = limitF(currentValue + speed * dt, destValue);
	return ret;
end;

function GC_AnimationManager:setMovedLimitedValues(minMax, currentValues, destValues, speeds, dt)
	local hasChanged = false
	for i = 1, minMax do
		local newValue = self:getMovedLimitedValue(currentValues[i], destValues[i], speeds[i], dt)
		if currentValues[i] ~= newValue then
			hasChanged = true
			currentValues[i] = newValue
		end
	end

	return hasChanged
end

function GC_AnimationManager:findCurrentPartIndex(animation)
	if animation.currentSpeed > 0 then
		animation.currentPartIndex = table.getn(animation.parts) + 1;
		for i, part in ipairs(animation.parts) do
			if part.startTime+part.duration >= animation.currentTime then
				animation.currentPartIndex = i;
				break;
			end;
		end;
	else
		animation.currentPartIndex = table.getn(animation.partsReverse) + 1;
		for i, part in ipairs(animation.partsReverse) do
			if part.startTime <= animation.currentTime then
				animation.currentPartIndex = i;
				break;
			end;
		end;
	end;
end;

function GC_AnimationManager:getDurationToEndOfPart(part, anim)
	if anim.currentSpeed > 0 then
		return part.startTime + part.duration - anim.currentTime;
	else
		return anim.currentTime - part.startTime;
	end;
end;

function GC_AnimationManager:getNextPartIsPlaying(nextPart, prevPart, anim, default)
	if anim.currentSpeed > 0 then
		if nextPart ~= nil then
			return nextPart.startTime > anim.currentTime;
		end;
	else
		if prevPart ~= nil then
			return prevPart.startTime + prevPart.duration < anim.currentTime;
		end;
	end;

	return default;
end;

function GC_AnimationManager:updateAnimations(dt, allowRestart)
	for _, anim in pairs(self.activeAnimations) do
		local dtToUse, stopAnim = self:updateAnimationCurrentTime(anim, dt, anim.stopTime);
		self:updateAnimation(anim, dtToUse, stopAnim, allowRestart);
	end;
end;

function GC_AnimationManager:updateAnimationByName(animName, dt, allowRestart)
	local animation = self.animations[animName]
	if animation ~= nil then
		local dtToUse, stopAnim = self:updateAnimationCurrentTime(animation, dt, animation.stopTime)
		self:updateAnimation(animation, dtToUse, stopAnim, allowRestart)
	end
end

function GC_AnimationManager:updateAnimationCurrentTime(anim, dt, stopTime)
	anim.currentTime = anim.currentTime + dt * anim.currentSpeed;
	local absSpeed = math.abs(anim.currentSpeed);
	local dtToUse = dt * absSpeed;
	local stopAnim = false;

	if stopTime ~= nil then
		if anim.currentSpeed > 0 then
			if stopTime <= anim.currentTime then
				dtToUse = dtToUse - (anim.currentTime - stopTime);
				anim.currentTime = stopTime;
				stopAnim = true;
			end;
		else
			if stopTime >= anim.currentTime then
				dtToUse = dtToUse - (stopTime - anim.currentTime);
				anim.currentTime = stopTime;
				stopAnim = true;
			end;
		end;
	end;

	return dtToUse, stopAnim;
end;

function GC_AnimationManager:updateAnimation(anim, dtToUse, stopAnim, allowRestart)
	local numParts = table.getn(anim.parts)
	local parts = anim.parts;

	if anim.currentSpeed < 0 then
		parts = anim.partsReverse;
	end;

	if dtToUse > 0 then
		local hasChanged = false;
		local nothingToChangeYet = false;
		for partI=anim.currentPartIndex, numParts do
			local part = parts[partI];
			local isInRange = true;

			if (part.direction == 0 or ((part.direction > 0) == (anim.currentSpeed >= 0))) and isInRange then
				local durationToEnd = self:getDurationToEndOfPart(part, anim);
				if durationToEnd > part.duration then
					nothingToChangeYet = true;
					break;
				end;

				local realDt = dtToUse;
				if anim.currentSpeed > 0 then
					local startT = anim.currentTime - dtToUse;
					if startT < part.startTime then
						realDt = dtToUse - part.startTime + startT;
					end;
				else
					local startT = anim.currentTime+dtToUse;
					local endTime = part.startTime + part.duration;
					if startT > endTime then
						realDt = dtToUse - (startT - endTime);
					end;
				end;

				durationToEnd = durationToEnd + realDt;

				if self:updateAnimationPart(anim, part, durationToEnd, dtToUse, realDt) then
					hasChanged = true;
				end;
			end;

			if partI == anim.currentPartIndex then
				if (anim.currentSpeed > 0 and part.startTime + part.duration < anim.currentTime) or
				   (anim.currentSpeed <= 0 and part.startTime > anim.currentTime)
				then
					self:resetAnimationPartValues(part);
					anim.currentPartIndex = anim.currentPartIndex + 1;
				end;
			end;
		end;
		if not nothingToChangeYet and not hasChanged and anim.currentPartIndex >= numParts then
			if anim.currentSpeed > 0 then
				anim.currentTime = anim.duration;
			else
				anim.currentTime = 0;
			end;
			stopAnim = true;
		end;
	end;

	if stopAnim or anim.currentPartIndex > numParts or anim.currentPartIndex < 1 then
		if not stopAnim then
			if anim.currentSpeed > 0 then
				anim.currentTime = anim.duration;
			else
				anim.currentTime = 0;
			end;
		end;
		
		anim.currentTime = math.min(math.max(anim.currentTime, 0), anim.duration);
		anim.stopTime = nil;
		
		if self.activeAnimations[anim.name] ~= nil then
			self.numActiveAnimations = self.numActiveAnimations - 1;
			
			if self.isClient then
				g_soundManager:stopSample(self.activeAnimations[anim.name].sample);
			end;
			
			self.activeAnimations[anim.name] = nil;

			-- Not sure if we should ignore this when looping??
			GC_AnimationManager.raiseTargetFunction(self, "animationFinishedPlaying", anim.name);
		end;
		
		if allowRestart == nil or allowRestart then
			if anim.looping then
				-- restart animation
				local factor = 0; -- 1
				self:setAnimationTime(anim.name, math.abs((anim.duration - anim.currentTime) - factor), true);
				self:playAnimation(anim.name, anim.currentSpeed, nil, true);
			end;
		end;
	end;
end;

function GC_AnimationManager:updateAnimationPart(animation, part, durationToEnd, dtToUse, realDt)
	local hasPartChanged = false;

	if part.startRot ~= nil and (durationToEnd > 0 or self:getNextPartIsPlaying(part.nextRotPart, part.prevRotPart, animation, true)) then
		local destRot = part.endRot;
		if animation.currentSpeed < 0 then
			destRot = part.startRot;
		end;

		if part.curRot == nil then
			local x, y, z = getRotation(part.node);
			part.curRot = {x, y, z};
			local invDuration = 1.0 / math.max(durationToEnd, 0.001);
			part.speedRot = {(destRot[1]-x) * invDuration, (destRot[2] - y) * invDuration, (destRot[3] - z) * invDuration};
		end;

		if self:setMovedLimitedValues(3, part.curRot, destRot, part.speedRot, realDt) then
			setRotation(part.node, part.curRot[1], part.curRot[2], part.curRot[3]);
			hasPartChanged = true;
		end;
	end;

	if part.startTrans ~= nil and (durationToEnd > 0 or self:getNextPartIsPlaying(part.nextTransPart, part.prevTransPart, animation, true)) then
		local destTrans = part.endTrans;
		if animation.currentSpeed < 0 then
			destTrans = part.startTrans;
		end;

		if part.curTrans == nil then
			local x, y, z = getTranslation(part.node);
			part.curTrans = {x, y, z};
			local invDuration = 1.0 / math.max(durationToEnd, 0.001);
			part.speedTrans = {(destTrans[1] - x) * invDuration, (destTrans[2] - y) * invDuration, (destTrans[3] - z) * invDuration};
		end;

		if self:setMovedLimitedValues(3, part.curTrans, destTrans, part.speedTrans, realDt) then
			setTranslation(part.node, part.curTrans[1], part.curTrans[2], part.curTrans[3]);
			hasPartChanged = true;
		end;
	end;

	if part.startScale ~= nil and (durationToEnd > 0 or self:getNextPartIsPlaying(part.nextScalePart, part.prevScalePart, animation, true)) then
		local destScale = part.endScale;
		if animation.currentSpeed < 0 then
			destScale = part.startScale;
		end;

		if part.curScale == nil then
			local x, y, z = getScale(part.node);
			part.curScale = {x, y, z};
			local invDuration = 1.0 / math.max(durationToEnd, 0.001);
			part.speedScale = {(destScale[1] - x) * invDuration, (destScale[2] - y) * invDuration, (destScale[3] - z) * invDuration};
		end;

		if self:setMovedLimitedValues(3, part.curScale, destScale, part.speedScale, realDt) then
			setScale(part.node, part.curScale[1], part.curScale[2], part.curScale[3]);
			hasPartChanged = true;
		end;
	end;

	if part.shaderParameter ~= nil and (durationToEnd > 0 or self:getNextPartIsPlaying(part.nextShaderPart, part.prevShaderPart, animation, true)) then
		local destValues = part.shaderEndValues;
		if animation.currentSpeed < 0 then
			destValues = part.shaderStartValues;
		end;

		if part.shaderCurValues == nil then
			local x, y, z, w = getShaderParameter(part.node, part.shaderParameter);
			part.shaderCurValues = {x, y, z, w}
			local invDuration = 1.0 / math.max(durationToEnd, 0.001);
			part.speedShader = {(destValues[1] - x) * invDuration, (destValues[2] - y) * invDuration, (destValues[3] - z) * invDuration, (destValues[4] - w) * invDuration};
		end;

		if self:setMovedLimitedValues(4, part.shaderCurValues, destValues, part.speedShader, realDt) then
			setShaderParameter(part.node, part.shaderParameter, part.shaderCurValues[1], part.shaderCurValues[2], part.shaderCurValues[3], part.shaderCurValues[4], false);
			hasPartChanged = true;
		end;
	end;

	if part.animationClip ~= nil and (durationToEnd > 0 or self:getNextPartIsPlaying(part.nextClipPart, part.prevClipPart, animation, true)) then
		local destValue = part.clipEndTime;
		if animation.currentSpeed < 0 then
			destValue = part.clipStartTime;
		end;

		local forceUpdate = false;
		if part.curClipTime == nil then
			local oldClipIndex = getAnimTrackAssignedClip(part.animationCharSet, 0);
			clearAnimTrackClip(part.animationCharSet, 0);
			assignAnimTrackClip(part.animationCharSet, 0, part.animationClipIndex);
			part.curClipTime = part.clipStartTime;

			if oldClipIndex == part.animationClipIndex then
				part.curClipTime = getAnimTrackTime(part.animationCharSet, 0);
			end;

			local invDuration = 1.0 / math.max(durationToEnd, 0.001);
			part.speedClip = (destValue-part.curClipTime)*invDuration;
			forceUpdate = true;
		end;

		local newTime = self:getMovedLimitedValue(part.curClipTime, destValue, part.speedClip, realDt);
		if newTime ~= part.curClipTime or forceUpdate then
			part.curClipTime = newTime;
			enableAnimTrack(part.animationCharSet, 0);
			setAnimTrackTime(part.animationCharSet, 0, newTime, true);
			disableAnimTrack(part.animationCharSet, 0);
			hasPartChanged = true
		end;
	end;

	if part.visibility ~= nil then
		if part.curVisibility == nil then
			part.curVisibility = getVisibility(part.node);
		end;

		if part.visibility ~= part.curVisibility then
			part.curVisibility = part.visibility;
			setVisibility(part.node, part.visibility);
			hasPartChanged = true;
		end;
	end;

	return hasPartChanged;
end;

function GC_AnimationManager:getNumOfActiveAnimations()
	return self.numActiveAnimations;
end;

function GC_AnimationManager:getAnimationName(id)
	return self.animationIdToName[id];
end;

function GC_AnimationManager:getAnimationId(name)
	return self.animationNameToId[name];
end;

function GC_AnimationManager:loadFromXMLFile(xmlFile, key) -- Need Testing!!
	for name, animation in pairs (self.animations) do		
		if not animation.resetOnStart then
			local animationKey = string.format("%s.animations.%s", key, name);
			local animTime = getXMLFloat(xmlFile, animationKey .. "#animTime");
			local speed = Utils.getNoNil(getXMLFloat(xmlFile, animationKey .. "#currentSpeed"), animation.currentSpeed);
			
			if animTime ~= nil then
				self:playAnimation(name, speed, nil, true);
				self:setAnimationTime(name, animTime);
			end;
		end;
	end;
	
	return true
end;

function GC_AnimationManager:saveToXMLFile(xmlFile, key, usedModNames) -- Need Testing!!
	for name, animation in pairs (self.animations) do
		-- Do not think we need to save these if we reset anyway.
		if not animation.resetOnStart then
			local animationKey = string.format("%s.animations.%s", key, name);
			setXMLFloat(xmlFile, animationKey .. "#animTime", animation.currentTime / animation.duration);
			setXMLFloat(xmlFile, animationKey .. "#currentSpeed", animation.currentSpeed);
		end;
	end;	
end;

function GC_AnimationManager.animPartSorter(a, b)
	if a.startTime < b.startTime then
		return true;
	elseif a.startTime == b.startTime then
		return a.duration < b.duration;
	end;

	return false;
end;

function GC_AnimationManager.animPartSorterReverse(a, b)
	local endTimeA = a.startTime + a.duration;
	local endTimeB = b.startTime + b.duration;

	if endTimeA > endTimeB then
		return true;
	elseif endTimeA == endTimeB then
		return a.startTime > b.startTime;
	end;

	return false;
end;

function GC_AnimationManager.raiseTargetFunction(self, functionName, animName)
	local target = self.target;	
	if target[functionName] ~= nil then
		target[functionName](target, animName);
	end;
end;

----------------------------------
-- Parent Load Helper Functions --
----------------------------------

function GC_AnimationManager:loadAnimationNameFromXML(xmlFile, xmlKey, warningExtra)
	local animationName = getXMLString(xmlFile, xmlKey .. "#name");
	if self:getAnimationExists(animationName) then
		return animationName;
	else
		if warningExtra == nil then
			warningExtra = "";
		end;

		g_company.debug:writeModding(self.debugData, "%s Unknown animation name '%s' given at %s", warningExtra, animationName, xmlKey);
	end;

	return;
end;

function GC_AnimationManager:loadAnimationNamesFromXML(xmlFile, xmlKey, warningExtra)
	local animationNames = {};

	local i = 0;
	while true do
		local key = string.format("%s(%d)", xmlKey, i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;

		local animationName = getXMLString(xmlFile, key .. "#name");
		if self:getAnimationExists(animationName) then
			table.insert(animationNames, animationName)
		else
			if warningExtra == nil then
				warningExtra = "";
			end;

			g_company.debug:writeModding(self.debugData, "%s Unknown animation name '%s' given at %s", warningExtra, animationName, key);
		end;

		i = i + 1;
	end;

	if #animationNames > 0 then
		return animationNames;
	end;

	return;
end;





