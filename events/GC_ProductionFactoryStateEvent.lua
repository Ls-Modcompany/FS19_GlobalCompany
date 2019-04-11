--
-- GlobalCompany - Events - GC_ProductionFactoryStateEvent
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 09.03.2019
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.0.0 (09.03.2019):
-- 		- initial fs19 (GtX)
--
-- 	v1.0.0.0 (22.03.2018):
-- 		- initial fs17 (GtX)
--
-- Notes:
--
--
-- ToDo:
--
--

GC_ProductionFactoryStateEvent = {};
GC_ProductionFactoryStateEvent_mt = Class(GC_ProductionFactoryStateEvent, Event);

InitEventClass(GC_ProductionFactoryStateEvent, "GC_ProductionFactoryStateEvent");

function GC_ProductionFactoryStateEvent:emptyNew()
	local self = Event:new(GC_ProductionFactoryStateEvent_mt);
	return self;
end;

function GC_ProductionFactoryStateEvent:new(factory, lineId, state)
	local self = GC_ProductionFactoryStateEvent:emptyNew()
	self.factory = factory;
	self.lineId = lineId;
	self.state = state;

	return self;
end;

function GC_ProductionFactoryStateEvent:readStream(streamId, connection)
	self.factory = NetworkUtil.readNodeObject(streamId);
	self.lineId = streamReadUInt8(streamId);
	self.state = streamReadBool(streamId);

	self:run(connection);
end;

function GC_ProductionFactoryStateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.factory);
	streamWriteUInt8(streamId, self.lineId);
	streamWriteBool(streamId, self.state);
end;

function GC_ProductionFactoryStateEvent:run(connection)
	self.factory:setFactoryState(self.lineId, self.state, true);

	if not connection:getIsServer() then
		g_server:broadcastEvent(GC_ProductionFactoryStateEvent:new(self.factory, self.lineId, self.state), nil, connection, self.factory);
	end;
end;

function GC_ProductionFactoryStateEvent.sendEvent(factory, lineId, state, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(GC_ProductionFactoryStateEvent:new(factory, lineId, state), nil, nil, factory);
        else
            g_client:getServerConnection():sendEvent(GC_ProductionFactoryStateEvent:new(factory, lineId, state));
        end;
    end;
end;





