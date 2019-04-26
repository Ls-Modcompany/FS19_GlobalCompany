--
-- GlobalCompany - Triggers - GC_PalletExtendedTrigger
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98 
-- @Date: 08.03.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.0.0.0 (08.03.2018):
-- 		- initial fs19 (kevink98)
--
-- Notes:
--
-- ToDo:
--
--


GC_PalletExtendedTrigger = {};

local GC_PalletExtendedTrigger_mt = Class(GC_PalletExtendedTrigger, Object);
InitObjectClass(GC_PalletExtendedTrigger, "GC_PalletExtendedTrigger");
GC_PalletExtendedTrigger.debugIndex = g_company.debug:registerScriptName("GC_PalletExtendedTrigger");

g_company.baleTrigger = GC_PalletExtendedTrigger;

GC_PalletExtendedTrigger.MODE_COUNTER = 0;

function GC_PalletExtendedTrigger:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_PalletExtendedTrigger_mt;
	end;

	local self = Object:new(isServer, isClient, customMt);

	self.triggerManagerRegister = true;

	return self;
end

function GC_PalletExtendedTrigger:load(nodeId, target, xmlFile, xmlKey, reference, mode)
	if nodeId == nil or target == nil then
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_PalletExtendedTrigger.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;
    self.reference = reference;
    self.mode = mode;
	
	self.palletInsideCounter = 0;

	if xmlFile ~= nil and xmlKey ~= nil then
		local palletTriggerNode = getXMLString(xmlFile, xmlKey .. "#palletTriggerNode");
		if not self:setTriggerNode(palletTriggerNode) then
			g_company.debug:logWrite(self.debugData, GC_DebugUtils.MODDING, "Error loading 'palletTriggerNode' %s!", palletTriggerNode);
		end;
	end;

    return true;
end;

function GC_PalletExtendedTrigger:setTriggerNode(palletTriggerNode)
	if palletTriggerNode ~= nil then
		self.palletTriggerNode = I3DUtil.indexToObject(self.rootNode, palletTriggerNode, self.target.i3dMappings);
		if self.palletTriggerNode ~= nil then
			addTrigger(self.palletTriggerNode, "palletTriggerCallback", self);
			return true;
		end;
	end;

	return false;
end;

function GC_PalletExtendedTrigger:delete()
	if self.palletTriggerNode ~= nil then
		removeTrigger(self.palletTriggerNode);
	end;
end;

function GC_PalletExtendedTrigger:palletTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local object = g_currentMission:getNodeObject(otherId)
	if object ~= nil and object.isPalletExtended then
        print("callback")
        --[[
        if onEnter then	
			if self.mode == GC_PalletExtendedTrigger.MODE_COUNTER then
				self.palletInsideCounter = self.palletInsideCounter + 1;
				if self.target.onEnterBaleTrigger ~= nil then
					self.target:onEnterBaleTrigger(self.reference, object);
				end;
			end;
		elseif onLeave then
			if self.mode == GC_PalletExtendedTrigger.MODE_COUNTER then
				self.palletInsideCounter = math.max(self.palletInsideCounter - 1, 0);
				if self.target.onLeaveBaleTrigger ~= nil then
					self.target:onLeaveBaleTrigger(self.reference, object);
				end;
			end;
        end;
        ]]--
	end;
end;

function GC_PalletExtendedTrigger:getTriggerEmpty()
	return self.palletInsideCounter == 0;
end;

function GC_PalletExtendedTrigger:getTriggerNotEmpty()
	return self.palletInsideCounter ~= 0;
end;

function GC_PalletExtendedTrigger:reset()
	self.palletInsideCounter = 0;
end;

function GC_PalletExtendedTrigger:getNum()
	return self.palletInsideCounter;
end;