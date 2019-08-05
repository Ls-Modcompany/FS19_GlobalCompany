--
-- GlobalCompany - Events - GC_AnimationManagerStopEvent
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 02.03.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
--
-- 	v1.0.0.0 (02.03.2019):
-- 		- initial fs19 
--
-- Notes:
--
--
-- ToDo:
--
--

GC_AnimationManagerStopEvent = {}
GC_AnimationManagerStopEvent_mt = Class(GC_AnimationManagerStopEvent, Event)

InitEventClass(GC_AnimationManagerStopEvent, "GC_AnimationManagerStopEvent")

function GC_AnimationManagerStopEvent:emptyNew()
	local self = Event:new(GC_AnimationManagerStopEvent_mt)
	return self
end

function GC_AnimationManagerStopEvent:new(object, animationId)
	local self = GC_AnimationManagerStopEvent:emptyNew()
	self.object = object
	self.animationId = animationId

	return self
end

function GC_AnimationManagerStopEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.animationId = streamReadUInt8(streamId)

	self:run(connection)
end

function GC_AnimationManagerStopEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUInt8(streamId, self.animationId)
end

function GC_AnimationManagerStopEvent:run(connection)
	local name = self.object.animationIdToName[self.animationId]
	self.object:stopAnimation(name, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(GC_AnimationManagerStopEvent:new(self.object, self.animationId), nil, connection, self.object)
	end
end