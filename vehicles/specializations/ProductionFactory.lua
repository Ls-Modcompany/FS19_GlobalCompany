--
-- GlobalCompany - AddOn - GC_SpecProductionFactory
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 02.05.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
--
-- 	v1.0.0.0 ():
--
-- Notes:
--
--
-- ToDo:
-- 
--
--
GC_SpecProductionFactory = {}
GC_SpecProductionFactory.modName = g_currentModName

function GC_SpecProductionFactory.initSpecialization()
    
end

function GC_SpecProductionFactory.prerequisitesPresent(specializations)
    return true
end

function GC_SpecProductionFactory.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "onLoadFactory", GC_SpecProductionFactory.onLoadFactory)
	SpecializationUtil.registerFunction(vehicleType, "getFactories", GC_SpecProductionFactory.getFactories)
    --SpecializationUtil.registerFunction(vehicleType, "readStream", GC_SpecProductionFactory.readStream)
    --SpecializationUtil.registerFunction(vehicleType, "writeStream", GC_SpecProductionFactory.writeStream)
end

function GC_SpecProductionFactory.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", GC_SpecProductionFactory)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", GC_SpecProductionFactory)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", GC_SpecProductionFactory)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", GC_SpecProductionFactory)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", GC_SpecProductionFactory)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", GC_SpecProductionFactory)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", GC_SpecProductionFactory)
    --SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", GC_SpecProductionFactory)
    --SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", GC_SpecProductionFactory)
end

function GC_SpecProductionFactory:onLoad(savegame)  
    self.spec_productionFactory = {}    
    local spec = self.spec_productionFactory
    
    spec.productionFactories = {}   

    local usedIndexNames = {}
    local i = 0
    while true do
        local key = string.format("vehicle.productionFactories.productionFactory(%d)", i)
        if not hasXMLProperty(self.xmlFile, key) then
            break
        end
   
        local indexName = getXMLString(self.xmlFile, key .. "#indexName")
        if indexName ~= nil and usedIndexNames[indexName] == nil then
            usedIndexNames[indexName] = key            
            local factory = GC_ProductionFactory:new(g_server ~= nil, g_dedicatedServerInfo == nil, nil, indexName, self.baseDirectory, self.customEnvironment, true)
            if factory:load(self.components, self.xmlFile, key, string.format("%s.%s", self.configFileName, i), false, self) then
                factory.owningPlaceable = self
                factory:setOwnerFarmId(self:getOwnerFarmId(), false)
                table.insert(spec.productionFactories, factory)
            else
                factory:delete()        
                print("SpecProductionFactory: Error while loading factory for vehicles.")
                break
            end
        else
            if indexName == nil then
                print(string.format("SpecProductionFactory: Can not load factory. 'indexName' is missing. From XML file '%s'!", filenameToUse))
            else
                local usedKey = usedIndexNames[indexName]
                print(string.format("SpecProductionFactory: Duplicate indexName '%s' found! indexName is used at '%s' in XML file '%s'!", indexName, usedKey, filenameToUse))
            end
        end                   
        i = i + 1
    end
end

function GC_SpecProductionFactory:onLoadFinished(savegame)  
    local spec = self.spec_productionFactory
  
	for _, factory in ipairs(spec.productionFactories) do
		factory:finalizePlacement()
		factory:register(true)
    end
end

function GC_SpecProductionFactory:onLoadFactory(factory)  
    local spec = self.spec_productionFactory
    factory.i3dMappings = self.i3dMappings   
end

function GC_SpecProductionFactory:onUpdate()   
    local spec = self.spec_productionFactory
    
    
end

function GC_SpecProductionFactory:getFactories()   
    local spec = self.spec_productionFactory
    return spec.productionFactories  
end


function GC_SpecProductionFactory:onDelete()
    local spec = self.spec_productionFactory

    for _,factory in ipairs(spec.productionFactories) do
        factory:delete()
    end    
end

function GC_SpecProductionFactory:onReadStream(streamId, connection)

end

function GC_SpecProductionFactory:onWriteStream(streamId, connection)
    local spec = self.spec_productionFactory
    spec.factoryObject = GC_ProductionFactoryObject:new(g_server ~= nil, g_dedicatedServerInfo == nil)
    spec.factoryObject:load(self)
end

function GC_SpecProductionFactory:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_productionFactory
    
    for index, factory in ipairs(spec.productionFactories) do
		local keyId = index - 1
		local factoryKey = string.format("%s.productionFactory(%d)", key, keyId)
		setXMLInt(xmlFile, factoryKey .. "#index", index)
		--setXMLString(xmlFile, factoryKey .. "#saveId", factory.saveId)
		factory:saveToXMLFile(xmlFile, factoryKey, usedModNames)
	end
end

function GC_SpecProductionFactory:onPostLoad(savegame)  
    local spec = self.spec_productionFactory
    
    if savegame == nil then return end

    local i = 0
	while true do
        local factoryKey = string.format("%s.%s.gcProductionFactory.productionFactory(%d)", savegame.key, GC_SpecProductionFactory.modName, i)
		if not hasXMLProperty(savegame.xmlFile, factoryKey) then
			break
		end
		local index = getXMLInt(savegame.xmlFile, factoryKey .. "#index")
		local indexName = Utils.getNoNil(getXMLString(savegame.xmlFile, factoryKey .. "#indexName"), "")
		if index ~= nil then
			if spec.productionFactories[index] ~= nil then
				if not spec.productionFactories[index]:loadFromXMLFile(savegame.xmlFile, factoryKey) then
					return false
				end
			else
				print(string.format("SpecProductionFactory: Could not load productionFactory '%s'. Given 'index' '%d' is not defined!", indexName, index))
			end
		end

		i = i + 1
	end
end