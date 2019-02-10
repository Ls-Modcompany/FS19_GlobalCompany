--
-- GlobalCompany - Objects - GC_Lighting
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
-- 	v1.1.0.0 (28.01.2019):
-- 		- convert to fs19
--
-- 	v1.0.0.0 (26.05.2018):
-- 		- initial fs17 (GtX)
--
-- Notes:
--		- Strobe Light sequence and operation code used with permission from 'Sven777b @ http://ls-landtechnik.com'
--		- Part of the original code as found in ‘Beleuchtung v3.1.1’
--
--		- Client Side Only.
--		- Parent script 'MUST' call delete().
--
-- ToDo:
--
--

GC_Lighting = {};

local GC_Lighting_mt = Class(GC_Lighting);
InitObjectClass(GC_Lighting, "GC_Lighting");

GC_Lighting.debugIndex = g_company.debug:registerScriptName("Lighting");

GC_Lighting.BEACON_LIGHT_TYPE = 1;
GC_Lighting.STROBE_LIGHT_TYPE = 2;
GC_Lighting.AREA_LIGHT_TYPE = 3;

g_company.lighting = GC_Lighting;

function GC_Lighting:new(isServer, isClient, customMt)
	local self = {};
	setmetatable(self, customMt or GC_Lighting_mt);

	self.isServer = isServer;
    self.isClient = isClient;

	return self;
end

function GC_Lighting:load(nodeId, target, xmlFile, xmlKey, baseDirectory, allowProfileOverride, noBeacon, noStrobe, noArea)
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' paramater = %s, 'target' paramater = %s 'xmlFile' paramater = %s, 'xmlKey' paramater = %s";
		g_company.debug:logWrite(GC_Lighting.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil);
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_Lighting.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;

	if baseDirectory == nil then
		baseDirectory = self.target.baseDirectory;
		if baseDirectory == nil or baseDirectory == "" then
			baseDirectory = g_currentMission.baseDirectory;
		end;
	end;

	self.baseDirectory = baseDirectory;

	local returnValue = false;
	if self.isClient then
		self.allowProfileOverride = Utils.getNoNil(allowProfileOverride, false);

		self.syncedLightState = false;

		local loadedXmlFiles = {};

		-- Beacon Lights --
		if noBeacon ~= true then
			self.beaconLights = self:loadBeaconLights(xmlFile, xmlKey, loadedXmlFiles);
			self.beaconLightsActive = false;
		end;

		-- Strobe Lights --
		if noStrobe ~= true then
			self.strobeLights = self:loadStrobeLights(xmlFile, xmlKey, loadedXmlFiles);
			self.strobeLightsActive = false;
			self.strobeLightsReset = false;
		end;

		-- Area Lights (Work / Operating Lights) --
		if noArea ~= true then
			self.areaLights = self:loadAreaLights(xmlFile, xmlKey, loadedXmlFiles);
			self.areaLightsActive = false;
		end;

		-- Cleanup Shared XML Files --
		for filename, file in pairs (loadedXmlFiles) do
			delete(file);
		end;

		loadedXmlFiles = nil;

		if self.beaconLights ~= nil or self.strobeLights ~= nil or self.areaLights ~= nil then
			g_company.addRaisedUpdateable(self);
			returnValue = true;
		end;
	else
		g_company.debug:writeDev(self.debugData, "Failed to load 'CLIENT ONLY' script on server!");
		returnValue = true; -- Send true so we can also print 'function' warnings if called.
	end;

	return returnValue;
end;

function GC_Lighting:delete()
	if self.isClient then
		g_company.removeRaisedUpdateable(self);

		if self.beaconLights ~= nil then
			for _, beaconLight in pairs(self.beaconLights) do
				if beaconLight.filename ~= nil then
					g_i3DManager:releaseSharedI3DFile(beaconLight.filename, self.baseDirectory, true);
				end;
			end;
		end;

		if self.strobeLights ~= nil then
			for _, strobeLight in pairs(self.strobeLights) do
				if strobeLight.filename ~= nil then
					g_i3DManager:releaseSharedI3DFile(strobeLight.filename, self.baseDirectory, true);
				end;
			end;
		end;

		if self.areaLights ~= nil then
			for _, areaLight in pairs(self.areaLights) do
				if areaLight.filename ~= nil then
					g_i3DManager:releaseSharedI3DFile(areaLight.filename, self.baseDirectory, true);
				end;
			end;
		end;
	end;
