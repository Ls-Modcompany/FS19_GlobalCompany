-- 
-- GlobalCompany - FillTypeManager
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 27.04.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (01.01.2019):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
-- 
-- 
-- ToDo:
--
-- 

GC_TreeTypeManager = {};
local GC_TreeTypeManager_mt = Class(GC_TreeTypeManager);

GC_TreeTypeManager.debugIndex = g_company.debug:registerScriptName("GlobalCompany-GC_TreeTypeManager");

function GC_TreeTypeManager:new()
    local self = {};
	setmetatable(self, GC_TreeTypeManager_mt);

	self.debugData = g_company.debug:getDebugData(GC_TreeTypeManager.debugIndex);

	return self;
end;

function GC_TreeTypeManager:loadFromXML(modName, xmlFile)

    local key = "globalCompany.treeTypeManager";
    if hasXMLProperty(xmlFile, key) then
        return;
    end;
    
    local filename = getXMLString(xmlFile, key .. "#filename");
    if filename == nil or filename == "" then
        return;
    end;

    local path = g_company.utils.createModPath(modName, filename);

    if not fileExists(path) then
        return;
    end;

    local xmlFile = loadXMLFile("map", path);

    XMLUtil.loadDataFromMapXML(xmlFile, "treeTypes", g_modsDirectory .. modName, g_treePlantManager, g_treePlantManager.loadTreeTypes, nil, g_modsDirectory .. modName)
end