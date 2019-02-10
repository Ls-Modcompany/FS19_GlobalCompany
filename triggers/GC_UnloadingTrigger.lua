-- 
-- GlobalCompany - Triggers - GC_UnloadingTrigger
-- 
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 09.02.2018
-- @Version: 1.0.0.0
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
-- 		- initial fs19 (GtX)
-- 
-- Notes:
--		- Some script fuctions part referenced - https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=67&class=7186
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
-- 		- debug text needs to be fixed.
--


GC_UnloadingTrigger = {};

local GC_UnloadingTrigger_mt = Class(GC_UnloadingTrigger, UnloadTrigger);
InitObjectClass(GC_UnloadingTrigger, "GC_UnloadingTrigger");

GC_UnloadingTrigger.debugIndex = g_company.debug:registerScriptName("UnloadingTrigger");

g_company.unloadingTrigger = GC_UnloadingTrigger;

function GC_UnloadingTrigger:new(isServer, isClient, customMt)
	if customMt == nil then
        customMt = GC_UnloadingTrigger_mt;
    end;

	local self = UnloadTrigger:new(isServer, isClient, customMt);
	
	self.triggerManagerRegister = true; -- 'GC_TriggerManager' Requirement.
	
	self.isEnabled = true;
	self.extraParamater = nil;
	
    return self;
end;

function GC_UnloadingTrigger:load(nodeId, target, xmlFile, xmlKey, forcedFillTypes, forcedToolTypes)
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' paramater = %s, 'target' paramater = %s 'xmlFile' paramater = %s, 'xmlKey' paramater = %s";
		g_company.debug:logWrite(GC_UnloadingTrigger.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil);
		return false;
	end;
	
	self.debugData = g_company.debug:getDebugData(GC_UnloadingTrigger.debugIndex, target);
	
	self.rootNode = nodeId;
	self.target = target;

	local exactFillRootNode = getXMLString(xmlFile, xmlKey .. "#exactFillRootNode");
	if exactFillRootNode ~= nil then        
		self.exactFillRootNode = I3DUtil.indexToObject(nodeId, exactFillRootNode, target.i3dMappings);
		if self.exactFillRootNode ~= nil then 
			local colMask = getCollisionMask(self.exactFillRootNode)
			if bitAND(FillUnit.EXACTFILLROOTNODE_MASK, colMask) == 0 then			
				local name = getName(self.exactFillRootNode);
				
				if target.i3dMappings ~= nil and target.i3dMappings[exactFillRootNode] ~= nil then
					name = target.i3dMappings[exactFillRootNode];
				end;
			
				g_company.debug:writeModding(self.debugData, "Invalid exactFillRootNode collision mask for 'unloadingTrigger' [%s]. Bit 30 needs to be set!", name);
				return false;
			end;
		
			g_currentMission:addNodeObject(self.exactFillRootNode, self);
		end;
    end;	

	local baleTriggerNode = getXMLString(xmlFile, xmlKey .. "#baleTriggerNode");	
	if baleTriggerNode ~= nil then
		self.baleTriggerNode = I3DUtil.indexToObject(nodeId, baleTriggerNode, target.i3dMappings);
        if self.baleTriggerNode ~= nil then
            addTrigger(self.baleTriggerNode, "baleTriggerCallback", self);
			
			local baleDeleteLitersPerSecond = getXMLInt(xmlFile, xmlKey .. "#baleDeleteLitersPerSecond");
			if baleDeleteLitersPerSecond ~= nil then
				self.baleDeleteLitersPerMS = baleDeleteLitersPerSecond * 0.0001;
			end;
        end;
    end;
	
	if self.exactFillRootNode ~= nil or self.baleTriggerNode ~= nil then
		if target.addFillLevel ~= nil and target.getFreeCapacity ~= nil then
		
			local fillTypes = forcedFillTypes;
			if fillTypes == nil then
				local fillTypeNames = getXMLString(xmlFile, xmlKey .. "#fillTypes"); --Allow adding by fillTypes
				local fillTypeCategories = getXMLString(xmlFile, xmlKey .. "#fillTypeCategories"); -- Allow adding by FillTypeCategories.
		
				if fillTypeCategories ~= nil and fillTypeNames == nil then
					local warning = self.debugData.header .. "Warning: Invalid fillTypeCategory '%s' given at " .. xmlKey .. ".";					
					fillTypes = g_fillTypeManager:getFillTypesByCategoryNames(fillTypeCategories, warning);
				elseif fillTypeNames ~= nil then
					local warning = self.debugData.header .. "Warning: Invalid fillType '%s' given at " .. xmlKey .. ".";
					fillTypes = g_fillTypeManager:getFillTypesByNames(fillTypeNames, warning);
				end;
			end;
			
			if fillTypes ~= nil then
				for _, fillTypeInt in pairs(fillTypes) do
					self:setAcceptedFillTypeState(fillTypeInt, state)
				end;
			end;
			
			local acceptedToolTypes = forcedToolTypes;
			if acceptedToolTypes == nil then
				local toolTypeNames = getXMLString(xmlFile, xmlKey .. "#acceptedToolTypes");			
				if toolTypeNames ~= nil then
					acceptedToolTypes = StringUtil.splitString(" ", toolTypeNames);	
				else
					acceptedToolTypes = {[1] = "UNDEFINED"};
					
					if self.exactFillRootNode ~= nil then
						acceptedToolTypes[2] = "DISCHARGEABLE";
					end;
					
					if self.baleTriggerNode ~= nil then
						acceptedToolTypes[#acceptedToolTypes + 1] = "BALE";
					end;
				end;
			end;
			
			if acceptedToolTypes ~= nil then				
				for _, acceptedToolType in pairs(acceptedToolTypes) do
					local toolTypeInt = g_toolTypeManager:getToolTypeIndexByName(acceptedToolType);
					self:setAcceptedToolTypeState(toolTypeInt, true);
				end;
			end;
		else
			if target.addFillLevel == nil then
				g_company.debug:writeDev(self.debugData, "Target function 'addFillLevel' could not be found!");
			end;
			
			if target.getFreeCapacity == nil then
				g_company.debug:writeDev(self.debugData, "Target function 'getFreeCapacity' could not be found!");
			end;

			return false;
		end;
	else
		g_company.debug:writeModding(self.debugData, "No 'exactFillRootNode' or 'baleTriggerNode' was found!");
		return false;
	end;
    
	return true
end;

function GC_UnloadingTrigger:addFillUnitFillLevel(farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData)
	local changed = 0;
	
	if self.target ~= nil then
		local freeCapacity = self.target:getFreeCapacity(fillTypeIndex, nil, self.extraParamater);
		local maxFillDelta = math.min(fillLevelDelta - changed, freeCapacity);
		changed = changed + maxFillDelta;
		
		self.target:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, self.extraParamater);
	end;
	
	return changed;
