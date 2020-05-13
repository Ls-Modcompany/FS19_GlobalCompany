-- 
-- GlobalCompany - DensityMapHeight
-- 
-- @Interface: 1.4.0.0 b5008
-- @Author: LS-Modcompany
-- @Date: 05.07.2019
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.1.0.0 (05.07.2019):
-- 		- adaption to patch 1.4
--
-- 	v1.0.0.0 (20.01.2019):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
-- 	    fixed error from giants function
--      Update 23.04: This is fixed with patch 1.3
--      Update 05.07: This is a bug again at patch 1.4
-- ToDo:
--
-- 



GC_densityMapHeightManager = {};
local GC_densityMapHeight_mt = Class(GC_densityMapHeightManager);

function GC_densityMapHeightManager:new()
    local self = {};
	setmetatable(self, GC_densityMapHeight_mt);

    self.fileNames = {};
    
    g_company.addLoadable(self, self.loadDensitys);

	self.debugData = g_company.debug:getDebugData(GC_FillTypeManager.debugIndex);

	return self;
end;

function GC_densityMapHeightManager:loadFromXML(modName, xmlFile)
    local key = "globalCompany.densityMapHeightManager";
    if not hasXMLProperty(xmlFile, key) then
        return
    end;

    local xmlFilename = getXMLString(xmlFile, key .. "#filename");
    if xmlFilename ~= nil then
        self.fileNames[g_company.utils.createModPath(modName, xmlFilename)] = modName;
    end;
end;

function GC_densityMapHeightManager:loadDensitys()
    for xmlFilename,modName in pairs(self.fileNames) do
        local xmlFile = loadXMLFile("densityMapHeightTypes", xmlFilename);	    
        local i = 0
        while true do
            local key = string.format("densityMapHeightTypes.densityMapHeightType(%d)", i)
            if not hasXMLProperty(xmlFile, key) then
                break
            end

            local fillTypeName = getXMLString(xmlFile, key .. "#fillTypeName")
            local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
            if fillTypeIndex == nil then
                g_company.debug:print("Error loading density map height. '"..tostring(key).."' has no valid 'fillTypeName' %s !", fillTypeName);
                return
            end

            local maxSurfaceAngle = math.rad( Utils.getNoNil(getXMLFloat(xmlFile, key .. "#maxSurfaceAngle"), 26) )
            local fillToGroundScale = Utils.getNoNil( getXMLFloat(xmlFile, key .. "#fillToGroundScale"), 1.0 )
            local allowsSmoothing = Utils.getNoNil( getXMLBool(xmlFile, key .. "#allowsSmoothing"), false )
            local collisionScale = Utils.getNoNil( getXMLFloat(xmlFile, key .. ".collision#scale"), 1.0 )
            local collisionBaseOffset = Utils.getNoNil( getXMLFloat(xmlFile, key .. ".collision#baseOffset"), 0.0 )
            local minCollisionOffset = Utils.getNoNil( getXMLFloat(xmlFile, key .. "#.collision#minOffset"), 0.0 )
            local maxCollisionOffset = Utils.getNoNil( getXMLFloat(xmlFile, key .. "#.collision#maxOffset"), 1.0 )

            local diffuseMapFilename = getXMLString(xmlFile, key .. ".textures#diffuse")
            local normalMapFilename = getXMLString(xmlFile, key .. ".textures#normal")
            local distanceFilename = getXMLString(xmlFile, key .. ".textures#distance")
            
            diffuseMapFilename = g_company.utils.createModPath(modName, diffuseMapFilename);
            normalMapFilename = g_company.utils.createModPath(modName, normalMapFilename);
            distanceFilename = g_company.utils.createModPath(modName, distanceFilename);

            if diffuseMapFilename == nil or normalMapFilename == nil or distanceFilename == nil then
                g_company.debug:print("Error loading density map height type. '"..tostring(key).."' is missing texture(s)!");
                return
            end
            
            g_densityMapHeightManager:addDensityMapHeightType(fillTypeName, maxSurfaceAngle, collisionScale, collisionBaseOffset, minCollisionOffset, maxCollisionOffset, fillToGroundScale, allowsSmoothing, diffuseMapFilename, normalMapFilename, distanceFilename, isBaseType)
            i = i + 1
        end
        delete(xmlFile);
    end;
end;

--g_densityMapHeightManager.loadMapData = Utils.appendedFunction(g_densityMapHeightManager.loadMapData, g_company.densityMapHeight.loadDensitys);