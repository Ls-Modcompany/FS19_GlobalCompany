--
-- GlobalCompany - Additionals - GC_ExtendedPlaceable
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 17.03.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (17.03.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--      Convert ExtendedPlaceable.lua from ls17
--      'FS19PlaceAnywhere' is an invalid mod! He have no permission from me to convert this script in fs19!
--
-- ToDo:
-- 
--
--

GC_ExtendedPlaceable = {};
local GC_ExtendedPlaceable_mt = Class(GC_ExtendedPlaceable);
InitObjectClass(GC_ExtendedPlaceable, "GC_ExtendedPlaceable");

GC_ExtendedPlaceable.debugIndex = g_company.debug:registerScriptName("GC_ExtendedPlaceable");

function GC_ExtendedPlaceable:init()
	local self = setmetatable({}, GC_ExtendedPlaceable_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_client ~= nil;	
	
	self.debugData = g_company.debug:getDebugData(GC_ExtendedPlaceable.debugIndex, g_company);

    self.backup_DISPLACEMENT = PlacementScreenController.DISPLACEMENT_COST_PER_M3;
    self.backup_SCULPT = Landscaping.SCULPT_BASE_COST_PER_M3;
        
    g_company.settings:initSetting("extendedPlaceable", false);

	return self;
end;

function GC_ExtendedPlaceable:loadSetting(name, value)
    if value then
        PlacementScreenController.DISPLACEMENT_COST_PER_M3 = 1;
    end;
end;

function GC_ExtendedPlaceable:changeSetting(name, value)
    if value then
        PlacementScreenController.DISPLACEMENT_COST_PER_M3 = 1;
        Landscaping.DISPLACEMENT_COST_PER_M3 = 1;
    else
        PlacementScreenController.DISPLACEMENT_COST_PER_M3 = self.backup_DISPLACEMENT;
        Landscaping.DISPLACEMENT_COST_PER_M3 = self.backup_SCULPT;
    end;
end;


function GC_ExtendedPlaceable:isModificationAreaOnOwnedLand(org)
    return function(...)
        if g_company.settings:getSetting("extendedPlaceable", true) then
            return true;
        else
            return org(...);
        end;
    end;
end;

function GC_ExtendedPlaceable:isPlacementValid(org)
    return function(...)
        if g_company.settings:getSetting("extendedPlaceable", true) then
            return true;
        else
            return org(...);
        end;
    end;
end;

function GC_ExtendedPlaceable:hasObjectOverlap(org)
    return function(...)
        if g_company.settings:getSetting("extendedPlaceable", true) then
            return false;
        else
            return org(...);
        end;
    end;
end;

function GC_ExtendedPlaceable:hasOverlapWithPoint(org)
    return function(...)
        if g_company.settings:getSetting("extendedPlaceable", true) then
            return false;
        else
            return org(...);
        end;
    end;
end;

function GC_ExtendedPlaceable:isInsidePlacementPlaces(org)
    return function(...)
        if g_company.settings:getSetting("extendedPlaceable", true) then
            return false;
        else
            return org(...);
        end;
    end;
end;

function GC_ExtendedPlaceable:isInsideRestrictedZone(org)
    return function(...)
        if g_company.settings:getSetting("extendedPlaceable", true) then
            return false;
        else
            return org(...);
        end;
    end;
end;

function GC_ExtendedPlaceable:setBlockedAreaMap(org)
    return function(...)
        if g_company.settings:getSetting("extendedPlaceable", true) then
            return true;
        else
            return org(...);
        end;
    end;
end;

function GC_ExtendedPlaceable:setDynamicObjectCollisionMask(org)
    return function(s, ...)
        if g_company.settings:getSetting("extendedPlaceable", true) then
            return org(s, 0);
        else
            return org(s, ...);
        end;
    end;
end;

Landscaping.isModificationAreaOnOwnedLand  = GC_ExtendedPlaceable:isModificationAreaOnOwnedLand (Landscaping.isModificationAreaOnOwnedLand);
PlacementScreenController.isPlacementValid  = GC_ExtendedPlaceable:isPlacementValid (PlacementScreenController.isPlacementValid);
PlacementUtil.hasObjectOverlap = GC_ExtendedPlaceable:hasObjectOverlap(PlacementUtil.hasObjectOverlap);
PlacementUtil.hasOverlapWithPoint = GC_ExtendedPlaceable:hasOverlapWithPoint(PlacementUtil.hasOverlapWithPoint);
PlacementUtil.isInsidePlacementPlaces = GC_ExtendedPlaceable:isInsidePlacementPlaces(PlacementUtil.isInsidePlacementPlaces);
PlacementUtil.isInsideRestrictedZone = GC_ExtendedPlaceable:isInsideRestrictedZone(PlacementUtil.isInsideRestrictedZone);
TerrainDeformation.setBlockedAreaMap = GC_ExtendedPlaceable:setBlockedAreaMap(TerrainDeformation.setBlockedAreaMap);
TerrainDeformation.setDynamicObjectCollisionMask = GC_ExtendedPlaceable:setDynamicObjectCollisionMask(TerrainDeformation.setDynamicObjectCollisionMask);

g_company.addInit(GC_ExtendedPlaceable, GC_ExtendedPlaceable.init);