end

function GC_UnloadingTrigger:updateBales(dt)
	if self.target ~= nil then	
		for index, bale in ipairs(self.balesInTrigger) do
			if bale ~= nil and bale.nodeId ~= 0 then
				if bale.dynamicMountJointIndex == nil then
					local fillTypeIndex = bale:getFillType();
					local fillLevel = bale:getFillLevel();
					local fillPositionData = nil;
					local fillLevelDelta = bale:getFillLevel();
					if self.baleDeleteLitersPerMS ~= nil then
						fillLevelDelta = self.baleDeleteLitersPerMS * dt;
					end;
	
					if fillLevelDelta > 0 then
						self.target:addFillLevel(bale:getOwnerFarmId(), fillLevelDelta, fillTypeIndex, ToolType.BALE, fillPositionData, self.extraParamater);				
						bale:setFillLevel(fillLevel - fillLevelDelta);
						local newFillLevel = bale:getFillLevel();
						if newFillLevel < 0.01 then
							bale:delete();
							table.remove(self.balesInTrigger, index);
							break;
						end;
					end;
				end;
			else
				table.remove(self.balesInTrigger, index);
			end;
		end;

		if #self.balesInTrigger > 0 then
			self:raiseActive();
		end;
	end;
end;

function GC_UnloadingTrigger:getIsFillTypeAllowed(fillTypeIndex)
	return self:getIsFillTypeSupported(fillTypeIndex) and self:getFillUnitFreeCapacity(1, fillTypeIndex) > 0;
end;

function GC_UnloadingTrigger:getIsFillTypeSupported(fillTypeIndex)
    local accepted = self.target ~= nil;
	
	if accepted then
		if self.target.getIsFillTypeAllowed ~= nil then
			if not self.target:getIsFillTypeAllowed(fillTypeIndex, self.extraParamater) then
				accepted = false;
			end;
		else
			if self.fillTypes ~= nil then
				if not self.fillTypes[fillTypeIndex] then
					accepted = false;
				end;
			end;
		end;
	end;
    
	return accepted;
end;

function GC_UnloadingTrigger:getIsToolTypeAllowed(toolType)
	local accepted = self.target ~= nil;
	
	if accepted then
		if self.target.getIsToolTypeAllowed ~= nil then
			if not self.target:getIsToolTypeAllowed(toolType) then
				accepted = false;
			end;
		else
			if self.acceptedToolTypes ~= nil then
				if self.acceptedToolTypes[toolType] ~= true then
					accepted = false;
				end;
			end;
		end;
	end;
    
	return accepted;
end;

function GC_UnloadingTrigger:getFillUnitFreeCapacity(fillUnitIndex, fillTypeIndex, farmId)
    if self.target == nil then
		return 0;
	end;
	
	return self.target:getFreeCapacity(fillTypeIndex, farmId, self.extraParamater);
end;

function GC_UnloadingTrigger:baleTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if self.isEnabled then
        local object = g_currentMission:getNodeObject(otherId)
        if object ~= nil and object:isa(Bale) then
            if onEnter  then				
				local fillTypeIndex = object:getFillType()				

				if self:getIsFillTypeAllowed(fillTypeIndex) and self:getIsToolTypeAllowed(ToolType.BALE) then
                    if self.target:getFreeCapacity(fillTypeIndex, object:getOwnerFarmId(), self.extraParamater) > 0 then
                        table.insert(self.balesInTrigger, object); 
						self:raiseActive()
                    end;
                end;
            elseif onLeave then
                for index, bale in ipairs(self.balesInTrigger) do
                    if bale == object then
                        table.remove(self.balesInTrigger, index);
                        break;
                    end;
                end;
            end;
        end;
    end;
end;

function GC_UnloadingTrigger:setAcceptedToolTypeState(toolTypeInt, state)	
	if self.acceptedToolTypes == nil then
		self.acceptedToolTypes = {};
	end;
	
	self.acceptedToolTypes[toolTypeInt] = state;
end;

function GC_UnloadingTrigger:setAcceptedFillTypeState(fillTypeInt, state)
	if self.fillTypes == nil then
		self.fillTypes = {};
	end;
	
	self.fillTypes[fillTypeInt] = true;
end;

function GC_UnloadingTrigger:setCustomDischargeNotAllowedWarning(text)
    if text ~= nil and text ~= "" then
		self.notAllowedWarningText = text;
	else
		self.notAllowedWarningText = nil;
	end;
end





