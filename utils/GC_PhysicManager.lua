--
-- GlobalCompany - Physic - Manager
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 09.08.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (09.08.2019):
-- 		- initial fs19
--
-- Notes:
--
--
--
-- ToDo:
--
--

-- self.raycastId =  g_company.raycastManager:addRaycastAll(spec, true, false, g_currentMission.player.cameraNode, 0,0,2, g_currentMission.player.cameraNode, 0,0,-2, "outsideRaycast", Player.MAX_PICKABLE_OBJECT_DISTANCE * 5);


GC_PhysicManager = {};
local GC_PhysicManager_mt = Class(GC_PhysicManager);

GC_PhysicManager.debugIndex = g_company.debug:registerScriptName("GC_PhysicManager");

GC_PhysicManager.ID_RAYCAST = 0;

function GC_PhysicManager:new()
	local self = {};
    setmetatable(self, customMt or GC_PhysicManager_mt);
    
	self.isServer = g_server ~= nil;
	self.isClient = g_dedicatedServerInfo == nil;

    self.ids = {};
    self.ids[GC_PhysicManager.ID_RAYCAST] = 0;

    self.raycasts = {};
    self.currentRaycast = -1;

    self.overlapSpheres = {};
    self.currentoverlapSphere = -1;

	self.debugData = g_company.debug:getDebugData(GC_PhysicManager.debugIndex);

    g_company.addUpdateable(self, self.update);	

	return self
end

function GC_PhysicManager:getNextId(IdIdx)
    local id = self.ids[IdIdx];
    self.ids[IdIdx] = self.ids[IdIdx] + 1;
    return id;
end;

function GC_PhysicManager:addRaycastAll(targetObject, onClient, onServer, node1, x,y,z, node2, nx,ny,nz, raycastFunctionCallback, maxDistance)
    local newRaycast = {};
    
    newRaycast.id = self:getNextId(GC_PhysicManager.ID_RAYCAST);
    newRaycast.targetObject = targetObject;
    newRaycast.onClient = onClient;
    newRaycast.onServer = onServer;
    newRaycast.node1 = node1;
    newRaycast.node2 = node2;
    newRaycast.x = x;
    newRaycast.y = y;
    newRaycast.z = z;
    newRaycast.nx = nx;
    newRaycast.ny = ny;
    newRaycast.nz = nz;
    newRaycast.raycastFunctionCallback = raycastFunctionCallback;
    newRaycast.maxDistance = Utils.getNoNil(maxDistance, Player.MAX_PICKABLE_OBJECT_DISTANCE * 1.75);
	
    self.raycasts[newRaycast.id] = newRaycast;
    return newRaycast.id;
end

function GC_PhysicManager:addOverlapSphere(targetObject, onClient, onServer, node, radius, overlapFunctionCallback, collisionMask, includeDynamics, includeStatics, exactTest)
    local newOverlapSphere = {};
    
    newOverlapSphere.id = self:getNextId(GC_PhysicManager.ID_RAYCAST);
    newOverlapSphere.targetObject = targetObject;
    newOverlapSphere.onClient = onClient;
    newOverlapSphere.onServer = onServer;
    newOverlapSphere.node = node;
    newOverlapSphere.radius = Utils.getNoNil(radius, Player.MAX_PICKABLE_OBJECT_DISTANCE * 1.75);
    newOverlapSphere.overlapFunctionCallback = overlapFunctionCallback;
    newOverlapSphere.collisionMask = collisionMask;
    newOverlapSphere.includeDynamics = Utils.getNoNil(includeDynamics, true);
    newOverlapSphere.includeStatics = Utils.getNoNil(includeStatics, true);
    newOverlapSphere.exactTest = Utils.getNoNil(exactTest, false);
	
    self.overlapSpheres[newOverlapSphere.id] = newOverlapSphere;
    return newOverlapSphere.id;
end

function GC_PhysicManager:update()
    for _,r in pairs(self.raycasts) do

        if r.targetObject:getIsActiveRaycast(r.id) then
            
			local x,y,z = localToWorld(r.node1, r.x, r.y, r.z);
			local nx,ny,nz = localDirectionToWorld(r.node2, r.nx, r.ny, r.nz);

            local run = false;
            if r.onServer and self.isServer then
                self.currentRaycast = r.id;
                raycastAll(x,y,z, nx,ny,nz, "hitRaycast", r.maxDistance, self);		
                self.currentRaycast = -1;
                run = true;	
            end;
            if not run and r.onClient and self.isClient then
                self.currentRaycast = r.id;
                raycastAll(x,y,z, nx,ny,nz, "hitRaycast", r.maxDistance, self);			
                self.currentRaycast = -1;	
            end;
        end;

    end;    

    for _,sphere in pairs(self.overlapSpheres) do
        if sphere.targetObject:getIsActiveOverlapSphere(sphere.id) then		
            --print("is active")	
			local x,y,z = getWorldTranslation(sphere.node);
            local run = false;
            if sphere.onServer and self.isServer then
                self.currentOverlapSphere = sphere.id;
                overlapSphere(x, y, z, sphere.radius, "hitOverlap", sphere.targetObject, sphere.collisionMask, sphere.includeDynamics, sphere.includeStatics, sphere.exactTest);
                self.currentOverlapSphere = -1;
                run = true;	
            end;
            if not run and sphere.onClient and self.isClient then
                self.currentOverlapSphere = sphere.id;
                overlapSphere(x, y, z, sphere.radius, "hitOverlap", sphere.targetObject, sphere.collisionMask, sphere.includeDynamics, sphere.includeStatics, sphere.exactTest);
                self.currentOverlapSphere = -1;	
            end;
        end;
    end;    
end

function GC_PhysicManager:hitRaycast(hitObjectId, x, y, z, distance)
    if self.currentRaycast > -1 and hitObjectId ~= nil and hitObjectId ~= g_currentMission.terrainDetailId then
        local raycast = self.raycasts[self.currentRaycast];
        raycast.targetObject[raycast.raycastFunctionCallback](raycast.targetObject, hitObjectId, x, y, z, distance);
    end;
end;

function GC_PhysicManager:hitOverlap(hitObjectId, x, y, z, distance)
    --print("hit")
    if self.currentOverlapSphere > -1 and hitObjectId ~= nil and hitObjectId ~= g_currentMission.terrainDetailId then
        local overlapSphere = self.overlapSpheres[self.currentOverlapSphere];
        overlapSphere.targetObject[overlapSphere.overlapFunctionCallback](overlapSphere.targetObject, hitObjectId, x, y, z, distance);
    end;
end;