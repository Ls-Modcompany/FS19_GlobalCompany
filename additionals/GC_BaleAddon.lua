--
-- GlobalCompany - Additionals - GC_BaleAddon
--
-- @Interface: --
-- @Author: LS-Modcompany / aPuehri
-- @Date: 20.06.2019
-- @Version: 1.0.2.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.2.0 (20.06.2019)/(aPuehri):
-- 		- changed client detection
--
-- 	v1.0.1.0 (01.06.2019)/(aPuehri):
-- 		- smaler changes
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
GC_BaleAddon.enableCutBale = false;
GC_BaleAddon.object = nil;

function GC_BaleAddon:load()
    Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, GC_BaleAddon.registerActionEvents);
    Player.removeActionEvents = Utils.appendedFunction(Player.removeActionEvents, GC_BaleAddon.removeActionEventsPlayer);
    --initialize
    GC_BaleAddon.eventName = {};
end;

function GC_BaleAddon:init()
    local self = setmetatable({}, GC_BaleAddon_mt);

    self.isServer = g_server ~= nil;
    self.isClient = g_dedicatedServerInfo == nil;
    self.isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer;
    
    self.debugData = g_company.debug:getDebugData(GC_BaleAddon.debugIndex, g_company);

    self.eventId_setCutBale = g_company.eventManager:registerEvent(self, self.setCutBaleEvent);
    gc_debugPrint(self.eventId_setCutBale, nil, nil, "GC_BaleAddon - self.eventId_setCutBale");
    
    if self.isClient then
        g_company.addUpdateable(self, self.update);			
    end;

    g_company.settings:initSetting("cutBales", true);
    
    return self;
end;

function GC_BaleAddon:registerActionEvents()
    local result, eventName = InputBinding.registerActionEvent(g_inputBinding, 'GC_BALEADDON_CUT',self, GC_BaleAddon.actionCut ,false ,true ,false ,true);
    if result then
        table.insert(GC_BaleAddon.eventName, eventName);
        g_inputBinding:setActionEventTextVisibility(eventName, false);
    end;
end;

function GC_BaleAddon:removeActionEventsPlayer()
    GC_BaleAddon.eventName = {};
end;

function GC_BaleAddon:update(dt)
    if self.isClient then
        GC_BaleAddon.enableCutBale = false;
        if g_company.settings:getSetting("cutBales", true) and g_currentMission.player.isControlled and not g_currentMission.player.isCarryingObject then
            if not self.isMultiplayer and g_currentMission.player.isObjectInRange then
                local foundObjectId = g_currentMission.player.lastFoundObject;
                if (foundObjectId ~= nil) and (foundObjectId ~= g_currentMission.terrainDetailId) then
                    local object = g_currentMission:getNodeObject(foundObjectId);                    
                    if (object~= nil) then 
                        if object:isa(Bale) then
                            if (object.typeName == nil) and (object.fillType ~= nil) and (object.fillLevel ~= nil) then
                                GC_BaleAddon.object = object;
                                GC_BaleAddon.enableCutBale = GC_BaleAddon:getCanCutBale(GC_BaleAddon.object);
                            end;
                        end;
                    end;
                end;
            elseif self.isMultiplayer and g_company.settings:getSetting("objectInfo", true) then
                if (GC_ObjectInfo.foundBale~= nil) then
                    if GC_BaleAddon.object ~= GC_ObjectInfo.foundBale then
                        GC_BaleAddon.object = GC_ObjectInfo.foundBale;
                        -- gc_debugPrint(GC_ObjectInfo.foundBale, nil, nil, "GC_BaleAddon - GC_ObjectInfo.foundBale");
                    end;
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
        GC_BaleAddon:setCutBale(GC_BaleAddon.object.nodeId, false);
    end;
end;

function GC_BaleAddon:displayHelp(state)
    for i=1, #GC_BaleAddon.eventName, 1 do
        if (GC_BaleAddon.eventName[i] ~= nil) then
            g_inputBinding:setActionEventTextVisibility(GC_BaleAddon.eventName[i], state);
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
            if (foundObject:getFillLevel() <= minLevel) then
                foundObject:delete();
            end;
        end;
    end;
end

