--
-- GlobalCompany - Triggers - GC_UnloadingTrigger
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 09.02.2019
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
--	v1.1.0.0 (09.02.2019):
-- 		- added new function 'setCustomDischargeNotAllowedWarning'
--		- add 'GC_DebugUtils' support.
--
-- 	v1.0.0.0 (19.12.2018):
-- 		- initial fs19
--
-- Notes:
--		- Some script functions part referenced - https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=67&class=7186
--
--		- TOOL TYPES
--			- UNDEFINED (Anything without a given type.)
--			- DISCHARGEABLE (TIPPERS, LIQUID TRAILERS, PIPE, PALLETS)
--			- TRIGGER ()
--			- BALE (BALES)
--
--
--
-- ToDo:
--
--


GC_UnloadingTrigger = {}

local GC_UnloadingTrigger_mt = Class(GC_UnloadingTrigger, UnloadTrigger)
InitObjectClass(GC_UnloadingTrigger, "GC_UnloadingTrigger")

GC_UnloadingTrigger.debugIndex = g_company.debug:registerScriptName("GC_UnloadingTrigger")

g_company.unloadingTrigger = GC_UnloadingTrigger

function GC_UnloadingTrigger:new(isServer, isClient, customMt)
	local self = UnloadTrigger:new(isServer, isClient, customMt or GC_UnloadingTrigger_mt)

	self.registerTriggerInStream = true

	self.isEnabled = true
	self.extraParamater = nil

	self.onlyUpdateOneBale = false
	
	self.nonDischargeNodePallets = {}
	self.palletsInTrigger = 0

	self.useTargetGetIsFillTypeAllowed = true

	return self
end

