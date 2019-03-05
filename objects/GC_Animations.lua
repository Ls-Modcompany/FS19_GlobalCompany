-- 
-- GlobalCompany - Objects - Animations
-- 
-- @Interface: --
-- @Author: LS-Modcompany / GtX / kevink98
-- @Date: 02.03.2019
-- @Version: 1.2.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
-- 	v1.2.0.0 (03.02.2019):
--		- add `canLoop` for external steering with 360° rotation of an object (kevink98)
--
-- 	v1.1.0.0 (13.12.2018):
--		- convert in fs19 (kevink98)
--		
-- 	v1.0.0.0 (20.11.2018):
-- 		- initial fs17 (GtX)
-- 
-- Notes:
-- 	Parts of this script based on 'AnimatedObject.lua'.
-- 	https://gdn.giants-software.com/documentation_scripting.php?version=script&category=65&class=3343
-- 
-- 
-- ToDo:
-- 	check Event in fs19
-- 	convert sample moving to fs19
-- 	debug and debugIndex
-- 

--source(g_company.dir.."events/SetGcAnimationsEvent.lua");

GC_Animations = {};
g_company.animations = GC_Animations;

GC_Animations_mt = Class(GC_Animations, Object);
InitObjectClass(GC_Animations, "GC_Animations");

function GC_Animations:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_Animations_mt;
	end;

	local self = Object:new(isServer, isClient, customMt);

	self.isMoving = false;
	self.sendIsMoving = false;

	return self;
end;

function GC_Animations:load(nodeId, target, enableSync, referenceKey, xmlFile, baseKey)
	self.nodeId = nodeId;
	self.enableSync = Utils.getNoNil(enableSync, true); -- This allows the MP sync to be disabled when not needed.

	if xmlFile ~= nil and (baseKey ~= nil or referenceKey ~= nil) then
		local key = referenceKey;
		if key == nil then
			key = string.format("%s.animation", baseKey);
		end;
		
		self.animation = {};
		self.animation.parts = {};
		self.animation.duration = Utils.getNoNil(getXMLFloat(xmlFile, key.."#duration"), 3) * 1000;
		self.animation.canLoop = Utils.getNoNil(getXMLBool(xmlFile, key .. "#canLoop"), false);
		if self.animation.duration == 0 then
			self.animation.duration = 1000;
		end;
		self.animation.time = 0;
		self.animation.direction = 0;

		local i = 0;
		while true do
			local partKey = string.format("%s.part(%d)", key, i);
			if not hasXMLProperty(xmlFile, partKey) then
				break;
			end;

			local node = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, partKey.."#index"), target.i3dMappings);
			if node ~= nil then
				local part = {};
				part.node = node;
				part.animCurve = AnimCurve:new(GC_Animations.linearInterpolatorN);
				local hasFrames = false;
				local j = 0;
				while true do
					local frameKey = string.format("%s.keyFrame(%d)", partKey, j);
					if not hasXMLProperty(xmlFile, frameKey) then
						break;
					end;

					local keyTime = getXMLFloat(xmlFile, frameKey.."#time");
					local values = {self:loadFrameValues(xmlFile, frameKey, node)};
					part.animCurve:addKeyframe({ v=values, time = keyTime});
					hasFrames = true;

					j = j + 1;
				end;

				if hasFrames then
					table.insert(self.animation.parts, part);
				end;
			end
			i = i + 1;
		end;

		local initialTime = Utils.getNoNil(getXMLFloat(xmlFile, key.."#initialTime"), 0) * 1000;
		self:setAnimTime(initialTime / self.animation.duration);

		if g_client ~= nil then
			local soundLinkNode = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, key..".sound#linkNode"));
			local linkIndex = Utils.getNoNil(soundLinkNode, self.nodeId);
			--self.sampleMoving = SoundUtil.loadSample(xmlFile, {}, key..".sound", nil, baseDir, linkIndex);
		end;
	end;
	
	if self.enableSync then
		self.gcAnimationsDirtyFlag = self:getNextDirtyFlag();
	end;
		
	g_company.addUpdateable(self, self.update);
		
	return true;
end;

function GC_Animations:loadFrameValues(xmlFile, key, node)
	local rx,ry,rz = StringUtil.getVectorFromString(getXMLString(xmlFile, key.."#rotation"));
	local x,y,z = StringUtil.getVectorFromString(getXMLString(xmlFile, key.."#translation"));
	local sx,sy,sz = StringUtil.getVectorFromString(getXMLString(xmlFile, key.."#scale"));
	local isVisible = Utils.getNoNil(getXMLBool(xmlFile, key.."#visibility"), true);

	local drx,dry,drz = getRotation(node);
	rx = Utils.getNoNilRad(rx, drx);
	ry = Utils.getNoNilRad(ry, dry);
	rz = Utils.getNoNilRad(rz, drz);
	local dx,dy,dz = getTranslation(node);
	x = Utils.getNoNil(x, dx);
	y = Utils.getNoNil(y, dy);
	z = Utils.getNoNil(z, dz);
	local dsx,dsy,dsz = getScale(node);
	sx = Utils.getNoNil(sx, dsx);
	sy = Utils.getNoNil(sy, dsy);
	sz = Utils.getNoNil(sz, dsz);

	local visibility = 1;
	if not isVisible then
		visibility = 0;
	end;

	return x, y, z, rx, ry, rz, sx, sy, sz, visibility;
end;

function GC_Animations:delete()
	if self.sampleMoving ~= nil then
		SoundUtil.deleteSample(self.sampleMoving);
	end;
	GC_Animations:superClass().delete(self);
end

function GC_Animations:readStream(streamId, connection)
	GC_Animations:superClass().readStream(self, streamId, connection);
	if connection:getIsServer() then
		if self.enableSync then
			local animTime = streamReadFloat32(streamId);
			self:setAnimTime(animTime);
		end;	
	end;
