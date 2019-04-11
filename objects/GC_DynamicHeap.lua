--
-- GlobalCompany - Triggers - GC_DynamicHeap
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98 / GtX
-- @Date: 14.01.2019
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.1.0.0 (14.01.2019):
-- 		- convert to fs19 (GtX)
--		- New functions and XML support (GtX / kevink98)
--
-- 	v1.0.0.0 (19.05.2018):
-- 		- initial fs17 (kevink98)
--
-- Notes:
--
--
-- ToDo:
--
--

GC_DynamicHeap = {};

local GC_DynamicHeap_mt = Class(GC_DynamicHeap);
InitObjectClass(GC_DynamicHeap, "GC_DynamicHeap");

GC_DynamicHeap.debugIndex = g_company.debug:registerScriptName("DynamicHeap");

g_company.dynamicHeap = GC_DynamicHeap;

function GC_DynamicHeap:new(isServer, isClient, customMt)
	local self = {};
	setmetatable(self, customMt or GC_DynamicHeap_mt);

	self.isServer = isServer;
	self.isClient = isClient;

	self.triggerManagerRegister = false;

	self.heapArea = nil;
	self.fillTypeIndex = nil;

	self.extraParamater = nil;
	self.vehiclesInRange = nil;
	self.numVehiclesInRange = 0;

	return self;
end;

function GC_DynamicHeap:load(nodeId, target, xmlFile, xmlKey, fillTypeName, fixedFillTypes, isFixedFillTypeArea)
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' parameter = %s, 'target' parameter = %s 'xmlFile' parameter = %s, 'xmlKey' parameter = %s";
		g_company.debug:logWrite(GC_DynamicHeap.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil);
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_DynamicHeap.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;

	-- Take the Parameter first if it is NOT nil.
	local userFillTypeName = getXMLString(xmlFile, xmlKey .. "#fillTypeName");
	local fillTypeNameToUse = fillTypeName or userFillTypeName;
	self.fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeNameToUse);

	if self.fillTypeIndex ~= nil then
		local startNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. "#startNode"), target.i3dMappings);
		local widthNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. "#widthNode"), target.i3dMappings);
		local heightNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. "#heightNode"), target.i3dMappings);
		if startNode ~= nil and widthNode ~= nil and heightNode ~= nil then
			self.heapArea = {start = startNode, width = widthNode, height = heightNode};

			self.accuracy = Utils.getNoNil(getXMLFloat(xmlFile, xmlKey .. "#accuracy"), 0.95);
			self.randomDrop = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. "#useRandomDrop"), false);

			self.isFixedFillTypeArea = Utils.getNoNil(isFixedFillTypeArea, true);
			if self.isFixedFillTypeArea then
				-- Set the fillTypeArea to first fillType.
				local fillTypes = {[self.fillTypeIndex] = true};

				-- If given then also set the fillTypeArea to also allow 'fixedFillTypes'.
				if fixedFillTypes ~= nil then
					for index, _ in pairs (fixedFillTypes) do
						fillTypes[index] = true;
					end;
				end;

				g_densityMapHeightManager:setFixedFillTypesArea(self.heapArea, fillTypes);
			end;

			local vehicleInteractionTrigger = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. "#vehicleInteractionTrigger"), target.i3dMappings);
			if vehicleInteractionTrigger ~= nil then
				if self.target.vehicleChangedHeapLevel ~= nil then
					self.vehicleInteractionTrigger = vehicleInteractionTrigger;
					
					-- Do this now so we can still check these loaded on the client side.
					if self.isServer then
						self.vehiclesInRange = {};						
						addTrigger(self.vehicleInteractionTrigger, "vehicleInteractionTriggerCallback", self);
						g_company.addRaisedUpdateable(self);
					end;
				else
					g_company.debug:writeDev(self.debugData, "'vehicleInteractionTrigger' can not be loaded! Parent script does not contain function 'vehicleChangedHeapLevel(heapLevel, fillTypeIndex, extraParamater)'.");
				end;
			end;

			return true;
		else
			g_company.debug:writeModding(self.debugData, "'startNode' or 'widthNode' or 'heightNode' is not valid at '%s'", key);
		end;
	else
		if fillTypeName ~= nil then
			g_company.debug:writeDev(self.debugData, "Unknown fillType '%s' given at parameter 'fillTypeName'!", fillTypeName);
		else
			g_company.debug:writeModding(self.debugData, "Unknown fillType '%s' given at '%s'", userFillTypeName, key);
		end;
	end;

	return false;
