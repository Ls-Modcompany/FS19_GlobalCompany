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
-- 	v1.1.0.0 (25.01.2020):
-- 		- remove Event
-- 		- move mp synch system to gc classses
--
-- 	v1.0.0.0 (26.03.2019):
-- 		- initial fs19 (kevink98)
--
-- Notes:
--
-- ToDo:
--      - need we this here as class?
--

GC_EventManager = {}
local GC_EventManager_mt = Class(GC_EventManager)
InitObjectClass(GC_EventManager, "GC_EventManager")
GC_EventManager.debugIndex = g_company.debug:registerScriptName("GC_EventManager")

GC_EventManager.TYP_NIL = 0
GC_EventManager.TYP_BOOL = 1
GC_EventManager.TYP_FLOAT32 = 2
GC_EventManager.TYP_INT8 = 3
GC_EventManager.TYP_INT16 = 4
GC_EventManager.TYP_INT32 = 5
GC_EventManager.TYP_UINT8 = 6
GC_EventManager.TYP_UINT16 = 7
GC_EventManager.TYP_STRING = 8

GC_EventManager.BIT_8 = 0
GC_EventManager.BIT_16 = 1
GC_EventManager.BIT_32 = 2

function GC_EventManager:new()
    local self = setmetatable({}, GC_EventManager_mt)
    
    self.debugData = g_company.debug:getDebugData(GC_EventManager.debugIndex)
    
    return self
end

function GC_EventManager:getTypeByValue(value)
    if value == nil or type(value) == "function"  then
        return self.TYP_NIL
    elseif type(value) == "table" then
        --should we synch recursive?
    elseif type(value) == "boolean" then
        return self.TYP_BOOL
    elseif type(value) == "string" then
        return self.TYP_STRING
    else
        if value > 0 then
            if math.ceil(value) - value == 0 then
                local bit = self:getBitNumber(value, true)
                if bit == self.BIT_8 then
                    return self.TYP_UINT8
                elseif bit == self.BIT_16 then
                    return self.TYP_UINT16
                else
                    return self.TYP_FLOAT32
                end
            else
                return self.TYP_FLOAT32
            end
        else
            if math.ceil(value) - value == 0 then
                local bit = self:getBitNumber(value, false)
                if bit == self.BIT_8 then
                    return self.TYP_INT8
                elseif bit == self.BIT_16 then
                    return self.TYP_INT16
                else
                    return self.TYP_FLOAT32
                end
            else
                return self.TYP_FLOAT32
            end
        end
    end
end

function GC_EventManager:getBitNumber(value, unsigned)
    if unsigned then    
        if value < 256 then
            return self.BIT_8
        elseif value < 65535 then
            return self.BIT_16
        else
            return self.BIT_32
        end
    else    
        if value >= -128 and value <= 127 then
            return self.BIT_8
        elseif value >= -32768 and value <= 32767 then
            return self.BIT_16
        else
            return self.BIT_32
        end
    end    
end

function GC_EventManager:doWrite(streamId, value) 
    local typ = self:getTypeByValue(value)
    streamWriteUInt8(streamId, typ)
    if typ == self.TYP_BOOL then
        streamWriteBool(streamId, value)
    elseif typ == self.TYP_FLOAT32 then
        streamWriteFloat32(streamId, value)
    elseif typ == self.TYP_INT8 then
        streamWriteInt8(streamId, value)
    elseif typ == self.TYP_INT16 then
        streamWriteInt16(streamId, value)
    elseif typ == self.TYP_INT32 then
        streamWriteInt32(streamId, value)
    elseif typ == self.TYP_UINT8 then
        streamWriteUInt8(streamId, value)
    elseif typ == self.TYP_UINT16 then
        streamWriteUInt16(streamId, value)
    elseif typ == self.TYP_STRING then
        streamWriteString(streamId, value)
    end
end

function GC_EventManager:doRead(streamId) 
    local typ = streamReadUInt8(streamId)  
    if typ == self.TYP_BOOL then
        return streamReadBool(streamId)
    elseif typ == self.TYP_FLOAT32 then
        return streamReadFloat32(streamId)
    elseif typ == self.TYP_INT8 then
        return  streamReadInt8(streamId)
    elseif typ == self.TYP_INT16 then
        return streamReadInt16(streamId)
    elseif typ == self.TYP_INT32 then
        return streamReadInt32(streamId)
    elseif typ == self.TYP_UINT8 then
        return streamReadUInt8(streamId)
    elseif typ == self.TYP_UINT16 then
        return streamReadUInt16(streamId)
    elseif typ == self.TYP_STRING then
        return streamReadString(streamId)
    end
end