function GC_BaleAddon:readStream(streamId, connection)
	GC_BaleAddon:superClass().readStream(self, streamId, connection);

    if connection:getIsServer() then
        print ("GC_BaleAddon:readStream");
        self:setCutBale(streamReadInt16(streamId), false);		
		-- if self.animationManager ~= nil then
		-- 	local animationManagerId = NetworkUtil.readNodeObjectId(streamId);
        --     self.animationManager:readStream(streamId, connection);
        --     g_client:finishRegisterObject(self.animationManager, animationManagerId);
		-- end;

		-- self.state_baler = streamReadInt16(streamId);
		-- self.shouldTurnOff = streamReadBool(streamId);
		-- self.needMove = streamReadBool(streamId);
		-- self:setFillTyp(streamReadInt16(streamId), false);
		-- self:setFillLevel(streamReadFloat32(streamId), true);
		-- self:setFillLevelBunker(streamReadFloat32(streamId), true, true);
		-- self.baleCounter = streamReadInt16(streamId);
		-- self.autoOn = streamReadBool(streamId);
		-- self.animationManager:setAnimationTime("baleAnimation", streamReadFloat32(streamId));
		-- if self.animationManager:getAnimationTime("baleAnimation") > 0 then	
		-- 	self:setBaleObjectToAnimation(true);	
		-- 	self.animationManager:setAnimationByState("baleAnimation", true, true);
		-- end;
		
		-- if self.hasStack then
		-- 	self.state_stacker = streamReadInt16(streamId);
		-- 	self.stackBalesTarget = streamReadInt16(streamId);
		-- 	self.animationState = streamReadInt16(streamId);

		-- 	local forkNodeNums = streamReadInt16(streamId);
		-- 	for _,info in pairs (self.baleAnimationObjects) do
		-- 		if info.fillTypeIndex == self.activeFillTypeIndex then
		-- 			for i=1, forkNodeNums do
		-- 				local newBale = clone(info.node, false, false, false);
		-- 				setVisibility(newBale, true);
		-- 				setTranslation(newBale, 0.015, 0.958 + (i-1)*0.8,-0.063);
		-- 				link(self.animationManager:getPartsOfAnimation("stackAnimation")[1].node, newBale);		
		-- 			end;
		-- 			break;
		-- 		end;
		-- 	end;

		-- 	self.animationManager:setAnimationTime("stackAnimation", streamReadFloat32(streamId));
		-- 	local time = self.animationManager:getAnimationTime("stackAnimation");
		-- 	if self.animationState == Baler.ANIMATION_ISSTACKING or self.animationState == Baler.ANIMATION_ISSTACKINGEND then		
		-- 		self.animationManager:setAnimationByState("stackAnimation", true, true);
		-- 	end;
		-- end;
	
		-- if g_dedicatedServerInfo == nil then		
		-- 	self.digitalDisplayLevel:updateLevelDisplays(self.fillLevel, self.capacity);
		-- 	self.digitalDisplayBunker:updateLevelDisplays(self.fillLevelBunker, 4000);
		-- 	self.digitalDisplayNum:updateLevelDisplays(self.baleCounter, 9999999999);
		-- end;

		-- if self.state_baler == Bale.STATE_ON then
		-- 	self.conveyorFillTypeEffect:setFillType(self.activeFillTypeIndex);
		-- 	self.conveyorFillTypeEffect:start();
		-- 	self.conveyorFillType:start();
		-- end;

		-- self.state_balerMove = streamReadInt16(streamId);
		
		-- --self.dirtyObject:readStream(streamId, connection);		
	end;
end;

function GC_BaleAddon:writeStream(streamId, connection)
	GC_BaleAddon:superClass().writeStream(self, streamId, connection);

    if not connection:getIsServer() then
        print ("GC_BaleAddon:writeStream");
        streamWriteInt16(streamId, GC_BaleAddon.object.nodeId);
		-- if self.animationManager ~= nil then
		-- 	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.animationManager));
        --     self.animationManager:writeStream(streamId, connection);
        --     g_server:registerObjectInStream(connection, self.animationManager);
		-- end;

		-- streamWriteInt16(streamId, self.state_baler);
		-- streamWriteBool(streamId, self.shouldTurnOff);
		-- streamWriteBool(streamId, self.needMove);
		-- streamWriteInt16(streamId, self.activeFillTypeIndex);
		-- streamWriteFloat32(streamId, self.fillLevel);
		-- streamWriteFloat32(streamId, self.fillLevelBunker);
		-- streamWriteInt16(streamId, self.baleCounter);
		-- streamWriteBool(streamId, self.autoOn);
		-- streamWriteFloat32(streamId, self.animationManager:getAnimationTime("baleAnimation"));
		
		-- if self.hasStack then
		-- 	streamWriteInt16(streamId, self.state_stacker);
		-- 	streamWriteInt16(streamId, self.stackBalesTarget);
		-- 	streamWriteInt16(streamId, self.animationState);
		-- 	streamWriteInt16(streamId, getNumOfChildren(self.animationManager:getPartsOfAnimation("stackAnimation")[1].node));
		-- 	streamWriteFloat32(streamId, self.animationManager:getAnimationTime("stackAnimation"));
		-- end;

		-- streamWriteInt16(streamId, self.state_balerMove);
		
		-- --self.dirtyObject:writeStream(streamId, connection);
	end;
end;

function GC_BaleAddon:setCutBale(objectId, noEventSend)   
	self:setCutBaleEvent({objectId}, noEventSend);   	
end;

function GC_BaleAddon:setCutBaleEvent(data, noEventSend)    
    gc_debugPrint(data, nil, nil, "GC_BaleAddon - GC_BaleAddon:setCutBaleEvent");
    g_company.eventManager:createEvent(self.eventId_setCutBale, data, false, noEventSend);
	-- if data[2] == nil or not data[2] then
	-- 	self.unloadTrigger.fillTypes = nil;
	-- 	self.unloadTrigger:setAcceptedFillTypeState(data[1], true);

	-- 	if self.hasStack then
	-- 		self.needMove = self.stackerBaleTrigger:getNum() > 0;
	-- 	else
	-- 		self.needMove = not self.mainBaleTrigger:getTriggerEmpty();
	-- 	end;
	-- end;
	-- self.activeFillTypeIndex = data[1]; 
end;

g_company.addInit(GC_BaleAddon, GC_BaleAddon.init);
g_company.addLoadable(GC_BaleAddon, GC_BaleAddon.load);