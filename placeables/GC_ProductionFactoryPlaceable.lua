--
-- GlobalCompany - Placeables - GC_ProductionFactoryPlaceable
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / kevink98
-- @Date: 21.02.2019
-- @Version: 1.1.1.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.1.0.0 (21.02.2019):
-- 		- Add multi factory support for one placeable.
--		- Add GC Placeable registration method instead of script specific.
--
-- 	v1.0.0.0 (06.02.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--		- Registration is completed in the GlobalCompany.lua as part of 'loadPlaceables' function.
--
--
-- ToDo:
--
--

GC_ProductionFactoryPlaceable = {}

local GC_ProductionFactoryPlaceable_mt = Class(GC_ProductionFactoryPlaceable, Placeable)
InitObjectClass(GC_ProductionFactoryPlaceable, "GC_ProductionFactoryPlaceable")

-- With Product Lines this is all we need for performance reasons.
-- This allows one factory to be used to build the other one if needed.
GC_ProductionFactoryPlaceable.MAX_FACTORIES = 5

GC_ProductionFactoryPlaceable.debugIndex = g_company.debug:registerScriptName("ProductionFactoryPlaceable")

getfenv(0)["GC_ProductionFactoryPlaceable"] = GC_ProductionFactoryPlaceable

function GC_ProductionFactoryPlaceable:new(isServer, isClient, customMt)
	local self = Placeable:new(isServer, isClient, customMt or GC_ProductionFactoryPlaceable_mt)

	self.debugData = nil
	self.productionFactories = {}

	self.totalSellPrice = 0

	registerObjectClassName(self, "GC_ProductionFactoryPlaceable")
	return self
end

function GC_ProductionFactoryPlaceable:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	if not GC_ProductionFactoryPlaceable:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
		return false
	end

	self.debugData = g_company.debug:getDebugData(GC_ProductionFactoryPlaceable.debugIndex, nil, self.customEnvironment)

	local filenameToUse = xmlFilename
	local xmlFile = loadXMLFile("TempPlaceableXML", xmlFilename)
	local canLoad = xmlFile ~= nil and xmlFile ~= 0

	if canLoad then
		local placeableKey = "placeable.productionFactories"
		local externalXML = getXMLString(xmlFile, placeableKey .. "#xmlFilename")
		if externalXML ~= nil then
			externalXML = Utils.getFilename(externalXML, self.baseDirectory)
			filenameToUse = externalXML
			if fileExists(filenameToUse) then
				delete(xmlFile)

				placeableKey = "globalCompany.productionFactories"
				xmlFile = loadXMLFile("TempExternalXML", filenameToUse)
				canLoad = xmlFile ~= nil and xmlFile ~= 0
			else
				canLoad = false
			end
		end

		if canLoad then
			local usedIndexNames = {}

			local i = 0
			while true do
				local key = string.format("%s.productionFactory(%d)", placeableKey, i)
				if not hasXMLProperty(xmlFile, key) or (i >= GC_ProductionFactoryPlaceable.MAX_FACTORIES) then
					break
				end

				local indexName = getXMLString(xmlFile, key .. "#indexName")
				if indexName ~= nil and usedIndexNames[indexName] == nil then
					usedIndexNames[indexName] = key
					local factory = GC_ProductionFactory:new(self.isServer, g_dedicatedServerInfo == nil, nil, filenameToUse, self.baseDirectory, self.customEnvironment)
					if factory:load(self.nodeId, xmlFile, key, indexName, true) then
						factory.owningPlaceable = self
						factory:setOwnerFarmId(self:getOwnerFarmId(), false)
						table.insert(self.productionFactories, factory)
					else
						factory:delete()
						factory = nil
						canLoad = false

						g_company.debug:writeError(self.debugData, "Can not load factory '%s' from XML file '%s'!", indexName, filenameToUse)
						break
					end
				else
					if indexName == nil then
						g_company.debug:writeError(self.debugData, "Can not load factory. 'indexName' is missing. From XML file '%s'!", filenameToUse)
					else
						local usedKey = usedIndexNames[indexName]
						g_company.debug:writeError(self.debugData, "Duplicate indexName '%s' found! indexName is used at '%s' in XML file '%s'!", indexName, usedKey, filenameToUse)
					end
				end

				i = i + 1
			end
		else
			g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_ProductionFactoryPlaceable]! Unable to load XML file '%s'.", filenameToUse)
		end

		delete(xmlFile)
	else
		g_company.debug:writeError(self.debugData, "Cannot load placeable type [GC_ProductionFactoryPlaceable]! Unable to load XML file '%s'.", filenameToUse)
	end

	return canLoad
