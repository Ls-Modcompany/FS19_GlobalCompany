--
-- GlobalCompany - AddOn - GC_SpecExtendedFillType
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
GC_SpecExtendedFillType = {}
GC_SpecExtendedFillType.modName = g_currentModName

function GC_SpecExtendedFillType.initSpecialization()
    
end

function GC_SpecExtendedFillType.prerequisitesPresent(specializations)
    return true
end

function GC_SpecExtendedFillType.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "isExtendedFillTypeObject", GC_SpecExtendedFillType.isExtendedFillTypeObject)
	SpecializationUtil.registerFunction(vehicleType, "getExtendedFillType", GC_SpecExtendedFillType.getExtendedFillType)
	SpecializationUtil.registerFunction(vehicleType, "getExtendedFillLevel", GC_SpecExtendedFillType.getExtendedFillLevel)
	SpecializationUtil.registerFunction(vehicleType, "addExtendedFillLevel", GC_SpecExtendedFillType.addExtendedFillLevel)
	SpecializationUtil.registerFunction(vehicleType, "isAcceptExtendedFillType", GC_SpecExtendedFillType.isAcceptExtendedFillType)
	SpecializationUtil.registerFunction(vehicleType, "getFreeExtendedFillLevel", GC_SpecExtendedFillType.getFreeExtendedFillLevel)
	SpecializationUtil.registerFunction(vehicleType, "getExtendedFillLevelPercentage", GC_SpecExtendedFillType.getExtendedFillLevelPercentage)
	SpecializationUtil.registerFunction(vehicleType, "getExtendedFillLevelCapacity", GC_SpecExtendedFillType.getExtendedFillLevelCapacity)
	SpecializationUtil.registerFunction(vehicleType, "getCurrentExtendedFillType", GC_SpecExtendedFillType.getCurrentExtendedFillType)
	SpecializationUtil.registerFunction(vehicleType, "updateFillLevel", GC_SpecExtendedFillType.updateFillLevel)
end

function GC_SpecExtendedFillType.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", GC_SpecExtendedFillType)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", GC_SpecExtendedFillType)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", GC_SpecExtendedFillType)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", GC_SpecExtendedFillType)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", GC_SpecExtendedFillType)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", GC_SpecExtendedFillType)
end

function GC_SpecExtendedFillType:onLoad(savegame)  
    self.spec_extendedFilltype = {}
    local spec = self.spec_extendedFilltype
    
    local isValid = false

    local fillTypeName = getXMLString(self.xmlFile, "vehicle.gcExtendedFilltype#filltype")
    local fillTypeCategorieName = getXMLString(self.xmlFile, "vehicle.gcExtendedFilltype#filltypeCategorie")

    if fillTypeName ~= nil then
        isValid = true
        fillTypeName = fillTypeName:upper()
        if g_company.fillTypeManager:getExtendedFillTypeByName(fillTypeName) ~= nil then
            spec.fillTypeName = fillTypeName
            spec.activeFillTypeIndex = g_company.fillTypeManager:getExtendedFillTypeIndexByName(fillTypeName)
        else
            print(string.format("SpecExtendedFillType: Invalid filltype %s", fillTypeName))
        end    
    end

    if fillTypeCategorieName ~= nil then
        isValid = true
        fillTypeCategorieName = fillTypeCategorieName:upper()
        if g_company.fillTypeManager:getExtendedFillTypeByCategorie(fillTypeCategorieName) ~= nil then
            spec.fillTypeCategorieName = fillTypeCategorieName
            spec.activeFillTypeIndex = -2
        else
            print(string.format("SpecExtendedFillType: Invalid filltypecategorie %s", fillTypeCategorieName))
        end    
    end

    if not isValid then        
        print(string.format("SpecExtendedFillType: filltype and filltypeCategorie must be set."))
    end

    spec.fillLevel = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.gcExtendedFilltype#startFillLevel"), 0)
    spec.capacity = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.gcExtendedFilltype#capacity"), 100)
    spec.deleteWhenEmpty = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.gcExtendedFilltype#deleteWhenEmpty"), false)    
        
    if self.isClient then
        if hasXMLProperty(self.xmlFile, "vehicle.gcExtendedFilltype.movers") then
            local movers = g_company.movers:new(self.isServer, self.isClient);
            if movers:load(self.components, self, self.xmlFile, "vehicle.gcExtendedFilltype", self.baseDirectory, spec.capacity, true) then
                spec.movers = movers
                spec.movers:updateMovers(spec.fillLevel)
            end
        end

        if hasXMLProperty(self.xmlFile, "vehicle.gcExtendedFilltype.showIfFull") then
            spec.showIfFullNode = I3DUtil.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.gcExtendedFilltype.showIfFull#node"), self.i3dMappings)
            setVisibility(spec.showIfFullNode, spec.fillLevel == spec.capacity)      
        end

        if hasXMLProperty(self.xmlFile, "vehicle.gcExtendedFilltype.setFilltypeColor") then            
            self.setFilltypeColor = {}
            local i = 0
            while true do
                local key = string.format("vehicle.gcExtendedFilltype.setFilltypeColor.color(%d)", i)
                if not hasXMLProperty(self.xmlFile, key) then
                    break
                end

                local node = I3DUtil.indexToObject(self.components, getXMLString(self.xmlFile, key .. "#node"), self.i3dMappings)
                local materialName = getXMLString(self.xmlFile, key .. "#material")
            
                if node ~= nil and getHasShaderParameter(node, materialName) then
                   table.insert(self.setFilltypeColor, {
                       node = node,
                       materialName = materialName
                   })
                end            
                
                i = i + 1
            end    
        end   

        if hasXMLProperty(self.xmlFile, "vehicle.gcExtendedFilltype.setFilltypeTexture") then            
            self.setFilltypeTexture = {}
            local i = 0
            while true do
                local key = string.format("vehicle.gcExtendedFilltype.setFilltypeTexture.texture(%d)", i)
                if not hasXMLProperty(self.xmlFile, key) then
                    break
                end

                local node = I3DUtil.indexToObject(self.components, getXMLString(self.xmlFile, key .. "#node"), self.i3dMappings)            
                table.insert(self.setFilltypeTexture, {node = node})
                
                i = i + 1
            end    
        end       
    end    

    spec.dirtyFlag = self:getNextDirtyFlag()
