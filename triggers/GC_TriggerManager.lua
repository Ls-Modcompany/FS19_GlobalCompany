-- 
-- GlobalCompany - Triggers - GC_TriggerManager
-- 
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 11.01.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (11.01.2019):
-- 		- initial fs19 (GtX)
-- 
-- Notes:
--
-- 
--
-- ToDo:
--
--


local debugIndex = g_debug.registerMod("GlobalCompany-GC_TriggerManager");

GC_TriggerManager = {};
local GC_TriggerManager_mt = Class(GC_TriggerManager);

g_company.triggerManager = GC_TriggerManager; -- I think this is better than 'getfenv(0)' as it keeps all GC scripts together. ?? @kevin


-- Create trigger manager object.
-- @param table parent = parent object.
-- @param table customMt = custom metatable. (optional)
-- @return table instance = instance of trigger manager if parent is found.
function GC_TriggerManager:new(parent, customMt)
    if customMt == nil then
        customMt = GC_TriggerManager_mt
    end;
	
	if parent == nil then
		-- No parent script given..
		return;
	end;

    local self = {};
    setmetatable(self, customMt);

	self.parent = parent;	
	
	-- This allows us to print the 'scriptNameSpace' with debugging so we know where the error came from..
	-- What do you think @kevin ??
	self.parentScriptName = GlobalCompanyUtils.getSplitClassName(parent, "____");

	self.nextTriggerId = 1;
	self.registeredTriggers = {};
	
    return self;
end;

-- Load and add triggers with a single line.
-- @param table triggerClass = trigger class you want to load.
-- @param integer rootNode = rootNode to send to trigger.
-- @param integer xmlFile = xmlFile to send to trigger.
-- @param string keyNode = keyNode to send to trigger.
-- @param ______ ... = extra trigger paramaters if needed.
-- @return trigger object if loaded correctly.
function GC_TriggerManager:loadTrigger(triggerClass, rootNode, xmlFile, keyNode, ...)
	local trigger = triggerClass:new(g_server ~= nil, g_client ~= nil);
	if trigger:load(rootNode, self.parent, xmlFile, keyNode, ...) then
		self:registerTrigger(trigger);
		return trigger;
	else
		trigger:delete();
		return nil;
	end;
end;

-- Registering triggers allows them to update and also fast clean deleting when mod is removed.
-- @param table trigger = trigger that is being registered.
-- @param boolean forceRegister = register the trigger.
-- @return boolean = success.
function GC_TriggerManager:registerTrigger(trigger, forceRegister)
	if self.registeredTriggers == nil then
		self.registeredTriggers = {};
	end;
	
	if trigger.triggerManagerRegister or (forceRegister ~= nil and forceRegister) then
		trigger:register(true);
	end;

	table.insert(self.registeredTriggers, trigger);
	
	trigger.managerId = self.nextTriggerId;
	self.nextTriggerId = self.nextTriggerId + 1;
end;

-- Unregister and delete single trigger attached to the mod. To be called on 'mod:delete()'
-- Could be used for upgrades and mod changes.
-- @param table trigger = trigger that is being unregistered / deleted.
function GC_TriggerManager:unregisterTrigger(trigger)
	if self:getNumberTriggers() > 0 then
		for key, t in pairs(self.registeredTriggers) do
			if t == trigger then
				table.remove(self.registeredTriggers, key);
				if trigger.isRegistered then
					trigger:unregister(true);
				end;
				trigger:delete();
				break;
			end;
		end;
	end;
end;

-- Unregister and delete all triggers attached to the mod. To be called on 'mod:delete()'
function GC_TriggerManager:unregisterAllTriggers()
	if self.registeredTriggers ~= nil then
		local deleted, unregistered = 0, 0;
		for _, trigger in pairs(self.registeredTriggers) do
			if trigger.isRegistered then
				trigger:unregister(true);
				unregistered = unregistered + 1;
			end;
			trigger:delete();
			deleted = deleted + 1;
		end;
		self.registeredTriggers = nil;

		g_debug.write(debugIndex, g_debug.DEV, "%s Trigger(s) have been deleted successfully and %s Trigger(s) have been unregistered successfully from [%s].", self.parentScriptName, deleted, unregistered);
	end;
end;

function GC_TriggerManager:getNumberTriggers()
	if self.registeredTriggers == nil then
		return 0;
	end;
	
	return #self.registeredTriggers;
end;

function GC_TriggerManager:getTriggerId(trigger)
	local triggerId = nil;
	
	if self:getNumberTriggers() > 0 then
		for _, regTrigger in pairs(self.registeredTriggers) do
			if regTrigger == trigger then
				triggerId = trigger.managerId;
				break;
			end;
		end;
	end;
	
	return triggerId;
end;

function GC_TriggerManager:getTriggerById(id)
	if id == nil or self.registeredTriggers == nil then
		return nil;
	end;
	
	local trigger = nil;	
	for _, regTrigger in pairs (self.registeredTriggers) do
		if trigger.managerId == id then
			trigger = regTrigger;
		end;
	end;
	
	return trigger;
end;




