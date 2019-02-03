--
-- GlobalCompany - Triggers - GC_ActivableObject
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 03.02.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.0.0.0 (03.02.2019):
-- 		- initial fs19 (kevink98)
--
-- Notes:
--
-- ToDo:
--
--

GC_ActivableObject = {};

local GC_ActivableObject_mt = Class(GC_ActivableObject);
InitObjectClass(GC_ActivableObject, "GC_ActivableObject");
GC_ActivableObject.debugIndex = g_company.debug:registerScriptName("GC_ActivableObject");

g_company.activableObject = GC_ActivableObject;

function GC_ActivableObject:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_ActivableObject_mt;
	end;

	local self = setmetatable({}, customMt)

	self.isServer = isServer;
	self.isClient = isClient;

	self.isOn = false;

	return self;
end

function GC_ActivableObject:load(target, reference, inputAction)
    self.target = target;
    self.reference = reference;
    self.inputAction = InputAction[inputAction];
	self.debugData = g_company.debug:getDebugData(GC_ActivableObject.debugIndex, target);

    self.onText = "onText";
    self.offText = "offText";
    self:setActivateText(self.onText);

	return true;
end;

function GC_ActivableObject:delete()
	
end;

function GC_ActivableObject:update(dt)
	if self:getIsActivatable() then
        self:raiseActive();
    end;
end;

function GC_ActivableObject:getIsActivatable()
	return g_currentMission.controlPlayer and g_currentMission.controlledVehicle == nil;
end;

function GC_ActivableObject:onActivateObject()
	self.isOn = not self.isOn;

	if self.target.onActivableObject ~= nil then
		self.target:onActivableObject(self.reference);
	end;

	if self.isOn then
		self:setActivateText(self.offText);
	else
		self:setActivateText(self.onText);
	end;
end;

function GC_ActivableObject:addActivatableObject()	
	local _, eventId = g_inputBinding:registerActionEvent(self.inputAction, self, self.onActivateObject, true, false, false, true);
	self.eventId = eventId;
	self:setActivateText(self.onText);
end;

function GC_ActivableObject:removeActivatableObject()
	if self.eventId ~= nil then
		g_inputBinding:removeActionEvent(self.eventId);
		self.eventId = nil;
	end;
end;

function GC_ActivableObject:setActivateText(text)
	g_inputBinding:setActionEventText(self.eventId, tostring(text));
end;

function GC_ActivableObject:setToOnText(text)
	self.onText = text;
end;

function GC_ActivableObject:setToOffText(text)
	self.offText = text;
end;

function GC_ActivableObject:getOn()
    return self.isOn;
end;


