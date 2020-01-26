--
-- GlobalCompany - Events - GC_SynchEvent
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 23.01.2020
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.0.0.0 (23.01.2020):
-- 		- initial fs19
--
--
-- Notes:
--
--
-- ToDo:
--
--

GC_SynchEvent = {}
GC_SynchEvent_mt = Class(GC_SynchEvent, Event)

InitEventClass(GC_SynchEvent, "GC_SynchEvent")

function GC_SynchEvent:emptyNew()
	local self = Event:new(GC_SynchEvent_mt)
	return self
end

function GC_SynchEvent:new(gcId, targetEventId, data, classType)
	local self = GC_SynchEvent:emptyNew()
	self.gcId = gcId
	self.targetEventId = targetEventId
	self.data = data
	self.classType = classType

	return self
end

function GC_SynchEvent:readStream(streamId, connection)
	self.gcId = streamReadUInt8(streamId)
    self.targetEventId = streamReadUInt8(streamId)
    local classType = streamReadUInt8(streamId)

    if classType == g_company.classType.CLASS then
        self.gcObject = g_company:getObject(self.gcId)
    elseif classType == g_company.classType.STATICCLASS then
        self.gcObject = g_company:getStaticObject(self.gcId)
    else
        print(string.format("Invalid classType %s", classType))
    end

    local event = self.gcObject.events[self.targetEventId]

    local useOwnIndex = event.useOwnIndex
    local clientToServer = event.clientToServer

    local lenght = streamReadUInt16(streamId);

    self.data = {}
    for i=1, lenght do
        if useOwnIndex then   
            local k = g_company.eventManager:doRead(streamId);
            local v = g_company.eventManager:doRead(streamId);
            self.data[k] = v;
        else
            local v = g_company.eventManager:doRead(streamId);
            table.insert(self.data, v);
        end;
    end;

	self:run(connection)
end

function GC_SynchEvent:writeStream(streamId, connection)
	streamWriteUInt8(streamId, self.gcId)
    streamWriteUInt8(streamId, self.targetEventId)
    streamWriteUInt8(streamId, self.classType)
    
    streamWriteUInt16(streamId, g_company.utils.getTableLength(self.data));

    if self.classType == g_company.classType.CLASS then
        self.gcObject = g_company:getObject(self.gcId)
    elseif self.classType == g_company.classType.STATICCLASS then
        self.gcObject = g_company:getStaticObject(self.gcId)
    else
        print(string.format("Invalid classType %s", self.classType))
    end

    local useOwnIndex = self.gcObject.events[self.targetEventId].useOwnIndex

    for k,v in pairs (self.data) do
        if useOwnIndex then
            g_company.eventManager:doWrite(streamId, k)
        end;
        g_company.eventManager:doWrite(streamId, v)
    end;
end

function GC_SynchEvent:run(connection)
	if not connection:getIsServer() and not self.clientToServer then
        g_server:broadcastEvent(self, false, connection, nil)
    end

    if self.gcObject ~= nil then
        self.gcObject:runEvent(self.targetEventId, self.data)
    end
end