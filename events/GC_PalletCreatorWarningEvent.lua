--
-- GlobalCompany - Events - GC_PalletCreatorWarningEvent
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 08.03.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
--
-- 	v1.0.0.0 (08.03.2019):
-- 		- initial fs19 ()
--
-- Notes:
--		- Server to Client only!
--
-- ToDo:
--
--

GC_PalletCreatorWarningEvent = {}
GC_PalletCreatorWarningEvent_mt = Class(GC_PalletCreatorWarningEvent, Event)

InitEventClass(GC_PalletCreatorWarningEvent, "GC_PalletCreatorWarningEvent")

function GC_PalletCreatorWarningEvent:emptyNew()
	local self = Event:new(GC_PalletCreatorWarningEvent_mt)
	return self
end

function GC_PalletCreatorWarningEvent:new(palletCreator)
	local self = GC_PalletCreatorWarningEvent:emptyNew()
	self.palletCreator = palletCreator
	return self
end

function GC_PalletCreatorWarningEvent:readStream(streamId, connection)
	local palletCreator = NetworkUtil.readNodeObject(streamId)
	if palletCreator ~= nil then
		palletCreator:showWarningMessage()
	end
end

function GC_PalletCreatorWarningEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.palletCreator)
end

function GC_PalletCreatorWarningEvent:run(connection)
	g_company.debug:print("Error: GC_PalletCreatorWarningEvent is a server to client only event")
end