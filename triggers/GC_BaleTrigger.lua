--
-- GlobalCompany - Triggers - GC_Baletrigger
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


GC_Baletrigger = {};

local GC_Baletrigger_mt = Class(GC_Baletrigger, Object);
InitObjectClass(GC_Baletrigger, "GC_Baletrigger");
GC_Baletrigger.debugIndex = g_company.debug:registerScriptName("GC_Baletrigger");

g_company.baleTrigger = GC_Baletrigger;

GC_Baletrigger.MODE_COUNTER;

function GC_Baletrigger:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_Baletrigger_mt;
	end;

	local self = Object:new(isServer, isClient, customMt);

	self.triggerManagerRegister = true;

	return self;
end

function GC_Baletrigger:load(nodeId, target, xmlFile, xmlKey, mode, triggerReference)
	if nodeId == nil or target == nil then
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_Baletrigger.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;
	self.triggerReference = triggerReference;
    self.mode = mode;
    

	if xmlFile ~= nil and xmlKey ~= nil then
		local baleTriggerNode = getXMLString(xmlFile, xmlKey .. "#baletriggerNode");
		if not self:setTriggerNode(baleTriggerNode) then
			g_company.debug:logWrite(self.debugData, GC_DebugUtils.MODDING, "Error loading 'baleTriggerNode' %s!", baleTriggerNode);
		end;
	end;

    return true;
end;

function GC_Baletrigger:setTriggerNode(baleTriggerNode)
	if baleTriggerNode ~= nil then
		self.baleTriggerNode = I3DUtil.indexToObject(self.rootNode, baleTriggerNode, self.target.i3dMappings);
		if self.baleTriggerNode ~= nil then
			addTrigger(self.baleTriggerNode, "baleTriggerCallback", self);
			return true;
		end;
	end;

	return false;
end;

function GC_Baletrigger:delete()
	if self.baleTriggerNode ~= nil then
		removeTrigger(self.baleTriggerNode);
	end;
end;

function Baler:baleTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local object = g_currentMission:getNodeObject(otherId)
	if object ~= nil and object:isa(Bale) then
		if onEnter  then	
			self.baleInsideCounter = self.baleInsideCounter + 1;
		elseif onLeave then
			self.baleInsideCounter = math.max(self.baleInsideCounter - 1, 0);
		end;
	end;
end;