end

function GC_SpecExtendedFillType:getExtendedFillType() 
    local spec = self.spec_extendedFilltype    
    if spec.fillTypeName ~= nil then
        return g_company.fillTypeManager:getExtendedFillTypeByName(spec.fillTypeName)
    end
end

function GC_SpecExtendedFillType:getExtendedFillLevel() 
    local spec = self.spec_extendedFilltype      
    return spec.fillLevel
end

function GC_SpecExtendedFillType:getExtendedFillLevelCapacity() 
    local spec = self.spec_extendedFilltype      
    return spec.capacity
end

function GC_SpecExtendedFillType:getExtendedFillLevelPercentage() 
    local spec = self.spec_extendedFilltype      
    return spec.fillLevel / spec.capacity 
end

function GC_SpecExtendedFillType:getFreeExtendedFillLevel() 
    local spec = self.spec_extendedFilltype      
    return spec.capacity - spec.fillLevel   
end

function GC_SpecExtendedFillType:isAcceptExtendedFillType(fillTypeIndex)
    local spec = self.spec_extendedFilltype    
    fillTypeName = g_company.fillTypeManager:getExtendedFillTypeNameByIndex(fillTypeIndex)
    return (spec.fillTypeName ~= nil and spec.fillTypeName == fillTypeName) or g_company.fillTypeManager:getIsExtendedFillTypeIsInCategorie(fillTypeName, spec.fillTypeCategorieName)
end

function GC_SpecExtendedFillType:getCurrentExtendedFillType() 
    local spec = self.spec_extendedFilltype    
    if spec.activeFillTypeIndex ~= -2 then
        return spec.activeFillTypeIndex
    end
end

function GC_SpecExtendedFillType:addExtendedFillLevel(delta, fillTypeIndex) 
    local spec = self.spec_extendedFilltype      
    
    local changeDelta = 0
    if delta > 0 then
        local freeSpace = spec.capacity - spec.fillLevel
        changeDelta = math.min(freeSpace, delta)
        spec.fillLevel = spec.fillLevel + changeDelta
    elseif delta < 0 then
        changeDelta = math.min(delta * -1, spec.fillLevel)
        spec.fillLevel = spec.fillLevel - changeDelta
    end

    local oldFilltypeIndex = spec.activeFillTypeIndex
    spec.activeFillTypeIndex = fillTypeIndex

    if spec.fillLevel == 0 and spec.deleteWhenEmpty then
        self:delete();
    else
        self:updateFillLevel(oldFilltypeIndex ~= spec.activeFillTypeIndex)
        self:raiseDirtyFlags(spec.dirtyFlag)
    end

    return changeDelta
