--
-- GlobalCompany - Events - GC_ProductionFactoryCustomTitleEvent
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 09.07.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--

-- 	v1.0.0.0 (09.07.2018):
-- 		- initial fs19 (GtX)
--
-- Notes:
--
--
-- ToDo:
--
--

GC_ProductionFactoryCustomTitleEvent = {}
GC_ProductionFactoryCustomTitleEvent_mt = Class(GC_ProductionFactoryCustomTitleEvent, Event)

InitEventClass(GC_ProductionFactoryCustomTitleEvent, "GC_ProductionFactoryCustomTitleEvent")

function GC_ProductionFactoryCustomTitleEvent:emptyNew()
	local self = Event:new(GC_ProductionFactoryCustomTitleEvent_mt)
	return self
end

function GC_ProductionFactoryCustomTitleEvent:new(factory, customTitle)
	local self = GC_ProductionFactoryCustomTitleEvent:emptyNew()
	self.factory = factory
	self.customTitle = customTitle

	return self
end

function GC_ProductionFactoryCustomTitleEvent:readStream(streamId, connection)
	self.factory = NetworkUtil.readNodeObject(streamId)
	self.customTitle = streamReadString(streamId)

	self:run(connection)
end

function GC_ProductionFactoryCustomTitleEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.factory)
	streamWriteString(streamId, self.customTitle)
end

function GC_ProductionFactoryCustomTitleEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(GC_ProductionFactoryCustomTitleEvent:new(self.factory, self.customTitle), nil, connection, self.factory)
	end

	self.factory:setCustomTitle(self.customTitle, true)
end

function GC_ProductionFactoryCustomTitleEvent.sendEvent(factory, customTitle, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(GC_ProductionFactoryCustomTitleEvent:new(factory, customTitle), nil, nil, factory)
        else
            g_client:getServerConnection():sendEvent(GC_ProductionFactoryCustomTitleEvent:new(factory, customTitle))
        end
    end
end