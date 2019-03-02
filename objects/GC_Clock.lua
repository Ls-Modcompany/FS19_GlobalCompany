--
-- GlobalCompany - Objects - GC_Clock
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 20.01.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (20.01.2019):
-- 		- initial fs19 (GtX)
--
-- Notes:
--		- Analogue Clock inspired by 'ChurchClock.lua' by GIANTS Software GmbH.
--
--		- Client Side Only.
--		- Parent script 'MUST' call delete().
--
-- ToDo:
--
--

GC_Clock = {};

local GC_Clock_mt = Class(GC_Clock);
InitObjectClass(GC_Clock, "GC_Clock");

GC_Clock.AXIS = {["X"] = {1, 0, 0},
				 ["Y"] = {1, 0, 0},
				 ["Z"] = {1, 0, 0}};

GC_Clock.debugIndex = g_company.debug:registerScriptName("Clock");

g_company.clock = GC_Clock;

function GC_Clock:new(isServer, isClient, customMt)
	local self = {};
	setmetatable(self, customMt or GC_Clock_mt);

	self.isServer = isServer;
	self.isClient = isClient;

	self.analogueClocks = nil;
	self.digitalClocks = nil;

	self.convertTwelveHour = false;

	return self;
end;

function GC_Clock:load(nodeId, target, xmlFile, xmlKey)
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' parameter = %s, 'target' parameter = %s 'xmlFile' parameter = %s, 'xmlKey' parameter = %s";
		g_company.debug:logWrite(GC_Clock.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil);
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_Clock.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;

	local returnValue = false;
	if self.isClient then
		local i = 0;
		while true do
			local key = string.format("%s.clocks.clock(%d)", xmlKey, i);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;

			-- If we have numbers then it is a Digital Clock.
			local numbers = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#numbers"), self.target.i3dMappings);
			if numbers ~= nil then
				local display = {};
				display.numbers = numbers;

				local numMeshes = getNumOfChildren(display.numbers);
				if numMeshes >= 4 then
					if self.digitalClocks == nil then
						self.digitalClocks = {};
					end;

					local useTwelveHour = Utils.getNoNil(getXMLBool(xmlFile, key .. "#useTwelveHour"), false);
					if useTwelveHour then
						display.useTwelveHour = useTwelveHour;
						display.amIconIndex = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#amIconIndex"), self.target.i3dMappings);
						display.pmIconIndex = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#pmIconIndex"), self.target.i3dMappings);
						self.convertTwelveHour = true;
					end;

					local numberColour = GlobalCompanyUtils.getNumbersFromString(xmlFile, key .. "#numberColor", 4, false, self.debugData);
					self:setNumberColour(display, numberColour);

					table.insert(self.digitalClocks, display);

					returnValue = true;
				else
					g_company.debug:writeModding(self.debugData, "Only '%d' number meshes found at '%s', minimum number meshes required '4'!", numMeshes, key);
				end

			else
				local hourHand = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#hourHand"), self.target.i3dMappings);
				local minuteHand = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#minuteHand"), self.target.i3dMappings);
				if hourHand ~= nil and minuteHand ~= nil then
					if self.analogueClocks == nil then
						self.analogueClocks = {};
					end;

					local rotationAxis = Utils.getNoNil(getXMLString(xmlFile, key .. "#rotationAxis"), "Z");
					if rotationAxis ~= nil then
						rotationAxis = rotationAxis:upper();
						if GC_Clock.AXIS[rotationAxis] == nil then
							rotationAxis = "Z";
							g_company.debug:writeModding(self.debugData, "rotationAxis '%s' is not valid! Use 'X' or 'Y' or 'Z'. Setting 'Z' axis by default at %s.", axis, key);
						end;
					else
						rotationAxis = "Z";
						g_company.debug:writeModding(self.debugData, "rotationAxis is missing! Setting 'Z' axis by default at %s.", axis, key);
					end;

					local reverseRotation = Utils.getNoNil(getXMLBool(xmlFile, key .. "#reverseRotation"), false);

					table.insert(self.analogueClocks, {minuteHand = minuteHand, hourHand = hourHand, rotationAxis = rotationAxis, reverseRotation = reverseRotation});

					returnValue = true;
				end;
			end;

			i = i + 1;
		end;

		if returnValue then
			g_currentMission.environment:addMinuteChangeListener(self);
			self:minuteChanged(); -- Push update so the displays and faces have correct time.
		end;
	end;

	return returnValue;
