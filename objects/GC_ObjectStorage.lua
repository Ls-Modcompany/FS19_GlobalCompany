--
-- GlobalCompany - Objects - GC_ObjectStorage
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 30.07.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (30.07.2020):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
--
-- ToDo:
--
--
--

GC_ObjectStorage = {}
GC_ObjectStorage._mt = Class(GC_ObjectStorage, g_company.gc_class)
InitObjectClass(GC_ObjectStorage, "GC_ObjectStorage")

GC_ObjectStorage.debugIndex = g_company.debug:registerScriptName("GC_ObjectStorage")

function GC_ObjectStorage:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)    
    return GC_ObjectStorage:superClass():new(GC_ObjectStorage._mt, isServer, isClient, scriptDebugInfo, xmlFilename, baseDirectory, customEnvironment)
end

function GC_ObjectStorage:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
    GC_ObjectStorage:superClass().load(self)    

	self.rootNode = nodeId
	self.indexName = indexName
	self.isPlaceable = isPlaceable

	self.debugData = g_company.debug:getDebugData(GC_ObjectStorage.debugIndex, nil, self.customEnvironment)

	self.triggerManager = GC_TriggerManager:new(self)
    self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings")
    
	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId")
	if self.saveId == nil then
		self.saveId = "ObjectStorage_" .. indexName
    end
    
    self.boxes = {}

    local i = 0
    while true do 
        local boxKey = string.format("%s.boxes.box(%d)", xmlKey, i);
        if not hasXMLProperty(xmlFile, boxKey) then
            break
        end

        local box = {}
        box.id = i + 1
        box.types = {}
        box.bales = {}

        box.currentFilltype = FillType.UNKNOWN
        box.currentNumBales = 0
        box.currentConfig = nil
        
        local j = 0
        while true do 
            local typeKey = string.format("%s.types.type(%d)", boxKey, j);
            if not hasXMLProperty(xmlFile, typeKey) then
                break
            end
            
            local categorie = getXMLString(xmlFile, typeKey .. "#categorie")
            local positions = getXMLString(xmlFile, typeKey .. "#positions")
            local width = getXMLFloat(xmlFile, typeKey .. "#width")
            local diameter = getXMLFloat(xmlFile, typeKey .. "#diameter")

            positions = I3DUtil.indexToObject(self.rootNode, positions, self.i3dMappings);

            table.insert(box.types, {categorie=categorie, positions=positions, width=width, diameter=diameter})      
            j = j + 1
        end

        box.baleTrigger = self.triggerManager:addTrigger(GC_BaleTrigger, self.rootNode, self , xmlFile, string.format("%s.baleTrigger", boxKey), box.id, GC_BaleTrigger.MO)
        
        self.boxes[box.id] = box
        i = i + 1
    end     

    self.obkectStorageDirtyFlag = self:getNextDirtyFlag()
        
    g_company.addRaisedUpdateable(self)

    --self.globalIndex = g_company.addObjectStorage(self)

	return true
end

function GC_ObjectStorage:finalizePlacement()
    GC_ObjectStorage:superClass().finalizePlacement(self)	
    

end

function GC_ObjectStorage:delete()
    --g_company.removeAObjectStorage(self, self.globalIndex)
    
	if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self)
    end
    
	if self.triggerManager ~= nil then
		self.triggerManager:removeAllTriggers()
    end

    
	

	GC_ObjectStorage:superClass().delete(self)
end

function GC_ObjectStorage:readStream(streamId, connection)
	GC_ObjectStorage:superClass().readStream(self, streamId, connection)  

	if connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:readStream(streamId, connection)
        end
        

	end
end

function GC_ObjectStorage:writeStream(streamId, connection)
	GC_ObjectStorage:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:writeStream(streamId, connection)
		end        

        
	end
end

function GC_ObjectStorage:readUpdateStream(streamId, timestamp, connection)
	GC_ObjectStorage:superClass().readUpdateStream(self, streamId, timestamp, connection)

	if connection:getIsServer() then
        if streamReadBool(streamId) then
                                
        end
	end
end

function GC_ObjectStorage:writeUpdateStream(streamId, connection, dirtyMask)
	GC_ObjectStorage:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)

	if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, self.animalFeederDirtyFlag) ~= 0) then
                       
        end
	end
end

function GC_ObjectStorage:loadFromXMLFile(xmlFile, key)
	GC_ObjectStorage:superClass().loadFromXMLFile(self, xmlFile, key)
    if not self.isPlaceable then
		key = string.format("%s.objectStorage", key)
    end

    self:raiseUpdate()
 
	return true
end

function GC_ObjectStorage:saveToXMLFile(xmlFile, key, usedModNames)
	GC_ObjectStorage:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)
	if not self.isPlaceable then
		key = string.format("%s.objectStorage", key)
		setXMLInt(xmlFile, key .. "#farmId", self:getOwnerFarmId())
    end
end

function GC_ObjectStorage:update(dt)     
	GC_ObjectStorage:superClass().update(self, dt)
    --self:raiseUpdate()
end

function GC_ObjectStorage:playerTriggerCanAddActivatable()
    return true
end

function GC_ObjectStorage:playerTriggerActivated()
    g_company.gui:openGuiWithData("GC_ObjectStorage", false, self)
end

function GC_ObjectStorage:onSetFarmlandStateChanged(farmId)
	self:setOwnerFarmId(farmId, false)
end

function GC_ObjectStorage:setOwnerFarmId(ownerFarmId, noEventSend)
	GC_ObjectStorage:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend)
	if self.triggerManager ~= nil then
		self.triggerManager:setAllOwnerFarmIds(ownerFarmId, noEventSend)
	end
end

function GC_ObjectStorage:onEnterBaleTrigger(ref, bale)
    local box = self.boxes[ref]

    if box.currentFilltype == FillType.UNKNOWN then
        box.currentFilltype = bale:getFillType()
        
        
        table.insert(box.bales, {})

    elseif box.currentFilltype == bale:getFillType()

    end
end

