--
-- GlobalCompany - Events - GC_AnimationManagerStartEvent
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / GtX
-- @Date: 02.03.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
--
-- 	v1.0.0.0 (02.03.2019):
-- 		- initial fs19 (GtX)
--
-- Notes:
--
--
-- ToDo:
--
--

GC_AnimationManagerStartEvent = {}
GC_AnimationManagerStartEvent_mt = Class(GC_AnimationManagerStartEvent, Event)

InitEventClass(GC_AnimationManagerStartEvent, "GC_AnimationManagerStartEvent")

function GC_AnimationManagerStartEvent:emptyNew()
	local self = Event:new(GC_AnimationManagerStartEvent_mt)
	return self
end

function GC_AnimationManagerStartEvent:new(object, animationId, speed, animTime)
	local self = GC_AnimationManagerStartEvent:emptyNew()
	self.object = object
	self.animationId = animationId
	self.speed = speed
	self.animTime = animTime

	return self
end

function GC_AnimationManagerStartEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.animationId = streamReadUInt8(streamId)
	self.speed = streamReadFloat32(streamId)
	self.animTime = streamReadFloat32(streamId)

	self:run(connection)
end

function GC_AnimationManagerStartEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUInt8(streamId, self.animationId)
	streamWriteFloat32(streamId, self.speed)
	streamWriteFloat32(streamId, self.animTime)
end

function GC_AnimationManagerStartEvent:run(connection)
	local name = self.object.animationIdToName[self.animationId]
	self.object:playAnimation(name, self.speed, self.animTime, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(GC_AnimationManagerStartEvent:new(self.object, self.animationId, self.speed, self.animTime), nil, connection, self.object)
	end
end