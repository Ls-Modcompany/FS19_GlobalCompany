--
-- GlobalCompany - Objects - GC_VisibilityNodes
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX / kevink98
-- @Date: 06.02.2019
-- @Version: 1.1.0.0
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
-- 		- initial fs17
--
-- Notes:
--
--		- Client Side Only.
--		- Parent script 'MUST' call delete().
--
-- ToDo:
--
--

GC_VisibilityNodes = {};

GC_VisibilityNodes_mt = Class(GC_VisibilityNodes);
InitObjectClass(GC_VisibilityNodes, "GC_VisibilityNodes");

GC_VisibilityNodes.debugIndex = g_company.debug:registerScriptName("VisibilityNodes");

g_company.visibilityNodes = GC_VisibilityNodes;

function GC_VisibilityNodes:new(isServer, isClient, customMt)
	local self = {};
	setmetatable(self, customMt or GC_VisibilityNodes_mt);

	self.isServer = isServer;
	self.isClient = isClient;

	return self;
end;

-- Load instance.
-- @param table triggerClass = trigger class you want to load.
-- @param integer nodeId = root node.
-- @param table target = parent object.
-- @param integer xmlFile = xmlFile to use.
-- @param string xmlKey = xmlKey to use.
-- @param string baseDirectory = baseDirectory to use.
-- @param float capacities = [disableFillType = true] - capacity of parent.
-- OR
-- @param table capacities = [disableFillType = false / nil] - All fillType capacities of parent. Table structure = (key = fillTypeIndex, variable = capacity).
-- @param boolan disableFillType = If 'true' fillTypeIndexing will be ignored.
-- @return instance loaded correctly.
function GC_VisibilityNodes:load(nodeId, target, xmlFile, xmlKey, baseDirectory, capacities, disableFillType)	
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil or capacities == nil then
		local text = "Loading failed! 'nodeId' paramater = %s, 'target' paramater = %s 'xmlFile' paramater = %s, 'xmlKey' paramater = %s, 'capacities' paramater = %s";
		g_company.debug:logWrite(GC_Movers.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil, capacities ~= nil);
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_VisibilityNodes.debugIndex, target);

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
		self.disableFillType = Utils.getNoNil(disableFillType, false);

		local i = 0;
		while true do
			local key = string.format("%s.visibilityNodes.nodeGroup(%d)", xmlKey, i);
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
				local loadedNodes = {};
				local hasChildCollisions = Utils.getNoNil(getXMLString(xmlFile, key.."#hasChildCollisions"), false);  -- No need to look if there is none!
	
				local nodeType = "VISIBILITY";
				local userNodeType = getXMLString(xmlFile, key .. "#type"); -- Options: 'VISIBILITY' or 'INVISIBILITY'
				if userNodeType ~= nil then
					local upperNodeType = userNodeType:upper();
					if upperNodeType == "VISIBILITY" or upperNodeType == "INVISIBILITY" then
						nodeType = userNodeType;
					else
						g_company.debug:writeModding(self.debugData, "Unknown type '%s' given at %s. Use 'VISIBILITY' or 'INVISIBILITY'", typ, key);
					end;
				end;
	
				local parentNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings);
				if parentNode ~= nil then
					-- Load from all children of given 'parent'.				
					local numInGroup = getNumOfChildren(parentNode);
					if numInGroup > 0 then
						local filename = getXMLString(xmlFile, key .. "#filename");
						local sharedI3dNode = Utils.getNoNil(getXMLString(xmlFile, key .. "#sharedI3dNode"), "0");					
						for id = 0, numInGroup - 1 do
							local node = getChildAt(parentNode, id);
							self:loadVisibilityNode(node, loadedNodes, hasChildCollisions, nodeType, filename, sharedI3dNode, key)
						end;
					end;
				else
					-- Load from individual given children as give in xml.
					local j = 0;
					while true do
						local childKey = string.format("%s.child(%d)", key, j);
						if not hasXMLProperty(xmlFile, childKey) then
							break;
						end;
	
						local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, childKey .. "#node"), self.target.i3dMappings);
						if node ~= nil then
							local filename = getXMLString(xmlFile, childKey .. "#filename");
							local sharedI3dNode = Utils.getNoNil(getXMLString(xmlFile, childKey .. "#sharedI3dNode"), "0");
							self:loadVisibilityNode(node, loadedNodes, hasChildCollisions, nodeType, filename, sharedI3dNode, childKey)
						end;
	
						j = j + 1;
					end;
				end;
	
				if #loadedNodes > 0 then
					local visNodes = {};
	
					visNodes.startLevel = math.max(Utils.getNoNil(getXMLFloat(xmlFile, key .. "#startChangeFillLevel"), 0), 0);
					local endLevel = getXMLFloat(xmlFile, key.."#endChangeFillLevel");
					if endLevel == nil or endLevel <= 0 or endLevel > capacity then
						visNodes.endLevel = capacity;
					else
						visNodes.endLevel = endLevel;
					end;

					visNodes.originalEndLevel = visNodes.endLevel;
					
					visNodes.nodes = loadedNodes;
					visNodes.nodeType = nodeType;
					visNodes.hasChildCollisions = hasChildCollisions;
	
					if self.visNodes == nil then
						self.visNodes = {};
					end;
	
					if self.disableFillType then
						table.insert(self.visNodes, visNodes);
						returnValue = true;
					else
						if self.visNodes[fillTypeIndex] == nil then
							self.visNodes[fillTypeIndex] = {};
						end;
	
						table.insert(self.visNodes[fillTypeIndex], visNodes);
						returnValue = true;
					end;
				end;
			end;

			i = i + 1;
		end;
	else
		g_company.debug:writeDev(self.debugData, "Failed to load 'CLIENT ONLY' script on server!");
		returnValue = true; -- Send true so we can also print 'function' warnings if called by server.
	end;

	return returnValue;
