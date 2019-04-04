--
-- GlobalCompany - Objects - GC_RotationNodes
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 06.02.2019
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.1.0 (06.02.2019):
-- 		- change to 'raiseUpdate' Updateable instead of using 'Object' class as this is a client side script only.
--
-- 	v1.1.0.0 (03.02.2019):
-- 		- convert to fs19
--
-- 	v1.0.0.0 (26.05.2018):
-- 		- initial fs17 (GtX)
--
-- Notes:
--		- Client Side Only.
--		- Parent script 'MUST' call delete()
--
-- ToDo:
--
--

GC_RotationNodes = {};
local GC_RotationNodes_mt = Class(GC_RotationNodes);

GC_RotationNodes.debugIndex = g_company.debug:registerScriptName("GC_RotationNodes");

g_company.rotationNodes = GC_RotationNodes;

function GC_RotationNodes:new(isServer, isClient, customMt)
	local self = {};
	setmetatable(self, customMt or GC_RotationNodes_mt);

	self.isServer = isServer;
    self.isClient = isClient;

	self.rotationNodes = nil;
	self.rotationActive = false;
	self.rotationsRunning = false;

	self.rotationAxes = {};
	self.rotationAxes["X"] = 1;
	self.rotationAxes["Y"] = 2;
	self.rotationAxes["Z"] = 3;
	
	self.numRotationNodes = 0;

	return self;
end;

function GC_RotationNodes:load(nodeId, target, xmlFile, xmlKey, groupKey, rotationNodes)
	if nodeId == nil or target == nil then
		local text = "Loading failed! 'nodeId' parameter = %s, 'target' parameter = %s";
		g_company.debug:logWrite(GC_RotationNodes.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil);
		return false;
	end;

	self.rootNode = nodeId;
	self.target = target;
	
	self.debugData = g_company.debug:getDebugData(GC_RotationNodes.debugIndex, target);
	
	local returnValue = false;
	if self.isClient then
		if rotationNodes == nil then
			rotationNodes = {};
	
			if xmlFile ~= nil and xmlKey ~= nil then
				if groupKey == nil then
					groupKey = "rotationNodes";
				end;
				
				local i = 0;
				while true do
					local key = string.format("%s.%s.rotationNode(%d)", xmlKey, groupKey, i);
					if not hasXMLProperty(xmlFile, key) then
						break;
					end;
	
					local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings);
					if node ~= nil then
						rotationNode = {};
						rotationNode.node = node;
						local rotateAxis = getXMLString(xmlFile, key.."#rotationAxis"); -- X, Y, Z
						rotationNode.rotateAxis = self.rotationAxes[rotateAxis];
						rotationNode.rotationSpeed = getXMLFloat(xmlFile, key.."#rotationSpeed");
						rotationNode.fadeOnTime = getXMLFloat(xmlFile, key.."#fadeOnTime");
						rotationNode.fadeOffTime = getXMLFloat(xmlFile, key.."#fadeOffTime");
						
						-- Operating sequence must be multiplies of two. These numbers will then loop.  6 8 4 4 = on(6 sec) off(8 sec) on(4 sec) off(4 sec)
						rotationNode.intervals = g_company.xmlUtils.getEvenTableFromXMLString(xmlFile, key .. "#operatingSequence", 2, true, false, 1000, self.debugData);
						-- This is the number of 'seconds' before the operation will start each time Rotation node is requested to start.
						rotationNode.startDelay = getXMLInt(xmlFile, key .. "#startDelay");
	
						table.insert(rotationNodes, rotationNode);
					end;
					i = i + 1;
				end;
			else
				local text = "Loading failed! 'xmlFile' parameter = %s, 'xmlKey' parameter = %s";
				g_company.debug:logWrite(GC_RotationNodes.debugIndex, GC_DebugUtils.DEV, text, xmlFile ~= nil, xmlKey ~= nil);
				returnValue = false;
			end;
		end;
	
		if self:loadRotationNodes(rotationNodes) then
			self.numRotationNodes = #self.rotationNodes;
			g_company.addRaisedUpdateable(self);
			returnValue = true;
		end;
	else
		g_company.debug:writeDev(self.debugData, "Failed to load 'CLIENT ONLY' script on server!");
		returnValue = true; -- Send true so we can also print 'function' warnings if called by server.
	end;

	return returnValue;
end;

function GC_RotationNodes:delete()
	if self.isClient then
		g_company.removeRaisedUpdateable(self);
	end;
