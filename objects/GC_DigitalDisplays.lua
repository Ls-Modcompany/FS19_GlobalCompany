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
--		- LEVEL = FillLevel in litres.
--		- PERCENT = FillLevel in percent.
--		- SPACE = Available storage space.
--		- SPACEPERCENT = Available storage space in percent.
--		- CAPACITY = Max storage capacity.
--		- TEXT = Display text using a shader. (Coming soon)
--
--
-- ToDo:
--		- Add text shader support.
--
--

GC_DigitalDisplays = {};

local GC_DigitalDisplays_mt = Class(GC_DigitalDisplays);
InitObjectClass(GC_DigitalDisplays, "GC_DigitalDisplays");

GC_DigitalDisplays.TYPES = {["LEVEL"] = 1,
							["PERCENT"] = 2,
							["SPACE"] = 3,
							["SPACEPERCENT"] = 4,
							["CAPACITY"] = 5,
							["TEXT"] = 6};

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
		local text = "Loading failed! 'nodeId' parameter = %s, 'target' parameter = %s 'xmlFile' parameter = %s, 'xmlKey' parameter = %s";
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
			local key = string.format("%s.%s.display(%d)", xmlKey, groupKey, i);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;

			local displayType = getXMLString(xmlFile, key .. "#displayType");
			if displayType ~= nil then
				local typeIndex = GC_DigitalDisplays.TYPES[displayType:upper()];
				if typeIndex ~= nil then
					local colourToSet;

					local display = {};

					if typeIndex == GC_DigitalDisplays.TYPES.TEXT then
						display = nil;
					else
						local numbers = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#numbers"), self.target.i3dMappings)
						if numbers ~= nil then
							local numMeshes = getNumOfChildren(numbers);
							if numMeshes > 0 then
								display.numbers = numbers;
								display.lastvalue = -1;
								display.numberColour = GlobalCompanyUtils.getNumbersFromString(xmlFile, key .. "#numberColor", 4, false, self.debugData);
								display.currentColourIndex = 1;
								colourToSet = display.numberColour;

								display.showOnEmpty = Utils.getNoNil(getXMLBool(xmlFile, key .. "#showOnEmpty"), true);

								if display.numberColour ~= nil and typeIndex ~= GC_DigitalDisplays.TYPES.CAPACITY then
									display.emptyNumberColour = GlobalCompanyUtils.getNumbersFromString(xmlFile, key .. "#emptyNumberColor", 4, false, self.debugData);
									display.fullNumberColour = GlobalCompanyUtils.getNumbersFromString(xmlFile, key .. "#fullNumberColor", 4, false, self.debugData);

									if display.emptyNumberColour ~= nil then
										colourToSet = display.emptyNumberColour;
										display.currentColourIndex = 2;
									end;
								end;

								display.setColour = display.emptyNumberColour ~= nil or display.fullNumberColour ~= nil;
								display.maxValue = (10 ^ (numMeshes)) - 1;
							end;
						else
							g_company.debug:writeModding(self.debugData, "Missing numbers node for display '%s'", key);
							display = nil;
						end;
					end;

					if display ~= nil then
						self:setNumberColour(display, colourToSet);

						if self.levelDisplays == nil then
							self.levelDisplays = {};
						end;

						if self.disableFillType == true then
							if self.levelDisplays[typeIndex] == nil then
								self.levelDisplays[typeIndex] = {};
							end;

							table.insert(self.levelDisplays[typeIndex], display);
							returnValue = true;
						else
							local fillTypeName = getXMLString(xmlFile, key .. "#fillType");
							if fillTypeName ~= nil then
								local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
								if fillTypeIndex ~= nil then
									if self.levelDisplays[fillTypeIndex] == nil then
										self.levelDisplays[fillTypeIndex] = {};
									end;

									if self.levelDisplays[fillTypeIndex][typeIndex] == nil then
										self.levelDisplays[fillTypeIndex][typeIndex] = {};
									end;

									table.insert(self.levelDisplays[fillTypeIndex][typeIndex], display);
									returnValue = true;
								else
									g_company.debug:writeModding(self.debugData, "fillType '%s' is not valid at %s", fillTypeName, key);
								end;
							else
								g_company.debug:writeModding(self.debugData, "No 'fillType' given at %s", key);
							end;
						end;
					end;
				else

				end;
			else
				g_company.debug:writeModding(self.debugData, "Unknown displayType '%s' given at '%s'", displayType, key);
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
				for typeIndex, displayType in pairs (self.levelDisplays) do
					local value = self:getLevelDisplayValue(typeIndex, fillLevel, capacity);

					for i = 1, #displayType do
						self:setLevelDisplayValue(displayType[i], value, capacity);
					end;
				end;
			else
				if self.levelDisplays[fillTypeIndex] ~= nil then
					for typeIndex, displayType in pairs (self.levelDisplays[fillTypeIndex]) do
						local value = self:getLevelDisplayValue(typeIndex, fillLevel, capacity);

						for i = 1, #displayType do
							self:setLevelDisplayValue(displayType[i], value, capacity);
						end;
					end;
				end;
			end;
		end;
	else
		g_company.debug:writeDev(self.debugData, "'updateLevelDisplays' is a client only function!");
	end;
end;

function GC_DigitalDisplays:getLevelDisplayValue(typeIndex, level, maxLevel)
	local value = 0;

	if typeIndex == GC_DigitalDisplays.TYPES.LEVEL then
		value = math.min(maxLevel, math.max(0, level));
	elseif typeIndex == GC_DigitalDisplays.TYPES.PERCENT then
		local percent = math.min(math.max(level / maxLevel, 0), 1);
		value = math.abs(percent * 100);
	elseif typeIndex == GC_DigitalDisplays.TYPES.SPACE then
		value = math.max(0, maxLevel - math.max(0, level));
	elseif typeIndex == GC_DigitalDisplays.TYPES.SPACEPERCENT then
		local percent = math.min(math.max(level / maxLevel, 0), 1);
		value = 100 - math.abs(percent * 100);
	elseif typeIndex == GC_DigitalDisplays.TYPES.CAPACITY then
		value = math.max(0, maxLevel);
	end;

	return value;
end;

-- IMPORTANT: Do not call this function outside this script. Use 'updateDisplays' instead.
function GC_DigitalDisplays:setLevelDisplayValue(display, value, maxLevel)
	local valueToSet = math.min(display.maxValue, math.max(0, value));
	--local actualValue = tonumber(string.format("%.0f", valueToSet));
	local actualValue = math.floor(valueToSet); -- Precision is always '0' so this will operate much faster.

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





