--
-- GlobalCompany - Triggers - GC_VehicleTrigger
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98 
-- @Date: 02.04.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.0.0.0 (02.04.2020):
-- 		- initial fs19 (kevink98)
--
-- Notes:
--
-- ToDo:
--
--


GC_VehicleTrigger = {}

local GC_Baletrigger_mt = Class(GC_VehicleTrigger, Object)
InitObjectClass(GC_VehicleTrigger, "GC_VehicleTrigger")
GC_VehicleTrigger.debugIndex = g_company.debug:registerScriptName("GC_VehicleTrigger")

g_company.vehicleTrigger = GC_VehicleTrigger

function GC_VehicleTrigger:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_Baletrigger_mt
	end

	local self = Object:new(isServer, isClient, customMt)

	self.registerTriggerInStream = true

    self.triggerVehicles = {}

	return self
end

function GC_VehicleTrigger:load(nodeId, target, xmlFile, xmlKey, reference)
	if nodeId == nil or target == nil then
		return false
	end

	self.debugData = g_company.debug:getDebugData(GC_VehicleTrigger.debugIndex, target)

	self.rootNode = nodeId
	self.target = target
    self.reference = reference
	

	if xmlFile ~= nil and xmlKey ~= nil then
		local triggerNode = getXMLString(xmlFile, xmlKey .. "#triggerNode")
		if not self:setTriggerNode(triggerNode) then
			g_company.debug:logWrite(self.debugData, GC_DebugUtils.MODDING, "Error loading 'triggerNode' %s!", triggerNode)
		end
	end

    return true
end

function GC_VehicleTrigger:setTriggerNode(triggerNode)
	if triggerNode ~= nil then
		self.triggerNode = I3DUtil.indexToObject(self.rootNode, triggerNode, self.target.i3dMappings)
		if self.triggerNode ~= nil then
			addTrigger(self.triggerNode, "triggerCallback", self)
			return true
		end
	end

	return false
end

function GC_VehicleTrigger:delete()
	if self.triggerNode ~= nil then
		removeTrigger(self.triggerNode)
	end
end

function GC_VehicleTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
        local vehicle = g_currentMission.nodeToObject[otherId]
        if vehicle ~= nil then
            print(string.format("GC_VehicleTrigger triggerCallback %s %s %s %s", onEnter, onLeave, otherId, otherShapeId))
            self.triggerVehicles[vehicle] = onEnter
        end
    end
end

function GC_VehicleTrigger:getVehicles()
    return self.triggerVehicles
end