end;

function GC_VisibilityNodes:loadVisibilityNode(node, loadedNodes, hasChildCollisions, nodeType, filename, sharedI3dNode, key)
	local loadedNode = {};
	loadedNode.node = node;

	if filename ~= nil and sharedI3dNode ~= nil then
		local i3dNode = g_i3DManager:loadSharedI3DFile(filename, self.baseDirectory, false, false, false);
		if i3dNode ~= 0 then
			local sharedRootNode = I3DUtil.indexToObject(i3dNode, sharedI3dNode);
			if sharedRootNode ~= nil then
				loadedNode.node = sharedRootNode;
				loadedNode.filename = filename;
				link(node, sharedRootNode);
				addToPhysics(sharedRootNode);
			else
				g_company.debug:writeWarning(self.debugData, "sharedI3dNode '%s' could not be found in i3d file '%s' at ( %s )", sharedI3dNode, filename, key);
			end;

			delete(i3dNode);
		else
			g_company.debug:writeWarning(self.debugData, "Could not load file '%s' at ( %s )", filename, key);
		end;
	end;

	loadedNode.rigidBody = getRigidBodyType(loadedNode.node);
	loadedNode.active = nodeType ~= "VISIBILITY"

	local visibility, rigidBodyType = self:getTypeData(loadedNode.rigidBody, nodeType);
	setRigidBodyType(loadedNode.node, rigidBodyType);
	setVisibility(loadedNode.node, visibility);

	if hasChildCollisions then
		local childColIndexs = {};
		self:getChildCollisionNodes(loadedNode.node, childColIndexs);
		if #childColIndexs > 0 then
			loadedNode.childNodes = {};
			for childId = 1, #childColIndexs do
				local childNodes = {};
				childNodes.node = childColIndexs[childId];
				childNodes.rigidBody = getRigidBodyType(childNodes.node);
				local _, rigidBodyType = self:getTypeData(childNodes.rigidBody, nodeType);
				setRigidBodyType(childNodes.node, rigidBodyType);
				table.insert(loadedNode.childNodes, childNodes);
			end;
		else
			hasChildCollisions = false;
		end;
	end;

	table.insert(loadedNodes, loadedNode);
end;

function GC_VisibilityNodes:delete()
	if self.isClient and self.visNodes ~= nil then
		for _, visNodes in pairs(self.visNodes) do
			for i = 1, #visNodes.nodes do
				if visNodes.nodes[i].filename ~= nil then
					g_i3DManager:releaseSharedI3DFile(visNodes.nodes[i].filename, self.baseDirectory, true);
				end;
			end;
		end;		
	end;
