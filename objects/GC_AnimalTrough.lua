--
-- GlobalCompany - Triggers - GC_AnimalTrough
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 09.02.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.0.0.0 (09.02.2020):
-- 		- initial fs19 (kevink98)
--
-- Notes:
--
-- names: food water foodSpillage straw
--
-- ToDo:
--
--

GC_AnimalTrough = {};

GC_AnimalTrough.DIRECTIONTOTROUGH = 1
GC_AnimalTrough.DIRECTIONTOTARGET = 2

GC_AnimalTrough._mt = Class(GC_AnimalTrough, g_company.gc_class);
InitObjectClass(GC_AnimalTrough, "GC_AnimalTrough");
GC_AnimalTrough.debugIndex = g_company.debug:registerScriptName("GC_AnimalTrough");

function GC_AnimalTrough:new(isServer, isClient)
    return GC_AnimalTrough:superClass():new(GC_AnimalTrough._mt, isServer, isClient);
end

function GC_AnimalTrough:load(nodeId, target, xmlFile, xmlKey, extraParameter)
    GC_AnimalTrough:superClass().load(self)
    
    self.nodeId = nodeId;
    self.target = target;
    self.extraParameter = extraParameter

    self.direction = GC_AnimalTrough.DIRECTIONTOTROUGH

    self.modulName = getXMLString(xmlFile, xmlKey .. "#modulName")
    if self.modulName == nil then
        print("missing modulname in animaltrough")
        return false
    end

    self.fillLitersPerMS = Utils.getNoNil(getXMLInt(xmlFile, xmlKey .. "#fillLitersPerSecond"), 1000) / 1000
    
    self.effects = g_effectManager:loadEffect(xmlFile, xmlKey, nodeId, self, target.i3dMappings)
    self.lastEffectState = false

    local fillSoundNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. ".sounds#fillSoundNode"), target.i3dMappings)
    local fillSoundIdentifier = getXMLString(xmlFile, xmlKey .. ".sounds#fillSoundIdentifier")
    if fillSoundIdentifier ~= nil then
        local xmlSoundFile = loadXMLFile("mapXML", g_currentMission.missionInfo.mapSoundXmlFilename)
        if xmlSoundFile ~= nil and xmlSoundFile ~= 0 then
            local directory = g_currentMission.baseDirectory
            local modName, baseDirectory = Utils.getModNameAndBaseDirectory(g_currentMission.missionInfo.mapSoundXmlFilename)
            if modName ~= nil then
                directory = baseDirectory .. modName
            end

            self.samplesLoad = g_soundManager:loadSampleFromXML(xmlSoundFile, "sound.object", fillSoundIdentifier, directory, getRootNode(), 0, AudioGroup.ENVIRONMENT, nil, nil)
            if self.samplesLoad ~= nil then
                link(nodeId, self.samplesLoad.soundNode)
                setTranslation(self.samplesLoad.soundNode, 0, 0, 0)
            end

            delete(xmlSoundFile)
        end
    end

    self.foundTroughModule = nil
    self.canSearch = false 

	g_company.addUpdateable(self, self.update)
	return true
end

function GC_AnimalTrough:finalizePlacement()
	GC_AnimalTrough:superClass().finalizePlacement(self)	
    self.eventId_setEffectState = self:registerEvent(self, self.setEffectStateEvent, false, false)  
    self.canSearch = true 
end

function GC_AnimalTrough:delete()
	
	g_company.removeUpdateable(self);
	GC_AnimalTrough:superClass().delete(self);
end


function GC_AnimalTrough:update(dt)
    GC_AnimalTrough:superClass().update(self, dt)

    if not self.isServer then
        return
    end

    if self.canSearch and self.foundTroughModule == nil then
        local distance = 9999999999
        for _,husbandry in pairs(g_currentMission.husbandries) do
            for name,mod in pairs(husbandry.modulesByName) do  
                if name == self.modulName then
                    local newDistance = self:calcDistance(mod.owner.nodeId)
                    if newDistance < distance then
                        distance = newDistance
                        self.foundTroughModule = mod
                    end
                end
            end    
        end
    end
 

    if self.foundTroughModule ~= nil then
        local fillTypeIndex = self:getFillTypeIndex()

        if self.direction == GC_AnimalTrough.DIRECTIONTOTROUGH then
            local delta = 0   
            local fillLevelTarget = self.target:getFillLevelFromOutputProduct(self.extraParameter)
            if fillLevelTarget > 0 then
                delta = self.foundTroughModule:changeFillLevels(math.min(self.fillLitersPerMS * dt, fillLevelTarget), fillTypeIndex)
                self.target:addFillLevelFromAnimalTroughOutput(-delta, fillTypeIndex, self.extraParameter)    
            end

            if self.lastEffectState and delta == 0 then
                self:setEffectStateEvent({false})
                self.lastEffectState = false
            elseif not self.lastEffectState and delta > 0 then
                self:setEffectStateEvent({true})
                self.lastEffectState = true
            end  
        else
            local delta = self.foundTroughModule:getFillLevel(fillTypeIndex)
            delta = self.target:addFillLevelFromAnimalTroughInput(math.min(self.fillLitersPerMS * dt, delta), fillTypeIndex, self.extraParameter)   
            self.foundTroughModule:changeFillLevels(-delta, fillTypeIndex)
        end
    
    end
end

function GC_AnimalTrough:calcDistance(targetNode)
    local x_t,_,z_t = getWorldTranslation(self.nodeId)
    local x,y,z = getWorldTranslation(targetNode)
    return MathUtil.vector3LengthSq(x - x_t, 0, z - z_t)
end

function GC_AnimalTrough:getFillTypeIndex()
    if self.direction == GC_AnimalTrough.DIRECTIONTOTROUGH then
        return self.target:getFillTypeIndexFromOutputProduct(self.extraParameter)
    else
        return self.target:getFillTypeIndexFromInputProduct(self.extraParameter)
    end
end

function GC_AnimalTrough:setEffectStateEvent(data, noEventSend)
    self:raiseEvent(self.eventId_setEffectState, data, noEventSend)
    if self.isClient then        
        if data[1] then
            g_effectManager:setFillType(self.effects, self:getFillTypeIndex())
            g_effectManager:startEffects(self.effects)
            g_soundManager:playSample(self.samplesLoad)
        else
            g_effectManager:stopEffects(self.effects)
            g_soundManager:stopSample(self.samplesLoad)
        end
    end
end