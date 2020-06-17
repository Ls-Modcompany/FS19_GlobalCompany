--
-- GlobalCompany - Triggers - GC_ExtendedFilTypesFillTrigger
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / kevink98
-- @Date: 23.08.2019
-- @Version: 1.2.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.0.0.0 (02.05.2020):
-- 		- initial fs19 (kevink98)
--
--
-- ToDo:
--
--

GC_ExtendedFilTypesFillTrigger = {}

local GC_ExtendedFilTypesFillTrigger_mt = Class(GC_ExtendedFilTypesFillTrigger, g_company.gc_class)
InitObjectClass(GC_ExtendedFilTypesFillTrigger, "GC_ExtendedFilTypesFillTrigger")

GC_ExtendedFilTypesFillTrigger.debugIndex = g_company.debug:registerScriptName("GC_ExtendedFilTypesFillTrigger")

g_company.playerTrigger = GC_ExtendedFilTypesFillTrigger

function GC_ExtendedFilTypesFillTrigger:new(isServer, isClient, customMt)
	local self = GC_ExtendedFilTypesFillTrigger:superClass():new(customMt or GC_ExtendedFilTypesFillTrigger_mt, isServer, isClient);

	self.registerTriggerInStream = false

	return self
end

function GC_ExtendedFilTypesFillTrigger:finalizePlacement()
	GC_ExtendedFilTypesFillTrigger:superClass().finalizePlacement(self)	
	self.eventId_setAnimationState = self:registerEvent(self, self.setAnimationState, false, false)  	
end

function GC_ExtendedFilTypesFillTrigger:load(nodeId, target, xmlFile, xmlKey, reference)
	if nodeId == nil or target == nil then
		return false
	end
	
    self.debugData = g_company.debug:getDebugData(GC_ExtendedFilTypesFillTrigger.debugIndex, target)
    
	self.rootNode = nodeId
	self.target = target
	self.reference = reference
	
	self.objectsInTrigger = {}

	if xmlFile ~= nil and xmlKey ~= nil then
		local triggerNode = getXMLString(xmlFile, xmlKey .. "#node")
		if not self:setTriggerNode(triggerNode) then
			g_company.debug:logWrite(self.debugData, GC_DebugUtils.MODDING, "Error loading 'triggerNode' %s!", triggerNode)
		end

		self.fillLitersPerSecond = Utils.getNoNil(getXMLInt(xmlFile, xmlKey .. "#fillLitersPerSecond"), 10)
		
		local effectNode = getXMLString(xmlFile, xmlKey .. "#effect")
		if effectNode ~= nil then
			self.effect = I3DUtil.indexToObject(self.rootNode, effectNode, self.target.i3dMappings)
			setVisibility(self.effect, false)	
		end
	end	

	self.isUnloading = false

	g_company.addRaisedUpdateable(self)
        
	return true
end

function GC_ExtendedFilTypesFillTrigger:setTriggerNode(triggerNode)
	if triggerNode ~= nil then
		self.triggerNode = I3DUtil.indexToObject(self.rootNode, triggerNode, self.target.i3dMappings)
		if self.triggerNode ~= nil then
			--if RaycastUtil.MASK.TRIGGER_PLAYER ~= getCollisionMask(self.playerTriggerNode) then
				--g_company.debug:logWrite(self.debugData, GC_DebugUtils.WARNING, "Playertrigger %s should have collisionMask! Need only Bit 20", self.playerTriggerNode);
			--end;
			addTrigger(self.triggerNode, "triggerCallback", self)
			return true
		end
	end

	return false
end

function GC_ExtendedFilTypesFillTrigger:delete()
	if self.triggerNode ~= nil and self.triggerNode ~= 0 then
		removeTrigger(self.triggerNode)
		self.triggerNode = nil
	end	
end

function GC_ExtendedFilTypesFillTrigger:setAcceptedFillType(fillTypeIndex)
	self.fillTypeIndex = fillTypeIndex
end

function GC_ExtendedFilTypesFillTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
		local object = g_currentMission:getNodeObject(otherShapeId)
		if object ~= nil then
			if object:isa(Vehicle) and object.typeName:find("gcProductionItem") then				
				if onEnter then
					if self.objectsInTrigger[otherShapeId] == nil and self.fillTypeIndex ~= nil then
						if object:isAcceptExtendedFillType(self.fillTypeIndex) then
							self.objectsInTrigger[otherShapeId] = true							
							self:raiseUpdate()
						end		
					end
				elseif onLeave then
					self.objectsInTrigger[otherShapeId] = nil
				end
			end
        end
    end
end

function GC_ExtendedFilTypesFillTrigger:update(dt)	
	if self.isServer and self.target ~= nil then	
		local isUnloading = false
		for otherShapeId, state in pairs(self.objectsInTrigger) do
			local object = g_currentMission:getNodeObject(otherShapeId)

            if object ~= nil then
                local filltype = g_company.fillTypeManager:getExtendedFillTypeByIndex(self.fillTypeIndex)
                
                local fillLevel = self.target:getProvidedFillLevel(self.fillTypeIndex, object:getOwnerFarmId(), self.extraParamater)			
                local freeCapacity = object:getFreeExtendedFillLevel()
                				
				local fillLevelDelta = (self.fillLitersPerSecond / 1000) * dt
				fillLevelDelta = math.min(fillLevelDelta, freeCapacity, fillLevel)
				
				if fillLevelDelta > 0 then
					local delta = object:addExtendedFillLevel(fillLevelDelta, filltype.index)
					self.target:removeFillLevel(object:getOwnerFarmId(), delta, filltype.index, self.extraParamater)
					isUnloading = true
				end			
			else
				self.objectsInTrigger[otherShapeId] = nil
			end
		end
		
		if g_company.utils.getTableLength(self.objectsInTrigger) > 0 then
			self:raiseUpdate()
		else
			isUnloading = false
		end	

		if isUnloading ~= self.isUnloading then
			self.isUnloading = isUnloading
			self:setAnimationState({self.isUnloading})
		end
	end			
end

function GC_ExtendedFilTypesFillTrigger:setAnimationState(data, noEventSend)
    self:raiseEvent(self.eventId_setAnimationState, data, noEventSend)	
	
	if self.isClient and self.effect ~= nil then
		setVisibility(self.effect, data[1])		
	end
end