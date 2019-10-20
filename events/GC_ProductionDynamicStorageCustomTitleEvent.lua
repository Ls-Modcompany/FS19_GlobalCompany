--
-- GlobalCompany - Events - GC_ProductionDynamicStorageCustomTitleEvent
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / kevink98
-- @Date: 20.10.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--

-- 	v1.0.0.0 (20.10.2018):
-- 		- initial fs19 ()
--
-- Notes:
--
--
-- ToDo:
--
--

GC_ProductionDynamicStorageCustomTitleEvent = {}
GC_ProductionDynamicStorageCustomTitleEvent_mt = Class(GC_ProductionDynamicStorageCustomTitleEvent, Event)

InitEventClass(GC_ProductionDynamicStorageCustomTitleEvent, "GC_ProductionDynamicStorageCustomTitleEvent")

function GC_ProductionDynamicStorageCustomTitleEvent:emptyNew()
	local self = Event:new(GC_ProductionDynamicStorageCustomTitleEvent_mt)
	return self
end

function GC_ProductionDynamicStorageCustomTitleEvent:new(dynamicStorage, customTitle)
	local self = GC_ProductionDynamicStorageCustomTitleEvent:emptyNew()
	self.dynamicStorage = dynamicStorage
	self.customTitle = customTitle

	return self
end

function GC_ProductionDynamicStorageCustomTitleEvent:readStream(streamId, connection)
	self.dynamicStorage = NetworkUtil.readNodeObject(streamId)
	self.customTitle = streamReadString(streamId)

	self:run(connection)
end

function GC_ProductionDynamicStorageCustomTitleEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.dynamicStorage)
	streamWriteString(streamId, self.customTitle)
end

function GC_ProductionDynamicStorageCustomTitleEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(GC_ProductionDynamicStorageCustomTitleEvent:new(self.dynamicStorage, self.customTitle), nil, connection, self.dynamicStorage)
	end

	self.dynamicStorage:setCustomTitle(self.customTitle, true)
end

function GC_ProductionDynamicStorageCustomTitleEvent.sendEvent(dynamicStorage, customTitle, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(GC_ProductionDynamicStorageCustomTitleEvent:new(dynamicStorage, customTitle), nil, nil, dynamicStorage)
        else
            g_client:getServerConnection():sendEvent(GC_ProductionDynamicStorageCustomTitleEvent:new(dynamicStorage, customTitle))
        end
    end
end