end;

function GC_VisibilityNodes:updateNodes(fillLevel, fillTypeIndex)
	if self.isClient then
		if self.visNodes ~= nil then
			if self.disableFillType then
				for _, visNodes in pairs(self.visNodes) do
					self:setNodes(visNodes, fillLevel);
				end;
			else
				if self.visNodes[fillTypeIndex] ~= nil then
					for _, visNodes in pairs(self.visNodes[fillTypeIndex]) do
						self:setNodes(visNodes, fillLevel);
					end;
				end;
			end;
		end;
	else
		g_company.debug:writeDev(self.debugData, "'updateNodes' is a client only function!");
	end;
end;

-- IMPORTANT: Do not call this function outside this script. Use 'updateNodes' instead.
function GC_VisibilityNodes:setNodes(visNodes, fillLevel)
	local numNodes = #visNodes.nodes;

	local nodesVisible = math.ceil(numNodes * (fillLevel - visNodes.startLevel) / (visNodes.endLevel - visNodes.startLevel));

	for i = 1, numNodes do
		if visNodes.nodeType == "VISIBILITY" then
			local active = i <= nodesVisible;
			if visNodes.nodes[i].active ~= active then
				visNodes.nodes[i].active = active;
				setVisibility(visNodes.nodes[i].node, active);
				setRigidBodyType(visNodes.nodes[i].node, active and visNodes.nodes[i].rigidBody or "NoRigidBody");
				if visNodes.hasChildCollisions then
					if visNodes.nodes[i].childNodes ~= nil then
						for _, childNode in pairs (visNodes.nodes[i].childNodes) do
							setRigidBodyType(childNode.node, active and childNode.rigidBody or "NoRigidBody");
						end;
					end;
				end;
			end;
		elseif visNodes.nodeType == "INVISIBILITY" then
			local active = i > nodesVisible;
			if visNodes.nodes[i].active ~= active then
				visNodes.nodes[i].active = active;
				setVisibility(visNodes.nodes[i].node, active);
				setRigidBodyType(visNodes.nodes[i].node, active and visNodes.nodes[i].rigidBody or "NoRigidBody");
				if visNodes.hasChildCollisions then
					if visNodes.nodes[i].childNodes ~= nil then
						for _, childNode in pairs (visNodes.nodes[i].childNodes) do
							setRigidBodyType(childNode.node, active and childNode.rigidBody or "NoRigidBody");
						end;
					end;
				end;
			end;
		end;
	end;
end;

-- Use this to update 'endLevel' if the capacity can change on target.
-- value will be added or subtracted from the 'originalEndLevel' as set in the XML or default.
function GC_VisibilityNodes:updateVisNodesEndLevel(value, fillTypeIndex)
	if self.isClient then
		if value == nil then
			value = 0;
		end;

		if self.visNodes ~= nil then
			if self.disableFillType then
				for _, visNodes in pairs(self.visNodes) do
					visNodes.endLevel = visNodes.originalEndLevel + value;
				end;
			else
				if fillTypeIndex ~= nil and self.visNodes[fillTypeIndex] ~= nil then
					for _, visNodes in pairs(self.visNodes[fillTypeIndex]) do
						visNodes.endLevel = visNodes.originalEndLevel + value;
					end;
				end;
			end;
		end;
	else
		g_company.debug:writeDev(self.debugData, "'updateVisNodesEndLevel' is a client only function!");
	end;
end;

function GC_VisibilityNodes:getTypeData(currentRBT, nodeType)
	local visibility, rigidBodyType = false, "NoRigidBody";

	if nodeType == "INVISIBILITY" then
		visibility = true;
		rigidBodyType = currentRBT;
	end;

	return visibility, rigidBodyType;
end;

function GC_VisibilityNodes:getChildCollisionNodes(node, childTable)
	local childCount = getNumOfChildren(node);
	if childCount > 0 then
		for i = 0, childCount - 1 do
			local child = getChildAt(node, i);
			if getRigidBodyType(child) ~= "NoRigidBody" then
				table.insert(childTable, child);
			end;

			self:getChildCollisionNodes(child, childTable);
		end;
	end;
end;





