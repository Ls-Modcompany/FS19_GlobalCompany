--
-- GlobalCompany - Objects - GC_ObjectSpawner
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX 
-- @Date: 06.03.2018
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
--
-- 	v1.0.0.0 (06.03.2018):
-- 		- initial fs19 (GtX)
--
--
-- Notes:
--		- This is just a example and there is much to be added including 'ObjectSpawnerManager.lua' for things like baleStorage. ;-)
--
--
-- ToDo:
--		- Maybe add permanent Debug to show areas.
--
--


GC_ObjectSpawner = {};
local GC_ObjectSpawner_mt = Class(GC_ObjectSpawner, Object);
InitObjectClass(GC_ObjectSpawner, "GC_ObjectSpawner");

GC_ObjectSpawner.debugIndex = g_company.debug:registerScriptName("GC_ObjectSpawner");

g_company.objectSpawner = GC_ObjectSpawner;

function GC_ObjectSpawner:new(isServer, isClient, customMt)
	local self = Object:new(isServer, isClient, customMt or GC_ObjectSpawner_mt);

	self.extraParamater = nil;
	self.triggerManagerRegister = true;

	self.spawnAreas = {};

	return self;
end;

function GC_ObjectSpawner:load(nodeId, target, xmlFile, xmlKey, keyName)
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' parameter = %s, 'target' parameter = %s 'xmlFile' parameter = %s, 'xmlKey' parameter = %s";
		g_company.debug:logWrite(GC_ObjectSpawner.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil);
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_ObjectSpawner.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;

	local key = xmlKey .. Utils.getNoNil(keyName, ".objectSpawner");

	local i = 0;
	while true do
		local areaKey = string.format("%s.area(%d)", key, i);
		if not hasXMLProperty(xmlFile, areaKey) then
			break;
		end;

		local startNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, areaKey .. "#startNode"), target.i3dMappings);
		local endNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, areaKey .. "#endNode"), target.i3dMappings);
		if startNode ~= nil and endNode ~= nil then
			local startX, _, _ = getTranslation(startNode);
			local endX, _, _ = getTranslation(endNode);
			if endX > startX then
				table.insert(self.spawnAreas, {startNode = startNode, endNode = endNode});
			else
				DebugPrint("ERROR", "SPACE")
			end;
		else
			DebugPrint("ERROR", "No Nodes")
		end;

		i = i + 1;
	end;

	if #self.spawnAreas > 0 then
		return true;
	end;

	return false;
end;

function GC_ObjectSpawner:getSpaceByObjectInfo(object, maxWanted, ignoreShapesHit)
	local totalFreeAreas = 0;
	if object.width ~= nil and object.length ~= nil then
		local numToCheck = g_company.utils.getLess(255, maxWanted, 255);
	
		for _, spawnArea in ipairs (self.spawnAreas) do
			if totalFreeAreas < numToCheck then
				local freeAreas = self:getSpawnAreaDataBySize(spawnArea, object.width, object.length, object.height, object.offset, numToCheck - totalFreeAreas);
				totalFreeAreas = totalFreeAreas + freeAreas;
			else
				break;
			end;
		end;
	end;

	return totalFreeAreas;
end;

