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

local GC_ActivableObject_mt = Class(GC_ActivableObject, Object);
InitObjectClass(GC_ActivableObject, "GC_ActivableObject");
GC_ActivableObject.debugIndex = g_company.debug:registerScriptName("GC_ActivableObject");

g_company.activableObject = GC_ActivableObject;

function GC_ActivableObject:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_ActivableObject_mt;
	end;

	local self = Object:new(isServer, isClient, customMt);

	self.isOn = false;

	return self;
end

function GC_ActivableObject:load(target, reference, inputAction, triggerOnlyKeys, triggerUp, triggerDown, triggerAlways, delayTime)
    self.target = target;
    self.reference = reference;
    self.inputAction = InputAction[inputAction];
    self.triggerOnlyKeys = triggerOnlyKeys;
	self.debugData = g_company.debug:getDebugData(GC_ActivableObject.debugIndex, target);

	self.triggerUp = true;
	self.triggerDown = false;
	self.triggerAlways = false;
	self.delayTime = 50;
	self.currentDelayTime = 0;
	
	if triggerUp ~= nil then
		self.triggerUp = triggerUp;
	end;
	if triggerDown ~= nil then
		self.triggerDown = triggerDown;
	end;
	if triggerAlways ~= nil then
		self.triggerAlways = triggerAlways;
	end;
	if delayTime ~= nil then
		self.delayTime = delayTime;
	end;

    self.onText = "onText";
    self.offText = "offText";

	g_company.addRaisedUpdateable(self);
	return true;
end;

function GC_ActivableObject:loadFromXML(xmlFile, xmlKey)	
	self.inputAction = Utils.getNoNil(InputAction[getXMLString(xmlFile, xmlKey .. "#turnAction")], self.inputAction);
	self.triggerOnlyKeys = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. "#triggerOnlyKeys"), self.triggerOnlyKeys);
	
	local onText = getXMLString(xmlFile, xmlKey .. "#onText")
	if onText ~= nil then
		self:setToOnText(g_company.languageManager:getText(onText));
	end;

	local offText = getXMLString(xmlFile, xmlKey .. "#offText")
	if offText ~= nil then
		self:setToOffText(g_company.languageManager:getText(offText));
	end;
end

function GC_ActivableObject:delete()
	if self.eventId ~= nil then
		g_inputBinding:removeActionEvent(self.eventId);
		self.eventId = nil;
	end;
	g_company.removeRaisedUpdateable(self);
end;

function GC_ActivableObject:onActivateObject()
	if self.triggerOnlyKeys then
		if self.currentDelayTime == 0 then
			if self.target.onActivableObject ~= nil then
				self.target:onActivableObject(self.reference, self.isOn);
			end;
			self.currentDelayTime = self.delayTime;
			self:raiseUpdate();
		end;
	else
		self.isOn = not self.isOn;

		if self.target.onActivableObject ~= nil then
			self.target:onActivableObject(self.reference, self.isOn);
		end;

		if self.isOn then
			self:setActivateText(self.offText);
		else
			self:setActivateText(self.onText);
		end;
	end;
end;

function GC_ActivableObject:addActivatableObject()	
	local _, eventId = g_inputBinding:registerActionEvent(self.inputAction, self, self.onActivateObject, self.triggerUp, self.triggerDown, self.triggerAlways, true);
	self.eventId = eventId;
	self:setActivateText(self.onText);
	self.currentDelayTime = 0;
end;

function GC_ActivableObject:removeActivatableObject()
	if self.eventId ~= nil then
		g_inputBinding:removeActionEvent(self.eventId);
		self.eventId = nil;
	end;
end;

function GC_ActivableObject:setActivateText(text)
	g_inputBinding:setActionEventText(self.eventId, tostring(text));
	if self.triggerOnlyKeys then
		self:setToOnText(text);
	end;
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

function GC_ActivableObject:update(dt)
	self.currentDelayTime = math.max(0, self.currentDelayTime - dt);
	if self.currentDelayTime > 0 then
		self:raiseUpdate();
	end;
end;