end;

function GC_Lighting:loadAreaLights(xmlFile, xmlKey, loadedXmlFiles)
	local areaLights;

	local i = 0;
	while true do
		local key = string.format("%s.areaLights.areaLight(%d)", xmlKey, i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;

		local light = {};

		if self.allowProfileOverride then
			light.ignoreLightsProfile = Utils.getNoNil(getXMLBool(xmlFile, key .. "#ignoreLightsProfile"), false);
		else
			light.ignoreLightsProfile = false;
		end;

		local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings);
		if node ~= nil then
			local areaLightXmlFilename = getXMLString(xmlFile, key .. "#filename")
			if areaLightXmlFilename ~= nil then
				areaLightXmlFilename = Utils.getFilename(areaLightXmlFilename, self.baseDirectory);

				local areaLightXmlFile, success;
				if loadedXmlFiles[areaLightXmlFilename] ~= nil then
					areaLightXmlFile = loadedXmlFiles[areaLightXmlFilename];
					success = true
				else
					areaLightXmlFile = loadXMLFile("areaLightXML", areaLightXmlFilename);
					if areaLightXmlFile ~= nil and areaLightXmlFile ~= 0 then
						loadedXmlFiles[areaLightXmlFilename] = areaLightXmlFile;
						success = true
					end;
				end;

				if success == true then
					local areaLightKey;
					if hasXMLProperty(areaLightXmlFile, "light") then
						areaLightKey = "light";
					elseif hasXMLProperty(areaLightXmlFile, "areaLight") then
						areaLightKey = "areaLight";
					end;

					if areaLightKey ~= nil then
						local i3dFilename = getXMLString(areaLightXmlFile, areaLightKey .. ".filename");
						if i3dFilename ~= nil then
							local i3dNode = g_i3DManager:loadSharedI3DFile(i3dFilename, self.baseDirectory, false, false, false);
							if i3dNode ~= nil and i3dNode ~= 0 then
								local rootNode = I3DUtil.indexToObject(i3dNode, getXMLString(areaLightXmlFile, areaLightKey .. ".rootNode#node"));

								-- Load 'lightNode' that is part of shared XML (e.g Previous generation coronas.)
								local lightNode = I3DUtil.indexToObject(i3dNode, getXMLString(areaLightXmlFile, areaLightKey .. ".light#node"));

								-- Load 'lightShaderNode' that is part of 'shared XML'
								local shaderNode = getXMLString(areaLightXmlFile, areaLightKey .. ".light#shaderNode");
								if shaderNode == nil then
									shaderNode = getXMLString(areaLightXmlFile, areaLightKey .. ".defaultLight#node");
								end;
								local lightShaderNode = I3DUtil.indexToObject(i3dNode, shaderNode);

								if rootNode ~= nil and (lightNode ~= nil or lightShaderNode ~= nil) then
									light.rootNode = rootNode;
									light.filename = i3dFilename;

									if lightNode ~= nil then
										light.lightNode = lightNode;
										setVisibility(lightNode, false);
									end;

									if lightShaderNode ~= nil then
										-- Allow 'intensity' override in mod XML.
										local intensity = getXMLFloat(xmlFile, key .. "#shaderIntensity");
										if intensity == nil then
											intensity = Utils.getNoNil(getXMLFloat(areaLightXmlFile, areaLightKey .. ".light#intensity"), 100);
										end;

										light.intensity = intensity;
										light.lightShaderNode = lightShaderNode;
										local _, y, z, w = getShaderParameter(lightShaderNode, "lightControl");
										light.shaderParameter = {y, z, w};
										setShaderParameter(lightShaderNode, "lightControl", 0, y, z, w, false);
									end;

									-- Load 'realLights' that are part of the main.i3d
									local realLightNode = I3DUtil.indexToObject(self.components, getXMLString(xmlFile, key .. "#realLightNode"), self.target.i3dMappings);
									if realLightNode ~= nil then
										light.defaultColor = {getLightColor(realLightNode)};
										setVisibility(realLightNode, false);
										light.realLightNode = realLightNode;
									end;

									-- Check and update light rotation nodes (spotlights brackets and mounting part adjustment).
									local j = 0;
									while true do
										local rotateNodesKey = string.format("%s.rotationNode(%d)", key, j);
										if not hasXMLProperty(xmlFile, rotateNodesKey) then
											break;
										end;

										local name = getXMLString(xmlFile, rotateNodesKey .. "#name");
										local rotation = Utils.getNoNil(GlobalCompanyUtils.getNumbersFromString(xmlFile, rotateNodesKey .. "#rotation", 3, true, self.debugData), {0, 0, 0});
										if name ~= nil then
											local keyToFind = areaLightKey .. "." .. name;
											if hasXMLProperty(areaLightXmlFile, keyToFind) then
												local rotationNode = I3DUtil.indexToObject(i3dNode, getXMLString(areaLightXmlFile, keyToFind .. "#node"));
												if rotationNode ~= nil then
													setRotation(rotationNode, unpack(rotation));
												end;
											else
												local text = "XML Property ( <%s /> ) does not exist in %s, rotationNode(%d) will be ignored!";
												g_company.debug:writeModding(self.debugData, text, name, areaLightXmlFilename, j);
											end;
										else
											local text = "'name' attribute is 'nil', %s will be ignored!";
											g_company.debug:writeModding(self.debugData, text, rotateNodesKey);
										end;

										j = j + 1;
									end;

									-- Adjust shader dirt
									local dirtLevel = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#shaderDirtLevel"), 0);
									self:setDirtLevel(light.rootNode, dirtLevel);

									link(node, rootNode);
									setTranslation(rootNode, 0, 0, 0);

									if areaLights == nil then
										areaLights = {};
									end;

									table.insert(areaLights, light);
								end;

								delete(i3dNode)
							end;
						end;
					end;
				end;
			end;
		else
			-- Load from mod.
			local lightNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#lightNode"), self.target.i3dMappings);
			local lightShaderNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#lightShaderNode"), self.target.i3dMappings);
			if lightNode ~= nil or lightShaderNode ~= nil then
				if lightNode ~= nil then
					light.lightNode = lightNode;
					setVisibility(lightNode, false);
				end;

				if lightShaderNode ~= nil then
					light.intensity = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#shaderIntensity"), 100);
					light.lightShaderNode = lightShaderNode;
					local _, y, z, w = getShaderParameter(lightShaderNode, "lightControl");
					light.shaderParameter = {y, z, w};
					setShaderParameter(lightShaderNode, "lightControl", 0, y, z, w, false);
				end;

				local realLightNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#realLightNode"), self.target.i3dMappings);
				if realLightNode ~= nil then
					light.defaultColor = {getLightColor(realLightNode)};
					setVisibility(realLightNode, false);
					light.realLightNode = realLightNode;
				end;

				if areaLights == nil then
					areaLights = {};
				end;

				table.insert(areaLights, light);
			end;
		end;
		i = i + 1;
	end;

	return areaLights;
