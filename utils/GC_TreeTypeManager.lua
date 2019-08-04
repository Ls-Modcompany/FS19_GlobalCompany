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
    if not hasXMLProperty(xmlFile, key) then
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

    local i = 0
    while true do
        local xmlKey = string.format("map.treeTypes.treeType(%d)", i);
        if not hasXMLProperty(xmlFile, xmlKey) then
            break;
        end;
        
        local name = getXMLString(xmlFile, xmlKey .. "#name");
        local nameI18N = getXMLString(xmlFile, xmlKey .. "#nameI18N");
        local growthTimeHours = getXMLInt(xmlFile, xmlKey .. "#growthTimeHours");
        
        local treeFilenames = {};
        while true do
            local stageKey = string.format("%s.stage(%d)", xmlKey, table.getn(treeFilenames));
            if not hasXMLProperty(xmlFile, stageKey) then
                break;
            end;
            table.insert(treeFilenames, g_company.utils.createModPath(modName, getXMLString(xmlFile, stageKey .. "#filename")));
        end;
        g_treePlantManager:registerTreeType(name, nameI18N, treeFilenames, growthTimeHours, false)
        
        i = i + 1;
    end;

    --XMLUtil.loadDataFromMapXML(xmlFile, "treeTypes", g_modsDirectory .. modName, g_treePlantManager, g_treePlantManager.loadTreeTypes)
end