end;

function GC_DynamicHeap:delete()
	if self.isServer then
		if self.vehicleInteractionTrigger ~= nil then
			removeTrigger(self.vehicleInteractionTrigger)
			g_company.removeRaisedUpdateable(self);
			self.vehicleInteractionTrigger = nil;
			self.vehiclesInRange = nil;
		end;
	end;

	if self.isFixedFillTypeArea then
		g_densityMapHeightManager:removeFixedFillTypesArea(self.heapArea);
	end;
end

function GC_DynamicHeap:update(dt)
	if self.isServer then
		for node, fillUnitData in pairs(self.vehiclesInRange) do
			local vehicle = g_currentMission.nodeToObject[node];
			if vehicle ~= nil then
				if vehicle:getIsActive() and vehicle:getFillUnitFillLevel(fillUnitData.fillUnitIndex) ~= fillUnitData.fillLevel then
					fillUnitData.fillLevel = vehicle:getFillUnitFillLevel(fillUnitData.fillUnitIndex);

					local heapLevel = self:getHeapLevel();
					self.target:vehicleChangedHeapLevel(heapLevel, self.fillTypeIndex, self.extraParamater);
				end;
			else
				self.vehiclesInRange[node] = nil;
				self.numVehiclesInRange = self.numVehiclesInRange - 1;
			end;
		end;

		if self.numVehiclesInRange > 0 then
			self:raiseUpdate();
		end;
	end;
end;

function GC_DynamicHeap:setFillTypeIndex(fillTypeIndex)
	if g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex) ~= nil then
		if self:getHeapLevel() <= 0 then
			self.fillTypeIndex = fillTypeIndex;
			return true;
		end;
	end;

	return false;
end;

function GC_DynamicHeap:updateDynamicHeap(delta, isRemoving, forceRandom)
	if isRemoving == true then
		return self:removeFromHeap(delta);
	end;

	return self:addToHeap(delta);
end;

function GC_DynamicHeap:getLineData(add, xs, zs, ux, uz, vx, vz, forceRandom)
	local sx, sz, sy, ex, ez, ey;

	if self.randomDrop or forceRandom == true then
		sx = xs + (math.random()*ux) + (math.random()*vx);
		sz = zs + (math.random()*uz) + (math.random()*vz);
		sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 0, sz);
		ex = xs + (math.random()*ux) + (math.random()*vx);
		ez = zs + (math.random()*uz) + (math.random()*vz);
		ey = sy;
	else
		if add then
			sx = xs + 0.40 * ux + 0.5 * vx;
			sz = zs + 0.40 * uz + 0.5 * vz;
			sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 0, sz) + 10;
			ex = xs + 0.60 * ux + 0.5 * vx;
			ez = zs + 0.60 * uz + 0.5 * vz;
			ey = sy;
		else
			sx = xs + 0.5 * ux + 0.5 * vx;
			sz = zs + 0.5 * uz + 0.5 * vz;
			sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 0, sz) + 10;
			ex = xs + 0.5 * ux + 0.5 * vx;
			ez = zs + 0.5 * uz + 0.5 * vz;
		end;
	end;

	return sx, sz, sy, ex, ez, ey;
end;

function GC_DynamicHeap:addToHeap(delta, forceRandom)
	local droppedLevel, lineOffset = 0, 0;

	if g_densityMapHeightManager:getMinValidLiterValue(self.fillTypeIndex) then
		local xs, _, zs = getWorldTranslation(self.heapArea.start);
		local xw, _, zw = getWorldTranslation(self.heapArea.width);
		local xh, _, zh = getWorldTranslation(self.heapArea.height);
		local ux, uz = xw - xs, zw - zs;
		local vx, vz = xh - xs, zh - zs;

		local vLength = MathUtil.vector2Length(vx, vz);
		local sx, sz, sy, ex, ez, ey = self:getLineData(true, xs, zs, ux, uz, vx, vz, forceRandom);
		droppedLevel, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(nil, delta, self.fillTypeIndex, sx, sy, sz, ex, ey, ez, 0, vLength, self.lineOffset, false, nil);
		self.lineOffset = lineOffset;
	end;

	return droppedLevel;