end;

function GC_Lighting:loadStrobeLights(xmlFile, xmlKey, loadedXmlFiles)
	local strobeLights;

	local i = 0;
	while true do
		local key = string.format("%s.strobeLights.strobeLight(%d)", xmlKey, i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;

		local light = {};
		light.ns = 0;
		light.t = 1;
		light.a = false;

		local sequence = getXMLString(xmlFile, key .. "#sequence");
		if sequence ~= nil then
			light.rnd = false;
			light.sq = {StringUtil.getVectorFromString(sequence)};
			light.inv = Utils.getNoNil(getXMLBool(xmlFile, key .. "#invert"), false);
			light.ls = light.inv;
			light.ss = 1;
		else
			light.rnd = true;
			light.ls = false;
			light.rndnn = Utils.getNoNil(getXMLInt(xmlFile, key .. "#minOn"), 100);
			light.rndxn = Utils.getNoNil(getXMLInt(xmlFile, key .. "#maxOn"), 100);
			light.rndnf = Utils.getNoNil(getXMLInt(xmlFile, key .. "#minOff"), 100);
			light.rndxf = Utils.getNoNil(getXMLInt(xmlFile, key .. "#maxOff"), 400);
			math.randomseed(getTime());
			math.random();
		end;

		if self.allowProfileOverride then
			light.ignoreLightsProfile = Utils.getNoNil(getXMLBool(xmlFile, key .. "#ignoreLightsProfile"), false);
		else
			light.ignoreLightsProfile = false;
		end;

		local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings);
		if node ~= nil then
			local strobeXmlFilename = getXMLString(xmlFile, key .. "#filename")
			if strobeXmlFilename ~= nil then
				strobeXmlFilename = Utils.getFilename(strobeXmlFilename, self.baseDirectory);

				local strobeXmlFile, success;
				if loadedXmlFiles[strobeXmlFilename] ~= nil then
					strobeXmlFile = loadedXmlFiles[strobeXmlFilename];
					success = true
				else
					strobeXmlFile = loadXMLFile("strobeLightXML", strobeXmlFilename);
					if strobeXmlFile ~= nil and strobeXmlFile ~= 0 then
						loadedXmlFiles[strobeXmlFilename] = strobeXmlFile;
						success = true
					end;
				end;

				if success == true then
					local strobeKey;
					if hasXMLProperty(strobeXmlFile, "light") then
						strobeKey = "light";
					elseif hasXMLProperty(strobeXmlFile, "strobeLight") then
						strobeKey = "strobeLight";
					end;

					if strobeKey ~= nil then
						local i3dFilename = getXMLString(strobeXmlFile, strobeKey .. ".filename");
						if i3dFilename ~= nil then
							local i3dNode = g_i3DManager:loadSharedI3DFile(i3dFilename, self.baseDirectory, false, false, false);
							if i3dNode ~= nil and i3dNode ~= 0 then
								local rootNode = I3DUtil.indexToObject(i3dNode, getXMLString(strobeXmlFile, strobeKey .. ".rootNode#node"));

								-- Load 'lightNode' that is part of shared XML (e.g Previous generation coronas.)
								local lightNode = I3DUtil.indexToObject(i3dNode, getXMLString(strobeXmlFile, strobeKey .. ".light#node"));

								-- Load 'lightShaderNode' that is part of 'shared XML'
								local shaderNode = getXMLString(strobeXmlFile, strobeKey .. ".light#shaderNode");
								if shaderNode == nil then
									shaderNode = getXMLString(strobeXmlFile, strobeKey .. ".defaultLight#node");
								end;
								local lightShaderNode = I3DUtil.indexToObject(i3dNode, shaderNode);


								if rootNode ~= nil and (lightNode ~= nil or lightShaderNode ~= nil) then
									light.rootNode = rootNode;
									light.filename = i3dFilename;

									if lightNode ~= nil then
										light.lightNode = lightNode;
										setVisibility(lightNode, false);
									end;

									if lightShaderNode ~= nil then
										-- Allow 'intensity' override in mod XML.
										local intensity = getXMLFloat(xmlFile, key .. "#shaderIntensity");
										if intensity == nil or intensity < 0 then
											intensity = Utils.getNoNil(getXMLFloat(strobeXmlFile, strobeKey .. ".light#intensity"), 100);
										end;

										light.intensity = intensity;
										light.lightShaderNode = lightShaderNode;
										local _, y, z, w = getShaderParameter(lightShaderNode, "lightControl");
										light.shaderParameter = {y, z, w};
										setShaderParameter(lightShaderNode, "lightControl", 0, y, z, w, false);
									end;

									-- Load 'realLights' that are part of the main.i3d
									local realLightNode = I3DUtil.indexToObject(self.components, getXMLString(xmlFile, key .. "#realLightNode"), self.target.i3dMappings);
									if realLightNode ~= nil then
										light.defaultColor = {getLightColor(realLightNode)};
										setVisibility(realLightNode, false);
										light.realLightNode = realLightNode;
									end;

									-- Adjust shader dirt
									local dirtLevel = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#shaderDirtLevel"), 0);
									self:setDirtLevel(rootNode, dirtLevel);

									link(node, rootNode);
									setTranslation(rootNode, 0, 0, 0);

									if strobeLights == nil then
										strobeLights = {};
									end;

									table.insert(strobeLights, light);
								end;

								delete(i3dNode)
							end;
						end;
					end;
				end;
			end;
		else
			-- Load from mod.
			local lightNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#lightNode"), self.target.i3dMappings);
			local lightShaderNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#lightShaderNode"), self.target.i3dMappings);
			if lightNode ~= nil or lightShaderNode ~= nil then
				if lightNode ~= nil then
					light.lightNode = lightNode;
					setVisibility(lightNode, false);
				end;

				if lightShaderNode ~= nil then
					light.intensity = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#shaderIntensity"), 100);
					light.lightShaderNode = lightShaderNode;
					local _, y, z, w = getShaderParameter(lightShaderNode, "lightControl");
					light.shaderParameter = {y, z, w};
					setShaderParameter(lightShaderNode, "lightControl", 0, y, z, w, false);
				end;

				local realLightNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#realLightNode"), self.target.i3dMappings);
				if realLightNode ~= nil then
					light.defaultColor = {getLightColor(realLightNode)};
					setVisibility(realLightNode, false);
					light.realLightNode = realLightNode;
				end;

				if strobeLights == nil then
					strobeLights = {};
				end;

				table.insert(strobeLights, light);
			end;
		end;
		i = i + 1;
	end;

	return strobeLights;
