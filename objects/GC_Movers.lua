--
-- GlobalCompany - Objects - GC_Movers
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 09.02.2019
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.0.0 (09.02.2019):
-- 		- convert to fs19
--
-- 	v1.0.0.0 (26.05.2018):
-- 		- initial fs17
--
-- Notes:
--
--		- Client Side Only.
--
--
-- ToDo:
--		- 'linearInterpolator' option or complete change.
--
--

GC_Movers = {};
local GC_Movers_mt = Class(GC_Movers);

GC_Movers.debugIndex = g_company.debug:registerScriptName("GC_Movers");

g_company.movers = GC_Movers;

function GC_Movers:new(isServer, isClient, customMt)
	local self = {};
	setmetatable(self, customMt or GC_Movers_mt);

	self.isServer = isServer;
	self.isClient = isClient;

	self.movers = nil;

	return self;
end;

function GC_Movers:load(nodeId, target, xmlFile, xmlKey, baseDirectory, capacities, disableFillType)
	if capacities == nil then
		return false;
	end;
	
	self.rootNode = nodeId;
	self.target = target;

	self.debugData = g_company.debug:getDebugData(GC_Movers.debugIndex, target);

	self.baseDirectory = GlobalCompanyUtils.getParentBaseDirectory(target, baseDirectory);

	if self.isClient then
		self.disableFillType = Utils.getNoNil(disableFillType, false);

		local i = 0;
		while true do
			local key = string.format(xmlKey .. ".movers.mover(%d)", i);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;

			local fillTypeIndex, capacity;
			if self.disableFillType then
				capacity = capacities;
			else
				local fillTypeName = getXMLString(xmlFile, key .. "#fillType");
				if fillTypeName ~= nil then
					fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
					if fillTypeIndex ~= nil then
						capacity = capacities[fillTypeIndex];
						if capacity == nil then
							g_company.debug:writeModding(self.debugData, "fillType '%s' can not be used at %s", fillTypeName, key);
						end;
					else
						g_company.debug:writeModding(self.debugData, "fillType '%s' is not valid at %s", fillTypeName, key);
					end;
				else
					g_company.debug:writeModding(self.debugData, "No 'fillType' given at %s", key);
				end;
			end;

			if capacity ~= nil then
				local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings);
				if node ~= nil then
					local mover = {};
					mover.node = node;
					mover.capacity = capacity;

					local transMax = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, key .. ".translation#maximum", 3, false, self.debugData);
					if transMax ~= nil then
						mover.transMin = Utils.getNoNil(GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, key .. ".translation#minimum", 3, false, self.debugData), {getTranslation(mover.node)});
						mover.transMax = transMax;
						setTranslation(mover.node, mover.transMin[1], mover.transMin[2], mover.transMin[3]);

						mover.useTranslation = true;
						mover.transReset = false;
						local startTrans = Utils.getNoNil(getXMLFloat(xmlFile, key .. ".translation#start"), 0);
						mover.startTrans = math.max(startTrans, 0);
						mover.stopTrans = self:getAcceptedStopLevel(getXMLFloat(xmlFile, key .. ".translation#stop"), capacity);
						mover.originalStopTrans = mover.stopTrans;
					else
						mover.useTranslation = false;
					end;

					local rotMax = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, key .. ".rotation#maximum", 3, true, self.debugData);
					if rotMax ~= nil then
						mover.rotMin = Utils.getNoNil(GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, key .. ".rotation#minimum", 3, true, self.debugData), {getRotation(mover.node)});
						mover.rotMax = rotMax;
						setRotation(mover.node, mover.rotMin[1], mover.rotMin[2], mover.rotMin[3]);

						mover.useRotation = true;
						mover.rotReset = false;
						local startRot = Utils.getNoNil(getXMLFloat(xmlFile, key .. ".rotation#start"), 0);
						mover.startRot = math.max(startRot, 0);
						mover.stopRot = self:getAcceptedStopLevel(getXMLFloat(xmlFile, key .. ".rotation#stop"), capacity);
						mover.originalStopRot = mover.stopRot;
					else
						mover.useRotation = false;
					end;

					local scaleMax = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, key .. ".scale#maximum", 3, false, self.debugData);
					if scaleMax ~= nil then
						mover.scaleMin = Utils.getNoNil(GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, key .. ".scale#minimum", 3, false, self.debugData), {getScale(mover.node)});
						mover.scaleMax = scaleMax;
						setScale(mover.node, mover.scaleMin[1], mover.scaleMin[2], mover.scaleMin[3]);

						mover.useScale = true;
						mover.scaleReset = false;
						local startScale = Utils.getNoNil(getXMLFloat(xmlFile, key .. ".scale#start"), 0);
						mover.startScale = math.max(startScale, 0);
						mover.stopScale = self:getAcceptedStopLevel(getXMLFloat(xmlFile, key .. ".scale#stop"), capacity);
						mover.originalStopScale = mover.stopScale;
					else
						mover.useScale = false;
					end;

					local colourMin = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, key .. ".shaderColor#minimum", 3, false, self.debugData);
					local colourMax = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, key .. ".shaderColor#maximum", 3, false, self.debugData);
					if colourMin ~= nil and colourMax ~= nil then
						-- Only with (bunkerSiloSilageShader.xml)
						if getHasShaderParameter(mover.node, "colorScale") then
							mover.colourMin = colourMin;
							mover.colourMax = colourMax;
							setShaderParameter(mover.node, "colorScale", colourMin[1], colourMin[2], colourMin[3], 0, false);

							mover.useColourChange = true;
							mover.colourReset = false;
							local startColourChange = Utils.getNoNil(getXMLFloat(xmlFile, key .. ".shaderColor#start"), 0);
							mover.startColourChange = math.max(startColourChange, 0);
							mover.stopColourChange = self:getAcceptedStopLevel(getXMLFloat(xmlFile, key .. ".shaderColor#stop"), capacity);
							mover.originalStopColourChange = mover.stopColourChange;
						else
							g_company.debug:writeModding(self.debugData, "'allowColorChange' disbaled! Shader Parameter 'colorScale' does not exist on node '%s' at %s. - Supported Shader: bunkerSiloSilageShader -", mover.node, key);
						end;
					else
						mover.useColourChange = false;
					end;

					mover.hideAtFillLevel = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#hideAtFillLevel"), -100) + 0.0001;
					mover.visibility = mover.hideAtFillLevel ~= 0.0001;
					setVisibility(mover.node, mover.visibility);

					if self.movers == nil then
						self.movers = {};
					end;

					if self.disableFillType then
						table.insert(self.movers, mover);
					else
						if self.movers[fillTypeIndex] == nil then
							self.movers[fillTypeIndex] = {};
						end;

						table.insert(self.movers[fillTypeIndex], mover);
					end;
					
					mover = nil;
				end;
			end;

			i = i + 1;
		end;
	end;

	return true;