end

function GC_SpecExtendedFillType:updateFillLevel(isChange) 
    local spec = self.spec_extendedFilltype   

    if self.isClient then
        if spec.movers ~= nil then
            spec.movers:updateMovers(spec.fillLevel)
        end
        if spec.showIfFullNode ~= nil then
            setVisibility(spec.showIfFullNode, spec.fillLevel == spec.capacity)    
        end
        if isChange and spec.activeFillTypeIndex ~= -2 then
            if self.setFilltypeColor ~= nil then
                for _,object in pairs(self.setFilltypeColor) do
                    local colorMat = g_company.fillTypeManager:getExtendedFillTypeByIndex(spec.activeFillTypeIndex).colorMat
                    if colorMat ~= nil then
                        local r, g, b, material = tonumber(colorMat[1]), tonumber(colorMat[2]), tonumber(colorMat[3]), tonumber(colorMat[4])
                        setShaderParameter(object.node, object.materialName, r, g, b, material, false)
                    end
                end
            end
            if self.setFilltypeTexture ~= nil then
                for _,object in pairs(self.setFilltypeTexture) do
                    local fillType = g_company.fillTypeManager:getExtendedFillTypeByIndex(spec.activeFillTypeIndex)
                    if fillType ~= nil and fillType.material ~= nil then
                        setMaterial(object.node, fillType.material, 0)   
                    else
                        print(string.format("No material set for %s", g_company.fillTypeManager:getExtendedFillTypeNameByIndex(spec.activeFillTypeIndex)))  
                    end
                end
            end
        end
    end  
end

function GC_SpecExtendedFillType:onReadStream(streamId, connection)
    local spec = self.spec_extendedFilltype
    local oldFilltypeIndex = spec.activeFillTypeIndex

    spec.fillLevel = streamReadFloat32(streamId)
    spec.activeFillTypeIndex = streamReadFloat32(streamId)
    
    self:updateFillLevel(oldFilltypeIndex ~= spec.activeFillTypeIndex)
end

function GC_SpecExtendedFillType:onWriteStream(streamId, connection)
    local spec = self.spec_extendedFilltype
    streamWriteFloat32(streamId, spec.fillLevel)    
    streamWriteFloat32(streamId, spec.activeFillTypeIndex)    
end

function GC_SpecExtendedFillType:onReadUpdateStream(streamId, timestamp, connection)
    local spec = self.spec_extendedFilltype
    local oldFilltypeIndex = spec.activeFillTypeIndex

    spec.fillLevel = streamReadFloat32(streamId)
    spec.activeFillTypeIndex = streamReadFloat32(streamId)

    self:updateFillLevel(oldFilltypeIndex ~= spec.activeFillTypeIndex)
end

function GC_SpecExtendedFillType:onWriteUpdateStream(streamId, connection, dirtyMask)
    local spec = self.spec_extendedFilltype
    streamWriteFloat32(streamId, spec.fillLevel)    
    streamWriteFloat32(streamId, spec.activeFillTypeIndex)   
end

function GC_SpecExtendedFillType:isExtendedFillTypeObject()
    return true
end

function GC_SpecExtendedFillType:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_extendedFilltype
    setXMLFloat(xmlFile, key.."#fillLevel", spec.fillLevel) 
    if spec.activeFillTypeIndex ~= -2 then
        setXMLString(xmlFile, key.."#activeFillType", g_company.fillTypeManager:getExtendedFillTypeNameByIndex(spec.activeFillTypeIndex)) 
    end
end

function GC_SpecExtendedFillType:onPostLoad(savegame)  
    local spec = self.spec_extendedFilltype
    
    if savegame == nil then return end

    local key = string.format("%s.%s.gcExtendedFillType", savegame.key, GC_SpecExtendedFillType.modName)

    spec.fillLevel = getXMLFloat(savegame.xmlFile, key.."#fillLevel")
    local activeFillType = getXMLString(savegame.xmlFile, key.."#activeFillType") 
    if activeFillType ~= nil then
        spec.activeFillTypeIndex = g_company.fillTypeManager:getExtendedFillTypeIndexByName(activeFillType)
    end
    self:updateFillLevel(true)   
end