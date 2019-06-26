--
-- GlobalCompany - Objects - GC_FillVolume
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 15.02.2019
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.0.0 (15.02.2019):
-- 		- convert to fs19
--
-- 	v1.0.0.0 (??.??.2018):
-- 		- initial fs17(kevink98)
--
-- Notes:
--
--		- Client Side Only.
--
--
-- ToDo:
--
--

GC_FillVolume = {};

local GC_FillVolume_mt = Class(GC_FillVolume);
InitObjectClass(GC_FillVolume, "GC_FillVolume");

GC_FillVolume.debugIndex = g_company.debug:registerScriptName("GC_FillVolume");

g_company.fillVolume = GC_FillVolume;

function GC_FillVolume:new(isServer, isClient, customMt)
	local self = {};
	setmetatable(self, customMt or GC_FillVolume_mt);

	self.isServer = isServer;
	self.isClient = isClient;

	self.fillVolumes = nil;

	return self;
end;

function GC_FillVolume:load(nodeId, target, xmlFile, xmlKey, capacity, forceCapacity, defaultFillType)
	self.rootNode = nodeId;
	self.target = target;

	self.debugData = g_company.debug:getDebugData(GC_FillVolume.debugIndex, target);	

	if self.isClient then
		self.fillVolumes = {};

		local i = 0;
		while true do
			local key = string.format("%s.fillVolumes.volume(%d)", xmlKey, i);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;

			local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings);
			if node ~= nil then

				local fillTypeIndex;
				if defaultFillType ~= nil then
					fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(defaultFillType);
					if fillTypeIndex == nil then
						g_company.debug:writeDev(self.debugData, "defaultFillType '%s' given as part of load is not valid!");
					end;
				else
					local fillTypeName = getXMLString(xmlFile, key .. "#defaultFillType");
					if fillTypeName ~= nil then
						fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
						if fillTypeIndex == nil then
							g_company.debug:writeModding(self.debugData, "defaultFillType '%s' is not valid at %s", fillTypeName, key);
						end;
					else
						g_company.debug:writeModding(self.debugData, "No 'defaultFillType' given at %s", key);
					end;
				end;

				if fillTypeIndex ~= nil then
					local setCapacity = capacity;
					if forceCapacity ~= true then
						local userCapacity = Utils.getNoNil(getXMLInt(xmlFile, key .. "#capacity"), capacity);
						setCapacity = math.min(math.max(userCapacity, 1), capacity); -- Only allow a capacity level > 1 and <= 'capacity paramater'.
					end;

					local volume = {};
					volume.node = node;
					volume.fillLevel = 0;
					volume.capacity = setCapacity;
					volume.fillTypeIndex = fillTypeIndex;
					volume.defaultFillTypeIndex = fillTypeIndex;

					volume.lastFillTypeIndex = nil;

					volume.allSidePlanes = Utils.getNoNil(getXMLBool(xmlFile, key .. "#allSidePlanes"), true);

					volume.maxDelta = Utils.getNoNil(getXMLFloat(xmlFile, key.."#maxDelta"), 1.0);
					volume.maxSubDivEdgeLength = Utils.getNoNil(getXMLFloat(xmlFile, key.."#maxSubDivEdgeLength"), 0.9);
					volume.maxSurfaceAngle = math.rad(Utils.getNoNil(getXMLFloat(xmlFile, key.."#maxAllowedHeapAngle"), 35));

					local maxPhysicalSurfaceAngle = math.rad(35);
					volume.volume = createFillPlaneShape(volume.node, "fillPlane", volume.capacity, volume.maxDelta, volume.maxSurfaceAngle, maxPhysicalSurfaceAngle, volume.maxSubDivEdgeLength, volume.allSidePlanes);
					setVisibility(volume.volume, false);

					if volume.volume ~= nil and volume.volume ~= 0 then
						link(volume.node, volume.volume);
						table.insert(self.fillVolumes, volume);
					end;
				end;
			end;

			i = i + 1;
		end;
	end;

	return true;
end;

function GC_FillVolume:delete()
	if self.isClient and self.fillVolumes ~= nil then
		for _, volume in pairs(self.fillVolumes) do
			if volume.volume ~= nil then
				delete(volume.volume);
			end

			volume.volume = nil;
		end
	end;
end;

function GC_FillVolume:setFillType(fillTypeIndex, volume)
	if fillTypeIndex ~= FillType.UNKNOWN and g_fillTypeManager.indexToName[fillTypeIndex] ~= nil then
		if volume ~= nil then
			volume.fillTypeIndex = fillTypeIndex;
		else
			for _, volume in pairs(self.fillVolumes) do
				volume.fillTypeIndex = fillTypeIndex;
			end;
		end;
	else
		g_company.debug:writeDev(self.debugData, "[function - setFillType()] fillTypeIndex '%s' is not valid or UNKNOWN!", fillTypeIndex);
	end;
end;

function GC_FillVolume:addFillLevel(fillLevel, volume)
	local deltaTable;

	if self.isClient then
		if volume ~= nil then
			local delta = self:addFillLevelVolume(fillLevel, volume);
			deltaTable = {delta};
		else
			deltaTable = {};
			for i = 1, #self.fillVolumes do
				local fillVolume = self.fillVolumes[i];
				local delta = self:addFillLevelVolume(fillLevel, fillVolume);
				deltaTable[i] = delta;
			end;
		end;
	end;

	return deltaTable;
end;

-- IMPORTANT: Do not call this function outside this script. Use 'addFillLevel' instead.
function GC_FillVolume:addFillLevelVolume(fillLevel, volume)
	local oldFillLevel = volume.fillLevel;

	volume.fillLevel = math.min(fillLevel, volume.capacity);

	local delta = volume.fillLevel - oldFillLevel;

	if delta ~= 0 then
		local fillTypeIndex = volume.fillTypeIndex or volume.defaultFillTypeIndex;

		if fillTypeIndex ~= nil and fillTypeIndex ~= FillType.UNKNOWN then
			local maxPhysicalSurfaceAngle
			local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex);
			if fillType ~= nil then
				maxPhysicalSurfaceAngle = fillType.maxPhysicalSurfaceAngle;
			end;
			if maxPhysicalSurfaceAngle ~= nil then
				if volume.volume ~= nil then
					setFillPlaneMaxPhysicalSurfaceAngle(volume.volume, maxPhysicalSurfaceAngle);
				end;
			end;

			if fillTypeIndex ~= volume.lastFillTypeIndex then
				local material = g_materialManager:getMaterial(fillTypeIndex, "fillplane", 1);
				if material ~= nil then
					setMaterial(volume.volume, material, 0);
				end;

				volume.lastFillTypeIndex = fillTypeIndex;
			end;
		end;

		setVisibility(volume.volume, volume.fillLevel > 0);

		--local x,y,z = localToWorld(volume.volume, 0, 0, 0);
		local x, y, z = getWorldTranslation(volume.volume);
		local d1x, d1y, d1z = localDirectionToWorld(volume.volume, 5, 0, 0);
		local d2x, d2y, d2z = localDirectionToWorld(volume.volume, 0, 0, 5);
		x = x - (d1x + d2x) / 2;
		y = y - (d1y + d2y) / 2;
		z = z - (d1z + d2z) / 2;

		fillPlaneAdd(volume.volume, delta, x, y, z, d1x, d1y, d1z, d2x, d2y, d2z);
	end;

	return delta;
end;





