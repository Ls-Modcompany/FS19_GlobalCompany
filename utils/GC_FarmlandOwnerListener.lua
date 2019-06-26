--
-- GlobalCompany - Utils - GC_FarmlandOwnerListener
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 24.03.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (24.03.2019):
-- 		- initial fs19
--
--
-- Notes:
--		- Parent script 'MUST' call delete()
--		- Send update when 'set' farmland has owner change. 'onSetFarmlandStateChanged(farmId)'
--
-- ToDo:
--
--

GC_FarmlandOwnerListener = {};
local GC_FarmlandOwnerListener_mt = Class(GC_FarmlandOwnerListener);

GC_FarmlandOwnerListener.debugIndex = g_company.debug:registerScriptName("GC_FarmlandOwnerListener");

function GC_FarmlandOwnerListener:new()
	if g_company.farmlandOwnerListener ~= nil then
		g_company.debug:print("  [LSMC - GlobalCompany > GC_FarmlandOwnerManager] - Class already registered! Use 'g_company.farmlandOwnerListener' to access farmland owner listener.");
		return;
	end;

	local self = {};
	setmetatable(self, GC_FarmlandOwnerListener_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_client ~= nil;

	self.debugData = g_company.debug:getDebugData(GC_FarmlandOwnerListener.debugIndex);

	self.maxFarmlandId = 0;
	self.ownerChangeListeners = {};
	self.loadComplete = false;

	-- FarmLands are not loaded until all mods and vehicles are finished. So we need to do our checks late.
	g_company.addInit(self, self.doInit);

	if self.isServer then
		g_farmlandManager:addStateChangeListener(self);
	end;

	return self;
end;

function GC_FarmlandOwnerListener:doInit()
	local numSorted = #g_farmlandManager.sortedFarmlandIds;
	self.maxFarmlandId = g_farmlandManager.sortedFarmlandIds[numSorted];

	self.loadComplete = true;
	self:checkInvalidIds();
end;

function GC_FarmlandOwnerListener:checkInvalidIds()
	for listener, data in pairs(self.ownerChangeListeners) do
		if data.warningText ~= nil and listener.debugData ~= nil and data.farmlandId > self.maxFarmlandId then
			g_company.debug:writeWarning(listener.debugData, data.warningText);
		end;
	end;
end;

function GC_FarmlandOwnerListener:delete()
	if self.isServer then
		g_farmlandManager:removeStateChangeListener(self);
	end;
end;

function GC_FarmlandOwnerListener:onFarmlandStateChanged(farmlandId, farmId)
	local newFarmId = g_company.utils.getCorrectValue(farmId, AccessHandler.NOBODY, AccessHandler.EVERYONE);

	for listener, data in pairs(self.ownerChangeListeners) do
		if farmlandId == data.farmlandId and newFarmId ~= data.farmId then
			data.farmId = newFarmId;
			listener:onSetFarmlandStateChanged(newFarmId);
		end;
	end;
end;

function GC_FarmlandOwnerListener:addListener(listener, farmlandId, warningText)
	if self.isServer and listener ~= nil and farmlandId ~= nil then
		if listener.onSetFarmlandStateChanged ~= nil then
			self.ownerChangeListeners[listener] = {farmlandId = farmlandId, farmId = -1, warningText = warningText};
		else
			g_company.debug:writeDev(self.debugData, "function 'onSetFarmlandStateChanged(farmId)' does not exist! 'addListener' failed.");
		end;
	end;
end;

function GC_FarmlandOwnerListener:removeListener(listener)
	if self.isServer and listener ~= nil then
		self.ownerChangeListeners[listener] = nil;
	end;
end;

function GC_FarmlandOwnerListener:getMaxFarmlandId()
	if self.loadComplete then
		return self.maxFarmlandId;
	else
		g_company.debug:writeDev(self.debugData, "function 'getMaxFarmlandId' is not available before load is complete. Returning '0'");
	end;

	return 0;
end;




