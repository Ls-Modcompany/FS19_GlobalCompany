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

GC_FillTypeManager = {};
local GC_FillTypeManager_mt = Class(GC_FillTypeManager);

GC_FillTypeManager.debugIndex = g_company.debug:registerScriptName("GlobalCompany-GC_FillTypeManager");

function GC_FillTypeManager:new()
    local self = {};
	setmetatable(self, GC_FillTypeManager_mt);

    self.fillTypes = {};
    self.fillTypesById = {};
    self.fillTypesByName = {};    

	self.debugData = g_company.debug:getDebugData(GC_FillTypeManager.debugIndex);

	return self;
end;

function GC_FillTypeManager:loadFromXML(modName, xmlFile)

    local key = "globalCompany.fillTypeManager";
    if not hasXMLProperty(xmlFile, key) then
        return;
    end;
    
    self:loadGcFillTypes(xmlFile);

    local filename = getXMLString(xmlFile, key .. "#filename");
    if filename == nil or filename == "" then
        return;
    end;

    local path = g_company.utils.createModPath(modName, filename);

    if not fileExists(path) then
        return;
    end;

    local mapXmlFile = loadXMLFile("map", path);

    XMLUtil.loadDataFromMapXML(mapXmlFile, "fillTypes", g_modsDirectory .. modFileName, g_fillTypeManager, g_fillTypeManager.loadFillTypes, nil, g_modsDirectory .. modFileName);

end

function GC_FillTypeManager:getNextId()
    if self.fillTypeId == nil then
        self.fillTypeId = -1;
    end;
    self.fillTypeId = self.fillTypeId + 1;
    return self.fillTypeId;
end
    
function GC_FillTypeManager:registerFillType(name, lang)
    if self.fillTypesByName[name] ~= nil then
        --debug
        return;
    end;
    
    local newFillType = {};
    newFillType.id = self:getNextId();
    newFillType.name = name;
    newFillType.langName = g_company.languageManager:getText(lang);

    self.fillTypesById[newFillType.id] = newFillType;
    self.fillTypesByName[name] = newFillType;
    table.insert(self.fillTypes, newFillType);
    return newFillType.id;
end;

function GC_FillTypeManager:loadGcFillTypes(xmlFile)
    local insertFillTypes = {};
    local i = 0;
    while true do
        local key = string.format("globalCompany.fillTypeManager.fillType(%d)", i);
        if not hasXMLProperty(xmlFile, key) then
            break;
        end;
        
        local name = getXMLString(xmlFile, key .. "#name");
        local langName = getXMLString(xmlFile, key .. "#langName");
        table.insert(insertFillTypes, self:registerFillType(name, langName));
        i = i + 1;
    end;
    return insertFillTypes;
end

--[[
function GC_FillTypeManager:readFillTypesFromXML(xmlFile, xmlKey)
    local fillTypes = {};
    local i = 0;
    while true do
        local key = string.format("%s.fillTypes.fillType(%d)", xmlKey, i);
        if not hasXMLProperty(xmlFile, key) then
            break;
        end;
        
        local name = getXMLString(xmlFile, key .. "#name");
        table.insert(fillTypes, self:getFillTypeByName(name));
        i = i + 1;
    end;
    return fillTypes;
end
]]--

function GC_FillTypeManager:getFillTypeLangNameById(id)
    print(id)
    if self.fillTypesById[id] ~= nil then
        return self.fillTypesById[id].langName;
    else
        --debug
        return "Not found"
    end;
end;

function GC_FillTypeManager:getFillTypeNameById(id)
    if self.fillTypesById[id] ~= nil then
        return self.fillTypesById[id].name;
    else
        --debug
        return "Not found"
    end;
end;

function GC_FillTypeManager:getFillTypeByName(name)
    if self.fillTypesByName[name] ~= nil then
        return self.fillTypesByName[name];
    else
        --debug
        return "Not found"
    end;
end;

function GC_FillTypeManager:getFillTypeIdByName(name)
    if self.fillTypesByName[name] ~= nil then
        return self.fillTypesByName[name].id;
    else
        --debug
        return "Not found"
    end;
end;