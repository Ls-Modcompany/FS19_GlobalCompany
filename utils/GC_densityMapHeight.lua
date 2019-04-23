-- 
-- GlobalCompany - DensityMapHeight
-- 
-- @Interface: --
-- @Author: LS-Modcompany
-- @Date: 20.01.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (20.01.2019):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
-- 	fixed error from giants function
--  Update 23.4: This is fixed with patch 1.3
-- ToDo:
--
-- 

GC_densityMapHeight = {};
g_company.densityMapHeight = GC_densityMapHeight;

function GC_densityMapHeight:loadFromXML(modName, xmlPath)
	local xmlFile = loadXMLFile("densityMapHeightTypes", xmlPath);	

local i = 0
    while true do
        local key = string.format("densityMapHeightTypes.densityMapHeightType(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local fillTypeName = getXMLString(xmlFile, key .. "#fillTypeName")
        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
        if fillTypeIndex == nil then
			g_company.debug:print("Error loading density map height. '"..tostring(key).."' has no valid 'fillTypeName'!");
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
end;