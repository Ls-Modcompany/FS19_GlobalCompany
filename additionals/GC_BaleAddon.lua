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
-- 		- initial fs19 (aPuehri)
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


function GC_BaleAddon:init()
	local self = setmetatable({}, GC_BaleAddon_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_client ~= nil;
	
	self.debugData = g_company.debug:getDebugData(GC_BaleAddon.debugIndex, g_company);

	if self.isClient then
		g_company.addUpdateable(self, self.update);	
	end;

	-- g_company.settings:initSetting(self, "objectInfo", true);
	
	return self;
end;

function GC_BaleAddon:update(dt)
	if self.isClient then
		if g_currentMission.player.isControlled and not g_currentMission.player.isCarryingObject then
			if g_currentMission.player.isObjectInRange then
				if (g_currentMission.player.lastFoundObject ~= nil) then
					local foundObjectId = g_currentMission.player.lastFoundObject;
					if (foundObjectId ~= g_currentMission.terrainDetailId) then	
						if getRigidBodyType(foundObjectId) == "Dynamic" then
							local object = g_currentMission:getNodeObject(foundObjectId);
							if (object~= nil) then
								-- gc_debugPrint(object, nil, 2, "GC_BaleAddon");
								-- GC_BaleAddon:shredderBale(object, self.isServer, self.isClient);
							end;
						end;
					end;
				end;
			end;	
		end;
	end;
end;

function GC_BaleAddon:shredderBale(foundObject, isServer, isClient)
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
		local minLevel = math.random(20, 150);
		
		local dropped, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(nil, foundObject.fillLevel, foundObject.fillType, sx, sy, sz, (sx + 0.1), (sy - 0.1), (sz + 0.1), 0, radius, 3, false, nil, false);
		gc_debugPrint(dropped, nil, nil, "GC_BaleAddon - dropped");
		gc_debugPrint(lineOffset, nil, nil, "GC_BaleAddon - lineOffset");
		foundObject:setFillLevel(foundObject:getFillLevel() - dropped);
		
		if isServer then
			if (foundObject:getFillLevel() < minLevel) then
				foundObject:delete();
			end;
		end;
	end;
end

g_company.addInit(GC_BaleAddon, GC_BaleAddon.init);