end;

function GC_DynamicHeap:removeFromHeap(delta, forceRandom)
	local removedLevel = 0;

	if delta <= self:getHeapLevel() then
		removedLevel = delta;
		if g_densityMapHeightManager:getMinValidLiterValue(self.fillTypeIndex) then
			local xs, _, zs = getWorldTranslation(self.heapArea.start);
			local xw, _, zw = getWorldTranslation(self.heapArea.width);
			local xh, _, zh = getWorldTranslation(self.heapArea.height);
			local ux, uz = xw - xs, zw - zs;
			local vx, vz = xh - xs, zh - zs;
			local radius = MathUtil.vector2Length(xw - xh, zw - zh) * 0.5;
			local sx, sz, sy, ex, ez, ey = self:getLineData(false, xs, zs, ux, uz, vx, vz, forceRandom);
			local dropped, _ = DensityMapHeightUtil.tipToGroundAroundLine(nil, -delta, self.fillTypeIndex, sx, sy, sz, ex, ey, ez, radius, radius, nil, false, nil);
			if dropped == 0 then
				removedLevel = 0;
			end;
		end;
	end;

	return removedLevel
end;

function GC_DynamicHeap:getHeapLevel()
	local xs, _, zs = getWorldTranslation(self.heapArea.start);
	local xw, _, zw = getWorldTranslation(self.heapArea.width);
	local xh, _, zh = getWorldTranslation(self.heapArea.height);
	local fillLevel = DensityMapHeightUtil.getFillLevelAtArea(self.fillTypeIndex, xs, zs, xw, zw, xh, zh);

	return fillLevel;
end;

function GC_DynamicHeap:getHeightCenter()
	local xs,_,zs = getWorldTranslation(self.heapArea.start);
	local xw,_,_ = getWorldTranslation(self.heapArea.width);
	local _,_,zh = getWorldTranslation(self.heapArea.height);

	local x = xs - ((xs - xw) / 2);
	local z = zs + ((zh - zs) / 2);

	return DensityMapHeightUtil.getHeightAtWorldPos(x,0,z) - getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x,0,z);
end;

function GC_DynamicHeap:getIsHeapEmpty()
	local xs, _, zs = getWorldTranslation(self.heapArea.start);
	local xw, _, zw = getWorldTranslation(self.heapArea.width);
	local xh, _, zh = getWorldTranslation(self.heapArea.height);

	return DensityMapHeightUtil.getFillTypeAtArea(xs, zs, xw, zw, xh, zh) == FillType.UNKNOWN;
end;

function GC_DynamicHeap:vehicleInteractionTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if onEnter or onLeave then
		local vehicle = g_currentMission.nodeToObject[otherShapeId]
		if vehicle ~= nil and vehicle.setBunkerSiloInteractorCallback ~= nil then
			if onEnter then
				if self.vehiclesInRange[vehicle] == nil then
					for fillUnitIndex, fillUnit in pairs (vehicle.spec_fillUnit.fillUnits) do
						if vehicle:getFillUnitSupportsFillType(fillUnitIndex, self.fillTypeIndex) then
							local fillLevel = vehicle:getFillUnitFillLevel(fillUnitIndex);
							self.vehiclesInRange[otherShapeId] = {fillLevel = fillLevel, fillUnitIndex = fillUnitIndex};
							self.numVehiclesInRange = self.numVehiclesInRange + 1;

							self:raiseUpdate();
							--vehicle:setBunkerSiloInteractorCallback(GC_DynamicHeap.onChangedFillLevelCallback, self);
						end;
					end;
				end;
			else
				if self.vehiclesInRange[otherShapeId] ~= nil then
					self.vehiclesInRange[otherShapeId] = nil;
					self.numVehiclesInRange = self.numVehiclesInRange - 1;

					self:raiseUpdate();
					--vehicle:setBunkerSiloInteractorCallback(nil);
				end;
			end;
		end;
	end;
end;

-- Removed as this is only updated when the shovel is removing!
-- function GC_DynamicHeap.onChangedFillLevelCallback(self, vehicle, fillDelta, fillTypeIndex)
	-- local heapLevel = self:getHeapLevel();
	-- self.target:vehicleChangedHeapLevel(heapLevel, fillTypeIndex, self.extraParamater)
-- end;





