--
-- GlobalCompany - Triggers - GC_AnimalLoadingTrigger
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 15.06.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
--
-- 	v1.0.0.0 (15.06.2019):
-- 		- initial fs19
--
-- Notes:
--		- Some script functions part referenced - https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=67&class=10081
--
--
-- ToDo:
--
--


GC_AnimalLoadingTrigger = {}

local GC_AnimalLoadingTrigger_mt = Class(GC_AnimalLoadingTrigger, Object)
InitObjectClass(GC_AnimalLoadingTrigger, "GC_AnimalLoadingTrigger")

GC_AnimalLoadingTrigger.debugIndex = g_company.debug:registerScriptName("GC_AnimalLoadingTrigger")

g_company.animalLoadingTrigger = GC_AnimalLoadingTrigger

function GC_AnimalLoadingTrigger:new(isServer, isClient)
    local self = Object:new(isServer, isClient, GC_AnimalLoadingTrigger_mt)

	self.title = g_i18n:getText("ui_farm")
	self.activateText = g_i18n:getText("animals_openAnimalScreen")
	
	self.text1 = g_company.languageManager:getText("GC_Factory_Animal_Dialogue1")
	self.text2 = g_company.languageManager:getText("GC_Factory_Animal_Dialogue2")

	self.triggerNode = nil
	
	self.isEnabled = true
	
	self.animals = nil
	self.isActivatableAdded = false   
	
	self.loadingVehicle = nil
	
	self.activatedTarget = nil
    self.objectActivated = false
	
	self.conversionData = nil
	
	self.registerTriggerInStream = true
	self.extraParamater = nil

	self.isInput = true
	self.subFillType = nil
   
   return self
end

function GC_AnimalLoadingTrigger:setDirection(isInput)
	self.isInput = Utils.getNoNil(isInput, true)
end

function GC_AnimalLoadingTrigger:setSubFillType(subFillType)
	self.subFillType = subFillType
end

function GC_AnimalLoadingTrigger:load(nodeId, target, xmlFile, xmlKey, conversionData)
	self.rootNode = nodeId
	self.target = target

	self.debugData = g_company.debug:getDebugData(GC_AnimalLoadingTrigger.debugIndex, target)
	
	if conversionData == nil then
		g_company.debug:writeDev(self.debugData, "No animal conversionData given for %s!", xmlKey)
		return false
	end
	
	local triggerNode = getXMLString(xmlFile, xmlKey .. "#triggerNode")
	if triggerNode ~= nil then
		self.triggerNode = I3DUtil.indexToObject(nodeId, triggerNode, target.i3dMappings)
		if self.triggerNode ~= nil then			
			addTrigger(self.triggerNode, "triggerCallback", self)
	
			self.conversionData = conversionData
		end
	end
	
	if self.triggerNode == nil then
		g_company.debug:writeModding(self.debugData, "Failed to load! No 'triggerNode' was found!")
		return false
	end

    return true
end

function GC_AnimalLoadingTrigger:delete()
    g_currentMission:removeActivatableObject(self)
    
	if self.triggerNode ~= nil then
        removeTrigger(self.triggerNode)
        self.triggerNode = nil
    end
end

function GC_AnimalLoadingTrigger:setTitleName(name)
	if name ~= nil then
		self.title = name
	end
end

function GC_AnimalLoadingTrigger:setDialogueText(text)
	if text ~= nil then
		self.text = text
	end
end

function GC_AnimalLoadingTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    if self.isEnabled and (onEnter or onLeave) then
        local vehicle = g_currentMission.nodeToObject[otherId]
        if vehicle ~= nil and vehicle.getSupportsAnimalType ~= nil then
            if onEnter then
				if (self.isInput and vehicle:getCurrentAnimalType() ~= nil) or not self.isInput then
					self:setLoadingTrailer(vehicle)
				end
            elseif onLeave then
                if vehicle == self.loadingVehicle then
                    self:setLoadingTrailer(nil)
                end                
				
				if vehicle == self.activatedTarget then
                    self.objectActivated = false
                end
            end
        end
    end
