-- 
-- GlobalCompany - Objects - MovingParts
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 02.02.2019
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
-- 	v1.0.0.0 (02.02.2019):
-- 
-- ToDo:
-- 


GC_MovingPart = {}
g_company.movingPart = GC_MovingPart

GC_MovingPart_mt = Class(GC_MovingPart, g_company.gc_class)
InitObjectClass(GC_MovingPart, "GC_MovingPart")

function GC_MovingPart:new(isServer, isClient, customMt)
	return GC_MovingPart:superClass():new(GC_MovingPart_mt, isServer, isClient);
end

function GC_MovingPart:finalizePlacement()
	GC_MovingPart:superClass().finalizePlacement(self)	
	self.eventId_setAnimationState = self:registerEvent(self, self.setAnimationState, false, false)  	
end

function GC_MovingPart:load(nodeId, xmlFile, key, target)
    GC_MovingPart:superClass().load(self)
	
	self.rootNode = nodeId
	self.target = target
	self.movingParts = {}
	self.triggerManager = GC_TriggerManager:new(self)

	local i = 0
	while true do
		local movingPartKey = string.format("%s.movingPart(%d)", key, i)
		if not hasXMLProperty(xmlFile, movingPartKey) then
			break
		end

		local movingPart = {}
		
		self.i3dMappings = target.i3dMappings
		local playerTrigger = self.triggerManager:addTrigger(GC_PlayerTrigger, self.rootNode, self, xmlFile, movingPartKey, i+1, false)
		if playerTrigger ~= nil then
			movingPart.playerTrigger = playerTrigger
		end
		self.i3dMappings = nil

		movingPart.axis = InputAction[getXMLString(xmlFile, movingPartKey .. "#axis")]
		movingPart.animationName = getXMLString(xmlFile, movingPartKey .. "#animation")
		movingPart.posText = getXMLString(xmlFile, movingPartKey .. "#posText")
		movingPart.negText = getXMLString(xmlFile, movingPartKey .. "#negText")

		if movingPart.posText ~= nil then
			movingPart.posText = g_company.languageManager:getText(movingPart.posText)
		else
			movingPart.posText = g_i18n:getText("input_ACTIVATE_OBJECT")
		end

		if movingPart.negText ~= nil then
			movingPart.negText = g_company.languageManager:getText(movingPart.negText)
		else
			movingPart.posText = movingPart.posText
		end

		table.insert(self.movingParts, movingPart)
		i = i + 1
	end

	return true
end

function GC_MovingPart:delete()
	for _, movingPart in pairs(self.movingParts) do
		if movingPart.playerTrigger ~= nil then
			movingPart.playerTrigger:delete()
		end
	end
	GC_MovingPart:superClass().delete(self);
end

function GC_MovingPart:update(dt)	
    GC_MovingPart:superClass().update(self, dt)
	self.lastAnimationState = self.animationState
	self.animation:setAnimationsState2(self.animationState)
	self.animationState = 0
end

function GC_MovingPart:addInputs(ref)	
	if self.movingParts[ref].eventId == nil then
		local _, eventId = g_inputBinding:registerActionEvent(self.movingParts[ref].axis, self, self.onMove, false, true, false, true)
		self.movingParts[ref].eventId = eventId
		if self:getCurrentAnimationState(self.movingParts[ref].animationName) then
			g_inputBinding:setActionEventText(eventId, self.movingParts[ref].posText);
		else
			g_inputBinding:setActionEventText(eventId, self.movingParts[ref].negText);
		end
	end
end

function GC_MovingPart:removeInputs(ref)	
	if self.movingParts[ref].eventId ~= nil then
		g_inputBinding:removeActionEvent(self.movingParts[ref].eventId)
		self.movingParts[ref].eventId = nil
	end
end

function GC_MovingPart:onMove(actionName,value,_,_,isMouse)
	for ref, movingPart in pairs(self.movingParts) do
		if movingPart.eventId ~= nil and movingPart.axis == actionName then
			local state = self:getCurrentAnimationState(movingPart.animationName)
			self:setAnimationState({ref, state})
		end
	end
end

function GC_MovingPart:playerTriggerOnEnterLeave(onEnter, ref)
	if onEnter then
		self:addInputs(ref)
	else
		self:removeInputs(ref)
	end
end

function GC_MovingPart:getCurrentAnimationState(animationName)	
	local state = self.target.animationManager:getAnimationTime(animationName) ~= 1
	if self.target.animationManager:getIsAnimationPlaying(animationName) then
		state = self.target.animationManager:getAnimation(animationName).currentSpeed ~= 1			
	end
	return state
end

function GC_MovingPart:setAnimationState(data, noEventSend)
    self:raiseEvent(self.eventId_setAnimationState, data, noEventSend)	
	
	self.target.animationManager:setAnimationByState(self.movingParts[data[1]].animationName, data[2], true)
	if self.isClient then
		if data[2] then
			g_inputBinding:setActionEventText(self.movingParts[data[1]].eventId, self.movingParts[data[1]].negText);
		else
			g_inputBinding:setActionEventText(self.movingParts[data[1]].eventId, self.movingParts[data[1]].posText);
		end
	end
end