end;

function GC_Lighting:loadBeaconLights(xmlFile, xmlKey, loadedXmlFiles)
	local beaconLights;

	local i = 0;
	while true do
		local key = string.format("%s.beaconLights.beaconLight(%d)", xmlKey, i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;

		local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings);
		if node ~= nil then
			-- Load from shared XML
			local lightXmlFilename = getXMLString(xmlFile, key .. "#filename");
			if lightXmlFilename ~= nil then
				lightXmlFilename = Utils.getFilename(lightXmlFilename, self.baseDirectory);

				local lightXmlFile, success;
				if loadedXmlFiles[lightXmlFilename] ~= nil then
					lightXmlFile = loadedXmlFiles[lightXmlFilename];
					success = true
				else
					lightXmlFile = loadXMLFile("beaconLightXML", lightXmlFilename);
					if lightXmlFile ~= nil and lightXmlFile ~= 0 then
						loadedXmlFiles[lightXmlFilename] = lightXmlFile;
						success = true
					end;
				end;

				if success then
					local i3dFilename = getXMLString(lightXmlFile, "beaconLight.filename");
					if i3dFilename ~= nil then
						local i3dNode = g_i3DManager:loadSharedI3DFile(i3dFilename, self.baseDirectory, false, false, false);
						if i3dNode ~= nil and i3dNode ~= 0 then
							local rootNode = I3DUtil.indexToObject(i3dNode, getXMLString(lightXmlFile, "beaconLight.rootNode#node"));
							local lightNode = I3DUtil.indexToObject(i3dNode, getXMLString(lightXmlFile, "beaconLight.light#node"));
							local lightShaderNode = I3DUtil.indexToObject(i3dNode, getXMLString(lightXmlFile, "beaconLight.light#shaderNode"));
							if rootNode ~= nil and (lightNode ~= nil or lightShaderNode ~= nil) then
								local light = {};
								light.rootNode = rootNode;
								light.lightNode = lightNode;
								light.filename = i3dFilename;
								light.lightShaderNode = lightShaderNode;
								local speed = getXMLFloat(xmlFile, key .. "#speed");
								if speed == nil then
									speed = Utils.getNoNil(getXMLFloat(lightXmlFile, "beaconLight.rotator#speed"), 0.015);
								end;
								light.speed = speed;
								if self.allowProfileOverride then
									light.ignoreLightsProfile = Utils.getNoNil(getXMLBool(xmlFile, key .. "#ignoreLightsProfile"), false);
								else
									light.ignoreLightsProfile = false;
								end;
								light.rotatorNode = I3DUtil.indexToObject(i3dNode, getXMLString(lightXmlFile, "beaconLight.rotator#node"));
								light.realLightNode = I3DUtil.indexToObject(i3dNode, getXMLString(lightXmlFile, "beaconLight.realLight#node"));

								if light.realLightNode ~= nil then
									light.defaultColor = {getLightColor(light.realLightNode)};
									setVisibility(light.realLightNode, false);
								end

								if light.lightNode ~= nil then
									setVisibility(light.lightNode, false);
								end;

								if light.lightShaderNode ~= nil then
									-- Allow 'intensity' override in mod XML.
									local intensity = getXMLFloat(xmlFile, key .. "#shaderIntensity");
									if intensity == nil or intensity < 0 then
										intensity = Utils.getNoNil(getXMLFloat(lightXmlFile, "beaconLight.light#intensity"), 1000);
									end;

									light.intensity = intensity;
									local _, y, z, w = getShaderParameter(light.lightShaderNode, "lightControl");
									setShaderParameter(light.lightShaderNode, "lightControl", 0, y, z, w, false);
								end;

								if light.speed > 0 then
									local rot = math.random(0, math.pi * 2);
									if light.rotatorNode ~= nil then
										setRotation(light.rotatorNode, 0, rot, 0);
									end;
								end;

								-- Adjust shader dirt
								local dirtLevel = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#shaderDirtLevel"), 0);
								self:setDirtLevel(rootNode, dirtLevel);

								link(node, rootNode);
								setTranslation(rootNode, 0, 0, 0);

								if beaconLights == nil then
									beaconLights = {};
								end;

								table.insert(beaconLights, light);
							end;
							delete(i3dNode);
						end;
					end;
				end;
			end;
		else
			-- Load from mod.
			local lightNode = I3DUtil.indexToObject(i3dNode, getXMLString(xmlFile, key .. "#lightNode"), self.target.i3dMappings);
			local lightShaderNode = I3DUtil.indexToObject(i3dNode, getXMLString(xmlFile, key .. "#lightShaderNode"), self.target.i3dMappings);
			if rootNode ~= nil and (lightNode ~= nil or lightShaderNode ~= nil) then
				local light = {};
				light.lightNode = lightNode;
				light.lightShaderNode = lightShaderNode;
				light.filename = i3dFilename;
				light.speed = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#speed"), 0.015);
				light.rotatorNode = I3DUtil.indexToObject(i3dNode, getXMLString(xmlFile, key .. "#rotatorNode"), self.target.i3dMappings)
				light.ignoreLightsProfile = Utils.getNoNil(getXMLBool(xmlFile, key .. "#ignoreLightsProfile"), false);
				light.realLightNode = I3DUtil.indexToObject(i3dNode, getXMLString(xmlFile, key .. "#realLightNode"), self.target.i3dMappings);

				if light.realLightNode ~= nil then
					light.defaultColor = {getLightColor(light.realLightNode)};
					setVisibility(light.realLightNode, false);
				end

				if light.lightNode ~= nil then
					setVisibility(light.lightNode, false);
				end;

				if light.lightShaderNode ~= nil then
					light.intensity = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#shaderIntensity"), 1000);
					local _, y, z, w = getShaderParameter(light.lightShaderNode, "lightControl");
					setShaderParameter(light.lightShaderNode, "lightControl", 0, y, z, w, false);
				end;

				if light.speed > 0 then
					local rot = math.random(0, math.pi * 2);
					if light.rotatorNode ~= nil then
						setRotation(light.rotatorNode, 0, rot, 0);
					end;
				end;

				if beaconLights == nil then
					beaconLights = {};
				end;

				table.insert(beaconLights, light);
			end;
		end;
		i = i + 1;
	end;

	return beaconLights;
