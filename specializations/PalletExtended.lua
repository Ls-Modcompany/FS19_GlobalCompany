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
    SpecializationUtil.registerFunction(vehicleType, "getFillType", PalletExtended.getFillType);
    SpecializationUtil.registerFunction(vehicleType, "getFillLevel", PalletExtended.getFillLevel);
    SpecializationUtil.registerFunction(vehicleType, "getFillTypeName", PalletExtended.getFillTypeName);
end;

function PalletExtended:onLoad(savegame)
    self.isPalletExtended = true;
	self.fillType = g_company.fillTypeManager:getFillTypeByName(getXMLString(self.xmlFile, "vehicle.palletExtended#fillType"));
	self.fillLevel = getXMLString(self.xmlFile, "vehicle.palletExtended#fillLevel");
	self.fillTypeLang = getXMLString(self.xmlFile, "vehicle.palletExtended#fillTypeLang");
end;

function PalletExtended:getFillType()
    return self.fillType;
end;

function PalletExtended:getFillLevel()
    return self.fillLevel;
end;

function PalletExtended:getFillTypeName()
    return g_company.languageManager:getText(string.format("GlobalCompanyFillType_%s", self.fillTypeLang));
end;