--
-- GlobalCompany - Objects - GC_DirtyObjects
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 02.03.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (02.03.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
--
-- ToDo:
-- 	MP-Test
--
--

DirtObjects = {};
DirtObjects_mt = Class(DirtObjects, Object);
InitObjectClass(DirtObjects, "DirtObjects");

local saveId = -1;
local function GetNextSaveId() saveId = saveId + 1; return saveId; end;

DirtObjects.debugIndex = g_company.debug:registerScriptName("DirtObjects");

getfenv(0)["GC_DirtyObjects"] = DirtObjects;

function DirtObjects:onCreate(id)
	local customEnvironment = g_currentMission.loadingMapModName;
	local baseDirectory = g_currentMission.loadingMapBaseDirectory;
	local object = DirtObjects:new(g_server ~= nil, g_client ~= nil, nil, baseDirectory, customEnvironment);
	
	if object:load(id, true) then
		local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
		g_currentMission:addOnCreateLoadedObjectToSave(object);
		g_company.debug:writeOnCreate(object.debugData, "[DirtObjects - %s]  Loaded successfully!  [onCreateIndex = %d]", getName(id), onCreateIndex);
		object:register(true);
	else
		g_company.debug:writeOnCreate(object.debugData, "[DirtObjects - %s]  Failed to load!", getName(id));
		object:delete();
	end;	
end;

function DirtObjects:new(isServer, isClient, customMt, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or DirtObjects_mt);

	self.baseDirectory = baseDirectory;
	self.customEnvironment = customEnvironment;

	self.debugData = g_company.debug:getDebugData(DirtObjects.debugIndex, nil, customEnvironment);

	if self.isServer then
		g_currentMission.environment:addHourChangeListener(self);
	end;
	return self;
end;

function DirtObjects:load(nodeId, isOnCreate)
	self.nodeId  = nodeId;
	self.isOnCreate = isOnCreate;

	if isOnCreate then
		self.saveId = string.format("DirtObjects_%s", GetNextSaveId());
	end;
	
	self.dirtNodes = {};
	I3DUtil.getNodesByShaderParam(self.nodeId, "RDT", self.dirtNodes);

	self.factorPerHour = Utils.getNoNil(getUserAttribute(nodeId, "factorPerHour"), 0.01);

	self.dirtObjectsDirtyFlag = self:getNextDirtyFlag();
	self:raiseActive();
	return true;
end;

function DirtObjects:delete()
	if self.isOnCreate then
		g_currentMission:removeOnCreateLoadedObjectToSave(self);
	end;
	if g_currentMission.environment ~= nil and self.isServer then
        g_currentMission.environment:removeWeatherChangeListener(self)
    end;	
	DirtObjects:superClass().delete(self)
end;

function DirtObjects:readStream(streamId, connection)
	DirtObjects:superClass().readStream(self, streamId, connection);
	if connection:getIsServer() then
		for i,dirtNode in pairs (self.dirtNodes) do	
			local dirtLevel = streamReadFloat32(streamId)
			local x, _, z, w = getShaderParameter(dirtNode, "RDT");
			setShaderParameter(dirtNode, "RDT", x, dirtLevel, z, w, false);
		end;
	end;
end;

function DirtObjects:writeStream(streamId, connection)
	DirtObjects:superClass().writeStream(self, streamId, connection);
	if not connection:getIsServer() then	
		for _,dirtNode in pairs (self.dirtNodes) do	
			local _, dirtLevel, _, _ = getShaderParameter(dirtNode, "RDT");
			streamWriteFloat32(streamId, dirtLevel);
		end;
	end;
end;

function DirtObjects:readUpdateStream(streamId, timestamp, connection)
	DirtObjects:superClass().readUpdateStream(self, streamId, timestamp, connection);
	if connection:getIsServer() then
		if streamReadBool(streamId) then
			for i,dirtNode in pairs (self.dirtNodes) do	
				local dirtLevel = streamReadFloat32(streamId)
				local x, _, z, w = getShaderParameter(dirtNode, "RDT");
				setShaderParameter(dirtNode, "RDT", x, dirtLevel, z, w, false);
			end;
		end;
	end;
end;

function DirtObjects:writeUpdateStream(streamId, connection, dirtyMask)
	DirtObjects:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);
	if not connection:getIsServer() then
		if streamWriteBool(streamId, bitAND(dirtyMask, self.DirtObjectsDirtyFlag) ~= 0) then
			for _,dirtNode in pairs (self.dirtNodes) do	
				local _, dirtLevel, _, _ = getShaderParameter(dirtNode, "RDT");
				streamWriteFloat32(streamId, dirtLevel);
			end;
		end;
	end;
end;

function DirtObjects:loadFromXMLFile(xmlFile, key)
	local i = 0;
	local dirtValues = {};
	while true do
		local dirtNodeKey = string.format("%s.dirtNode(%d)", key, i);
		if not hasXMLProperty(xmlFile, dirtNodeKey) then
			break;
		end
		local dirtLevel = getXMLFloat(xmlFile, string.format("%s#dirtLevel", dirtNodeKey));
		
		if dirtLevel == nil then
			dirtLevel = 0;
		end;
		table.insert(dirtValues, dirtLevel);
		i = i + 1;
	end

	i = 1;
	for _, dirtNode in pairs(self.dirtNodes) do		
		if dirtValues[i] == nil then
			return true;
		end;
		local x, _, z, w = getShaderParameter(dirtNode, "RDT");
		setShaderParameter(dirtNode, "RDT", x, dirtValues[i], z, w, false);
		i = i + 1;
	end;

	return true;
end;

function DirtObjects:saveToXMLFile(xmlFile, key, usedModNames)	
	local i = 0;
	for _,dirtNode in pairs (self.dirtNodes) do	
		local dirtNodeKey = string.format("%s.dirtNode(%d)", key, i);
		local _, dirtLevel, _, _ = getShaderParameter(dirtNode, "RDT");
		setXMLFloat(xmlFile, string.format("%s#dirtLevel", dirtNodeKey), dirtLevel);
		i = i + 1;
	end;
end;

function DirtObjects:update(dt)
	
end;

function DirtObjects:hourChanged()	
	local needRaise = false;
	local factor = 1;
	if g_currentMission ~= nil and g_currentMission.environment ~= nil and g_currentMission.environment.weather:getIsRaining() then
		factor = -2;
	end;
	for _,dirtNode in pairs(self.dirtNodes) do			
		local x, y, z, w = getShaderParameter(dirtNode, "RDT");
		local newY = math.max(math.min(y + self.factorPerHour * factor, 1), 0);
		if y ~= newY then
			setShaderParameter(dirtNode, "RDT", x, newY, z, w, false);
			needRaise = true;
		end;
	end;
	if needRaise then
		self:raiseDirtyFlags(self.dirtObjectsDirtyFlag);
	end;
end;