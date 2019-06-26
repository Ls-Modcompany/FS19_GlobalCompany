--
-- GlobalCompany - Events - GC_ProductionFactorySpawnPalletEvent
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / GtX
-- @Date: 12.03.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.0.0.0 (12.03.2019):
-- 		- initial fs19 (GtX)
--
--
-- Notes:
--
--
-- ToDo:
--
--

GC_ProductionFactorySpawnPalletEvent = {}
GC_ProductionFactorySpawnPalletEvent_mt = Class(GC_ProductionFactorySpawnPalletEvent, Event)

InitEventClass(GC_ProductionFactorySpawnPalletEvent, "GC_ProductionFactorySpawnPalletEvent")

function GC_ProductionFactorySpawnPalletEvent:emptyNew()
	local self = Event:new(GC_ProductionFactorySpawnPalletEvent_mt)
	return self
end

function GC_ProductionFactorySpawnPalletEvent:new(factory, lineId, outputId, numberToSpawn)
	local self = GC_ProductionFactorySpawnPalletEvent:emptyNew()
	self.factory = factory
	self.lineId = lineId
	self.outputId = outputId
	self.numberToSpawn = numberToSpawn

	return self
end

function GC_ProductionFactorySpawnPalletEvent:readStream(streamId, connection)
	assert(g_currentMission:getIsServer())
	
	self.factory = NetworkUtil.readNodeObject(streamId)
	self.lineId = streamReadUInt8(streamId)
	self.outputId = streamReadUInt8(streamId)
	self.numberToSpawn = streamReadUInt8(streamId)

	self:run(connection)
end

function GC_ProductionFactorySpawnPalletEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.factory)
	streamWriteUInt8(streamId, self.lineId)
	streamWriteUInt8(streamId, self.outputId)
	streamWriteUInt8(streamId, self.numberToSpawn)
end

function GC_ProductionFactorySpawnPalletEvent:run(connection)
	if not connection:getIsServer() then
		local productLine = self.factory.productLines[self.lineId]
		if productLine ~= nil and productLine.outputs ~= nil then
			local output =  productLine.outputs[self.outputId]
			self.factory:spawnPalletFromOutput(output, self.numberToSpawn)
		end
	else
		g_company.debug:print("  [LSMC - GlobalCompany > GC_ProductionFactory] ERROR: SpawnPalletEvent is a client to server only event!")
	end
end