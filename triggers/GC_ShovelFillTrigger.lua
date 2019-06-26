--
-- GlobalCompany - Triggers - GC_ShovelFillTrigger
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 12.06.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (12.06.2019):
-- 		- initial fs19 (GtX)
--
-- Notes:
--
--
-- ToDo:
--
--

GC_ShovelFillTrigger = {}

local GC_ShovelFillTrigger_mt = Class(GC_ShovelFillTrigger)
InitObjectClass(GC_ShovelFillTrigger, "GC_ShovelFillTrigger")

GC_ShovelFillTrigger.debugIndex = g_company.debug:registerScriptName("GC_ShovelFillTrigger")

g_company.shovelFillTrigger = GC_ShovelFillTrigger

function GC_ShovelFillTrigger:new(isServer, isClient, customMt)
	local self = {}
	setmetatable(self, customMt or GC_ShovelFillTrigger_mt)

	self.isServer = isServer
	self.isClient = isClient
	
	self.registerTriggerInStream = false

	self.isEnabled = true
	self.extraParamater = nil

	self.shovelsInTrigger = {}
	self.numShovelsInTrigger = 0

	return self
end

function GC_ShovelFillTrigger:load(nodeId, source, xmlFile, xmlKey, forcedFillType)
	self.rootNode = nodeId
	self.source = source

	self.debugData = g_company.debug:getDebugData(GC_ShovelFillTrigger.debugIndex, source)

	if self.isServer then
		local triggerNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. "#node"), self.source.i3dMappings)
		if triggerNode ~= nil then
			if source.removeFillLevel ~= nil then
				local fillTypeIndex = forcedFillType
				if fillTypeIndex == nil then
					local fillTypeName = getXMLString(xmlFile, xmlKey .. "#fillType")
					fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
				end

				if fillTypeIndex ~= nil then
					self.fillTypeIndex = fillTypeIndex

					self.triggerNode = triggerNode
					addTrigger(self.triggerNode, "shovelFillTriggerCallback", self)

					g_company.addRaisedUpdateable(self)
					g_currentMission:addNodeObject(self.triggerNode, self)
				end
			else
				if source.removeFillLevel == nil then
					g_company.debug:writeDev(self.debugData, "Source function 'removeFillLevel' could not be found!")
				end

			end
		else
			g_company.debug:writeModding(self.debugData, "'node' could not be found at %s!", xmlKey)
		end
	end

	return true
end

function GC_ShovelFillTrigger:delete()
	if self.isServer then
		g_company.removeRaisedUpdateable(self)

		if self.triggerNode ~= nil and self.triggerNode ~= 0 then
			removeTrigger(self.triggerNode)
		end

		g_currentMission:removeNodeObject(self.triggerNode)
	end
end

function GC_ShovelFillTrigger:update(dt)
	if self.isServer and self.numShovelsInTrigger > 0 then
		for objectShapeId, inTrigger in pairs (self.shovelsInTrigger) do
			local shovel = g_currentMission.nodeToObject[objectShapeId]
			if inTrigger and shovel ~= nil then
				for _, shovelNode in pairs(shovel.spec_shovel.shovelNodes) do
					if shovel:getShovelNodeIsActive(shovelNode) then
						local fillLevel = shovel:getFillUnitFillLevel(shovelNode.fillUnitIndex)
						local capacity = shovel:getFillUnitCapacity(shovelNode.fillUnitIndex)
						if fillLevel < capacity then
							local pickupFillType = shovel:getFillUnitFillType(shovelNode.fillUnitIndex)
							if fillLevel / capacity < shovel:getFillTypeChangeThreshold() then
								pickupFillType = FillType.UNKNOWN
							end

							local farmId = shovel:getOwnerFarmId()
							local available = self:getSourceFillLevel(self.fillTypeIndex, farmId)
							local deltaFillLevel = math.min(capacity - fillLevel, available)

							if pickupFillType == FillType.UNKNOWN or pickupFillType == self.fillTypeIndex then
								pickupFillType = self.fillTypeIndex

								local fillFactor = 0.001
								if shovelNode.needsMovement then
									local movementSpeed = math.min(math.abs(shovel:getLastSpeed()), 6)
									fillFactor = movementSpeed * 0.0001
								end

								local litersPerSecond = math.min(shovelNode.fillLitersPerSecond, 10000)
								deltaFillLevel = math.min(deltaFillLevel, litersPerSecond * dt * fillFactor)

								local loadInfo = shovel:getFillVolumeLoadInfo(shovelNode.loadInfoIndex)
								local deltaAdded = shovel:addFillUnitFillLevel(farmId, shovelNode.fillUnitIndex, deltaFillLevel, pickupFillType, ToolType.UNDEFINED, loadInfo)

								if deltaAdded > 0 then
									local newFillLevel = self.source:removeFillLevel(farmId, deltaAdded, self.fillTypeIndex, self.extraParamater)
									if newFillLevel < 0.0001 then
										self.currentVehicleNode = nil
									end
								end
							end
						end
					end
				end
			else
				self.shovelsInTrigger[objectShapeId] = nil
				self.numShovelsInTrigger = math.max(self.numShovelsInTrigger - 1, 0)
			end
		end

		self:raiseUpdate()
	end
end

-- I do it this way so you can overwrite this function if you wish :-)
function GC_ShovelFillTrigger:getSourceFillLevel(fillTypeIndex, farmId)
	if self.source.getProvidedFillLevel ~= nil then
		return self.source:getProvidedFillLevel(fillTypeIndex, farmId, self.extraParamater)
	end

	return 0
end

function GC_ShovelFillTrigger:shovelFillTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if self.isEnabled then
		if otherShapeId ~= nil and (onEnter or onLeave) then
			local object = g_currentMission:getNodeObject(otherShapeId)
			if object ~= nil and object:isa(Vehicle) and object.spec_shovel ~= nil then

				if onEnter then
					if self.shovelsInTrigger[otherShapeId] == nil then
						self.shovelsInTrigger[otherShapeId] = true
						self.numShovelsInTrigger = self.numShovelsInTrigger + 1
					end
				else
					if self.shovelsInTrigger[otherShapeId] ~= nil then
						self.shovelsInTrigger[otherShapeId] = nil
						self.numShovelsInTrigger = math.max(self.numShovelsInTrigger - 1, 0)
					end
				end

				self:raiseUpdate()
			end
		end
	end
end