--
-- GlobalCompany - Objects - GC_Visibility
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
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
-- 		- initial fs17 (kevink98)
--
-- Notes:
--
--		- Client Side Only.
--		- Parent script 'MUST' call delete().
--
-- ToDo:
--
--

GC_Visibility = {}

GC_Visibility_mt = Class(GC_Visibility)
InitObjectClass(GC_Visibility, "GC_Visibility")

GC_Visibility.debugIndex = g_company.debug:registerScriptName("GC_Visibility")

g_company.visibility = GC_Visibility

function GC_Visibility:new(isServer, isClient, customMt)
	local self = {}
	setmetatable(self, customMt or GC_Visibility_mt)

	self.isServer = isServer
	self.isClient = isClient
	
	self.visNodes = nil

	return self
end

function GC_Visibility:load(nodeId, target, xmlFile, xmlKey, baseDirectory)
	if nodeId == nil or target == nil then
		return false
	end

	self.debugData = g_company.debug:getDebugData(GC_Visibility.debugIndex, target)

	self.rootNode = nodeId
	self.target = target

	self.baseDirectory = GlobalCompanyUtils.getParentBaseDirectory(target, baseDirectory)

    local i = 0
    while true do
        local key = string.format("%s.visibility.nodeGroup(%d)", xmlKey, i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end			

        local loadedNodes = {}
        local hasChildCollisions = Utils.getNoNil(getXMLString(xmlFile, key.."#hasChildCollisions"), false)  -- No need to look if there is none!

        local nodeType = "VISIBILITY"
        local userNodeType = getXMLString(xmlFile, key .. "#type") -- Options: 'VISIBILITY' or 'INVISIBILITY'
        if userNodeType ~= nil then
            local upperNodeType = userNodeType:upper()
            if upperNodeType == "VISIBILITY" or upperNodeType == "INVISIBILITY" then
                nodeType = userNodeType
            else
                g_company.debug:writeModding(self.debugData, "Unknown type '%s' given at %s. Use 'VISIBILITY' or 'INVISIBILITY'", typ, key)
            end
        end

        local parentNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings)
        if parentNode ~= nil then
            -- Load from all children of given 'parent'.
            local numInGroup = getNumOfChildren(parentNode)
            if numInGroup > 0 then
                local filename = getXMLString(xmlFile, key .. "#filename")
                local sharedI3dNode = Utils.getNoNil(getXMLString(xmlFile, key .. "#sharedI3dNode"), "0")
                for id = 0, numInGroup - 1 do
                    local node = getChildAt(parentNode, id)
                    self:loadVisibilityNode(node, loadedNodes, hasChildCollisions, nodeType, filename, sharedI3dNode, key)
                end
            end
        else
            -- Load from individual given children as give in xml.
            local j = 0
            while true do
                local childKey = string.format("%s.child(%d)", key, j)
                if not hasXMLProperty(xmlFile, childKey) then
                    break
                end

                local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, childKey .. "#node"), self.target.i3dMappings)
                if node ~= nil then
                    local filename = getXMLString(xmlFile, childKey .. "#filename")
                    local sharedI3dNode = Utils.getNoNil(getXMLString(xmlFile, childKey .. "#sharedI3dNode"), "0")
                    self:loadVisibilityNode(node, loadedNodes, hasChildCollisions, nodeType, filename, sharedI3dNode, childKey)
                end

                j = j + 1
            end
        end

        if #loadedNodes > 0 then
            local visNodes = {}

            visNodes.originalEndLevel = visNodes.endLevel

            visNodes.nodes = loadedNodes
            visNodes.nodeType = nodeType
            visNodes.hasChildCollisions = hasChildCollisions

            if self.visNodes == nil then
                self.visNodes = {}
            end

            table.insert(self.visNodes, visNodes)
        end

        i = i + 1
    end

	return true
end

