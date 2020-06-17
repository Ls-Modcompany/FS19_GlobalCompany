--
-- GlobalCompany - Triggers - GC_ExtendedFillTypesTrigger
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

GC_ExtendedFillTypesTrigger = {}

local GC_ExtendedFillTypesTrigger_mt = Class(GC_ExtendedFillTypesTrigger)
InitObjectClass(GC_ExtendedFillTypesTrigger, "GC_ExtendedFillTypesTrigger")

GC_ExtendedFillTypesTrigger.debugIndex = g_company.debug:registerScriptName("GC_ExtendedFillTypesTrigger")

g_company.playerTrigger = GC_ExtendedFillTypesTrigger

function GC_ExtendedFillTypesTrigger:new(isServer, isClient, customMt)
	local self = {}
	setmetatable(self, customMt or GC_ExtendedFillTypesTrigger_mt)
	
	self.isServer = isServer
	self.isClient = isClient
	
	self.isEnabled = true

	self.registerTriggerInStream = false

	return self
end

function GC_ExtendedFillTypesTrigger:load(nodeId, target, xmlFile, xmlKey, reference)
	if nodeId == nil or target == nil then
		return false
	end
	
    self.debugData = g_company.debug:getDebugData(GC_ExtendedFillTypesTrigger.debugIndex, target)
    
	self.rootNode = nodeId
	self.target = target
	self.reference = reference
	
	self.fillTypes = {}
	self.objectsInTrigger = {}

	if self.isServer and xmlFile ~= nil and xmlKey ~= nil then
		local triggerNode = getXMLString(xmlFile, xmlKey .. "#node")
		if not self:setTriggerNode(triggerNode) then
			g_company.debug:logWrite(self.debugData, GC_DebugUtils.MODDING, "Error loading 'triggerNode' %s!", triggerNode)
		end
		g_company.addRaisedUpdateable(self)
		g_currentMission:addNodeObject(self.triggerNode, self)
	end	

	self.fillLitersPerSecond = Utils.getNoNil(getXMLInt(xmlFile, xmlKey .. "#fillLitersPerSecond"), 0)

	
	return true
end

function GC_ExtendedFillTypesTrigger:setTriggerNode(triggerNode)
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

function GC_ExtendedFillTypesTrigger:delete()
	if self.triggerNode ~= nil and self.triggerNode ~= 0 then
		removeTrigger(self.triggerNode)
		g_currentMission:removeNodeObject(self.triggerNode)
		self.triggerNode = nil
	end	
	g_company.removeRaisedUpdateable(self)
end

function GC_ExtendedFillTypesTrigger:setAcceptedFillTypeState(fillTypeIndex, state)
	self.fillTypes[fillTypeIndex] = state
end

function GC_ExtendedFillTypesTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if onEnter or onLeave then
		local object = g_currentMission:getNodeObject(otherShapeId)
		if object ~= nil then
			if object:isa(Vehicle) and object.typeName:find("gcProductionItem") then
				
				if onEnter then
					if self.objectsInTrigger[otherShapeId] == nil then
						local filltypeIndex = object:getCurrentExtendedFillType()
						local filltype = g_company.fillTypeManager:getExtendedFillTypeByIndex(filltypeIndex)
						if filltype ~= nil and filltype.name ~= nil and self.fillTypes[filltype.index] then
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

function GC_ExtendedFillTypesTrigger:update(dt)	
	if self.isServer and self.target ~= nil then	
		for otherShapeId, state in pairs(self.objectsInTrigger) do
			local object = g_currentMission:getNodeObject(otherShapeId)

			if object ~= nil then
				local filltypeIndex = object:getCurrentExtendedFillType()
				local filltype = g_company.fillTypeManager:getExtendedFillTypeByIndex(filltypeIndex)
				if filltype ~= nil then
					local fillLevel = object:getExtendedFillLevel()					
					local freeCapacity = self.target:getFreeCapacity(filltype.index, object:getOwnerFarmId(), self.extraParamater)
					
					local fillLevelDelta = fillLevel
					if self.fillLitersPerSecond ~= 0 then
						fillLevelDelta = math.min((self.fillLitersPerSecond / 1000) * dt, fillLevelDelta)
					end
					fillLevelDelta = math.min(freeCapacity, fillLevelDelta)
					
					if fillLevelDelta > 0 then
						local delta = object:addExtendedFillLevel(fillLevelDelta * -1, filltype.index)
						if freeCapacity - delta < 0.01 then delta = freeCapacity end
						self.target:addFillLevel(object:getOwnerFarmId(), delta, filltype.index, ToolType.UNDEFINED, nil, self.extraParamater)
					end	
				end		
			else
				self.objectsInTrigger[otherShapeId] = nil
			end
		end

		if g_company.utils.getTableLength(self.objectsInTrigger) > 0 then
			self:raiseUpdate()
		end
    end	
end