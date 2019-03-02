--
-- GlobalCompany - Objects - GC_Shaders
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
--
-- 	v1.1.0.0 (07.02.2019):
-- 		- convert to fs19
--
-- 	v1.0.0.0 (29.04.2018):
-- 		- initial fs17 (GtX)
--
-- Notes:
--
--		- Client Side Only.
--		- Parent script 'MUST' call delete().
--
-- ToDo:
--
--

GC_Shaders = {};

local GC_Shaders_mt = Class(GC_Shaders);
InitObjectClass(GC_Shaders, "GC_Shaders");

GC_Shaders.debugIndex = g_company.debug:registerScriptName("Shaders");

g_company.shaders = GC_Shaders;

function GC_Shaders:new(isServer, isClient, customMt)
	local self = {};
	setmetatable(self, customMt or GC_Shaders_mt);

	self.isServer = isServer;
	self.isClient = isClient;

	self.shadersActive = false;
	self.disableShaders = false;

	return self;
end;

function GC_Shaders:load(nodeId, target, xmlFile, xmlKey, groupKey)
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' parameter = %s, 'target' parameter = %s 'xmlFile' parameter = %s, 'xmlKey' parameter = %s";
		g_company.debug:logWrite(GC_Shaders.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil);
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_Shaders.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;

	local returnValue = false;
	if self.isClient then
		if groupKey == nil then
			groupKey = "shaders";
		end;

		local i = 0;
		while true do
			local key = string.format("%s.%s.shader(%d)", xmlKey, groupKey, i);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;

			local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings);
			local shaderParameter = getXMLString(xmlFile, key .. "#parameter");
			if node ~= nil and shaderParameter ~= nil then
				if getHasShaderParameter(node, shaderParameter) then
					local shader = {};
					shader.node = node;
					shader.shaderParameter = shaderParameter;

					local values = {getShaderParameter(node, shaderParameter)};
					shader.offValues = Utils.getNoNil(GlobalCompanyUtils.getNumbersFromString(xmlFile, key .. "#offValues", 4, false, self.debugData), values);
					shader.onValues = Utils.getNoNil(GlobalCompanyUtils.getNumbersFromString(xmlFile, key .. "#onValue", 4, false, self.debugData), values);
					shader.shared = Utils.getNoNil(getXMLBool(xmlFile, key .. "#shared"), false);

					local operatingInterval = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#operatingIntervalSeconds"), 0);
					if operatingInterval > 0 then
						local stoppedInterval = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#stoppedIntervalSeconds"), operatingInterval);
						local delayStart = Utils.getNoNil(getXMLBool(xmlFile, key .. "#delayedStart"), false);
						local operatingTime = 0;
						if delayStart then
							operatingTime = stoppedInterval * 1000;
						end;

						shader.active = false;
						shader.delayTime = operatingTime;
						shader.operatingInterval = operatingInterval * 1000;
						shader.stoppedInterval = stoppedInterval * 1000;
						shader.interval = operatingTime;
						shader.operatingTime = operatingTime;

						if self.intervalShaders == nil then
							self.intervalShaders = {};
							returnValue = true;
						end;

						table.insert(self.intervalShaders, shader);
					else
						if self.standardShaders == nil then
							self.standardShaders = {};
							returnValue = true;
						end;

						table.insert(self.standardShaders, shader);
					end;
				else
					g_company.debug:writeModding(self.debugData, "shaderParameter '%s' does not exist on node '%s' at %s", shaderParameter, node, key);
				end;
			end;

			i = i + 1;
		end;

		if self.intervalShaders ~= nil then
			g_company.addRaisedUpdateable(self);
		end;
	else
		g_company.debug:writeDev(self.debugData, "Failed to load 'CLIENT ONLY' script on server!");
		returnValue = true; -- Send true so we can also print 'function' warnings if called by server.
	end;

	return returnValue;
end;

function GC_Shaders:delete()
	if self.isClient then
		if self.intervalShaders ~= nil then
			g_company.removeRaisedUpdateable(self);
		end;
	end;
end;

function GC_Shaders:update(dt)
	if self.isClient then
		if self.intervalShaders ~= nil then
			if self.shadersActive then
				for _, shader in pairs (self.intervalShaders) do
					shader.operatingTime = shader.operatingTime - dt;
					if shader.operatingTime <= 0 then
						if shader.active then
							shader.active = false;
							setShaderParameter(shader.node, shader.shaderParameter, shader.offValues[1], shader.offValues[2], shader.offValues[3], shader.offValues[4], shader.shared);
							shader.interval = shader.stoppedInterval;
						else
							shader.active = true;
							setShaderParameter(shader.node, shader.shaderParameter, shader.onValues[1], shader.onValues[2], shader.onValues[3], shader.onValues[4], shader.shared);
							shader.interval = shader.operatingInterval;
						end;
						shader.operatingTime = shader.operatingTime + shader.interval;
					end;
				end;

				if not self.disableShaders then
					self.disableShaders = true;
				end;

				self:raiseUpdate();
			else
				if self.disableShaders then
					self.disableShaders = false;
					for _, shader in pairs (self.intervalShaders) do
						if shader.active then
							shader.active = false;
							setShaderParameter(shader.node, shader.shaderParameter, shader.offValues[1], shader.offValues[2], shader.offValues[3], shader.offValues[4], shader.shared);
							shader.operatingTime = shader.delayTime;
						end;
					end;
				end;
			end;
		end;
	end;
end;

function GC_Shaders:setShadersState(state, forceState)
	if self.isClient then
		local setState = state or (not self.shadersActive);
		
		if self.shadersActive ~= setState or forceState == true then
			self.shadersActive = setState;
		
			if self.standardShaders ~= nil then
				for _, shader in pairs (self.standardShaders) do
					if self.shadersActive then
						setShaderParameter(shader.node, shader.shaderParameter, shader.onValues[1], shader.onValues[2], shader.onValues[3], shader.onValues[4], shader.shared);
					else
						setShaderParameter(shader.node, shader.shaderParameter, shader.offValues[1], shader.offValues[2], shader.offValues[3], shader.offValues[4], shader.shared);
					end;
				end;
			end;
	
			if self.intervalShaders ~= nil then
				self:raiseUpdate();
			end;
		end;
	else
		g_company.debug:writeDev(self.debugData, "'setShadersState' is a client only function!");
	end;
end;

function GC_Shaders:getShadersState()
	return self.shadersActive;
end;




