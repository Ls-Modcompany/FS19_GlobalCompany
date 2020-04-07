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


GC_Class = {}
GC_Class._mt = Class(GC_Class, Object)
g_company.gc_class = GC_Class

function GC_Class:new(mt, isServer, isClient, scriptDebugInfo, xmlFilename, baseDirectory, customEnvironment, scriptName)
    
    local self = Object:new(isServer, isClient, mt)

    self.xmlFilename = xmlFilename
    self.baseDirectory = baseDirectory
    self.customEnvironment = customEnvironment

    if scriptDebugInfo ~= nil then
        --self.debug = g_company.debugManager:createDebugObject(isServer, isClient, scriptDebugInfo, target, customEnvironment)
    end

    self.eventId = 0
    self.events = {}

    self.isRegister = false

    return self
end

function GC_Class:load()
    if GC_Class:superClass().load ~= nil then
        GC_Class:superClass().load(self)
    end
end

function GC_Class:finalizePlacement()
    if GC_Class:superClass().finalizePlacement ~= nil then
        GC_Class:superClass().finalizePlacement(self)
    end
    self.isRegister = true
    g_company:registerObject(self)
end

function GC_Class:delete()
    if GC_Class:superClass().delete ~= nil then
        GC_Class:superClass().delete(self)
    end
    g_company:unregisterObject(self.gcId)    
end

function GC_Class:readStream(streamId, connection)
    if GC_Class:superClass().readStream ~= nil then
        GC_Class:superClass().readStream(self, streamId, connection)
    end

    self.gcId = streamReadUInt8(streamId)
end

function GC_Class:writeStream(streamId, connection)
    if GC_Class:superClass().writeStream ~= nil then
        GC_Class:superClass().writeStream(self, streamId, connection)
    end
    streamWriteUInt8(streamId, self.gcId)
end

function GC_Class:readUpdateStream(streamId, timestamp, connection)
    if GC_Class:superClass().readUpdateStream ~= nil then
        GC_Class:superClass().readUpdateStream(self, streamId, timestamp, connection)
    end    
end

function GC_Class:writeUpdateStream(streamId, connection, dirtyMask)
    if GC_Class:superClass().writeUpdateStream ~= nil then
        GC_Class:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
    end    
end

function GC_Class:loadFromXMLFile(xmlFile, key)
    if GC_Class:superClass().loadFromXMLFile ~= nil then
        GC_Class:superClass().loadFromXMLFile(self, xmlFile, key)
    end    
end

function GC_Class:saveToXMLFile(xmlFile, key, usedModNames)
    if GC_Class:superClass().saveToXMLFile ~= nil then
        GC_Class:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)
    end    
end

function GC_Class:update(dt)
    if GC_Class:superClass().update ~= nil then
        GC_Class:superClass().update(dt)
    end    
end

function GC_Class:registerEvent(target, func, useOwnIndex, clientToServer)
    self.eventId = self.eventId + 1
    
    self.events[self.eventId] = 
    {
        id = self.eventId,
        target = target,
        func = func,
        useOwnIndex = useOwnIndex,
        clientToServer = Utils.getNoNil(clientToServer, false)
    }

    return self.eventId
end

function GC_Class:raiseEvent(eventId, data, noEventSend)
    if self.isRegister and eventId ~= nil and (noEventSend == nil or noEventSend == false) then
        local useOwnIndex = self.events[eventId].useOwnIndex
        if g_company:getIsServer() then       
            g_server:broadcastEvent(GC_SynchEvent:new(self.gcId, eventId, data, 1))
        else 
			g_client:getServerConnection():sendEvent(GC_SynchEvent:new(self.gcId, eventId, data, 1))
        end;
    end;
end

function GC_Class:runEvent(eventId, data)
    for id, event in pairs(self.events) do
        if id == eventId then
            event.func(self, data, true)
            break
        end
    end
end