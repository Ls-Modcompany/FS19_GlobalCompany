--
-- GlobalCompany - Additionals - GC_BaleAddon
--
-- @Interface: --
-- @Author: LS-Modcompany / aPuehri
-- @Date: 29.03.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (29.03.2019):
-- 			- initial fs19 (aPuehri)
--
--
-- Notes:
--
--
-- ToDo:
-- 
--
--

GC_BaleAddon = {};
local GC_BaleAddon_mt = Class(GC_BaleAddon);
InitObjectClass(GC_BaleAddon, "GC_BaleAddon");

GC_BaleAddon.debugIndex = g_company.debug:registerScriptName("GC_BaleAddon");
GC_BaleAddon.eventName = {};
GC_BaleAddon.enableCutBale = false;
GC_BaleAddon.object = nil;

function GC_BaleAddon:load()
    Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, GC_BaleAddon.registerActionEvents);
end;

function GC_BaleAddon:init()
    local self = setmetatable({}, GC_BaleAddon_mt);

    self.isServer = g_server ~= nil;
    self.isClient = g_client ~= nil;
    self.isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer;
    
    self.debugData = g_company.debug:getDebugData(GC_BaleAddon.debugIndex, g_company);
    
    if self.isClient and not (self.isServer and self.isMultiplayer) then
        g_company.addUpdateable(self, self.update);			
    end;

    g_company.settings:initSetting("cutBales", true);
    
    return self;
end;

function GC_BaleAddon:registerActionEvents()
    local result, eventName = InputBinding.registerActionEvent(g_inputBinding, 'GC_BALEADDON_CUT',self, GC_BaleAddon.actionCut ,false ,true ,false ,true);
    if result then
        g_inputBinding:setActionEventTextPriority(eventName, GS_PRIO_HIGH);
        table.insert(GC_BaleAddon.eventName, eventName);
        g_inputBinding.events[eventName].displayIsVisible = false;
    end;
end;

function GC_BaleAddon:update(dt)
    if self.isClient then
        GC_BaleAddon.enableCutBale = false;
        if g_company.settings:getSetting("cutBales", true) and g_currentMission.player.isControlled and not g_currentMission.player.isCarryingObject then
            if not self.isMultiplayer and g_currentMission.player.isObjectInRange then
                if (g_currentMission.player.lastFoundObject ~= nil) then
                    local foundObjectId = g_currentMission.player.lastFoundObject;
                    if (foundObjectId ~= g_currentMission.terrainDetailId) then	
                        if getRigidBodyType(foundObjectId) == "Dynamic" then
                            GC_BaleAddon.object = g_currentMission:getNodeObject(foundObjectId);
                            if (GC_BaleAddon.object~= nil) then
                                if (GC_BaleAddon.object.typeName == nil) and (GC_BaleAddon.object.fillType ~= nil) and (GC_BaleAddon.object.fillLevel ~= nil) then
                                    -- gc_debugPrint(GC_BaleAddon.object.typeName, nil, nil, "GC_BaleAddon - GC_BaleAddon.object.typename");
                                    GC_BaleAddon.enableCutBale = GC_BaleAddon:getCanCutBale(GC_BaleAddon.object);
                                end;
                            end;
                        end;
                    end;
                end;
            elseif self.isMultiplayer and g_company.settings:getSetting("objectInfo", true) then
                if (GC_ObjectInfo.mpFoundBale~= nil) then
                    GC_BaleAddon.object = GC_ObjectInfo.mpFoundBale;
                    if (GC_BaleAddon.object.typeName == nil) and (GC_BaleAddon.object.fillType ~= nil) and (GC_BaleAddon.object.fillLevel ~= nil) then
                        GC_BaleAddon.enableCutBale = GC_BaleAddon:getCanCutBale(GC_BaleAddon.object);
                    end;
                end;
            end;	
        end;
        GC_BaleAddon:displayHelp(GC_BaleAddon.enableCutBale);
    end;
end;

function GC_BaleAddon:actionCut(actionName, keyStatus, arg3, arg4, arg5)
    if GC_BaleAddon.enableCutBale and (GC_BaleAddon.object ~= nil) then
        GC_BaleAddon:cutBale(GC_BaleAddon.object, self.isServer, self.isClient);
    end;
end;

function GC_BaleAddon:displayHelp(state)
    for i=1, #self.eventName, 1 do
        if (g_inputBinding.events[self.eventName[i]] ~= nil) then
            g_inputBinding.events[self.eventName[i]].displayIsVisible = state;
        end;	
    end;
end;

function GC_BaleAddon:getCanCutBale(foundObject)
    if (foundObject.fillLevel ~= nil) and (foundObject.fillType ~= nil) then
        local testDrop = g_densityMapHeightManager:getMinValidLiterValue(foundObject.fillType);
        local sx,sy,sz = getWorldTranslation(foundObject.nodeId);
        local radius = (DensityMapHeightUtil.getDefaultMaxRadius(foundObject.fillType) / 2);
        
        if DensityMapHeightUtil.getCanTipToGroundAroundLine(nil, testDrop, foundObject.fillType, sx, sy, sz, (sx + 0.1), (sy - 0.1), (sz + 0.1), radius, nil, 3, true, nil, true) then
            return true;
        end;
    end;
    
    return false;
end;

function GC_BaleAddon:cutBale(foundObject, isServer, isClient)
    -- Arguments
    -- table	vehicle	vehicle that is tipping
    -- float	delta	delta to tip
    -- integer	filltype	fill type to tip
    -- float	sx	start x position
    -- float	sy	start y position
    -- float	sz	start z position
    -- float	ex	end x position
    -- float	ey	end y position
    -- float	ez	end z position
    -- float	innerRadius	inner radius
    -- float	radius	radius
    -- float	lineOffset	line offset
    -- boolean	limitToLineHeight	limit to line height
    -- table	occlusionAreas	occlusion areas
    -- boolean	useOcclusionAreas	use occlusion areas
    -- Return Values
    -- float	dropped	real fill level dropped
    -- float	lineOffset	line offset
    
    if (foundObject.fillLevel ~= nil) and (foundObject.fillType ~= nil) then
        local sx,sy,sz = getWorldTranslation(foundObject.nodeId);
        local radius = (DensityMapHeightUtil.getDefaultMaxRadius(foundObject.fillType) / 2);
        local minLevel = g_densityMapHeightManager:getMinValidLiterValue(foundObject.fillType);
        
        local dropped, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(nil, foundObject.fillLevel, foundObject.fillType, sx, sy, sz, (sx + 0.1), (sy - 0.1), (sz + 0.1), 0, radius, 3, false, nil, false);
        foundObject:setFillLevel(foundObject:getFillLevel() - dropped);
        
        if isServer then
            print ("Server delete");
            if (foundObject:getFillLevel() <= minLevel) then
                foundObject:delete();
            end;
        end;
    end;
end

g_company.addInit(GC_BaleAddon, GC_BaleAddon.init);
g_company.addLoadable(GC_BaleAddon, GC_BaleAddon.load);