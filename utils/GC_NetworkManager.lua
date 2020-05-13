-- 
-- GlobalCompany - Networkmanager
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 05.05.2019
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
-- 	v1.0.0.0 (05.05.2019):
-- 
-- ToDo:
-- 


GC_NetworkManager = {}
GC_NetworkManager_mt = Class(GC_NetworkManager, g_company.gc_class)
InitObjectClass(GC_NetworkManager, "GC_NetworkManager")

function GC_NetworkManager:new(isServer, isClient, customMt)
    local self = GC_NetworkManager:superClass():new(GC_NetworkManager_mt, isServer, isClient);
    
    GC_NetworkManager:superClass().load(self)
    GC_NetworkManager:superClass().finalizePlacement(self)	
	
	self.readWriteStreams = {}

    return self
end

function GC_NetworkManager:delete()   
	GC_NetworkManager:superClass().delete(self);
end

function GC_NetworkManager:update(dt)	
    GC_NetworkManager:superClass().update(self, dt)	
end

function GC_NetworkManager:readStream(streamId, connection)
	GC_NetworkManager:superClass().readStream(self, streamId, connection)
    for _,element in pairs(self.readWriteStreams) do
        element.target.readStream(target, streamId, connection)
    end       
end

function GC_NetworkManager:writeStream(streamId, connection)
	GC_NetworkManager:superClass().writeStream(self, streamId, connection)
    for _,element in pairs(self.readWriteStreams) do
        element.target.writeStream(target, streamId, connection)
    end    
end

function GC_NetworkManager.addReadWriteStream(target)
    table.insert(g_company.networkManager.readWriteStreams, {target=target});
end

function onConnectionFinishedLoading(mission, connection, x,y,z, viewDistanceCoeff)
    connection:sendEvent(GC_NetworkManagerInitEvent:new())    
end

FSBaseMission.onConnectionFinishedLoading = g_company.utils.appendedFunction2(FSBaseMission.onConnectionFinishedLoading, onConnectionFinishedLoading)