end;

function GC_Movers:getAcceptedStopLevel(level, capacity)
	if level == nil then
		return capacity;
	else
		if level <= 0 or level > capacity then
			return capacity;
		end;
	end;

	return level;
end;

function GC_Movers:updateMovers(fillLevel, fillTypeIndex)
	if self.isClient then
		if self.movers ~= nil then
			if self.disableFillType then
				for _, mover in pairs(self.movers) do
					self:setMover(mover, fillLevel);
				end;
			else
				if self.movers[fillTypeIndex] ~= nil then
					for _, mover in pairs(self.movers[fillTypeIndex]) do
						self:setMover(mover, fillLevel);
					end;
				end;
			end;
		end;
	end;
end;

-- IMPORTANT: Do not call this function outside this script. Use 'updateNodes' instead.
function GC_Movers:setMover(mover, fillLevel)
	local state = fillLevel > mover.hideAtFillLevel;
	if state ~= mover.visibility then
		setVisibility(mover.node, state);
	end;

	if mover.useTranslation then
		if fillLevel > mover.startTrans then
			mover.transReset = true;

			if fillLevel < mover.stopTrans then
				local trans = {};
				local factor = (fillLevel-mover.startTrans) / (mover.stopTrans-mover.startTrans);
				for i = 1, 3 do
					trans[i] = mover.transMin[i] + factor * (mover.transMax[i] - mover.transMin[i]);
				end;
				setTranslation(mover.node, trans[1], trans[2], trans[3]);
			end;
		else
			if mover.transReset then
				setTranslation(mover.node, mover.transMin[1], mover.transMin[2], mover.transMin[3]);
				mover.transReset = false;
			end;
		end;
	end;

	if mover.useRotation then
		if fillLevel > mover.startRot then
			mover.rotReset = true;

			if fillLevel < mover.stopRot then
				local rot = {};
				local factor = (fillLevel-mover.startRot) / (mover.stopRot-mover.startRot);
				for i = 1, 3 do
					rot[i] = mover.rotMin[i] + factor * (mover.rotMax[i] - mover.rotMin[i]);
				end;

				setRotation(mover.node, rot[1], rot[2], rot[3]);
			end;
		else
			if mover.rotReset then
				setRotation(mover.node, mover.rotMin[1], mover.rotMin[2], mover.rotMin[3]);
				mover.rotReset = false;
			end;
		end;
	end;

	if mover.useScale then
		if fillLevel > mover.startScale then
			mover.scaleReset = true;

			if fillLevel < mover.stopScale then
				local scale = {};
				local factor = (fillLevel-mover.startScale) / (mover.stopScale-mover.startScale);
				for i = 1, 3 do
					scale[i] = mover.scaleMin[i] + factor * (mover.scaleMax[i] - mover.scaleMin[i]);
				end;

				setScale(mover.node, scale[1], scale[2], scale[3]);
			end;
		else
			if mover.scaleReset then
				setScale(mover.node, mover.scaleMin[1], mover.scaleMin[2], mover.scaleMin[3]);
				mover.scaleReset = false;
			end;
		end;
	end;

	if mover.useColourChange then
		if fillLevel >= mover.startColourChange then
			mover.colourReset = true;

			if fillLevel < mover.stopColourChange then
				local colourScale = {0, 0, 0};
				local factor = (fillLevel - mover.startColourChange) / (mover.stopColourChange - mover.startColourChange);
				for i = 1, 3 do
					colourScale[i] = MathUtil.clamp(mover.colourMin[i] + factor * (mover.colourMax[i] - mover.colourMin[i]), 0, 1);
				end;

				setShaderParameter(mover.node, "colorScale", colourScale[1], colourScale[2], colourScale[3], 0, false);
			end;
		else
			if mover.colourReset then
				setShaderParameter(mover.node, "colorScale", mover.colourMin[1], mover.colourMin[2], mover.colourMin[3], 0, false);
				mover.colourReset = false;
			end;
		end;
	end;
