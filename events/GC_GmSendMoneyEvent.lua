--
-- GlobalCompany - Events - SendMoney
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 08.08.2020
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.0.0.0 (08.08.2020):
-- 		- initial fs19 ()
--
--
-- Notes:
--
--
-- ToDo:
--
--

GC_GmSendMoneyEvent = {}
GC_GmSendMoneyEvent_mt = Class(GC_GmSendMoneyEvent, Event)

InitEventClass(GC_GmSendMoneyEvent, "GC_GmSendMoneyEvent")

function GC_GmSendMoneyEvent:emptyNew()
	local self = Event:new(GC_GmSendMoneyEvent_mt)
	return self
end

function GC_GmSendMoneyEvent:new(money, farmId)
	local self = GC_GmSendMoneyEvent:emptyNew()
	self.money = money
	self.farmId = farmId

	return self
end

function GC_GmSendMoneyEvent:readStream(streamId, connection)
	assert(g_currentMission:getIsServer())
	self.money = streamReadInt32(streamId)
	self.farmId = streamReadInt8(streamId)

	self:run(connection)
end

function GC_GmSendMoneyEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.money)
	streamWriteInt8(streamId, self.farmId)
end

function GC_GmSendMoneyEvent:run(connection)
	if not connection:getIsServer() then
		g_currentMission:addMoney(self.money, self.farmId, MoneyType.HARVEST_INCOME, true, false)
	end
end