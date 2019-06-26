-- 
-- GlobalCompany - Triggers - GC_WoodTrigger
-- 
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 19.12.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (19.12.2018):
-- 		- initial fs19 (GtX)
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

GC_WoodTrigger.debugIndex = g_company.debug:registerScriptName("WoodTrigger")

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
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' parameter = %s, 'target' parameter = %s 'xmlFile' parameter = %s, 'xmlKey' parameter = %s"
		g_company.debug:logWrite(GC_WoodTrigger.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil)
		return false
	end
	
	self.debugData = g_company.debug:getDebugData(GC_WoodTrigger.debugIndex, target)
	
	self.rootNode = nodeId
	self.target = target

	local woodTriggerNode = getXMLString(xmlFile, xmlKey .. "#triggerNode")		
	if woodTriggerNode ~= nil then
		if target.addFillLevel ~= nil and target.getFreeCapacity ~= nil then	
			self.woodTriggerNode = I3DUtil.indexToObject(nodeId, woodTriggerNode, target.i3dMappings)
			if self.woodTriggerNode ~= nil then
		
				self.maxAllowedLength = Utils.getNoNil(getXMLFloat(xmlFile, xmlKey.."#maxAllowedLength"), 0)
				self.maxAllowedAttachments = getXMLFloat(xmlFile, xmlKey.."#maxAllowedAttachments")
		
				self.allowOverfill = Utils.getNoNil(getXMLBool(xmlFile, xmlKey.."#allowTimberOverfill"), true)
		
				self.showLengthWarnings = Utils.getNoNil(getXMLBool(xmlFile, xmlKey.."#showLengthWarnings"), false) -- Not Done Yet.
				self.showAttachmentsWarning = Utils.getNoNil(getXMLBool(xmlFile, xmlKey.."#showAttachmentsWarning"), false) -- Not Done Yet.
				self.showNoCapacityWarning = Utils.getNoNil(getXMLBool(xmlFile, xmlKey.."#showNoCapacityWarning"), true) -- Not Done Yet.
		
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
							--print(string.format("Log length is greater than set limit of %s  (%s)", self.maxAllowedLength, maxSize)) -- Just for testing until warning is done -)
							-- Maybe added a flashing warning we send to the clients in the trigger area??
						end
					end

					if self.maxAllowedAttachments ~= nil then
						if numAttachments == nil then
							numAttachments = 0
						end
						if numAttachments > self.maxAllowedAttachments then
							isAccepted = false
							--print(string.format("Number of attachments is greater than set limit of %s  (%s)", self.maxAllowedAttachments, numAttachments))  -- Just for testing until warning is done -)
							-- Maybe added a flashing warning we send to the clients in the trigger area??
						end
					end

					if isAccepted then
						local farmId = nil -- Maybe?? Need to see if splitShapes store this like 'nodeObjects'
						local fillLevelDelta = volume * 1000 * splitType.woodChipsPerLiter
						local freeSpace = self:getFreeCapacity(self.fillTypeIndex, farmId)
						local canAdd = (freeSpace >= fillLevelDelta)
						if not canAdd and self.allowOverfill then
							canAdd = (freeSpace > 0)
						end

						if canAdd then
							self:addFillLevel(farmId, fillLevelDelta, self.fillTypeIndex)
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