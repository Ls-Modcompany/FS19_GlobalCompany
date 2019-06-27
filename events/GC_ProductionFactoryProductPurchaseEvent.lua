--
-- GlobalCompany - Events - GC_ProductionFactoryProductPurchaseEvent
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / GtX
-- @Date: 09.03.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.0.0.0 (09.03.2019):
-- 		- initial fs19 (GtX)
--
--
-- Notes:
--
--
-- ToDo:
--
--

GC_ProductionFactoryProductPurchaseEvent = {}
GC_ProductionFactoryProductPurchaseEvent_mt = Class(GC_ProductionFactoryProductPurchaseEvent, Event)

InitEventClass(GC_ProductionFactoryProductPurchaseEvent, "GC_ProductionFactoryProductPurchaseEvent")

function GC_ProductionFactoryProductPurchaseEvent:emptyNew()
	local self = Event:new(GC_ProductionFactoryProductPurchaseEvent_mt)
	return self
end

function GC_ProductionFactoryProductPurchaseEvent:new(factory, lineId, inputId, buyLiters, purchasePrice)
	local self = GC_ProductionFactoryProductPurchaseEvent:emptyNew()
	self.factory = factory
	self.lineId = lineId
	self.inputId = inputId
	self.buyLiters = buyLiters
	self.purchasePrice = purchasePrice

	return self
end

function GC_ProductionFactoryProductPurchaseEvent:readStream(streamId, connection)
	assert(g_currentMission:getIsServer())
	self.factory = NetworkUtil.readNodeObject(streamId)
	self.lineId = streamReadUInt8(streamId)
	self.inputId = streamReadUInt8(streamId)
	self.buyLiters = streamReadFloat32(streamId)
	self.purchasePrice = streamReadFloat32(streamId)

	self:run(connection)
end

function GC_ProductionFactoryProductPurchaseEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.factory)
	streamWriteUInt8(streamId, self.lineId)
	streamWriteUInt8(streamId, self.inputId)
	streamWriteFloat32(streamId, self.buyLiters)
	streamWriteFloat32(streamId, self.purchasePrice)
end

function GC_ProductionFactoryProductPurchaseEvent:run(connection)
	if not connection:getIsServer() then
		local productLine = self.factory.productLines[self.lineId]
		if productLine ~= nil and productLine.inputs ~= nil then
			local input =  productLine.inputs[self.inputId]
			self.factory:doProductPurchase(input, self.buyLiters, self.purchasePrice)
		end
	else
		g_company.debug:print("  [LSMC - GlobalCompany > GC_ProductionFactory] ERROR: ProductPurchaseEvent is a client to server only event!")
	end
end






