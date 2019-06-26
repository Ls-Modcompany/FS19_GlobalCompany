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


GC_TriggerManager = {}
local GC_TriggerManager_mt = Class(GC_TriggerManager)

GC_TriggerManager.debugIndex = g_company.debug:registerScriptName("GC_TriggerManager")

g_company.triggerManager = GC_TriggerManager

-- Create trigger manager object.
-- @param table parent = parent object.
-- @param table customMt = custom metatable. (optional)
-- @return table instance = instance of trigger manager if parent is found.
function GC_TriggerManager:new(parent, customMt)
	if parent == nil then
		g_company.debug:logWrite(GC_TriggerManager.debugIndex, GC_DebugUtils.DEV, "No 'PARENT' was given, unable to create trigger manager instance!")
		return
	end

	local self = {}
	setmetatable(self, customMt or GC_TriggerManager_mt)

	self.parent = parent
	self.nextTriggerId = 1
	self.registeredTriggers = {}

	self.debugData = g_company.debug:getDebugData(GC_TriggerManager.debugIndex, parent)

	return self
end

-- Load and add triggers with a single line.
-- @param table triggerClass = trigger class you want to load.
-- @param integer rootNode = rootNode to send to trigger.
-- @param integer xmlFile = xmlFile to send to trigger.
-- @param string keyNode = keyNode to send to trigger.
-- @param ______ ... = extra trigger paramaters if needed.
-- @return trigger object if loaded correctly.
function GC_TriggerManager:addTrigger(triggerClass, ...)
	if triggerClass ~= nil then
		local trigger = triggerClass:new(g_server ~= nil, g_client ~= nil)
		if trigger:load(...) then
			if trigger.isa ~= nil and trigger:isa(Object) then
				trigger:register(true)
			end
			
			table.insert(self.registeredTriggers, trigger)

			trigger.managerId = self.nextTriggerId
			self.nextTriggerId = self.nextTriggerId + 1
			
			return trigger
		else
			trigger:delete()			
		end
	else
		g_company.debug:writeDev(self.debugData, "'addTrigger' Failed! Trigger Class is a 'nil' value.")
	end
	
	return nil
end

-- Unregister and delete single trigger attached to the mod. To be called on when needed.
-- @param table trigger = trigger that is being unregistered / deleted.
function GC_TriggerManager:removeTrigger(trigger)
	if self:getHasTriggers() then
		for key, registeredTrigger in ipairs(self.registeredTriggers) do
			if registeredTrigger == trigger then
				table.remove(self.registeredTriggers, key)
				-- Call in case the trigger:delete() does not call the superClass
				if trigger.isRegistered then
					trigger:unregister(true)
				end
				
				trigger:delete()
				break
			end
		end
	end
end

-- Unregister and delete all triggers attached to the mod. To be called on 'mod:delete()'
function GC_TriggerManager:removeAllTriggers()
	for _, trigger in ipairs(self.registeredTriggers) do
		-- Call in case the trigger:delete() does not call the superClass
		if trigger.isRegistered then
			trigger:unregister(true)
		end
		
		trigger:delete()
	end

	self.registeredTriggers = {}
	self.nextTriggerId = 1
end

function GC_TriggerManager:getNumberTriggers()
	return #self.registeredTriggers
end

function GC_TriggerManager:getHasTriggers()
	return #self.registeredTriggers > 0
end

function GC_TriggerManager:getTriggerId(trigger)
	local triggerId = nil

	for _, regTrigger in ipairs(self.registeredTriggers) do
		if regTrigger == trigger then
			return trigger.managerId
		end
	end

	return nil
end

function GC_TriggerManager:getTriggerById(id)
	if id == nil or not self:getHasTriggers() then
		return nil
	end

	local trigger = nil
	for _, regTrigger in ipairs (self.registeredTriggers) do
		if trigger.managerId == id then
			return regTrigger
		end
	end

	return nil
end

function GC_TriggerManager:setTriggerOwnerFarmId(trigger, ownerFarmId, noEventSend)
	for _, registeredTrigger in ipairs(self.registeredTriggers) do
		if registeredTrigger == trigger and trigger.setOwnerFarmId ~= nil then
			trigger:setOwnerFarmId(ownerFarmId, noEventSend)
			break
		end
	end
end

function GC_TriggerManager:setAllOwnerFarmIds(ownerFarmId, noEventSend)
	for _, trigger in ipairs(self.registeredTriggers) do
		if trigger.setOwnerFarmId ~= nil then
			trigger:setOwnerFarmId(ownerFarmId, noEventSend)
		end
	end
end

function GC_TriggerManager:readStream(streamId, connection) 
	if connection:getIsServer() then
		if self:getHasTriggers() then
			for _, trigger in ipairs(self.registeredTriggers) do
				if trigger.registerTriggerInStream == true then
					local triggerId = NetworkUtil.readNodeObjectId(streamId)
					trigger:readStream(streamId, connection)
					g_client:finishRegisterObject(trigger, triggerId)
				end
			end
		end
    end
end

function GC_TriggerManager:writeStream(streamId, connection)
    if not connection:getIsServer() then
		if self:getHasTriggers() then
			for _, trigger in ipairs(self.registeredTriggers) do
				if trigger.registerTriggerInStream == true then
					NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(trigger))
					trigger:writeStream(streamId, connection)
					g_server:registerObjectInStream(connection, trigger)
				end
			end
		end
    end
end


---------------------------
-- DEPRECIATED FUNCTIONS --
---------------------------

function GC_TriggerManager:loadTrigger(triggerClass, rootNode, xmlFile, keyNode, ...)
	if self.loadTriggerWarning == nil then
		self.loadTriggerWarning = true
		g_company.debug:writeDev(self.debugData, "'loadTrigger' is depreciated! These needs to be changed to 'addTrigger([class], [...])'. Check 'GC_TriggerManager' for more info.")
		g_company.debug:writeDev(self.debugData, "'unregisterAllTriggers' is depreciated! These needs to be changed to 'removeAllTriggers()'. Check 'GC_TriggerManager' for more info.")
	end
	
	return self:addTrigger(triggerClass, rootNode, self.parent, xmlFile, keyNode, ...)
end

function GC_TriggerManager:unregisterAllTriggers()
	if self.unregisterAllTriggersWarning == nil then
		self.unregisterAllTriggersWarning = true
		g_company.debug:writeDev(self.debugData, "'unregisterAllTriggers' is depreciated! These needs to be changed to 'removeAllTriggers()'. Check 'GC_TriggerManager' for more info.");
	end
	
	self:removeAllTriggers()
end