end;

function GC_Lighting:update(dt)
	if self.beaconLights ~= nil and self.beaconLightsActive then
		for _, beaconLight in pairs(self.beaconLights) do
			if beaconLight.rotatorNode ~= nil then
				rotate(beaconLight.rotatorNode, 0, beaconLight.speed * dt, 0);
			end;
		end;

		self:raiseUpdate();
	end;

	if self.strobeLights ~= nil then
		if self.strobeLightsActive then
			self.strobeLightsReset = true;
			for _, st in ipairs(self.strobeLights) do
				if st.t > st.ns then
					st.ls = not st.ls;

					if st.realBeaconLights and st.realLightNode ~= nil then
						setVisibility(st.realLightNode, st.ls);
					end;

					if st.lightNode ~= nil then
						setVisibility(st.lightNode, st.ls);
					end;

					if st.lightShaderNode ~= nil then
						local value = 1 * st.intensity;
						if not st.ls then
							value = 0;
						end;
						setShaderParameter(st.lightShaderNode, "lightControl", value, st.shaderParameter[1], st.shaderParameter[2], st.shaderParameter[3], false);
					end;

					st.t = 0;
					if st.rnd then
						if st.ls then
							st.ns = math.random(st.rndnn,st.rndxn);
						else
							st.ns = math.random(st.rndnf,st.rndxf);
						end;
					else
						st.ss = st.ss + 1;
						if st.ss > table.getn(st.sq) then
							st.ss = 1;
						end;
						st.ns = st.sq[st.ss];
					end;
				else
					st.t = st.t + dt;
				end;
			end;

			self:raiseUpdate();
		else
			if self.strobeLightsReset then
				for _, st in ipairs(self.strobeLights) do
					if st.realBeaconLights and st.realLightNode ~= nil then
						setVisibility(st.realLightNode, false);
					end;

					if st.lightNode ~= nil then
						setVisibility(st.lightNode, false);
					end;

					if st.lightShaderNode ~= nil then
						setShaderParameter(st.lightShaderNode, "lightControl", 0, st.shaderParameter[1], st.shaderParameter[2], st.shaderParameter[3], false);
					end;
				end;
				self.strobeLightsReset = false;
			end;
		end;
	end;
