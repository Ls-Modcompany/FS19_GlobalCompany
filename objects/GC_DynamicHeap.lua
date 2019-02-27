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
-- 		- convert to fs19,
--		- add TriggerManager support,
--		- add XML support (GtX)
--
-- 	v1.0.0.0 (19.05.2018):
-- 		- initial fs17 (kevink98)
--
-- Notes:
-- 
--
-- ToDo:
--		- setFixedFillTypesArea??
--


local debugIndex = g_company.debug:registerScriptName("GlobalCompany-DynamicHeap");

GC_DynamicHeap = {};

GC_DynamicHeap_mt = Class(GC_DynamicHeap, Object);
InitObjectClass(GC_DynamicHeap, "GC_DynamicHeap");

g_company.playerTrigger = GC_PlayerTrigger;

function GC_DynamicHeap:new(isServer, isClient, customMt)
    if customMt == nil then
        customMt = GC_DynamicHeap_mt;
    end;
	
    local self = Object:new(isServer, isClient, customMt);
	
	self.isServer = isServer;
	self.isClient = isClient;

	self.triggerManagerRegister = true; -- GC_TriggerManager needs to know if it should register 'object'.	
	
	self.extraParamater = nil;

    return self;
end

function GC_DynamicHeap:load(nodeId, target, xmlFile, xmlKey, fillTypeName, maxHeapLevel)
	if nodeId == nil or target == nil then
		return false;
	end;
	
	self.rootNode = nodeId;
	self.target = target;
	
	--self.targetScriptName = GlobalCompanyUtils.getSplitClassName(target.className);

	if fillTypeName == nil then
		if xmlFile == nil or xmlKey == nil then
			return false;
		end;
		
		fillTypeName = getXMLString(xmlFile, xmlKey .. "#fillTypeName");
	end;
	
	self.fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
	if self.fillTypeIndex ~= nil then	
		local startNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. "#startNode"), target.i3dMappings)
		local widthNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. "#widthNode"), target.i3dMappings)
		local heightNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. "#heightNode"), target.i3dMappings)
		if startNode ~= nil and widthNode ~= nil and heightNode ~= nil then
			self.heapArea = {start = startNode, width = widthNode, height = heightNode}			
			self.accuracy = Utils.getNoNil(getXMLFloat(xmlFile, xmlKey .. "#accuracy"), 0.95);
			
			self.randomDrop = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. "#useRandomDrop"), false);

			if maxHeapLevel == nil then
				maxHeapLevel = getXMLFloat(xmlFile, xmlKey .. "#maxHeapLevel"); -- ?? maybe we can stop vehicles tipping with this... Need more API Docs for the vehicles.
			end;
			self.maxHeapLevel = maxHeapLevel;

			local fillTypes = {};
			fillTypes[self.fillTypeIndex] = true;
			g_densityMapHeightManager:setFixedFillTypesArea(self.heapArea, fillTypes);
			
			if self.isServer then
				self.vehiclesInTrigger = {};
				self.numVehiclesInTrigger = 0;
				
				local vehicleDetectionTriggerNode = getXMLString(xmlFile, xmlKey .. "#vehicleDetectionTriggerNode");
				if vehicleDetectionTriggerNode ~= nil then
					self.vehicleDetectionTriggerNode = I3DUtil.indexToObject(nodeId, vehicleDetectionTriggerNode, target.i3dMappings);
					if self.vehicleDetectionTriggerNode ~= nil then
						if self.target.vehicleChangedHeapLevel ~= nil then
							addTrigger(self.vehicleDetectionTriggerNode, "vehicleDetectionTriggerCallback", self);
						else
							-- Target is missing function.
						end;
					end;
				end;
			end;
		
		else
			return false;
		end;
	else
		return false;
	end;

	-- if self.start ~= nil and self.width ~= nil and self.height ~= nil then	
		-- g_debug.write(debugIndex, g_debug.LOAD, string.format("ExtendedHeap %s loaded", getName(self.id)));	
		-- return true;
	-- else
		-- g_debug.write(debugIndex, g_debug.ERROR, string.format("ExtendedHeap %s index invalid ", getName(self.id)));
		-- return false		
	-- end;	
	
	return true;
end;

function GC_DynamicHeap:delete()
    g_densityMapHeightManager:removeFixedFillTypesArea(self.heapArea);
end

function GC_DynamicHeap:update(dt)
	if self.isServer and self.numVehiclesInTrigger > 0 then
		for vehicle, v in pairs (self.vehiclesInTrigger) do
			if vehicle ~= nil and vehicle:getFillUnitFillLevel(v.fillUnitIndex) ~= v.fillLevel then
				v.fillLevel = vehicle:getFillUnitFillLevel(v.fillUnitIndex);
			
				if self:getHeapLevel() ~= self.lastHeapLevel then
					self.lastHeapLevel = self:getHeapLevel();					
					self.target:vehicleChangedHeapLevel(self.lastHeapLevel, self.fillTypeIndex, self.extraParamater);
				end;
			end;			
		end;
		
		self:raiseActive();
	end;
end;