end;

function GC_Animations:writeStream(streamId, connection)
	GC_Animations:superClass().writeStream(self, streamId, connection);
	if not connection:getIsServer() then
		if self.enableSync then
			streamWriteFloat32(streamId, self.animation.time);
		end;	
	end;
end;

function GC_Animations:readUpdateStream(streamId, timestamp, connection)
	GC_Animations:superClass().readUpdateStream(self, streamId, timestamp, connection);
	if connection:getIsServer() then
		if self.enableSync then
			self.isMoving = streamReadBool(streamId);
			if self.isMoving then
				local animTime = streamReadFloat32(streamId);
				self:setAnimTime(animTime);
			end;
		end;
	end;
end;

function GC_Animations:writeUpdateStream(streamId, connection, dirtyMask)
	GC_Animations:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);
	if not connection:getIsServer() then
		if self.enableSync then
			streamWriteBool(streamId, self.isMoving);
	
			if self.isMoving then
				streamWriteFloat32(streamId, self.animation.time);
			end;
	
			self.sendIsMoving = self.isMoving;
		end;
	end;
end;

function GC_Animations:setAnimationsState(setPositive)
	local isPositive = setPositive;
	
	if setPositive == nil then
		isPositive = not self.isPositive;
	end;
	
	if g_server == nil and self.enableSync then
		g_client:getServerConnection():sendEvent(SetGcAnimationsEvent:new(self, isPositive));
	end;

	self.isPositive = isPositive;

	if isPositive then
		self.animation.direction = 1;
	else
		self.animation.direction = -1;
	end;
end;

function GC_Animations:setAnimationsState2(state)
	
	--create own event
	if g_server == nil and self.enableSync then
		--g_client:getServerConnection():sendEvent(SetGcAnimationsEvent:new(self, isPositive));
	end;

	if state > 0 then
		self.animation.direction = 1;
	elseif state < 0 then
		self.animation.direction = -1;
	else
		self.animation.direction = 0;
	end;	
end

function GC_Animations:update(dt)
	GC_Animations:superClass().update(self, dt);
	if self.enableSync then	
		if self.isServer then
			if self.animation.direction ~= 0 then
				local newAnimTime = MathUtil.clamp(self.animation.time + (self.animation.direction*dt)/self.animation.duration, 0, 1);
				self:setAnimTime(newAnimTime);
				
				if self.animation.canLoop then
					if newAnimTime == 0 and self.animation.direction < 0 then
						self:setAnimTime(1);
					elseif newAnimTime == 1 and self.animation.direction > 0 then
						self:setAnimTime(0);
					end;
				else
					if newAnimTime == 0 or newAnimTime == 1 then
						self.animation.direction = 0;
					end;
				end;
	
				self:raiseDirtyFlags(self.gcAnimationsDirtyFlag);
			end
	
			self.isMoving = self.animation.direction ~= 0;
	
			if self.sendIsMoving ~= self.isMoving then
				self:raiseDirtyFlags(self.gcAnimationsDirtyFlag);
			end;
		end;
	else
		if self.animation.direction ~= 0 then
			local newAnimTime = MathUtil.clamp(self.animation.time + (self.animation.direction*dt)/self.animation.duration, 0, 1);
			self:setAnimTime(newAnimTime);
			
			if self.animation.canLoop then
				if newAnimTime == 0 and self.animation.direction < 0 then
					newAnimTime = 1;
				elseif newAnimTime == 1 and self.animation.direction > 0 then
					newAnimTime = 0;
				end;
			else
				if newAnimTime == 0 or newAnimTime == 1 then
					self.animation.direction = 0;
				end;
			end;
		end
	
		self.isMoving = self.animation.direction ~= 0;
	end;

	if self.isClient and self.sampleMoving ~= nil then
		if self.isMoving then
			if not self.sampleMoving.isPlaying then
				SoundUtil.play3DSample(self.sampleMoving);
				self.sampleMoving.isPlaying = true;
			end;
		else
			if self.sampleMoving.isPlaying then
				SoundUtil.stop3DSample(self.sampleMoving);
				self.sampleMoving.isPlaying = false;
			end;
		end;
	end;
end;

function GC_Animations:setAnimTime(t)
	t = MathUtil.clamp(t, 0, 1);
	for _, part in pairs(self.animation.parts) do
		local v = part.animCurve:get(t)
		self:setFrameValues(part.node, v)
	end;
	self.animation.time = t;
end

function GC_Animations:setFrameValues(node, v)
	setTranslation(node, v[1], v[2], v[3])
	setRotation(node, v[4], v[5], v[6])
	setScale(node, v[7], v[8], v[9])
	setVisibility(node, v[10] == 1)
end

function GC_Animations:getAnimationTime()
	return self.animation.time;
end;

function GC_Animations:getIsMoving()
	return self.isMoving;
end;

function GC_Animations:getIsOn()
	return self.animation.time == 1;
end;

function GC_Animations:getIsOff()
	return self.animation.time == 0;
end;

function GC_Animations:getIsPositive()
	return self.isPositive;

	-- if self.animation.direction == 0 and self.animation.time > 0 then
		-- return true;
	-- end;

	-- if self.animation.direction == 1 and self.animation.time > 0 then
		-- return true;
	-- end;

	-- return false;
end;

--Copy from fs17 (fs19 don't work) -kevink98
function GC_Animations.linearInterpolatorN(first, second, alpha)
    local oneMinusAlpha = 1-alpha;
    local ret={};
    for i=1, table.getn(first.v) do
        table.insert(ret, first.v[i]*alpha + second.v[i]*oneMinusAlpha);
    end;
    return ret;
end;