end;

function GC_RotationNodes:loadRotationNodes(rotationNodes)
	local numRotNodes = #rotationNodes;

	if numRotNodes > 0 then
		self.rotationNodes = {};

		for i = 1, numRotNodes do
			local rotationNode = rotationNodes[i];

			if rotationNode.node ~= nil then
				local node = {};
				node.index = rotationNode.node;

				node.rotateAxis = rotationNode.rotateAxis;
				if node.rotateAxis == nil or node.rotateAxis < 1 or node.rotateAxis > 3 then
					node.rotateAxis = 2;
				end;
				node.rotationSpeed = math.rad(Utils.getNoNil(rotationNode.rotationSpeed, 800) * 0.001);
				node.fadeOnTime = Utils.getNoNil(rotationNode.fadeOnTime, 3) * 1000;
				node.fadeOffTime = Utils.getNoNil(rotationNode.fadeOffTime, 3) * 1000;
				node.currentRotation = 0;
				
				if rotationNode.intervals ~= nil then					
					local startDelay = Utils.getNoNil(rotationNode.startDelay, 0);
					startDelay = math.max(startDelay, 0);
					local operatingTime = 0;
					if startDelay > 0 then
						operatingTime = startDelay * 1000;
					end;

					node.intervalId = 0;
					node.intervals = rotationNode.intervals;
					node.numIntervals = #rotationNode.intervals;
					node.intervalActive = false;
					node.delayTime = operatingTime;
					node.operatingTime = operatingTime;
				end;

				table.insert(self.rotationNodes, node);
			end;
		end;

		return true;
	end;

	return false;
end;

function GC_RotationNodes:update(dt)
	if self.isClient and self:getCanUpdateRotation() then
		local rotatingNodes = 0;
		for i = 1, self.numRotationNodes do
			local node = self.rotationNodes[i];
			if node.intervals ~= nil then
				if self.rotationActive then
					node.operatingTime = node.operatingTime - dt;
					if node.operatingTime <= 0 then
						node.intervalId = node.intervalId + 1;
						if node.intervalId > node.numIntervals then
							node.intervalId = 1;
						end;

						node.operatingTime = node.operatingTime + node.intervals[node.intervalId];
						node.intervalActive = not node.intervalActive;
					end;
					
					if node.intervalActive then
						node.currentRotation = math.min(1, node.currentRotation + dt / node.fadeOnTime);
					else
						node.currentRotation = math.max(0, node.currentRotation - dt / node.fadeOffTime);
					end;
				else
					node.currentRotation = math.max(0, node.currentRotation - dt / node.fadeOffTime);
					if node.intervalActive then
						node.intervalActive = false;
					end;
					node.operatingTime = node.delayTime;
					node.intervalId = 0;
				end;
			else
				if self.rotationActive then
					node.currentRotation = math.min(1, node.currentRotation + dt / node.fadeOnTime);
				else
					node.currentRotation = math.max(0, node.currentRotation - dt / node.fadeOffTime);
				end;
			end;

			if node.currentRotation > 0 then
				rotatingNodes = rotatingNodes + 1;
				local rotatation = node.currentRotation * dt * node.rotationSpeed;
				if node.rotateAxis == 1 then
					rotate(node.index, rotatation, 0, 0);
				elseif node.rotateAxis == 2 then
					rotate(node.index, 0, rotatation, 0);
				elseif node.rotateAxis == 3 then
					rotate(node.index, 0, 0, rotatation);
				end
			end;
		end;

		self.rotationsRunning = rotatingNodes ~= 0;

		self:raiseUpdate();
	end;
end;

function GC_RotationNodes:getCanUpdateRotation()
	if self.rotationActive == false and self.rotationsRunning == false then
		return false;
	end;
	return true;
end;

function GC_RotationNodes:setRotationNodesState(state, forceState)
	if self.isClient then
		local setState = Utils.getNoNil(state, not self.rotationActive);
		
		if self.rotationActive ~= setState or forceState == true then
			self.rotationActive = setState;
		end;

		self:raiseUpdate();
	else
		g_company.debug:writeDev(self.debugData, "'setRotationNodesState' is a client only function!");
	end;
end;

function GC_RotationNodes:getRotationNodesState()
	return self.rotationActive;
end;

function GC_RotationNodes:getRotationNodesRunning()
	return self.rotationsRunning;
end;