end;

function GC_Lighting:setAllLightsState(state)
	if state ~= nil then
		self.syncedLightState = state;

		if self.beaconLights ~= nil then
			self:setBeaconLightsState(self.syncedLightState)
		end;

		if self.strobeLights ~= nil then
			self:setStrobeLightsState(self.syncedLightState)
		end;

		if self.areaLights ~= nil then
			self:setAreaLightsState(self.syncedLightState);
		end;
	end;
end;

function GC_Lighting:setLightsState(lightType, forceState)
	if lightType == GC_Lighting.BEACON_LIGHT_TYPE and self.beaconLights ~= nil then
		if forceState == nil then
			forceState = not self.beaconLightsActive;
		end;

		self:setBeaconLightsState(forceState);
	elseif lightType == GC_Lighting.STROBE_LIGHT_TYPE and self.strobeLights ~= nil then
		if forceState == nil then
			forceState = not self.beaconLightsActive;
		end;

		self:setStrobeLightsState(forceState);
	elseif lightType == GC_Lighting.AREA_LIGHT_TYPE and self.areaLights ~= nil then
		if forceState == nil then
			forceState = not self.areaLightsActive;
		end;

		self:setAreaLightsState(forceState);
	end;
end;

function GC_Lighting:setAreaLightsState(state)
	if self.areaLights == nil then
		return false;
	end;

	if self.isClient then
		if state == nil then
			state = not self.areaLightsActive;
		end;

		if state ~= self.areaLightsActive then
			self.areaLightsActive = state;

			for _, areaLight in pairs(self.areaLights) do
				local useRealLights = self:getUseRealLights(GC_Lighting.AREA_LIGHT_TYPE, areaLight);

				if useRealLights and areaLight.realLightNode ~= nil then
					setVisibility(areaLight.realLightNode, state);
				end;

				if areaLight.lightNode ~= nil then
					setVisibility(areaLight.lightNode, state);
				end;

				if areaLight.lightShaderNode ~= nil then
					local value = 1 * areaLight.intensity;

					if not state then
						value = 0;
					end;

					local _,y,z,w = getShaderParameter(areaLight.lightShaderNode, "lightControl");
					setShaderParameter(areaLight.lightShaderNode, "lightControl", value, y, z, w, false);
				end;
			end;

			return state;
		end;
	else
		g_company.debug:writeDev(self.debugData, "'setAreaLightsState' is a client only function!");
	end;
