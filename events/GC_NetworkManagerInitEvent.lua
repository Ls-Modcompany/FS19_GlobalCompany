--
-- GlobalCompany - Events - GC_NetworkManagerInitEvent
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 05.05.2020
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
--
-- 	v1.0.0.0 (05.05.2020):
-- 		- initial fs19 
--
-- Notes:
--
--
-- ToDo:
--
--

GC_NetworkManagerInitEvent = {}
local GC_NetworkManagerInitEvent_mt = Class(GC_NetworkManagerInitEvent, Event)

InitEventClass(GC_NetworkManagerInitEvent, "GC_NetworkManagerInitEvent")

function GC_NetworkManagerInitEvent:emptyNew()
    return Event:new(GC_NetworkManagerInitEvent_mt)
end

function GC_NetworkManagerInitEvent:new()
    return GC_NetworkManagerInitEvent:emptyNew()
end

function GC_NetworkManagerInitEvent:writeStream(streamId, connection)
    g_company.networkManager:writeStream(streamId, connection)
end

function GC_NetworkManagerInitEvent:readStream(streamId, connection)
    g_company.networkManager:readStream(streamId, connection)
end