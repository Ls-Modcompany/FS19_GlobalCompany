-- 
-- GlobalCompany - Utils - Specializations
-- 
-- @Interface: --
-- @Author: LS-Modcompany / GtX, kevink98
-- @Date: 31.12.2018
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.1.0.0 (31.12.2018):
-- 		- make it dynamicly (kevink98)
--
-- 	v1.0.0.0 (30.11.2018):
-- 		- initial fs19 (GtX)
-- 
-- Notes:
-- 
-- 
-- ToDo:
-- 

local debugIndex = g_company.debug:registerScriptName("GlobalCompany-GC_specializations");

GC_specializations = {};
g_company.specializations = GC_specializations;
GC_specializations.specs = {};
GC_specializations.modNeedSpec = {};

function GC_specializations:loadFromXML(modName, xmlFile)
	local key = "globalCompany.specializations";
	if hasXMLProperty(xmlFile, key) then
		local externalXml = getXMLString(xmlFile, string.format("%s#xmlFilename", key));
		if externalXml ~= nil then
			xmlFile = loadXMLFile("specializations", g_company.utils.createModPath(modName, externalXml));
			key = "specializations";
		end;	

		local i = 0;
		while true do
			local key = string.format("%s.specialization(%d)", key, i);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;	
			GC_specializations:registerSpecialization(xmlFile, key, modName); 				
			i = i + 1;
		end;	

		if externalXml ~= nil then
			delete(xmlFile);	
		end;	
	end;
end;

function GC_specializations:registerSpecialization(xmlFile, key, modName)
	local name = getXMLString(xmlFile, string.format("%s#name", key));
	local className = getXMLString(xmlFile, string.format("%s#className", key));
	local filename = Utils.getNoNil(getXMLString(xmlFile, string.format("%s#filename", key)), "");
	local onlyLoad = Utils.getNoNil(getXMLString(xmlFile, string.format("%s#onlyLoad", key)), false);
	filename = g_company.utils.createModPath(modName, filename)

	if onlyLoad then
		local mName = string.format("%s.%s", modName, name);	
		local cName = string.format("%s.%s", modName, className);	
		g_specializationManager:addSpecialization(mName, cName, filename, modName);	
		
		if GC_specializations.modNeedSpec[name] ~= nil then
			for _, mName in pairs(GC_specializations.modNeedSpec[name])do
				local mNameN = string.format("%s.%s", mName, name);	
				local cNameN = string.format("%s.%s", mName, className);	
				g_specializationManager:addSpecialization(mNameN, cNameN, filename, mName);	
			end;
		end;
	else
		local specEnvName = string.format("%s.%s", "FS19_GlobalCompany", name);
		table.insert(GC_specializations.specs, {specEnvName=specEnvName, modName=modName, name=name, className=className, filename=filename});	
		g_specializationManager:addSpecialization(name, className, filename);	
	end;
end;

function GC_specializations:load()
	for _,s in pairs(GC_specializations.specs) do
		local spec = g_specializationManager:getSpecializationObjectByName(s.specEnvName);		
		
		if spec.prerequisitesPresent~= nil then
			if spec.registerEventListeners ~= nil then
				local vehicleTypes = g_vehicleTypeManager:getVehicleTypes();
				for typeName, vehicleType in pairs(vehicleTypes) do
					if vehicleType ~= nil and vehicleType.specializations ~= nil then
						if self:getCanAddSpec(vehicleType, spec, s) then
							g_vehicleTypeManager:addSpecialization(typeName, s.specEnvName);

							spec.registerEventListeners(vehicleType);

							if spec.registerFunctions ~= nil then
								spec.registerFunctions(vehicleType);
							end;

							if spec.registerOverwrittenFunctions ~= nil then
								spec.registerOverwrittenFunctions(vehicleType);
							end;
						end;
					end;
				end;
			else
				--g_company.debug.write(debugIndex, g_company.debug.ERROR, "[%s] at %s missing required function 'registerEventListeners'!  Specialization cannot be added to vehicles.", s.className, s.filename);
			end;
		else
			--g_company.debug.write(debugIndex, g_company.debug.ERROR, "[%s] at %s missing required function 'prerequisitesPresent'!  Specialization cannot be added to vehicles.", s.className, s.filename);
		end;
	end;
end;

function GC_specializations:getCanAddSpec(vehicleType, spec, s)
	for name, _ in pairs (vehicleType.specializationsByName) do
		local point = string.find(name, ".", nil, true)
		if point ~= nil then
			local envName = string.sub(name, 1, point - 1);
			if string.format("%s.%s", envName, s.className) ~= nil then
				return false;
			end;
		end;
	end;

	return spec.prerequisitesPresent(vehicleType.specializations);
end;

function GC_specializations:addNeedSpec(modName, specName)
	if GC_specializations.modNeedSpec[specName] == nil then
		GC_specializations.modNeedSpec[specName] = {};
	end;
	table.insert(GC_specializations.modNeedSpec[specName], modName);
end;

GlobalCompany.addLoadable(GC_specializations, GC_specializations.load);