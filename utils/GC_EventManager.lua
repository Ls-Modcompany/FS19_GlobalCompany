--
-- GlobalCompany - utils - GC_EventManager
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.03.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (26.03.2019):
-- 		- initial fs19 (kevink98)
--
-- Notes:
--
-- ToDo:
--

GC_EventManager = {};
local GC_EventManager_mt = Class(GC_EventManager);
InitObjectClass(GC_EventManager, "GC_EventManager");
GC_EventManager.debugIndex = g_company.debug:registerScriptName("GC_EventManager");

GC_EventManager.TYP_NIL = 0;
GC_EventManager.TYP_BOOL = 1;
GC_EventManager.TYP_FLOAT32 = 2;
GC_EventManager.TYP_INT8 = 3;
GC_EventManager.TYP_INT16 = 4;
GC_EventManager.TYP_INT32 = 5;
GC_EventManager.TYP_UINT8 = 6;
GC_EventManager.TYP_UINT16 = 7;
GC_EventManager.TYP_STRING = 8;

GC_EventManager.BIT_8 = 0;
GC_EventManager.BIT_16 = 0;
GC_EventManager.BIT_32 = 0;

function GC_EventManager:new()
    local self = setmetatable({}, GC_EventManager_mt);	

	self.isServer = g_server ~= nil;
    self.isClient = g_client ~= nil;

    self.id = -1;
    self.events = {};
    
    return self;
end;

function GC_EventManager:getNextEventId()
    self.id = self.id + 1;
    return self.id;
end;

function GC_EventManager:registerEvent(target, func)
    local id = self:getNextEventId();
    self.events[id] = {target=target, func=func};
    return id;
end;

function GC_EventManager:getTypeByValue(value)
    if value == nil or type(value) == "function"  then
        return self.TYP_NIL;
    elseif type(value) == "table" then
        --should we synch recursive?
    elseif type(value) == "bool" then
        return self.TYP_BOOL;
    elseif type(value) == "string" then
        return self.TYP_STRING;
    else
        if value > 0 then
            if math.ceil(value) - value == 0 then
                local bit = self:getBitNumber(value, true);
                if bit == self.BIT_8 then
                    return self.TYP_UINT8;
                elseif bit == self.BIT_16 then
                    return self.TYP_UINT16;
                else
                    return self.TYP_FLOAT32;
                end;
            else
                return self.TYP_FLOAT32;
            end;
        else
            if math.ceil(value) - value == 0 then
                local bit = self:getBitNumber(value, false);
                if bit == self.BIT_8 then
                    return self.TYP_INT8;
                elseif bit == self.BIT_16 then
                    return self.TYP_INT16;
                else
                    return self.TYP_FLOAT32;
                end;
            else
                return self.TYP_FLOAT32;
            end;
        end;
    end;
end;

function GC_EventManager:getBitNumber(value, unsigned)
    if unsigned then    
        if value < 256 then
            return self.BIT_8;
        elseif value < 65535 then
            return self.BIT_16;
        else
            return self.BIT_32;
        end;
    else    
        if value >= −128 and value <= 127 then
            return self.BIT_8;
        elseif value >= -32768 and value <= 32767 then
            return self.BIT_16;
        else
            return self.BIT_32;
        end;
    end;    
end;

function GC_EventManager:doWrite(streamId, value) 
    local typ = self:getTypeByValue(value);
    streamWriteUInt8(streamId, typ);
    if typ == self.TYP_BOOL then
        streamWriteBool(streamId, value);
    elseif typ == self.TYP_FLOAT32 then
        streamWriteFloat32(streamId, value);
    elseif typ == self.TYP_INT8 then
        streamWriteInt8(streamId, value);
    elseif typ == self.TYP_INT16 then
        streamWriteInt16(streamId, value);
    elseif typ == self.TYP_INT32 then
        streamWriteInt32(streamId, value);
    elseif typ == self.TYP_UINT8 then
        streamWriteUInt8(streamId, value);
    elseif typ == self.TYP_UINT16 then
        streamWriteUInt16(streamId, value);
    elseif typ == self.TYP_STRING then
        streamWriteString(streamId, value);
    end;
end;

function GC_EventManager:doRead(streamId) 
    local typ = streamReadUInt8(streamId);    
    if typ == self.TYP_BOOL then
        return streamReadBool(streamId);
    elseif typ == self.TYP_FLOAT32 then
        return streamReadFloat32(streamId);
    elseif typ == self.TYP_INT8 then
        return  streamReadInt8(streamId);
    elseif typ == self.TYP_INT16 then
        return streamReadInt16(streamId);
    elseif typ == self.TYP_INT32 then
        return streamReadInt32(streamId);
    elseif typ == self.TYP_UINT8 then
        return streamReadUInt8(streamId);
    elseif typ == self.TYP_UINT16 then
        return streamReadUInt16(streamId);
    elseif typ == self.TYP_STRING then
        return streamReadString(streamId);
    end;
end;

function GC_EventManager:createEvent(targetId, data, useOwnIndex, noEventSend)
	if (noEventSend == nil or noEventSend == false) then
        if self.isServer then        
            g_server:broadcastEvent(GC_DefaultEvent:new(data, targetId))
        else
			g_client:getServerConnection():sendEvent(GC_DefaultEvent:new(data, targetId))
        end;
    end;
end;

function GC_EventManager:raiseSynch(targetId, data)        
    local target = self.events[targetid];
    target.func(target.target, data);
end;


GC_DefaultEvent = {};
GC_DefaultEvent_mt = Class(GC_DefaultEvent, Event);
InitEventClass(GC_DefaultEvent, "GC_DefaultEvent");

function GC_DefaultEvent:new(targetId, data, useOwnIndex)
    local self = Event:new(GC_DefaultEvent_mt);
    self.targetId = targetId;
    self.data = data;
    self.useOwnIndex = Utils.getNoNil(useOwnIndex, true);
    return self;
end;

function GC_DefaultEvent:writeStream(streamId, connection)
    streamWriteUInt16(streamId, table.getn(self.targetId));
    streamWriteBool(streamId, self.useOwnIndex);
    streamWriteUInt16(streamId, table.getn(self.data));

    for k,v in pairs (self.data) do
        if self.useOwnIndex then
            g_company.eventManager:doWrite(streamId, k);
        end;
        g_company.eventManager:doWrite(streamId, v);
    end;
end;

function GC_DefaultEvent:readStream(streamId, connection)
    self.data = {};

    self.targetId = streamReadUInt16(streamId);
    self.useOwnIndex = streamReadBool(streamId);
    local lenght = streamReadUInt16(streamId);

    for i=1, lenght do
        if self.useOwnIndex then   
            local k = g_company.eventManager:doRead(streamId);
            local v = g_company.eventManager:doRead(streamId);
            data[k] = v;
        else
            local v = g_company.eventManager:doRead(streamId);
            table.insert(self.data, v);
        end;
    end;

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, nil);
    end;        
    g_company.eventManager:raiseSynch(self.targetId, self.data);
end;