end;

-- Use this to update 'endLevel' if the capacity can change on target.
-- value will be added or subtracted from the 'originalEndLevel' as set in the XML or default.
function GC_Movers:updateMoversEndLevel(value, fillTypeIndex)
	if self.isClient then
		if value == nil then
			value = 0;
		end;

		if self.movers ~= nil then
			if self.disableFillType then
				for _, mover in pairs(self.movers) do
					if mover.stopTrans ~= nil then
						mover.stopTrans = mover.originalStopTrans + value;
					end;
					if mover.stopRot ~= nil then
						mover.stopRot = mover.originalStopRot + value;
					end;
					if mover.stopScale ~= nil then
						mover.stopScale = mover.originalStopScale + value;
					end;
					if mover.stopColourChange ~= nil then
						mover.stopColourChange = mover.originalStopColourChange + value;
					end;
				end;
			else
				if fillTypeIndex ~= nil and self.movers[fillTypeIndex] ~= nil then
					for _, mover in pairs(self.movers[fillTypeIndex]) do
						if mover.stopTrans ~= nil then
							mover.stopTrans = mover.originalStopTrans + value;
						end;
						if mover.stopRot ~= nil then
							mover.stopRot = mover.originalStopRot + value;
						end;
						if mover.stopScale ~= nil then
							mover.stopScale = mover.originalStopScale + value;
						end;
						if mover.stopColourChange ~= nil then
							mover.stopColourChange = mover.originalStopColourChange + value;
						end;
					end;
				end;
			end;
		end;
	end;
end;