function GC_DynamicHeap:vehicleDetectionTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
        local vehicle = g_currentMission.nodeToObject[otherShapeId];
        if vehicle ~= nil then
            if onEnter then
				if self.vehiclesInTrigger[vehicle] == nil and vehicle.spec_fillUnit ~= nil then
					for _, fillUnit in pairs (vehicle.spec_fillUnit.fillUnits) do
						if fillUnit.supportedFillTypes ~= nil and fillUnit.supportedFillTypes[self.fillTypeIndex] ~= nil then
							
							--local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName:lower());
							--print(storeItem.name);							
							
							local fillLevel = fillUnit.fillLevel
							local fillUnitIndex = fillUnit.fillUnitIndex
							self.vehiclesInTrigger[vehicle] = {fillUnitIndex = fillUnitIndex, fillLevel = fillLevel};						
							
							self.numVehiclesInTrigger = self.numVehiclesInTrigger + 1;
							self:raiseActive();							
							break;
						end;
					end;
                end;
            else
                if self.vehiclesInTrigger[vehicle] ~= nil then
                    self.vehiclesInTrigger[vehicle] = nil;
                    self.numVehiclesInTrigger = self.numVehiclesInTrigger - 1;
					
					if self.numVehiclesInTrigger <= 0 then
						self.vehiclesInTrigger = {};
					end;
					
					self:raiseActive();
                end;
            end;
        end;		
	end;
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
		sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx,0,sz);
		ex = xs + (math.random()*ux) + (math.random()*vx);
		ez = zs + (math.random()*uz) + (math.random()*vz);
		ey = sy;
	else	
		if add then
			sx = xs + 0.40 * ux + 0.5 * vx;
			sz = zs + 0.40 * uz + 0.5 * vz;
			sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 0, sz) + 10.0;
			ex = xs + 0.60 * ux + 0.5 * vx;
			ez = zs + 0.60 * uz + 0.5 * vz;
			ey = sy;
		else
			sx = xs + 0.5 * ux + 0.5 * vx;
			sz = zs + 0.5 * uz + 0.5 * vz;
			sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx,0,sz) + 10;
			ex = xs + 0.5 * ux + 0.5 * vx;
			ez = zs + 0.5 * uz + 0.5 * vz;
		end;
	end;
	
	return sx, sz, sy, ex, ez, ey;
end;

function GC_DynamicHeap:addToHeap(delta, forceRandom)
    local droppedLevel = 0
    
	if self:getCanAddRemove(delta, self.fillTypeIndex, true) then
        local xs, _, zs = getWorldTranslation(self.heapArea.start);
        local xw, _, zw = getWorldTranslation(self.heapArea.width);
        local xh, _, zh = getWorldTranslation(self.heapArea.height);
        local ux, uz = xw - xs, zw - zs;
        local vx, vz = xh - xs, zh - zs;
		
        local vLength = MathUtil.vector2Length(vx, vz);
        local sx, sz, sy, ex, ez, ey = self:getLineData(true, xs, zs, ux, uz, vx, vz, forceRandom);
        local droppedLevel, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(nil, delta, self.fillTypeIndex, sx, sy, sz, ex, ey, ez, 0, vLength, self.lineOffset, false, nil);
        self.lineOffset = lineOffset;
    end;
    
	return droppedLevel;
end;

function GC_DynamicHeap:removeFromHeap(delta, forceRandom)
	local removedLevel = 0;
	
	if delta <= self:getHeapLevel() then
		removedLevel = delta;
		if self:getCanAddRemove(delta, self.fillTypeIndex, false) then
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

function GC_DynamicHeap:getCanAddRemove(delta, fillTypeIndex, isAdding)
	local allow = delta > g_densityMapHeightManager:getMinValidLiterValue(fillTypeIndex);
	
	if allow and isAdding and self.maxHeapLevel ~= nil then
		allow = self:getHeapLevel() + delta <= self.maxHeapLevel;
	end;

	return allow;
end;

--[[function GC_DynamicHeap:updateDynamicHeap(increase, isRemoving)
	local droppedLvl = 0;
	if isRemoving then
		if not (increase > g_densityMapHeightManager:getMinValidLiterValue(self.fillTypeIndex)) then
			return droppedLvl;
		end;
	end;
	
	local xs,_,zs = getWorldTranslation(self.startNode);
	local xw,_,zw = getWorldTranslation(self.widthNode);
	local xh,_,zh = getWorldTranslation(self.heightNode);
	
	local ux, uz = xw-xs, zw-zs;
	local vx, vz = xh-xs, zh-zs;
	
	local vLength = MathUtil.vector2Length(vx,vz);
	
	-- local sx = xs + (math.random()*ux) + (math.random()*vx);
	-- local sz = zs + (math.random()*uz) + (math.random()*vz);
	-- local sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx,0,sz);
	-- local ex = xs + (math.random()*ux) + (math.random()*vx);
	-- local ez = zs + (math.random()*uz) + (math.random()*vz);
	-- local ey = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, ex,0,ez);
	
	local sx = xs + 0.40 * ux + 0.5 * vx;
    local sz = zs + 0.40 * uz + 0.5 * vz;
    local sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 0, sz) + 10.0;
    local ex = xs + 0.60 * ux + 0.5 * vx;
    local ez = zs + 0.60 * uz + 0.5 * vz;
    local ey = sy;
	
	
	
	local dropped, lineOffset = 0;	
	local i = 0;
	while true do
		dropped, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(nil, increase - dropped, self.fillTypeIndex, sx,sy,sz, ex,ey,ez, 0, vLength, self.lineOffset, false, nil)
		droppedLvl = droppedLvl + dropped;
		
		if droppedLvl >= self.accuracy * increase then
			break;
		end;
		i = i + 1;
		if i >= 100 then
			g_debug.write(debugIndex, g_debug.ERROR, string.format("GC_DynamicHeap %s end tipping: no space", getName(self.rootNode)));		
			break;
		end;
	end;
	
	self.lineOffset = lineOffset;
	return droppedLvl;
end;
]]--

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
	--print(string.format("%s %s", x,z));
	--print(string.format("%s %s", xw,xs));
	--print(string.format("%s %s", zh,zs));
	return DensityMapHeightUtil.getHeightAtWorldPos(x,0,z) - getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x,0,z);
end;