end

function GC_ProductionFactoryPlaceable:finalizePlacement()
	GC_ProductionFactoryPlaceable:superClass().finalizePlacement(self)

	for _, factory in ipairs(self.productionFactories) do
		factory:finalizePlacement()
		factory:register(true)
	end
end

function GC_ProductionFactoryPlaceable:delete()
	for id, factory in ipairs(self.productionFactories) do
		factory:delete()
	end

	unregisterObjectClassName(self)
	GC_ProductionFactoryPlaceable:superClass().delete(self)
end

function GC_ProductionFactoryPlaceable:readStream(streamId, connection)
	GC_ProductionFactoryPlaceable:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then
		for _, factory in ipairs(self.productionFactories) do
			local factoryId = NetworkUtil.readNodeObjectId(streamId)
			factory:readStream(streamId, connection)
			g_client:finishRegisterObject(factory, factoryId)
		end
	end
end

function GC_ProductionFactoryPlaceable:writeStream(streamId, connection)
	GC_ProductionFactoryPlaceable:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		for _, factory in ipairs(self.productionFactories) do
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(factory))
			factory:writeStream(streamId, connection)
			g_server:registerObjectInStream(connection, factory)
		end		
	end
end

function GC_ProductionFactoryPlaceable:collectPickObjects(node)
	if g_currentMission.nodeToObject[node] == nil then
		GC_ProductionFactoryPlaceable:superClass().collectPickObjects(self, node)
	end
end

function GC_ProductionFactoryPlaceable:loadFromXMLFile(xmlFile, key, resetVehicles)
	if not GC_ProductionFactoryPlaceable:superClass().loadFromXMLFile(self, xmlFile, key, resetVehicles) then
		return false
	end

	local i = 0
	while true do
		local factoryKey = string.format("%s.productionFactory(%d)", key, i)
		if not hasXMLProperty(xmlFile, factoryKey) then
			break
		end

		local index = getXMLInt(xmlFile, factoryKey .. "#index")
		local indexName = Utils.getNoNil(getXMLString(xmlFile, factoryKey .. "#indexName"), "")
		if index ~= nil then
			if self.productionFactories[index] ~= nil then
				if not self.productionFactories[index]:loadFromXMLFile(xmlFile, factoryKey) then
					return false
				end
			else
				g_company.debug:writeWarning(self.debugData, "Could not load productionFactory '%s'. Given 'index' '%d' is not defined!", indexName, index)
			end
		end

		i = i + 1
	end

	return true
end

function GC_ProductionFactoryPlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	GC_ProductionFactoryPlaceable:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)

	for index, factory in ipairs(self.productionFactories) do
		local keyId = index - 1
		local factoryKey = string.format("%s.productionFactory(%d)", key, keyId)
		setXMLInt(xmlFile, factoryKey .. "#index", index)
		setXMLString(xmlFile, factoryKey .. "#saveId", factory.saveId)
		factory:saveToXMLFile(xmlFile, factoryKey, usedModNames)
	end
end

function GC_ProductionFactoryPlaceable:setOwnerFarmId(ownerFarmId, noEventSend)
	GC_ProductionFactoryPlaceable:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend)

	for _, factory in ipairs(self.productionFactories) do
		factory:setOwnerFarmId(ownerFarmId, noEventSend)
	end
end

function GC_ProductionFactoryPlaceable:canBeSold()
	self.totalSellPrice = 0

	for _, factory in ipairs(self.productionFactories) do
		self.totalSellPrice = self.totalSellPrice + factory:doBulkProductSell(true)
	end

	if self.totalSellPrice > 0 then
		local text = g_company.languageManager:getText("GC_Factory_Sell_Warning", nil, "Bulk Product Sale Price:  %s")
		local warning = string.format(text, g_i18n:formatMoney(self.totalSellPrice, 0, true, true))
		return true, warning
	end

	return true, nil
end

function GC_ProductionFactoryPlaceable:onSell()
	if self.isServer and self.totalSellPrice > 0 then
		g_currentMission:addMoney(self.totalSellPrice, self:getOwnerFarmId(), MoneyType.OTHER, true, true)
		self.totalSellPrice = 0
	end

	GC_ProductionFactoryPlaceable:superClass().onSell(self)
end