--
-- GlobalCompany - Placeables - GC_FillTypeConstructorPlaceable
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 21.04.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (21.04.2019):
-- 		- initial fs19 (GtX)
--
--
-- Notes:
--	
--
-- ToDo:
--
--

GC_FillTypeConstructorPlaceable = {};

local GC_FillTypeConstructorPlaceable_mt = Class(GC_FillTypeConstructorPlaceable, Placeable);
InitObjectClass(GC_FillTypeConstructorPlaceable, "GC_FillTypeConstructorPlaceable");

GC_FillTypeConstructorPlaceable.debugIndex = g_company.debug:registerScriptName("GC_FillTypeConstructorPlaceable");

getfenv(0)["GC_FillTypeConstructorPlaceable"] = GC_FillTypeConstructorPlaceable;

function GC_FillTypeConstructorPlaceable:new(isServer, isClient, customMt)
	local self = Placeable:new(isServer, isClient, customMt or GC_FillTypeConstructorPlaceable_mt);
	
	self.debugData = nil;
	self.constructor = nil;

	registerObjectClassName(self, "GC_FillTypeConstructorPlaceable");	
	return self;
end;

function GC_FillTypeConstructorPlaceable:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	if not GC_FillTypeConstructorPlaceable:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_FillTypeConstructorPlaceable.debugIndex, nil, self.customEnvironment);

	local filenameToUse = xmlFilename;
	local xmlFile = loadXMLFile("TempPlaceableXML", xmlFilename);
	local canLoad = xmlFile ~= nil and xmlFile ~= 0;
	
	if canLoad then
		local indexNameWanted;
		local placeableKey = "placeable.globalCompany";
		local externalXML = getXMLString(xmlFile, placeableKey .. "#xmlFilename");
		if externalXML ~= nil then
			indexNameWanted = getXMLString(xmlFile, placeableKey .. "#indexName");
			externalXML = Utils.getFilename(externalXML, self.baseDirectory);
			filenameToUse = externalXML;
			if fileExists(filenameToUse) then
				if indexNameWanted ~= nil then
					delete(xmlFile);
					
					placeableKey = "globalCompany.fillTypeConstructors";
					xmlFile = loadXMLFile("TempExternalXML", filenameToUse);
					canLoad = xmlFile ~= nil and xmlFile ~= 0;
				else
					g_company.debug:writeError(self.debugData, "Failed to load, 'indexName' is missing at %s. From XML file '%s'!", placeableKey, xmlFilename);
				end;
			else
				canLoad = false;
			end;
		end;

		if canLoad then
			local i = 0;
			while true do
				local key = string.format("%s.fillTypeConstructor(%d)", placeableKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local indexName = getXMLString(xmlFile, key .. "#indexName");
				if indexName ~= nil then
					if indexNameWanted == nil then
						indexNameWanted = indexName;
					end;
					
					if indexName == indexNameWanted then
						local constructor = GC_FillTypeConstructor:new(self.isServer, self.isClient, nil, filenameToUse, self.baseDirectory, self.customEnvironment);
						if constructor:load(self.nodeId, xmlFile, key, indexName, true) then
							constructor:setOwnerFarmId(self:getOwnerFarmId(), false);
							self.constructor = constructor;
							break;
						else
							constructor:delete();
							constructor = nil;
							canLoad = false;
	
							g_company.debug:writeError(self.debugData, "Failed to load fillTypeConstructor '%s' from XML file '%s'!", indexName, filenameToUse);
							break;
						end;
					end;
				else
					g_company.debug:writeError(self.debugData, "Failed to load, 'indexName' is missing. From XML file '%s'!", filenameToUse);
				end;

				i = i + 1;
			end;
		else
			g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_FillTypeConstructorPlaceable]! Unable to load XML file '%s'.", filenameToUse);
		end;

		delete(xmlFile);
	else
		g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_FillTypeConstructorPlaceable]! Unable to load XML file '%s'.", filenameToUse);
	end;

	return canLoad;
end;

function GC_FillTypeConstructorPlaceable:finalizePlacement()
	GC_FillTypeConstructorPlaceable:superClass().finalizePlacement(self)

	self.constructor:register(true);
end;

function GC_FillTypeConstructorPlaceable:delete()
	if self.constructor ~= nil then	
		self.constructor:delete();
	end;

	unregisterObjectClassName(self);
	GC_FillTypeConstructorPlaceable:superClass().delete(self);
end;

function GC_FillTypeConstructorPlaceable:readStream(streamId, connection)
    GC_FillTypeConstructorPlaceable:superClass().readStream(self, streamId, connection);
    
	if connection:getIsServer() then
        local constructorId = NetworkUtil.readNodeObjectId(streamId);
        self.constructor:readStream(streamId, connection);
        g_client:finishRegisterObject(factory, constructorId);
    end;
end;

function GC_FillTypeConstructorPlaceable:writeStream(streamId, connection)
    GC_FillTypeConstructorPlaceable:superClass().writeStream(self, streamId, connection);
    
	if not connection:getIsServer() then
        NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.constructor));
        self.constructor:writeStream(streamId, connection);
        g_server:registerObjectInStream(connection, self.constructor);
    end;
end;

function GC_FillTypeConstructorPlaceable:collectPickObjects(node)
	if g_currentMission.nodeToObject[node] == nil then
		GC_FillTypeConstructorPlaceable:superClass().collectPickObjects(self, node);
	end;
end;

function GC_FillTypeConstructorPlaceable:loadFromXMLFile(xmlFile, key, resetVehicles)
	if not GC_FillTypeConstructorPlaceable:superClass().loadFromXMLFile(self, xmlFile, key, resetVehicles) then
		return false;
	end;
	
	--if not self.constructor:loadFromXMLFile(xmlFile, key .. ".constructor") then
		--return false;
	--end;

	return true;
end;

function GC_FillTypeConstructorPlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	GC_FillTypeConstructorPlaceable:superClass().saveToXMLFile(self, xmlFile, key, usedModNames);
	
	--local constructorKey = key .. ".constructor";
	--setXMLString(xmlFile, constructorKey .. "#saveId", factory.saveId);
	--self.constructor:saveToXMLFile(xmlFile, constructorKey, usedModNames);
end;

-- We need to update the 'OwnerFarmId' here so that sub-objects can also be updated and for land sales.
function GC_FillTypeConstructorPlaceable:setOwnerFarmId(ownerFarmId, noEventSend)
    GC_FillTypeConstructorPlaceable:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend);

	if self.constructor ~= nil then
		self.constructor:setOwnerFarmId(ownerFarmId, noEventSend);
	end;
end;