end;

function GC_Clock:delete()
	if self.isClient then
		if g_currentMission ~= nil and g_currentMission.environment ~= nil then
			g_currentMission.environment:removeMinuteChangeListener(self);
		end;
	end;
end;

function GC_Clock:minuteChanged()
	if self.digitalClocks ~= nil then
		local currentMinute = g_currentMission.environment.currentMinute;
		local currentHour = g_currentMission.environment.currentHour;
		local timeStringTwentyFour = string.format("%02d%02d", currentHour, currentMinute);
		local covertedHour = currentHour;

		local timeStringTwelveHour = "0000";
		if self.convertTwelveHour then
			if currentHour == 0 then
				covertedHour = 12;
			elseif currentHour > 12 then
				covertedHour = currentHour - 12;
			end;
			timeStringTwelveHour = string.format("%02d%02d", covertedHour, currentMinute);
		end;

		for i = 1, #self.digitalClocks do
			local digitalClock = self.digitalClocks[i];

			if digitalClock.numbers ~= nil then
				if digitalClock.useTwelveHour then
					if currentHour >= 0 and currentHour < 12 then
						if digitalClock.amActive ~= true then
							if digitalClock.amIconIndex ~= nil then
								setVisibility(digitalClock.amIconIndex, true);
							end;
							if digitalClock.pmIconIndex ~= nil then
								setVisibility(digitalClock.pmIconIndex, false);
							end;
							digitalClock.amActive = true;
						end;
					else
						if digitalClock.amActive ~= false then
							if digitalClock.amIconIndex ~= nil then
								setVisibility(digitalClock.amIconIndex, false);
							end;
							if digitalClock.pmIconIndex ~= nil then
								setVisibility(digitalClock.pmIconIndex, true);
							end;
							digitalClock.amActive = false;
						end;
					end;

					for j = 0, 3 do
						local mesh = getChildAt(digitalClock.numbers, j);
						if j == 3 and covertedHour < 10 then
							setShaderParameter(mesh, "number", -1, 0, 0, 0, false);
						else
							local subId = 4 - j;
							local numberString = string.sub(timeStringTwelveHour, subId, subId);
							setShaderParameter(mesh, "number", tonumber(numberString), 0, 0, 0, false);
						end;
					end;
				else
					for j = 0, 3 do
						local mesh = getChildAt(digitalClock.numbers, j);
						local subId = 4 - j;
						local numberString = string.sub(timeStringTwentyFour, subId, subId);
						setShaderParameter(mesh, "number", tonumber(numberString), 0, 0, 0, false);
					end;
				end;
			end;
		end;
	end;

	if self.analogueClocks ~= nil then
		for i = 1, #self.analogueClocks do
			local analogueClock = self.analogueClocks[i];
			local axis = GC_Clock.AXIS[analogueClock.rotationAxis];
			local minuteHandRot = (2 * math.pi) * (g_currentMission.environment.dayTime / (1000 * 60 * 60));
			local hourHandRot = (2 * math.pi) * (g_currentMission.environment.dayTime / (1000 * 60 * 60 * 12));

			if analogueClock.reverseRotation then
				setRotation(analogueClock.minuteHand, -axis[1] * minuteHandRot, -axis[2] * minuteHandRot, -axis[3] * minuteHandRot);
				setRotation(analogueClock.hourHand, -axis[1] * hourHandRot, -axis[2] * hourHandRot, -axis[3] * hourHandRot);
			else
				setRotation(analogueClock.minuteHand, axis[1] * minuteHandRot, axis[2] * minuteHandRot, axis[3] * minuteHandRot);
				setRotation(analogueClock.hourHand, axis[1] * hourHandRot, axis[2] * hourHandRot, axis[3] * hourHandRot);
			end;
		end;
	end;
end;

function GC_Clock:setNumberColour(display, colourToSet)
	if display ~= nil and display.numbers ~= nil and colourToSet ~= nil then
		for node, _ in pairs(I3DUtil.getNodesByShaderParam(display.numbers, "numberColor")) do
			setShaderParameter(node, "numberColor", colourToSet[1], colourToSet[2], colourToSet[3], colourToSet[4], false);
		end;
	end;
end;