end;

function GC_Lighting:setStrobeLightsState(state)
	if self.strobeLights == nil then
		return false;
	end;

	if self.isClient then
		if state == nil then
			state = not self.strobeLightsActive;
		end;

		if state ~= self.strobeLightsActive then
			for _, strobeLight in pairs(self.strobeLights) do
				strobeLight.realBeaconLights = self:getUseRealLights(GC_Lighting.STROBE_LIGHT_TYPE, strobeLight);
			end;

			self.strobeLightsActive = state;

			self:raiseUpdate();

			return state;
		end
	else
		g_company.debug:writeDev(self.debugData, "'setStrobeLightsState' is a client only function!");
	end;
end;

function GC_Lighting:setBeaconLightsState(state)
	if self.beaconLights == nil then
		return false;
	end;

	if self.isClient then
		if state == nil then
			state = not self.beaconLightsActive;
		end;

		if state ~= self.beaconLightsActive then
			self.beaconLightsActive = state;

			for _, beaconLight in pairs(self.beaconLights) do
				local useRealLights = self:getUseRealLights(GC_Lighting.BEACON_LIGHT_TYPE, beaconLight);

				if useRealLights and beaconLight.realLightNode ~= nil then
					setVisibility(beaconLight.realLightNode, state);
				end;

				if beaconLight.lightNode ~= nil then
					setVisibility(beaconLight.lightNode, state);
				end;

				if beaconLight.lightShaderNode ~= nil then
					local value = 1 * beaconLight.intensity;

					if not state then
						value = 0;
					end;

					local _,y,z,w = getShaderParameter(beaconLight.lightShaderNode, "lightControl");
					setShaderParameter(beaconLight.lightShaderNode, "lightControl", value, y, z, w, false);
				end;
			end;

			self:raiseUpdate();

			return state;
		end
	else
		g_company.debug:writeDev(self.debugData, "'setBeaconLightsState' is a client only function!");
	end;
