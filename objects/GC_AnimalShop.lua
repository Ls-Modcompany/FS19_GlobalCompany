--
-- GlobalCompany - Objects - GC_AnimalShop
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 25.08.2018
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.0.0.0 (22.03.2018):
-- 		- initial fs17 ()
--
--
-- Notes:
--
--
-- ToDo:
--
--

GC_AnimalShop = {};
local GC_AnimalShop_mt = Class(GC_AnimalShop, Object);
InitObjectClass(GC_AnimalShop, "GC_AnimalShop");

GC_AnimalShop.REF_TRIGGER_PLAYER = 1;

GC_AnimalShop.debugIndex = g_company.debug:registerScriptName("GC_AnimalShop");

getfenv(0)["GC_AnimalShop"] = GC_AnimalShop;


function GC_AnimalShop:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName")
	local xmlFilename = getUserAttribute(transformId, "xmlFile")

	if indexName ~= nil and xmlFilename ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName
		local baseDirectory = g_currentMission.loadingMapBaseDirectory

		local object = GC_AnimalShop:new(g_server ~= nil, g_dedicatedServerInfo == nil, nil, xmlFilename, baseDirectory, customEnvironment)
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.animalShops.animalShop", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object)
				g_currentMission:addOnCreateLoadedObjectToSave(object)

				g_company.debug:writeOnCreate(object.debugData, "[ANIMALSHOP - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex)
				object:register(true)
			else
				g_company.debug:writeOnCreate(object.debugData, "[ANIMALSHOP - %s]  Failed to load from '%s'!", indexName, xmlFilename)
				object:delete()
			end

			delete(xmlFile)
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[ANIMALSHOP - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename)
			else
				g_company.debug:writeModding(object.debugData, "[ANIMALSHOP - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename)
			end
		end
	else
		g_company.debug:print("  [LSMC - GlobalCompany] - [GC_AnimalShop]")
		if indexName == nil then
			g_company.debug:print("    ONCREATE: Trying to load 'ANIMALSHOP' with nodeId name %s, attribute 'indexName' could not be found.", getName(transformId))
		elseif xmlFilename == nil then
            g_company.debug:print("    ONCREATE: [ANIMALSHOP - %s]  Attribute 'xmlFilename' is missing!", indexName)
		end
	end
end

function GC_AnimalShop:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or GC_AnimalShop_mt)

	self.xmlFilename = xmlFilename
	self.baseDirectory = baseDirectory
	self.customEnvironment = customEnvironment

	

	self.debugData = g_company.debug:getDebugData(GC_AnimalShop.debugIndex, nil, customEnvironment)

	return self
end

function GC_AnimalShop:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)

	self.rootNode = nodeId
	self.indexName = indexName
	self.isPlaceable = isPlaceable

	self.triggerManager = GC_TriggerManager:new(self)
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings")

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId")
	if self.saveId == nil then
		self.saveId = "ProductionFactory_" .. indexName
    end


    self.playerTrigger = self.triggerManager:addTrigger(GC_PlayerTrigger, self.rootNode, self , xmlFile, string.format("%s.playerTrigger", xmlKey), GC_AnimalShop.REF_TRIGGER_PLAYER, true, g_company.languageManager:getText("GC_animalShop_openGui"));
		


    if self.isServer then
        g_currentMission.environment:addHourChangeListener(self);
    end

    return true;
end;

function GC_AnimalShop:delete()
    if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self)
	end

	if self.isServer then
		g_currentMission.environment:removeHourChangeListener(self)
	end

	if self.triggerManager ~= nil then
		self.triggerManager:removeAllTriggers()
	end

	GC_AnimalShop:superClass().delete(self)
end

function GC_AnimalShop:readStream(streamId, connection)
	GC_AnimalShop:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:readStream(streamId, connection)
		end
	end
end

function GC_AnimalShop:writeStream(streamId, connection)
	GC_AnimalShop:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:writeStream(streamId, connection)
		end
	end
end

function GC_AnimalShop:readUpdateStream(streamId, timestamp, connection)
	GC_AnimalShop:superClass().readUpdateStream(self, streamId, timestamp, connection)

    if connection:getIsServer() then
        
    end
end

function GC_AnimalShop:writeUpdateStream(streamId, connection, dirtyMask)
	GC_AnimalShop:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)

    if not connection:getIsServer() then
        
	end
end

function GC_AnimalShop:loadFromXMLFile(xmlFile, key)

	return true
end

function GC_AnimalShop:saveToXMLFile(xmlFile, key, usedModNames)

end

function GC_AnimalShop:update(dt)

    --self:raiseActive()
end;

function GC_AnimalShop:hourChanged()

end;

function GC_AnimalShop:playerTriggerActivated(ref)
    if ref == GC_AnimalShop.REF_TRIGGER_PLAYER then        
        g_company.gui:openGuiWithData("gc_animalShop", false);
    end;
end;