function GC_UnloadingTrigger:load(nodeId, target, xmlFile, xmlKey, forcedFillTypes, forcedToolTypes)
	self.rootNode = nodeId
	self.target = target

	self.debugData = g_company.debug:getDebugData(GC_UnloadingTrigger.debugIndex, target)	

	local exactFillRootNode = getXMLString(xmlFile, xmlKey .. "#exactFillRootNode")
	if exactFillRootNode ~= nil then
		self.exactFillRootNode = I3DUtil.indexToObject(nodeId, exactFillRootNode, target.i3dMappings)
		if self.exactFillRootNode ~= nil then
			local colMask = getCollisionMask(self.exactFillRootNode)
			if bitAND(FillUnit.EXACTFILLROOTNODE_MASK, colMask) == 0 then
				local name = getName(self.exactFillRootNode)

				if target.i3dMappings ~= nil and target.i3dMappings[exactFillRootNode] ~= nil then
					name = target.i3dMappings[exactFillRootNode]
				end

				g_company.debug:writeModding(self.debugData, "Invalid exactFillRootNode collision mask for 'unloadingTrigger' [%s]. Bit 30 needs to be set!", name)
				return false
			end

			g_currentMission:addNodeObject(self.exactFillRootNode, self)
		end
	end

	local baleTriggerNode = getXMLString(xmlFile, xmlKey .. "#baleTriggerNode")
	if baleTriggerNode ~= nil then
		self.baleTriggerNode = I3DUtil.indexToObject(nodeId, baleTriggerNode, target.i3dMappings)
		if self.baleTriggerNode ~= nil then
			addTrigger(self.baleTriggerNode, "baleTriggerCallback", self)

			local baleDeleteLitersPerSecond = getXMLInt(xmlFile, xmlKey .. "#baleDeleteLitersPerSecond")
			if baleDeleteLitersPerSecond ~= nil then
				self.baleDeleteLitersPerMS = baleDeleteLitersPerSecond * 0.0001
			end
		end
	end
	
	-- This is only needed if you wish to use pallets with no 'dischargeNode'. e.g Giants Liquid Tanks
	local palletTriggerNode = getXMLString(xmlFile, xmlKey .. "#palletTriggerNode")
	if palletTriggerNode ~= nil then
		self.palletTriggerNode = I3DUtil.indexToObject(nodeId, palletTriggerNode, target.i3dMappings)
		if self.palletTriggerNode ~= nil then
			addTrigger(self.palletTriggerNode, "palletTriggerCallback", self)

			local palletDeleteLitersPerSecond = Utils.getNoNil(getXMLInt(xmlFile, xmlKey .. "#palletDeleteLitersPerSecond"), 250)
			if palletDeleteLitersPerSecond > 0 then
				self.palletDeleteLitersPerSecond = palletDeleteLitersPerSecond * 0.001
			end
		end
	end

	if self.exactFillRootNode ~= nil or self.baleTriggerNode ~= nil or self.palletTriggerNode ~= nil then
		if target.addFillLevel ~= nil and target.getFreeCapacity ~= nil then

			local fillTypes = forcedFillTypes
			if fillTypes == nil then
				local fillTypeNames = getXMLString(xmlFile, xmlKey .. "#fillTypes") --Allow adding by fillTypes
				local fillTypeCategories = getXMLString(xmlFile, xmlKey .. "#fillTypeCategories") -- Allow adding by FillTypeCategories.

				if fillTypeCategories ~= nil and fillTypeNames == nil then
					local warning = self.debugData.header .. "Warning: Invalid fillTypeCategory '%s' given at " .. xmlKey .. "."
					fillTypes = g_fillTypeManager:getFillTypesByCategoryNames(fillTypeCategories, warning)
				elseif fillTypeNames ~= nil then
					local warning = self.debugData.header .. "Warning: Invalid fillType '%s' given at " .. xmlKey .. "."
					fillTypes = g_fillTypeManager:getFillTypesByNames(fillTypeNames, warning)
				end
			end

			if fillTypes ~= nil then
				for _, fillTypeInt in pairs(fillTypes) do
					self:setAcceptedFillTypeState(fillTypeInt, true)
				end
			end

			local acceptedToolTypes = forcedToolTypes
			if acceptedToolTypes == nil then
				local toolTypeNames = getXMLString(xmlFile, xmlKey .. "#acceptedToolTypes")
				if toolTypeNames ~= nil then
					acceptedToolTypes = StringUtil.splitString(" ", toolTypeNames)
				else
					acceptedToolTypes = {[1] = "UNDEFINED"}

					if self.exactFillRootNode ~= nil then
						acceptedToolTypes[2] = "DISCHARGEABLE"
					end

					if self.baleTriggerNode ~= nil then
						acceptedToolTypes[#acceptedToolTypes + 1] = "BALE"
					end
				end
			end

			if acceptedToolTypes ~= nil then
				for _, acceptedToolType in pairs(acceptedToolTypes) do
					local toolTypeInt = g_toolTypeManager:getToolTypeIndexByName(acceptedToolType)
					self:setAcceptedToolTypeState(toolTypeInt, true)
				end
			end
		else
			if target.addFillLevel == nil then
				g_company.debug:writeDev(self.debugData, "Target function 'addFillLevel' could not be found!")
			end

			if target.getFreeCapacity == nil then
				g_company.debug:writeDev(self.debugData, "Target function 'getFreeCapacity' could not be found!")
			end

			return false
		end
	else
		g_company.debug:writeModding(self.debugData, "No 'exactFillRootNode' or 'baleTriggerNode' was found!")
		return false
	end

	return true
end

function GC_UnloadingTrigger:addFillUnitFillLevel(farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData)
	local changed = 0

	if self.target ~= nil then
		local freeCapacity = self.target:getFreeCapacity(fillTypeIndex, farmId, self.extraParamater)
		local maxFillDelta = math.min(fillLevelDelta - changed, freeCapacity)
		changed = changed + maxFillDelta

		self.target:addFillLevel(farmId, maxFillDelta, fillTypeIndex, toolType, fillPositionData, self.extraParamater)
	end

	return changed
end

function GC_UnloadingTrigger:delete()
    if self.palletTriggerNode ~= nil and self.palletTriggerNode ~= 0 then
        removeTrigger(self.palletTriggerNode)
        self.palletTriggerNode = 0
    end
    
	GC_UnloadingTrigger:superClass().delete(self)
end

function GC_UnloadingTrigger:update(dt)
    GC_UnloadingTrigger:superClass().update(self, dt)
    
	if self.isServer and self.target ~= nil then
        self:updatePallets(dt)
    end
end

function GC_UnloadingTrigger:updatePallets(dt)
	for objectShapeId, item in pairs (self.nonDischargeNodePallets) do
		local pallet = g_currentMission.nodeToObject[objectShapeId]	
		if item ~= nil and pallet ~= nil then
			local fillUnitIndex = item.fillUnitIndex
			local fillTypeIndex = item.fillTypeIndex
			local fillLevel = pallet:getFillUnitFillLevel(fillUnitIndex)
			local fillLevelDelta = math.min(fillLevel, self.palletDeleteLitersPerSecond * dt)
			
			if fillLevelDelta > 0 then
				self.target:addFillLevel(pallet:getOwnerFarmId(), fillLevelDelta, fillTypeIndex, ToolType.UNDEFINED, nil, self.extraParamater)
				
				local delta = pallet:addFillUnitFillLevel(pallet:getOwnerFarmId(), fillUnitIndex, -fillLevelDelta, fillTypeIndex, ToolType.UNDEFINED, nil)
				local newFillLevel = fillLevel + delta
				if newFillLevel < 0.01 then
					self.palletsInTrigger = self.palletsInTrigger - 1
					self.nonDischargeNodePallets[objectShapeId] = nil
					break
				end
			else
				self.palletsInTrigger = self.palletsInTrigger - 1
				self.nonDischargeNodePallets[objectShapeId] = nil
				break
			end
		else
			self.palletsInTrigger = self.palletsInTrigger - 1
			self.nonDischargeNodePallets[objectShapeId] = nil
			break
		end
	end
	
	if self.palletsInTrigger > 0 then
		self:raiseActive()
	end
end

function GC_UnloadingTrigger:updateBales(dt)
	if self.target ~= nil then
		for index, bale in ipairs(self.balesInTrigger) do
			if bale ~= nil and bale.nodeId ~= 0 then
				if bale.dynamicMountJointIndex == nil then
					local fillTypeIndex = bale:getFillType()
					local fillLevel = bale:getFillLevel()
					local fillPositionData = nil
					local fillLevelDelta = bale:getFillLevel()
					if self.baleDeleteLitersPerMS ~= nil then
						fillLevelDelta = self.baleDeleteLitersPerMS * dt
					end

					if fillLevelDelta > 0 then
						self.target:addFillLevel(bale:getOwnerFarmId(), fillLevelDelta, fillTypeIndex, ToolType.BALE, fillPositionData, self.extraParamater)
						bale:setFillLevel(fillLevel - fillLevelDelta)
						local newFillLevel = bale:getFillLevel()
						if newFillLevel < 0.01 then
							bale:delete()
							table.remove(self.balesInTrigger, index)
							break
						end
						if self.onlyUpdateOneBale then
							break
						end
					end
				end
			else
				table.remove(self.balesInTrigger, index)
			end
		end

		if #self.balesInTrigger > 0 then
			self:raiseActive()
		end
	end
end

function GC_UnloadingTrigger:getIsFillTypeAllowed(fillTypeIndex)
	return self:getIsFillTypeSupported(fillTypeIndex) and self:getFillUnitFreeCapacity(1, fillTypeIndex) > 0
end

function GC_UnloadingTrigger:getIsFillTypeSupported(fillTypeIndex)
	local accepted = self.target ~= nil

	if accepted then
		if self.useTargetGetIsFillTypeAllowed and self.target.getIsFillTypeAllowed ~= nil then
			if not self.target:getIsFillTypeAllowed(fillTypeIndex, self.extraParamater, self) then
				accepted = false
			end
		else
			if self.fillTypes ~= nil then
				if not self.fillTypes[fillTypeIndex] then
					accepted = false
				end
			end
		end
	end

	return accepted
end

function GC_UnloadingTrigger:getIsToolTypeAllowed(toolType)
	local accepted = self.target ~= nil

	if accepted then
		if self.target.getIsToolTypeAllowed ~= nil then
			if not self.target:getIsToolTypeAllowed(toolType) then
				accepted = false
			end
		else
			if self.acceptedToolTypes ~= nil then
				if self.acceptedToolTypes[toolType] ~= true then
					accepted = false
				end
			end
		end
	end

	return accepted
end

function GC_UnloadingTrigger:getFillUnitFreeCapacity(fillUnitIndex, fillTypeIndex, farmId)
	if self.target == nil then
		return 0
	end

	return self.target:getFreeCapacity(fillTypeIndex, farmId, self.extraParamater)
end

function GC_UnloadingTrigger:baleTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if self.isEnabled then
		local object = g_currentMission:getNodeObject(otherId)
		if object ~= nil and object:isa(Bale) then
			if onEnter  then
				local fillTypeIndex = object:getFillType()
				if self:getIsFillTypeAllowed(fillTypeIndex) and self:getIsToolTypeAllowed(ToolType.BALE) then
					if self.target:getFreeCapacity(fillTypeIndex, object:getOwnerFarmId(), self.extraParamater) > 0 then
						table.insert(self.balesInTrigger, object)
						self:raiseActive()
					end
				end
			elseif onLeave then
				for index, bale in ipairs(self.balesInTrigger) do
					if bale == object then
						table.remove(self.balesInTrigger, index)
						break
					end
				end
			end
		end
	end
end

function GC_UnloadingTrigger:palletTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if self.isEnabled and otherShapeId ~= nil then
		local object = g_currentMission:getNodeObject(otherShapeId)
		if object ~= nil and object:isa(Vehicle) and object.typeName == "pallet" and object.spec_dischargeable ~= nil then				
			local dischargeNode = object.spec_dischargeable.currentDischargeNode
			if dischargeNode == nil then
				if onEnter then
					if self.nonDischargeNodePallets[object] == nil then
						local fillUnitIndex = 1
						local fillTypeIndex
						
						local fillUnits = object:getFillUnits()
						for index, fillUnit in ipairs (fillUnits) do
							if self:getIsFillTypeAllowed(fillUnit.fillType) then
								fillUnitIndex = index
								fillTypeIndex = fillUnit.fillType	
								break
							end
						end
				
						if fillTypeIndex ~= nil then
							if self.target:getFreeCapacity(fillTypeIndex, object:getOwnerFarmId(), self.extraParamater) > 0 then
								self.palletsInTrigger = self.palletsInTrigger + 1
								self.nonDischargeNodePallets[otherShapeId] = {fillUnitIndex = fillUnitIndex, fillTypeIndex = fillTypeIndex}								
								self:raiseActive()
							end
						end
					end
				elseif onLeave then
					if self.nonDischargeNodePallets[otherShapeId] ~= nil then
						self.palletsInTrigger = math.max(self.palletsInTrigger - 1, 0)
						self.nonDischargeNodePallets[otherShapeId] = nil
					end
				end
			end
		end
	end
end

function GC_UnloadingTrigger:setAcceptedToolTypeState(toolTypeInt, state)
	if self.acceptedToolTypes == nil then
		self.acceptedToolTypes = {}
	end

	self.acceptedToolTypes[toolTypeInt] = state
end

function GC_UnloadingTrigger:setAcceptedFillTypeState(fillTypeInt, state)
	if self.fillTypes == nil then
		self.fillTypes = {}
	end

	self.fillTypes[fillTypeInt] = state
end

function GC_UnloadingTrigger:setCustomDischargeNotAllowedWarning(text)
	if text ~= nil and text ~= "" then
		self.notAllowedWarningText = text
	else
		self.notAllowedWarningText = nil
	end
end

function GC_UnloadingTrigger:getIsFillAllowedFromFarm(farmId)
	return g_currentMission.accessHandler:canFarmAccess(farmId, self.target)
end