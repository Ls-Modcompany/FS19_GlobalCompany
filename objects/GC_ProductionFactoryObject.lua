

GC_ProductionFactoryObject = {}

local GC_ProductionFactoryObject_mt = Class(GC_ProductionFactoryObject, Object)
InitObjectClass(GC_ProductionFactoryObject, "GC_ProductionFactoryObject")


GC_ProductionFactoryObject.debugIndex = g_company.debug:registerScriptName("ProductionFactoryObject")

getfenv(0)["GC_ProductionFactoryObject"] = GC_ProductionFactoryObject

function GC_ProductionFactoryObject:new(isServer, isClient, customMt)
	local self = Object:new(isServer, isClient, customMt or GC_ProductionFactoryObject_mt)

	self.debugData = g_curNumLoadingBarStep

	registerObjectClassName(self, "GC_ProductionFactoryObject")
	return self
end

function GC_ProductionFactoryObject:load(vehicle)
	self.vehicle = vehicle
    self:register()
end

function GC_ProductionFactoryObject:finalizePlacement()
	GC_ProductionFactoryObject:superClass().finalizePlacement(self)
end

function GC_ProductionFactoryObject:delete()
	unregisterObjectClassName(self)
	GC_ProductionFactoryObject:superClass().delete(self)
end

function GC_ProductionFactoryObject:readStream(streamId, connection)
	GC_ProductionFactoryObject:superClass().readStream(self, streamId, connection)

    if connection:getIsServer() then
        local vehicle = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))

		for _, factory in ipairs(vehicle:getFactories()) do
			local factoryId = NetworkUtil.readNodeObjectId(streamId)
			factory:readStream(streamId, connection)
			g_client:finishRegisterObject(factory, factoryId)
		end        
	end
end

function GC_ProductionFactoryObject:writeStream(streamId, connection)
	GC_ProductionFactoryObject:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
        local b1 = connection
        local b2 = true        
        NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.vehicle))

        for _, factory in ipairs(self.vehicle:getFactories()) do
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(factory))
            factory:writeStream(streamId, connection)
            
            g_server.currentWriteStreamConnection = connection
            g_server.currentWriteStreamConnectionIsInitial = true
			g_server:registerObjectInStream(connection, factory)
        end		
        
        g_server.currentWriteStreamConnection = b1
        g_server.currentWriteStreamConnectionIsInitial = b2                
	end
end