end;

function GC_Lighting:getAreaLightsActive()
	return self.areaLightsActive;
end;

function GC_Lighting:getStrobeLightsActive()
	return self.strobeLightsActive;
end;

function GC_Lighting:getBeaconLightsActive()
	return self.beaconLightsActive;
end;

function GC_Lighting:getSyncedLightState()
	return self.syncedLightState;
end;

function GC_Lighting:getUseRealLights(lightType, light)
	if light ~= nil then
		if light.ignoreGameLightSettings == true then
			return true;
		end;
	end;

	if lightType == GC_Lighting.BEACON_LIGHT_TYPE or GC_Lighting.STROBE_LIGHT_TYPE then
		return g_gameSettings:getValue("realBeaconLights");
	end;

	if lightType == GC_Lighting.AREA_LIGHT_TYPE then
		local lightsProfile = g_gameSettings:getValue("lightsProfile");
		return lightsProfile == GS_PROFILE_HIGH or lightsProfile == GS_PROFILE_VERY_HIGH;
	end;

	return false;
end;

function GC_Lighting:setDirtLevel(rootNode, level)
	if level == nil then
		level = 0;
	end;

	local dirtNodes = {};
	local dirtLevel = math.min(math.max(level, 0), 1);
	I3DUtil.getNodesByShaderParam(rootNode, "RDT", dirtNodes);

	for _, dirtNode in pairs(dirtNodes) do
		local x, _, z, w = getShaderParameter(dirtNode, "RDT");
        setShaderParameter(dirtNode, "RDT", x, dirtLevel, z, w, false);
    end;
end;




