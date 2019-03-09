--
-- GlobalCompany - Triggers - GC_BaleTrigger
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


GC_BaleTrigger = {};

local GC_Baletrigger_mt = Class(GC_BaleTrigger, Object);
InitObjectClass(GC_BaleTrigger, "GC_BaleTrigger");
GC_BaleTrigger.debugIndex = g_company.debug:registerScriptName("GC_BaleTrigger");

g_company.baleTrigger = GC_BaleTrigger;

GC_BaleTrigger.MODE_COUNTER = 0;

function GC_BaleTrigger:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_Baletrigger_mt;
	end;

	local self = Object:new(isServer, isClient, customMt);

	self.triggerManagerRegister = true;

	return self;
end

function GC_BaleTrigger:load(nodeId, target, xmlFile, xmlKey, mode)
	if nodeId == nil or target == nil then
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_BaleTrigger.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;
    self.mode = mode;
    

	if xmlFile ~= nil and xmlKey ~= nil then
		local baleTriggerNode = getXMLString(xmlFile, xmlKey .. "#baletriggerNode");
		if not self:setTriggerNode(baleTriggerNode) then
			g_company.debug:logWrite(self.debugData, GC_DebugUtils.MODDING, "Error loading 'baleTriggerNode' %s!", baleTriggerNode);
		end;
	end;

    return true;
end;

function GC_BaleTrigger:setTriggerNode(baleTriggerNode)
	if baleTriggerNode ~= nil then
		self.baleTriggerNode = I3DUtil.indexToObject(self.rootNode, baleTriggerNode, self.target.i3dMappings);
		if self.baleTriggerNode ~= nil then
			addTrigger(self.baleTriggerNode, "baleTriggerCallback", self);
			return true;
		end;
	end;

	return false;
end;

function GC_BaleTrigger:delete()
	if self.baleTriggerNode ~= nil then
		removeTrigger(self.baleTriggerNode);
	end;
end;

function GC_BaleTrigger:baleTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local object = g_currentMission:getNodeObject(otherId)
	if object ~= nil and object:isa(Bale) then
		if onEnter then	
			if self.mode == GC_BaleTrigger.MODE_COUNTER then
				self.baleInsideCounter = self.baleInsideCounter + 1;
			end;
		elseif onLeave then
			if self.mode == GC_BaleTrigger.MODE_COUNTER then
				self.baleInsideCounter = math.max(self.baleInsideCounter - 1, 0);
			end;
		end;
	end;
end;

function GC_BaleTrigger:getTriggerEmpty()
	return self.baleInsideCounter == 0;
end;

function GC_BaleTrigger:getTriggerNotEmpty()
	return self.baleInsideCounter ~= 0;
end;

function GC_BaleTrigger:reset()
	self.baleInsideCounter = 0;
end;