function GC_Visibility:loadVisibilityNode(node, loadedNodes, hasChildCollisions, nodeType, filename, sharedI3dNode, key)
	local loadedNode = {}
	loadedNode.node = node

	if filename ~= nil and sharedI3dNode ~= nil then
		local i3dNode = g_i3DManager:loadSharedI3DFile(filename, self.baseDirectory, false, false, false)
		if i3dNode ~= 0 then
			local sharedRootNode = I3DUtil.indexToObject(i3dNode, sharedI3dNode)
			if sharedRootNode ~= nil then
				loadedNode.node = sharedRootNode
				loadedNode.filename = filename
				link(node, sharedRootNode)
				addToPhysics(sharedRootNode)
			else
				g_company.debug:writeWarning(self.debugData, "sharedI3dNode '%s' could not be found in i3d file '%s' at ( %s )", sharedI3dNode, filename, key)
			end

			delete(i3dNode)
		else
			g_company.debug:writeWarning(self.debugData, "Could not load file '%s' at ( %s )", filename, key)
		end
	end

	loadedNode.rigidBody = getRigidBodyType(loadedNode.node)
	loadedNode.active = nodeType ~= "VISIBILITY"

	local visibility, rigidBodyType = self:getTypeData(loadedNode.rigidBody, nodeType)
	setRigidBodyType(loadedNode.node, rigidBodyType)
	setVisibility(loadedNode.node, visibility)

	if hasChildCollisions then
		local childColIndexs = {}
		self:getChildCollisionNodes(loadedNode.node, childColIndexs)
		if #childColIndexs > 0 then
			loadedNode.childNodes = {}
			for childId = 1, #childColIndexs do
				local childNodes = {}
				childNodes.node = childColIndexs[childId]
				childNodes.rigidBody = getRigidBodyType(childNodes.node)
				local _, rigidBodyType = self:getTypeData(childNodes.rigidBody, nodeType)
				setRigidBodyType(childNodes.node, rigidBodyType)
				table.insert(loadedNode.childNodes, childNodes)
			end
		else
			hasChildCollisions = false
		end
	end

	table.insert(loadedNodes, loadedNode)
end

function GC_Visibility:delete()
	--self.isClient and
	if self.visNodes ~= nil then
		for _, visNodes in pairs(self.visNodes) do
			for i = 1, #visNodes.nodes do
				if visNodes.nodes[i].filename ~= nil then
					g_i3DManager:releaseSharedI3DFile(visNodes.nodes[i].filename, self.baseDirectory, true)
				end
			end
		end
	end
end

function GC_Visibility:updateNodes(state)
	--if self.isClient then
		if self.visNodes ~= nil then
            for _, visNodes in pairs(self.visNodes) do
                self:setNodes(visNodes, state)
            end
		end
	--end
end

-- IMPORTANT: Do not call this function outside this script. Use 'updateNodes' instead.
function GC_Visibility:setNodes(visNodes, state)
	local numNodes = #visNodes.nodes

	for i = 1, numNodes do
		if visNodes.nodeType == "VISIBILITY" then
            setVisibility(visNodes.nodes[i].node, state)
            setRigidBodyType(visNodes.nodes[i].node, state and visNodes.nodes[i].rigidBody or "NoRigidBody")
            if visNodes.hasChildCollisions then
                if visNodes.nodes[i].childNodes ~= nil then
                    for _, childNode in pairs (visNodes.nodes[i].childNodes) do
                        setRigidBodyType(childNode.node, state and childNode.rigidBody or "NoRigidBody")
                    end
                end
            end
		elseif visNodes.nodeType == "INVISIBILITY" then
            setVisibility(visNodes.nodes[i].node, active)
            setRigidBodyType(visNodes.nodes[i].node, state and visNodes.nodes[i].rigidBody or "NoRigidBody")
            if visNodes.hasChildCollisions then
                if visNodes.nodes[i].childNodes ~= nil then
                    for _, childNode in pairs (visNodes.nodes[i].childNodes) do
                        setRigidBodyType(childNode.node, state and childNode.rigidBody or "NoRigidBody")
                    end
                end
            end
		end
	end
end

function GC_Visibility:getTypeData(currentRBT, nodeType)
	local visibility, rigidBodyType = false, "NoRigidBody"

	if nodeType == "INVISIBILITY" then
		visibility = true
		rigidBodyType = currentRBT
	end

	return visibility, rigidBodyType
end

function GC_Visibility:getChildCollisionNodes(node, childTable)
	local childCount = getNumOfChildren(node)
	if childCount > 0 then
		for i = 0, childCount - 1 do
			local child = getChildAt(node, i)
			if getRigidBodyType(child) ~= "NoRigidBody" then
				table.insert(childTable, child)
			end

			self:getChildCollisionNodes(child, childTable)
		end
	end
end