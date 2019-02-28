--
-- GlobalCompany - Objects - GC_DigitalDisplays
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 25.02.2019
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.0.0 (25.02.2019):
-- 		- convert to fs19
--
-- 	v1.0.0.0 (09.06.2018):
-- 		- initial fs17 (GtX)
--
-- Notes:
--
--		- Client Side Only.
--
--
-- ToDo:
--		- Add text shader support.
--
--

GC_DigitalDisplays = {};

local GC_DigitalDisplays_mt = Class(GC_DigitalDisplays);
InitObjectClass(GC_DigitalDisplays, "GC_DigitalDisplays");

GC_DigitalDisplays.TYPES = {};
GC_DigitalDisplays.TYPES["LEVEL"] = 1;				-- FillLevel in litres
GC_DigitalDisplays.TYPES["PERCENT"] = 2;			-- FillLevel in percent
GC_DigitalDisplays.TYPES["SPACE"] = 3;				-- Available storage space
GC_DigitalDisplays.TYPES["SPACEPERCENT"]= 4;		-- Available storage space in percent
GC_DigitalDisplays.TYPES["CAPACITY"] = 5;			-- Max storage capacity
GC_DigitalDisplays.TYPES["TEXT"] = 6; 				-- Coming soon.

GC_DigitalDisplays.debugIndex = g_company.debug:registerScriptName("DigitalDisplays");

g_company.digitalDisplays = GC_DigitalDisplays;

function GC_DigitalDisplays:new(isServer, isClient, customMt)
	local self = {};
	setmetatable(self, customMt or GC_DigitalDisplays_mt);

	self.isServer = isServer;
	self.isClient = isClient;

	self.levelDisplays = nil;
	self.textDisplays = nil;

	return self;
end;

function GC_DigitalDisplays:load(nodeId, target, xmlFile, xmlKey, groupKey, disableFillType)
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' paramater = %s, 'target' paramater = %s 'xmlFile' paramater = %s, 'xmlKey' paramater = %s";
		g_company.debug:logWrite(GC_DigitalDisplays.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil);
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_DigitalDisplays.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;

	local returnValue = false;
	if self.isClient then
		self.disableFillType = Utils.getNoNil(disableFillType, false);

		if groupKey == nil then
			groupKey = "digitalDisplays";
		end;

		local i = 0;
		while true do
			local key = string.format(xmlKey .. "%s.%s.display(%d)", xmlKey, groupKey, i);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;

			local displayType = getXMLString(xmlFile, key .. "#displayType");
			if displayType ~= nil then
				local typeIndex = GC_DigitalDisplays.TYPES[displayType:upper()];
				if typeIndex ~= nil then
					local colourToSet;

					local display = {};
					display.typeIndex = typeIndex;

					if typeIndex == GC_DigitalDisplays.TYPES.TEXT then
						display = nil;
					else
						local numbers = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#numbers"), self.target.i3dMappings)
						if numbers ~= nil then
							display.numbers = numbers;
							display.lastvalue = 0;
							display.numberColour = GlobalCompanyUtils.getNumbersFromString(xmlFile, key .. "#numberColor", 4, false, self.debugData);
							display.currentColourIndex = 1;
							colourToSet = display.numberColour;

							display.precision = 0;
							display.showOnEmpty = Utils.getNoNil(getXMLBool(xmlFile, key .. "#showOnEmpty"), true);

							if display.numberColour ~= nil and display.typeIndex ~= GC_DigitalDisplays.TYPES.CAPACITY then
								display.emptyNumberColour = GlobalCompanyUtils.getNumbersFromString(xmlFile, key .. "#emptyNumberColor", 4, false, self.debugData);
								display.fullNumberColour = GlobalCompanyUtils.getNumbersFromString(xmlFile, key .. "#fullNumberColor", 4, false, self.debugData);

								if display.emptyNumberColour ~= nil then
									colourToSet = display.emptyNumberColour;
									display.currentColourIndex = 2;
								end;
							end;

							display.setColour = display.emptyNumberColour ~= nil or display.fullNumberColour ~= nil;

							-- REFERANCE: VehicleHudUtils.lua @ https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=69&class=8923#setHudValue142801
							display.numChildren = getNumOfChildren(display.numbers);
							display.numChildren = display.numChildren - display.precision;
							display.maxValue = (10 ^ (display.numChildren)) - 1 / (10^display.precision); -- e.g. max with 2 childs and 1 float -> 10^2 - 1/10 -> 99.9 -> makes sure that display doesn't show 00.0 if value is 100
						else
							g_company.debug:writeWarning(self.debugData, "Missing numbers node for display '%s'", key);
							display = nil;
						end;
					end;

					if display ~= nil then
						self:setNumberColour(display, colourToSet);

						if self.levelDisplays == nil then
							self.levelDisplays = {};
						end;

						if self.disableFillType == true then
							table.insert(self.levelDisplays, display);
							returnValue = true;
						else
							local fillTypeName = getXMLString(xmlFile, key .. "#fillType");
							if fillTypeName ~= nil then
								local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
								if fillTypeIndex ~= nil then
									if self.levelDisplays[fillTypeIndex] == nil then
										self.levelDisplays[fillTypeIndex] = {};
									end;

									table.insert(self.levelDisplays[fillTypeIndex], display);
									returnValue = true;
								else
									g_company.debug:writeWarning(self.debugData, "fillType '%s' is not valid at %s", fillTypeName, key);
								end;
							else
								g_company.debug:writeWarning(self.debugData, "No 'fillType' given at %s", key);
							end;
						end;
					end;
				else

				end;
			else
				g_company.debug:writeWarning(self.debugData, "Unknown displayType '%s' given at '%s'", displayType, key);
			end;

			i = i + 1;
		end;
	else
		g_company.debug:writeDev(self.debugData, "Failed to load 'CLIENT ONLY' script on server!");
		returnValue = true; -- Send true so we can also print 'function' warnings if called by server.
	end;

	return returnValue;