end

function GC_AnimalLoadingTrigger:setLoadingTrailer(loadingVehicle)
    if self.loadingVehicle ~= nil and self.loadingVehicle.setLoadingTrigger ~= nil then
        self.loadingVehicle:setLoadingTrigger(nil)
    end
    
	self.loadingVehicle = loadingVehicle
    
	if self.loadingVehicle ~= nil and self.loadingVehicle.setLoadingTrigger ~= nil then
        self.loadingVehicle:setLoadingTrigger(self)
    end
   
	self:updateActivatableObject()
end

function GC_AnimalLoadingTrigger:updateActivatableObject()
    if self.loadingVehicle ~= nil then
        if not self.isActivatableAdded then
            self.isActivatableAdded = true
            g_currentMission:addActivatableObject(self)
        end
    else
        if self.isActivatableAdded and self.loadingVehicle == nil then
            g_currentMission:removeActivatableObject(self)
            self.isActivatableAdded = false
            self.objectActivated = false
        end
    end
end

function GC_AnimalLoadingTrigger:getIsActivatable(vehicle)
    local canAccess = self.target:getOwnerFarmId() == g_currentMission:getFarmId()
    
	if g_gui.currentGui == nil and self.isEnabled and canAccess then
        local rootAttacherVehicle = nil
        if self.loadingVehicle ~= nil then
            rootAttacherVehicle = self.loadingVehicle:getRootVehicle()
        end
        
		return rootAttacherVehicle == g_currentMission.controlledVehicle
    end
    
	return false
end

function GC_AnimalLoadingTrigger:drawActivate()
end

function GC_AnimalLoadingTrigger:getAnimalTypeAccepted(typeName)
	if self.conversionData ~= nil and self.conversionData[typeName] ~= nil then
		return true
	end
	
	return false
end

function GC_AnimalLoadingTrigger:getConversionDataPerAnimal(typeName)
	if self.conversionData ~= nil and self.conversionData[typeName] ~= nil then
		return self.conversionData[typeName]
	end
	
	return 1
end

function GC_AnimalLoadingTrigger:getFreeCapacity(typeName, farmId)
	if self.subFillType ~= nil and self.subFillType.fillType ~= nil then	
		local factor = self.conversionData[typeName]		
		if factor ~= nil then
			local freeCapacity = self.target:getFreeCapacity(self.subFillType.fillType, farmId, self.extraParamater)
			local mod = freeCapacity % factor
			
			-- Allow overfilling if it is less than half.
			if mod < (factor * 0.5) then
				return MathUtil.round(freeCapacity / factor, 0) + 1
			end
			
			return MathUtil.round(freeCapacity / factor, 0)
		end
	end
	
	return 0
end

function GC_AnimalLoadingTrigger:getNumAnimals(typeName, farmId)
	local animals = self.target:getAnimlsNum(self.subFillType.fillType, farmId, self.extraParamater)
	return math.floor(animals/self.conversionData[typeName])
end

function GC_AnimalLoadingTrigger:getAnimalsNumAndFreeCapacity(typeName)
	local animals, freeCapacity
	if self.isInput then
		animals = g_company.utils.getTableLength(self.activatedTarget:getAnimals())
		freeCapacity = self:getFreeCapacity(typeName, self.activatedTarget:getOwnerFarmId())
	else
		animals = self:getNumAnimals(typeName, self.activatedTarget:getOwnerFarmId())
		local place = self.activatedTarget.spec_livestockTrailer.animalTypeToPlaces[self.subFillType.type]
		freeCapacity = g_company.utils.getTableLength(place.slots) - place.numUsed
	end
	return animals, freeCapacity
end

