-- 
-- GlobalCompany - Utils - i3dLoader
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.12.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (26.12.2018):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
-- 
-- 
-- ToDo:
-- 	delete i3d node after loading?
-- 

local debugIndex = g_company.debug:registerScriptName("GlobalCompany-GC_i3dLoader");

GC_i3dLoader = {};
g_company.i3dLoader = GC_i3dLoader;

function GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey)
	local i3dMappings = {};
	
	local i = 0;
	while true do
		local key = string.format("%s.i3dMapping(%d)", xmlKey, i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;
	
		local id = getXMLString(xmlFile, key .. "#id");
		local node = getXMLString(xmlFile, key .. "#node");
		i3dMappings[id] = node;			
	
		i = i + 1;
	end;
	return i3dMappings;
end;

function GC_i3dLoader:loadMaterials(i3dPath, dir, xmlFile, xmlKey, i3dMappings)
	local materials = {};
	
	local nodeId = g_i3DManager:loadSharedI3DFile(i3dPath, dir, false, false, false);
	
	local i = 0;
	while true do
		local key = string.format("%s.value(%d)", xmlKey, i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;
	
		local name = getXMLString(xmlFile, key .. "#name");
		local index = getXMLString(xmlFile, key .. "#index");
		local materialIndex = getXMLInt(xmlFile, key .. "#materialIndex");
		
		if i3dMappings ~= nil then
			index = i3dMappings[index];
		end;
				
		if materialIndex == nil then materialIndex = 0; end;
		
		if name ~= nil and name ~= "" and index ~= nil then
		
			local node = I3DUtil.indexToObject(nodeId, index);
			local material = getMaterial(node, materialIndex);
			materials[name] = material;
		end;
	
		i = i + 1;
	end;
	
	return materials;
end;