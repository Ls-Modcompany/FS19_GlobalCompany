-- 
-- GlobalCompany - Triggers - GC_WoodTrigger
-- 
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 19.12.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (19.12.2018):
-- 		- initial fs19
-- 
-- Notes:
-- 		
-- 
--
-- ToDo:
--		- Warning options and remove test prints!!
--


GC_WoodTrigger = {}

local GC_WoodTrigger_mt = Class(GC_WoodTrigger)
InitObjectClass(GC_WoodTrigger, "GC_WoodTrigger")

GC_WoodTrigger.debugIndex = g_company.debug:registerScriptName("GC_WoodTrigger")

g_company.woodTrigger = GC_WoodTrigger

function GC_WoodTrigger:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_WoodTrigger_mt
	end

	local self = {}
	setmetatable(self, customMt)

	self.isServer = isServer
	self.isClient = isClient
	
	self.registerTriggerInStream = false
	self.extraParamater = nil

	return self
end

function GC_WoodTrigger:load(nodeId, target, xmlFile, xmlKey, fillTypeName)
	self.rootNode = nodeId
	self.target = target
	
	self.debugData = g_company.debug:getDebugData(GC_WoodTrigger.debugIndex, target)

	local woodTriggerNode = getXMLString(xmlFile, xmlKey .. "#triggerNode")		
	if woodTriggerNode ~= nil then
		if target.addFillLevel ~= nil and target.getFreeCapacity ~= nil then	
			self.woodTriggerNode = I3DUtil.indexToObject(nodeId, woodTriggerNode, target.i3dMappings)
			if self.woodTriggerNode ~= nil then
		
				self.maxAllowedLength = Utils.getNoNil(getXMLFloat(xmlFile, xmlKey.."#maxAllowedLength"), 0)
				self.maxAllowedAttachments = getXMLFloat(xmlFile, xmlKey.."#maxAllowedAttachments")
		
				self.allowOverfill = Utils.getNoNil(getXMLBool(xmlFile, xmlKey.."#allowTimberOverfill"), true)
		
				if fillTypeName == nil then					
					fillTypeName = getXMLString(xmlFile, xmlKey .. "#convertedFillType")
				end
				
				local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
				self.fillTypeIndex = Utils.getNoNil(fillTypeIndex, FillType.WOODCHIPS)
				
				addTrigger(self.woodTriggerNode, "woodTriggerCallback", self)
				
				return true
			end
		else
			if target.addFillLevel == nil then
				g_company.debug:writeDev(self.debugData, "Target function 'addFillLevel' could not be found!")
			end
			
			if target.getFreeCapacity == nil then
				g_company.debug:writeDev(self.debugData, "Target function 'getFreeCapacity' could not be found!")
			end
		end
	end

	return false
end

function GC_WoodTrigger:delete()
	if self.woodTriggerNode ~= nil and self.woodTriggerNode ~= 0 then
		removeTrigger(self.woodTriggerNode)
		self.woodTriggerNode = nil
	end
end

function GC_WoodTrigger:woodTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if g_currentMission:getIsServer() then
		if onEnter and otherActorId ~= 0 then
			local splitType = g_splitTypeManager.typesByIndex[getSplitType(otherActorId)]

			if splitType ~= nil and splitType.woodChipsPerLiter > 0 then
				local sizeX, sizeY, sizeZ, numConvexes, numAttachments = getSplitShapeStats(otherActorId)
				local volume = getVolume(otherActorId)
				if sizeX ~= nil and volume > 0 then
					local isAccepted = true

					local maxSize = math.max(sizeX, math.max(sizeY, sizeZ))
					if self.maxAllowedLength > 0 then
						if maxSize > (self.maxAllowedLength + 0.2) then -- Increased by 0.2 to allow for imperfections.
							isAccepted = false
						end
					end

					if self.maxAllowedAttachments ~= nil then
						if numAttachments == nil then
							numAttachments = 0
						end
						if numAttachments > self.maxAllowedAttachments then
							isAccepted = false
						end
					end

					if isAccepted then
						local fillLevelDelta = volume * 1000 * splitType.woodChipsPerLiter
						local freeSpace = self:getFreeCapacity(self.fillTypeIndex, farmId)
						local canAdd = (freeSpace >= fillLevelDelta)
						if not canAdd and self.allowOverfill then
							canAdd = (freeSpace > 0)
						end

						if canAdd then
							self:addFillLevel(nil, fillLevelDelta, self.fillTypeIndex)
							delete(otherActorId)
						end
					end
				end
			end
		end
	end
end

function GC_WoodTrigger:getFreeCapacity(fillTypeIndex, farmId)
	if self.target ~= nil then
		return self.target:getFreeCapacity(fillTypeIndex, farmId, self.extraParamater)
	end
	
	return 0
end

function GC_WoodTrigger:addFillLevel(farmId, fillLevelDelta, fillTypeIndex)
	if self.target ~= nil then
		local toolType, fillPositionData = nil, nil
		self.target:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, self.extraParamater)
	end
end