function GC_ObjectSpawner:spawnByObjectInfo(object, numberToSpawn, customOffset, ignoreShapesHit)
	local numSpawned = 0;
	local owner = self:getOwnerFarmId();

	numberToSpawn = g_company.utils.getLess(1, numberToSpawn, 255);
	local wantedCount = numberToSpawn;
	
	if object.filename ~= nil and object.width ~= nil and object.length ~= nil then
		local offset = Utils.getNoNil(customOffset, object.offset);
		
		local spawned = 0;
		local placesToSpawn = {};
		for _, spawnArea in ipairs (self.spawnAreas) do
			if #placesToSpawn < wantedCount then
				spawned = self:getSpawnAreaDataBySize(spawnArea, object.width, object.length, object.height, object.offset, numberToSpawn, placesToSpawn);
				numberToSpawn = numberToSpawn - spawned;
			else
				break;
			end;
		end;

		local freeSpaces = #placesToSpawn;
		if freeSpaces > 0 then
			for i = 1, freeSpaces do
				local spawnPlace = placesToSpawn[i];
				local x, y, z = spawnPlace[1], spawnPlace[2], spawnPlace[3];
				local rx, ry, rz = spawnPlace[4], spawnPlace[5], spawnPlace[6];

				if object.filename ~= nil then
					if object.fillLevel ~= nil then
						if object.isBale == true then
							ry = ry + math.rad(90);
							if object.isRoundBale then
								rx = rx + math.rad(90);
							end;

							local baleObject = Bale:new(self.isServer, self.isClient);
							baleObject:load(object.filename, x, y, z, rx, ry, rz, object.fillLevel);
							baleObject:setOwnerFarmId(owner, true);
							baleObject:register();
							baleObject:setCanBeSold(false); -- This is conflicting through all Giants scripts. Need to test!!!!

							numSpawned = numSpawned + 1;
						else
							local configs = object.configurations;
							local pallet = g_currentMission:loadVehicle(object.filename, x, y, z, 0, ry, true, 0, Vehicle.PROPERTY_STATE_OWNED, owner, configs, nil);
							if pallet ~= nil then
								if object.fillUnitIndex ~= nil and object.fillTypeIndex ~= nil then
									pallet:addFillUnitFillLevel(owner, object.fillUnitIndex, object.fillLevel, object.fillTypeIndex, ToolType.UNDEFINED);
								end;

								numSpawned = numSpawned + 1;
							end;
						end;
					else
						local save = Utils.getNoNil(object.save, true);
						local price = Utils.getNoNil(object.price, 0);
						local propertyState = Utils.getNoNil(object.propertyState, Vehicle.PROPERTY_STATE_OWNED);

						local vehicle = g_currentMission:loadVehicle(objectData.filename, x, y, z, 0, ry, save, price, propertyState, owner, object.configurations, nil);
						if vehicle ~= nil then
							if numberToSpawn > 1 then
								numSpawned = numSpawned + 1;
							else
								return vehicle;
							end;
						end;
					end;
				end;
			end;
		end;
	end;

	return numSpawned;
end;

function GC_ObjectSpawner:getSpawnAreaDataBySize(spawnArea, width, length, height, nextOffset, count, placesToSpawn, ignoreShapesHit)
	local halfWidth = width * 0.5;
	-- local halfLength = length * 0.5;
	-- local halfHeight = height * 0.5;

	local offset = halfWidth + Utils.getNoNil(nextOffset, 0.2);

	local freeSpaces = 0;
	local bitMaskDec = 528895;	
	local usedWidth = 0;
	local spawnerWidth, _, _ = getTranslation(spawnArea.endNode);
	local areaValue = spawnerWidth - halfWidth;
	local rx, ry, rz = getWorldRotation(spawnArea.startNode);

	for i = 1, count do
		if (halfWidth + usedWidth) < areaValue then
			for dirX = halfWidth + usedWidth, areaValue, 0.5 do
				local x, y, z = localToWorld(spawnArea.startNode, dirX, 0, 0);
				local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, y, z) + 0.5;
				y = math.max(terrainHeight, y);
	
				self.areaUsed = false;
				local shapesHit = overlapBox(x, y, z, rx, ry, rz, halfWidth, 10, length, "collisionCallback", self, bitMaskDec, true, false);
				if (ignoreShapesHit == true or shapesHit == 0) and self.areaUsed == false then
					usedWidth = dirX + offset;
					
					freeSpaces = freeSpaces + 1;					
					if placesToSpawn ~= nil then
						table.insert(placesToSpawn, {x, y, z, rx, ry, rz});
					end;
	
					-- DEBUG --
					-- local name = tostring(width) .. "-" .. tostring(length) .. "-" .. tostring(height)
					-- self:debugDraw(x, y, z, rx, ry, rz, halfWidth, halfHeight, halfLength, i, name);

					if i == count then
						return freeSpaces;
					else	
						break;
					end;
				end;
				
				if (dirX + halfWidth) >= areaValue then
					return freeSpaces;
				end;
			end;
		else
			return freeSpaces;
		end;
	end;	

	return freeSpaces;
end;

function GC_ObjectSpawner:collisionCallback(transformId)
	self.areaUsed = g_currentMission.nodeToObject[transformId] ~= nil or g_currentMission.players[transformId] ~= nil;
end;

function GC_ObjectSpawner:debugDraw(x, y, z, rx, ry, rz, ex, ey, ez, id, name, r, g, b)
	r = Utils.getNoNil(r, 0.5);
	g = Utils.getNoNil(g, 1.0);
	b = Utils.getNoNil(b, 0.5);

	DebugUtil.drawOverlapBox(x, y, z, rx, ry, rz, ex, ey, ez, r, g, b);

	if id ~= nil and name ~= nil then
		local text = string.format("Object %s - Group %s", id, name);
		Utils.renderTextAtWorldPosition(x, y, z, text, 0.02, 0);
	end;
end;





