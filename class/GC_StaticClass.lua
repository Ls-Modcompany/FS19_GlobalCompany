--
-- GlobalCompany - Class
--
-- @Interface: 1.5.1.0 b6730
-- @Author: LS-Modcompany
-- @Date: 18.01.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.0.0.0 (18.01.2020):
--

--local initAllowed = true
local staticClassId = 0
local function getNexStaticClassId()
    --if initAllowed then
        staticClassId = staticClassId + 1
        return staticClassId
    --end
end

GC_StaticClass = {}
g_company.gc_staticClass = GC_StaticClass

function GC_StaticClass:new(mt, isServer, isClient, scriptDebugInfo, target)
        
    if mt == nil then
        mt = Class(GC_StaticClass)
    end
    local self = setmetatable({}, mt)

    self.isClient = isClient
    self.isServer = isServer
        
    if scriptDebugInfo ~= nil then
      --  self.debug = g_company.debugManager:createDebugObject(isServer, isClient, scriptDebugInfo, target, customEnvironment)
    end

    self.eventId = 0
    self.events = {}

    g_company:registerStaticObject(self, getNexStaticClassId())

    return self
end

function GC_StaticClass:delete()
    g_company:unregisterStaticObject(self.gcId)    
end
--[[
function GC_StaticClass:readStream(streamId, connection)
    
end

function GC_StaticClass:writeStream(streamId, connection)
    
end

function GC_StaticClass:readUpdateStream(streamId, timestamp, connection)
    
end

function GC_StaticClass:writeUpdateStream(streamId, connection, dirtyMask)
    
end
]]--

function GC_StaticClass:loadFromXMLFile(xmlFile, key)
    
end

function GC_StaticClass:saveToXMLFile(xmlFile, key, usedModNames)
    
end

function GC_StaticClass:update(dt)
    
end

function GC_StaticClass:registerEvent(target, func, useOwnIndex, clientToServer)
    self.eventId = self.eventId + 1
    
    self.events[self.eventId] = 
    {
        id = self.eventId,
        target = target,
        classType = g_company.classType.STATICCLASS,
        func = func,
        useOwnIndex = useOwnIndex,
        clientToServer = Utils.getNoNil(clientToServer, false)
    }

    return self.eventId
end

function GC_StaticClass:raiseEvent(eventId, data, noEventSend)
    if eventId ~= nil and (noEventSend == nil or noEventSend == false) then
        local classType = self.events[eventId].classType
        if g_company:getIsServer() then       
            g_server:broadcastEvent(GC_SynchEvent:new(self.gcId, eventId, data, classType))
        else 
			g_client:getServerConnection():sendEvent(GC_SynchEvent:new(self.gcId, eventId, data, classType))
        end;
    end;
end

function GC_StaticClass:runEvent(eventId, data)
    for id, event in pairs(self.events) do
        if id == eventId then
            event.func(self, data, true)
            break
        end
    end
end