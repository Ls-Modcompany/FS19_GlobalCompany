-- 
-- GlobalCompany - Vehicles - PalletExtended
-- 
-- @Interface: 1.2.0.1 b3264
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.04.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (31.12.2018):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
-- 
-- 
-- ToDo:
-- 

PalletExtended = {};
PalletExtended.debugIndex = g_company.debug:registerScriptName("GlobalCompany-Vehicles-PalletExtended", true);

function PalletExtended.initSpecialization()
    
end;

function PalletExtended.prerequisitesPresent(specializations)
    return true;
end;

function PalletExtended.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", PalletExtended);
    SpecializationUtil.registerFunction(vehicleType, "getFillTypeId", PalletExtended.getFillTypeId);
    SpecializationUtil.registerFunction(vehicleType, "getFillLevel", PalletExtended.getFillLevel);
    SpecializationUtil.registerFunction(vehicleType, "getFillTypeName", PalletExtended.getFillTypeName);
    SpecializationUtil.registerFunction(vehicleType, "setFillLevel", PalletExtended.setFillLevel);
    SpecializationUtil.registerFunction(vehicleType, "setFillLevelEvent", PalletExtended.setFillLevelEvent);
    SpecializationUtil.registerFunction(vehicleType, "addFillLevel", PalletExtended.addFillLevel);
end;

function PalletExtended:onLoad(savegame)
    self.isPalletExtended = true;
	self.fillTypeId = g_company.fillTypeManager:getFillTypeIdByName(getXMLString(self.xmlFile, "vehicle.palletExtended#fillType"));
	self.fillLevel = getXMLString(self.xmlFile, "vehicle.palletExtended#fillLevel");
    self.langName = getXMLString(self.xmlFile, "vehicle.palletExtended#langName");
    self.deleteIfEmpty = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.palletExtended#deleteIfEmpty"), true);

    
	self.eventId_setFillLevel = g_company.eventManager:registerEvent(self, self.setFillLevelEvent);
end;

function PalletExtended:getFillTypeId()
    return self.fillTypeId;
end;

function PalletExtended:getFillLevel()
    return self.fillLevel;
end;

function PalletExtended:getFillTypeName()
    return g_company.languageManager:getText(self.langName);
end;

function PalletExtended:setFillLevel(newLevel, noEventSend)
    self:setFillLevelEvent({newLevel}, noEventSend);
end;

function PalletExtended:setFillLevelEvent(data, noEventSend)
    g_company.eventManager:createEvent(self.eventId_setFillLevel, data, false, noEventSend);
    self.fillLevel = data[1];
    if self.isServer and self.fillLevel == 0 and self.deleteIfEmpty then
        self:delete();
    end;
end;

function PalletExtended:addFillLevel(level)
    self:setFillLevel(self:getFillLevel() + level);
end;