end;

function GC_DigitalDisplays:updateLevelDisplays(fillLevel, capacity, fillTypeIndex)
	if self.isClient then
		if self.levelDisplays ~= nil then
			if self.disableFillType then
				for i = 1, #self.levelDisplays do
					self:setDisplayValue(self.levelDisplays[i], fillLevel, capacity);
				end;
			else
				if self.levelDisplays[fillTypeIndex] ~= nil then
					for i = 1, #self.levelDisplays[fillTypeIndex] do
						self:setDisplayValue(self.levelDisplays[i], fillLevel, capacity);
					end;
				end;
			end;
		end;
	else
		g_company.debug:writeDev(self.debugData, "'updateLevelDisplays' is a client only function!");
	end;
end;

-- IMPORTANT: Do not call this function outside this script. Use 'updateDisplays' instead.
function GC_DigitalDisplays:setDisplayValue(display, level, maxLevel)
	local value = 0;

	if display.typeIndex == GC_DigitalDisplays.TYPES.LEVEL then
		value = math.min(maxLevel, math.max(0, level));
	elseif display.typeIndex == GC_DigitalDisplays.TYPES.PERCENT then
		local percent = math.min(math.max(level / maxLevel, 0), 1);
		value = math.abs(percent * 100);
	elseif display.typeIndex == GC_DigitalDisplays.TYPES.SPACE then
		value = math.max(0, maxLevel - math.max(0, level));
	elseif display.typeIndex == GC_DigitalDisplays.TYPES.SPACEPERCENT then
		local percent = math.min(math.max(level / maxLevel, 0), 1);
		value = 100 - math.abs(percent * 100);
	elseif display.typeIndex == GC_DigitalDisplays.TYPES.CAPACITY then
		value = math.max(0, maxLevel);
	end;

	--local actualValue = math.floor(math.min(value, display.maxValue));
	local actualValue = tonumber(string.format("%." .. display.precision .. "f", value)); -- More testing needed.

	if display.lastvalue ~= actualValue then
		display.lastvalue = actualValue;
		I3DUtil.setNumberShaderByValue(display.numbers, actualValue, 0, display.showOnEmpty);

		if display.setColour and display.typeIndex ~= GC_DigitalDisplays.TYPES.CAPACITY then
			local colour, index = self:getNextColour(display, actualValue, maxLevel);
			if index ~= display.currentColourIndex then
				display.currentColourIndex = index;
				self:setNumberColour(display, colour);
			end;
		end;
	end;
end;

function GC_DigitalDisplays:getNextColour(display, value, maxValue)
	if value <= 0 and display.emptyNumberColour ~= nil then
		return display.emptyNumberColour, 2;
	elseif value >= maxValue and display.fullNumberColour ~= nil then
		return display.fullNumberColour, 3;
	else
		return display.numberColour, 1;
	end;
end;

function GC_DigitalDisplays:setNumberColour(display, colourToSet)
	if colourToSet ~= nil then
		for node, _ in pairs(I3DUtil.getNodesByShaderParam(display.numbers, "numberColor")) do
			setShaderParameter(node, "numberColor", colourToSet[1], colourToSet[2], colourToSet[3], colourToSet[4], false);
		end;
	end;
end;





