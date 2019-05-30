-- 
-- GC_MoreTrees
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.03.2019
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.1.0.0 (26.03.2019):
-- 		- add script to gc
--		- this function can dis-/enabled in the gc-settings
--		
-- 	v1.0.0.0 (06.01.2019):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
-- 
-- 
-- ToDo:
--
-- 

GC_MoreTrees = {};
local GC_MoreTrees_mt = Class(GC_MoreTrees);
InitObjectClass(GC_MoreTrees, "GC_MoreTrees");

GC_MoreTrees.debugIndex = g_company.debug:registerScriptName("GC_MoreTrees");

function GC_MoreTrees:init()
	local self = setmetatable({}, GC_MoreTrees_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_client ~= nil;	
	
	self.debugData = g_company.debug:getDebugData(GC_MoreTrees.debugIndex, g_company);
        
    g_company.settings:initSetting("moreTrees", true);

	return self;
end;

function GC_MoreTrees:canPlantTree(org)
    return function(...)
        if g_company.settings:getSetting("moreTrees", true) then
            local numUnsplit, _ = getNumOfSplitShapes(); 
            return numUnsplit < 6840+1000 * 1500;
        else
            return org(...);
        end;
    end;
end;

g_treePlantManager.canPlantTree = GC_MoreTrees:canPlantTree(g_treePlantManager.canPlantTree);
g_company.addInit(GC_MoreTrees, GC_MoreTrees.init);