function GC_AnimalLoadingTrigger:onActivateObject()
    g_currentMission:removeActivatableObject(self)
    
	self.isActivatableAdded = false
    self.objectActivated = true
	self.activatedTarget = self.loadingVehicle
	
	if self.subFillType == nil then
		self.subFillType = self.activatedTarget:getAnimals()[1]:getSubType()
	end
	
	if (self.isInput and self:getAnimalTypeAccepted(self.subFillType.type)) or not self.isInput then
		local animals, freeCapacity = self:getAnimalsNumAndFreeCapacity(self.subFillType.type)
	
		local dialog = g_gui:showDialog("GC_AnimalDeliveryDialog")
		if dialog ~= nil then
			dialog.target:setTitle(self.title)
			if self.isInput then
				dialog.target:setText(self.text1)
			else
				dialog.target:setText(self.text2)
			end
			dialog.target:setDialogData(animals, freeCapacity, self.subFillType, self.isInput)
			dialog.target:setCallback(self.doDeliveryCallback, self)
		end
	else
		g_currentMission:showBlinkingWarning(g_i18n:getText("animals_invalidAnimalType"), 5000)
	end
end

function GC_AnimalLoadingTrigger:doDeliveryCallback(numberToDeliver)
	if self.objectActivated and self.activatedTarget ~= nil then
		if numberToDeliver > 0 then
			if not self.isServer then
				g_client:getServerConnection():sendEvent(GC_AnimalLoadingTriggerEvent:new(self, self.activatedTarget, numberToDeliver))
			else
				self:deliverAnimals(self.activatedTarget, numberToDeliver)
			end
		end
	else
		g_currentMission:showBlinkingWarning(g_i18n:getText("animals_transportTargetLeftTrigger"), 5000)
	end
	
	self.activatedTarget = nil
    self.objectActivated = false
end

function GC_AnimalLoadingTrigger:deliverAnimals(animalTrailer, numberToDeliver)
	if not self.isServer or animalTrailer == nil then
        return
    end

	local animals = animalTrailer:getAnimals()
	local numAnimal = #animals

	if self.subFillType == nil then
		self.subFillType = animals[1]:getSubType()
	end
	
	if self.isInput then
		if numAnimal > 0 then
			local typeName = animalTrailer:getCurrentAnimalType()
			if self:getAnimalTypeAccepted(typeName) then
				local fillTypeIndex = self.subFillType.fillType
				if fillTypeIndex ~= nil then
					local farmId = animalTrailer:getOwnerFarmId()
					local litresPerAnimal = self:getConversionDataPerAnimal(typeName)
					local freeCapacity = self:getFreeCapacity(typeName, subType, farmId)
				
					local maxAvailableAnimals = math.min(numberToDeliver, numAnimal)
					local numberToRemove = math.min(maxAvailableAnimals, freeCapacity)
		
					local animalsToRemove = {}
					for i = 1, numberToRemove do
						table.insert(animalsToRemove, animals[i])
					end

					animalTrailer:removeAnimals(animalsToRemove)
					self.target:addFillLevel(farmId, litresPerAnimal * numberToRemove, fillTypeIndex, ToolType.UNDEFINED, nil, self.extraParamater)
				end
			end
		end
	else
		local fillTypeIndex = self.subFillType.fillType
		if fillTypeIndex ~= nil then
			local farmId = animalTrailer:getOwnerFarmId()
			local litresPerAnimal = self:getConversionDataPerAnimal(self.subFillType.type)		

			local place = animalTrailer.spec_livestockTrailer.animalTypeToPlaces[self.subFillType.type]
			local freeCapacity = g_company.utils.getTableLength(place.slots) - place.numUsed	
								
			numAnimal = self:getNumAnimals(self.subFillType.type, self.activatedTarget:getOwnerFarmId())
			local maxAvailableAnimals = math.min(numberToDeliver, numAnimal)
			local numberToAdd = math.min(maxAvailableAnimals, freeCapacity)

			for i = 1, numberToAdd do
				local newAnimal = Animal.createFromFillType(self.isServer, self.isClient, nil, fillTypeIndex)
				newAnimal:register()
				animalTrailer:addAnimal(newAnimal)
			end
			
			self.target:removeFillLevel(farmId, litresPerAnimal * numberToAdd, fillTypeIndex, self.extraParamater)
		end
	end
end