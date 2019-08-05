--
-- GlobalCompany - Events - GC_AnimalLoadingTriggerEvent
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 15.07.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.0.0.0 (15.07.2019):
-- 		- initial fs19 ()
--
--
-- Notes:
--
--
-- ToDo:
--
--

GC_AnimalLoadingTriggerEvent = {}
GC_AnimalLoadingTriggerEvent_mt = Class(GC_AnimalLoadingTriggerEvent, Event)

InitEventClass(GC_AnimalLoadingTriggerEvent, "GC_AnimalLoadingTriggerEvent")

function GC_AnimalLoadingTriggerEvent:emptyNew()
	local self = Event:new(GC_AnimalLoadingTriggerEvent_mt)
	return self
end

function GC_AnimalLoadingTriggerEvent:new(trigger, animalTrailer, numberToDeliver)
	local self = GC_AnimalLoadingTriggerEvent:emptyNew()
	self.trigger = trigger
	self.animalTrailer = animalTrailer
	self.numberToDeliver = numberToDeliver

	return self
end

function GC_AnimalLoadingTriggerEvent:readStream(streamId, connection)
	self.trigger = NetworkUtil.readNodeObject(streamId)
	self.animalTrailer = NetworkUtil.readNodeObject(streamId)
	self.numberToDeliver = streamReadInt32(streamId)

	self:run(connection)
end

function GC_AnimalLoadingTriggerEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.trigger)
	NetworkUtil.writeNodeObject(streamId, self.animalTrailer)
	streamWriteInt32(streamId, self.numberToDeliver)
end

function GC_AnimalLoadingTriggerEvent:run(connection)
	if not connection:getIsServer() then
		self.trigger:deliverAnimals(self.animalTrailer, self.numberToDeliver)
	else
		g_company.debug:print("  [LSMC - GlobalCompany] ERROR: GC_AnimalLoadingTriggerEvent is a client to server only event!")
	end
end