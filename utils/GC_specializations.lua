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

local debugIndex = gc_debug.registerMod("GlobalCompany-GC_specializations");

GC_specializations = {};
g_company.specializations = GC_specializations;
GC_specializations.specs = {};

function GC_specializations:loadFromXML(modName, xmlPath)
	local xmlFile = loadXMLFile("specializations", xmlPath);	
		
	local i = 0;
	while true do
		local key = string.format("specializations.specialization(%d)", i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;	
		GC_specializations:registerSpecialization(xmlFile, key, modName); 				
		i = i + 1;
	end;	
	delete(xmlFile);
end;

function GC_specializations:registerSpecialization(xmlFile, key, modName)
	local name = getXMLString(xmlFile, string.format("%s#name", key));
	local className = getXMLString(xmlFile, string.format("%s#className", key));
	local filename = Utils.getNoNil(getXMLString(xmlFile, string.format("%s#filename", key)), "");
	local onlyLoad = Utils.getNoNil(getXMLString(xmlFile, string.format("%s#onlyLoad", key)), false);
	filename = g_company.utils.createModPath(modName, filename)
	
	if onlyLoad then
		name = string.format("%s.%s", modName, name);	
		className = string.format("%s.%s", modName, className);	
		g_specializationManager:addSpecialization(name, className, filename, modName);	
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
				--gc_debug.write(debugIndex, gc_debug.ERROR, "[%s] at %s missing required function 'registerEventListeners'!  Specialization cannot be added to vehicles.", s.className, s.filename);
			end;
		else
			--gc_debug.write(debugIndex, gc_debug.ERROR, "[%s] at %s missing required function 'prerequisitesPresent'!  Specialization cannot be added to vehicles.", s.className, s.filename);
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

GlobalCompany.addLoadable(GC_specializations, GC_specializations.load);





