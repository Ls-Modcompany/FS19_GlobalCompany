--
-- GlobalCompany - Triggers - GC_PlayerTrigger
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / kevink98
-- @Date: 23.08.2019
-- @Version: 1.2.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.1.1.0 (26.01.2019):
--		- add query if bitmask is correct (for autodrive)
--
-- 	v1.1.1.0 (26.01.2019):
--		- add function for set triggernode when don't use xml for loading
--
-- 	v1.1.0.0 (14.01.2019):
-- 		- convert to fs19,
--		- add TriggerManager support,
--		- add FS19 class update support,
--		- add new target update functions,
--		- add option to use as activatable
--
-- 	v1.0.0.0 (19.05.2018):
-- 		- initial fs17 (kevink98)
--
-- Notes:
--		- Target functions: (isActivatable = true)
--			- playerTriggerActivated() [Activatable Only] - Updated 'once' when input is pressed.
--			- playerTriggerDrawActivate() [Activatable Only] - Updated each frame while player is in trigger.  (optional)
--			- playerTriggerGetActivateText() [Activatable Only] - Get the new input text to be displayed.  (optional)
--			- playerTriggerUpdate(dt) [All] - Updated each frame when player is in trigger.  (optional)
--
--
-- ToDo:
--
--

GC_PlayerTrigger = {}

local GC_PlayerTrigger_mt = Class(GC_PlayerTrigger, Object)
InitObjectClass(GC_PlayerTrigger, "GC_PlayerTrigger")

GC_PlayerTrigger.debugIndex = g_company.debug:registerScriptName("GC_PlayerTrigger")

g_company.playerTrigger = GC_PlayerTrigger

function GC_PlayerTrigger:new(isServer, isClient, customMt)
	local self = Object:new(isServer, isClient, customMt or GC_PlayerTrigger_mt)
	
	self.registerTriggerInStream = false

	return self
end

function GC_PlayerTrigger:load(nodeId, target, xmlFile, xmlKey, triggerReference, isActivatable, activateText, removeAfterActivated)
	if nodeId == nil or target == nil then
		return false
	end
	
	self.rootNode = nodeId
	self.target = target

	self.debugData = g_company.debug:getDebugData(GC_PlayerTrigger.debugIndex, target)

	self.triggerReference = triggerReference

	self.playerInTrigger = false
	self.isActivatable = Utils.getNoNil(isActivatable, false)

	if xmlFile ~= nil and xmlKey ~= nil then
		local playerTriggerNode = getXMLString(xmlFile, xmlKey .. "#playerTriggerNode")
		if not self:setTriggerNode(playerTriggerNode) then
			g_company.debug:logWrite(self.debugData, GC_DebugUtils.MODDING, "Error loading 'playerTriggerNode' %s!", playerTriggerNode)
		end
	end

	if self.isActivatable then
		if self.target.playerTriggerActivated ~= nil then
			self.removeAfterActivated = Utils.getNoNil(removeAfterActivated, false)
			self.activateText = Utils.getNoNil(activateText, g_i18n:getText("input_ACTIVATE_OBJECT"))
		else
			g_company.debug:logWrite(self.debugData, GC_DebugUtils.DEV, "function 'playerTriggerActivated' does not exist. 'isActivatable' is not an option.")
			self.isActivatable = false
		end
	end

	return true
end

function GC_PlayerTrigger:setTriggerNode(playerTriggerNode)
	if playerTriggerNode ~= nil then
		self.playerTriggerNode = I3DUtil.indexToObject(self.rootNode, playerTriggerNode, self.target.i3dMappings)
		if self.playerTriggerNode ~= nil then
			if RaycastUtil.MASK.TRIGGER_PLAYER ~= getCollisionMask(self.playerTriggerNode) then
				g_company.debug:logWrite(self.debugData, GC_DebugUtils.WARNING, "Playertrigger %s should have collisionMask! Need only Bit 20", self.playerTriggerNode);
			end;
			addTrigger(self.playerTriggerNode, "playerTriggerCallback", self)
			return true
		end
	end

	return false
end

function GC_PlayerTrigger:delete()
	if self.isActivatable and self.playerInTrigger then
		g_currentMission:removeActivatableObject(self)
	end

	self.playerInTrigger = false

	if self.playerTriggerNode ~= nil then
		removeTrigger(self.playerTriggerNode)
	end
	
	GC_PlayerTrigger:superClass().delete(self)
end

function GC_PlayerTrigger:update(dt)
	if self.target.playerTriggerUpdate ~= nil then
		self.target:playerTriggerUpdate(dt, self.playerInTrigger, self.triggerReference)
	end

	if self.playerInTrigger then
		if self:getIsActivatable() then
			if self.isActivatable and self.target.playerTriggerGetActivateText ~= nil then
				local text = self.target:playerTriggerGetActivateText(self.triggerReference)
				self:setActivateText(text)
			end

			self:raiseActive()
		else
			self.playerInTrigger = false

			if self.target.playerTriggerOnEnterLeave ~= nil then
				self.target:playerTriggerOnEnterLeave(false, self.triggerReference)
			end
			
			if self.isActivatable then
				g_currentMission:removeActivatableObject(self)
			end
		end
	end
end

function GC_PlayerTrigger:getIsActivatable()
	return g_currentMission.controlPlayer and g_currentMission.controlledVehicle == nil
end

function GC_PlayerTrigger:onActivateObject()
	self.target:playerTriggerActivated(self.triggerReference)
end

function GC_PlayerTrigger:shouldRemoveActivatable()
	return self.removeAfterActivated
end

function GC_PlayerTrigger:setActivateText(text)
	self.activateText = tostring(text)
end

function GC_PlayerTrigger:getPlayerInTrigger()
	return self.playerInTrigger
end

function GC_PlayerTrigger:drawActivate()
	if self.target.playerTriggerDrawActivate ~= nil then
		self.target:playerTriggerDrawActivate(self.triggerReference)
	end
end

function GC_PlayerTrigger:canAddActivatable()
	if self.isActivatable then
		if self.target.playerTriggerCanAddActivatable ~= nil then
			return self.target:playerTriggerCanAddActivatable(self.triggerReference)
		end
	
		return true
	end
	
	return false
end

function GC_PlayerTrigger:playerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if g_currentMission.controlPlayer and (g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode) then		
		if onEnter or onLeave then
			if onEnter then
				if not self.playerInTrigger then
					if g_currentMission.accessHandler:canFarmAccess(g_currentMission:getFarmId(), self.target) then				
						self.playerInTrigger = true
						if self:canAddActivatable() then
							g_currentMission:addActivatableObject(self)
						end
						
						if self.target.playerTriggerOnEnterLeave ~= nil then
							self.target:playerTriggerOnEnterLeave(true, self.triggerReference)
						end
					end
				end
				-- if self.target.playerTriggerOnEnterLeve ~= nil then
					-- self.target:playerTriggerOnEnter(self.triggerReference)
				-- end
			else
				if self.playerInTrigger then
					self.playerInTrigger = false
	
					if self.isActivatable then
						g_currentMission:removeActivatableObject(self)
					end
					
					if self.target.playerTriggerOnEnterLeave ~= nil then
						self.target:playerTriggerOnEnterLeave(false, self.triggerReference)
					end
				end
				-- if self.target.playerTriggerOnLeave ~= nil then
					-- self.target:playerTriggerOnLeave(self.triggerReference)
				-- end
			end
		
			self:raiseActive()
		end
	end
end