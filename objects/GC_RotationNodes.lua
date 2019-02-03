--
-- GlobalCompany - Objects - GC_RotationNodes
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 03.02.2019
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.0.0 (03.02.2019):
-- 		- convert to fs19
--
-- 	v1.0.0.0 (26.05.2018):
-- 		- initial fs17 (GtX)
--
-- Notes:
--		- Client Side Only.
--
-- ToDo:
--
--

GC_RotationNodes = {};

local GC_RotationNodes_mt = Class(GC_RotationNodes, Object);
InitObjectClass(GC_RotationNodes, "GC_RotationNodes");

GC_RotationNodes.debugIndex = g_company.debug:registerScriptName("RotationNodes");

g_company.rotationNodes = GC_RotationNodes;

function GC_RotationNodes:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_RotationNodes_mt;
	end;

	local self = Object:new(isServer, isClient, customMt);

	self.rotationNodes = nil;
	self.rotationActive = false;
	self.rotationsRunning = false;

	self.rotationAxes = {};
	self.rotationAxes["X"] = 1;
	self.rotationAxes["Y"] = 2;
	self.rotationAxes["Z"] = 3;

	return self;
end;

function GC_RotationNodes:load(nodeId, target, xmlFile, xmlKey, rotationNodes)
	if nodeId == nil or target == nil then
		local text = "Loading failed! 'nodeId' paramater missing = %s, 'target' paramater missing = %s";
		g_company.debug:logWrite(GC_RotationNodes.debugIndex, GC_DebugUtils.DEV, text, nodeId == nil, target == nil);
		return false;
	end;

	self.rootNode = nodeId;
	self.target = target;
	self.debugData = g_company.debug:getDebugData(GC_RotationNodes.debugIndex, target);

	if rotationNodes == nil then
		rotationNodes = {};

		if xmlFile ~= nil and xmlKey ~= nil then
			local i = 0;
			while true do
				local key = string.format("%s.rotationNodes.rotationNode(%d)", xmlKey, i);
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
					rotationNode.operatingInterval = getXMLFloat(xmlFile, key.."#operatingIntervalSeconds");
					rotationNode.delayStart = getXMLBool(xmlFile, key.."#delayedStart");

					table.insert(rotationNodes, rotationNode);
				end;
				i = i + 1;
			end;
		end;
	end;

	if self:loadRotationNodes(rotationNodes) then
		self:register(true);
		return true;
	end;

	return false;
end;

function GC_RotationNodes:delete()
	if self.isRegistered then
		self:unregister(true);
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

				local operatingInterval = Utils.getNoNil(rotationNode.operatingInterval, 0);
				if operatingInterval > 0 then
					local delayStart = Utils.getNoNil(rotationNode.delayStart, false);
					local operatingTime = 0;
					if delayStart then
						operatingTime = operatingInterval * 1000;
					end;

					node.delayTime = operatingTime;
					node.operatingTime = operatingTime;
					node.operatingInterval = operatingInterval * 1000;
					node.active = false;
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
		for _, node in pairs(self.rotationNodes) do
			if node.operatingInterval ~= nil then
				if self.rotationActive then
					node.operatingTime = node.operatingTime - dt;
					if node.operatingTime <= 0 then
						node.operatingTime = node.operatingTime + node.operatingInterval;
						node.active = not node.active
					end;
					if node.active then
						node.currentRotation = math.min(1, node.currentRotation + dt / node.fadeOnTime);
					else
						node.currentRotation = math.max(0, node.currentRotation - dt / node.fadeOffTime);
					end;
				else
					node.currentRotation = math.max(0, node.currentRotation - dt / node.fadeOffTime);
					if node.active then
						node.active = not node.active;
						node.operatingTime = node.delayTime;
					else
						node.operatingTime = node.delayTime;
					end;
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

		self:raiseActive();
	end;
end;

function GC_RotationNodes:getCanUpdateRotation()
	if self.rotationActive == false and self.rotationsRunning == false then
		return false;
	end;
	return true;
end;

function GC_RotationNodes:setRotationNodesState(forceActive)
	if self.isClient then
		if forceActive ~= nil then
			self.rotationActive = forceActive;
		else
			self.rotationActive = not self.rotationActive;
		end;

		self:raiseActive();
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





