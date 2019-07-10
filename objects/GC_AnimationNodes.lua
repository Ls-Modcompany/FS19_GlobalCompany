--
-- GlobalCompany - Objects - GC_AnimationNodes
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 03.02.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
--
-- 	v1.0.0.0 (03.02.2019):
-- 		- initial fs19 (GtX)
--
-- Notes:
--		- Client Side Only.
--		- Parent script 'MUST' call delete()
--
--		- Simple 'Animation Nodes' addon that makes use of the 'AnimationManager' of Giants but adds the option for intervals and groups.
--
-- ToDo:
--
--

GC_AnimationNodes = {}
local GC_AnimationNodes_mt = Class(GC_AnimationNodes)

GC_AnimationNodes.debugIndex = g_company.debug:registerScriptName("GC_AnimationNodes")

g_company.animationNodes = GC_AnimationNodes

function GC_AnimationNodes:new(isServer, isClient, customMt)
	local self = {}
	setmetatable(self, customMt or GC_AnimationNodes_mt)

	self.isServer = isServer
	self.isClient = isClient

	self.animationsRunning = false
	self.disableAnimationNodes = false

	self.numIntervalAnimations = 0

	return self
end

function GC_AnimationNodes:load(nodeId, target, xmlFile, xmlKey, groupKey)
	if nodeId == nil or target == nil then
		return false
	end

	self.rootNode = nodeId
	self.target = target

	self.debugData = g_company.debug:getDebugData(GC_AnimationNodes.debugIndex, target)

	local returnValue = false
	if self.isClient then
		local baseKey = Utils.getNoNil(groupKey, "animationNodeGroups")

		local i = 0
		while true do
			local key = string.format("%s.%s.animationNodes(%d)", xmlKey, baseKey, i)
			if not hasXMLProperty(xmlFile, key) then
				break
			end

			local group = {}
			group.animationNodes = g_animationManager:loadAnimations(xmlFile, key, nodeId, self, target.i3dMappings)
			if group.animationNodes ~= nil then

				-- Operating sequence must be multiplies of two. These numbers will then loop.  6 8 4 4 = on(6 sec) off(8 sec) on(4 sec) off(4 sec)
				local intervals = g_company.xmlUtils.getEvenTableFromXMLString(xmlFile, key .. "#operatingSequence", 2, true, false, 1000, self.debugData)
				if intervals ~= nil then
					-- This is the number of 'seconds' before the operation will start each time animation group is requested to start.
					local startDelay = Utils.getNoNil(getXMLInt(xmlFile, key .. "#startDelay"), 0)
					startDelay = math.max(startDelay, 0)
					local operatingTime = 0
					if startDelay > 0 then
						operatingTime = startDelay * 1000
					end

					group.intervalId = 0
					group.intervals = intervals
					group.numIntervals = #intervals
					group.intervalActive = false
					group.delayTime = operatingTime
					group.operatingTime = operatingTime

					if self.intervalAnimations == nil then
						self.intervalAnimations = {}
						returnValue = true
					end

					table.insert(self.intervalAnimations, group)
				else
					if self.standardAnimations == nil then
						self.standardAnimations = {}
						returnValue = true
					end

					table.insert(self.standardAnimations, group)
				end
			end

			i = i + 1
		end

		if self.intervalAnimations ~= nil then
			self.numIntervalAnimations = #self.intervalAnimations
			g_company.addRaisedUpdateable(self)
		end
	end

	return returnValue
end

function GC_AnimationNodes:delete()
	if self.isClient then
		g_company.removeRaisedUpdateable(self)

		if self.standardAnimations ~= nil then
			for _, group in pairs (self.standardAnimations) do
				g_animationManager:deleteAnimations(group.animationNodes)
			end

			self.standardAnimations = nil
		end

		if self.intervalAnimations ~= nil then
			for _, group in pairs (self.intervalAnimations) do
				g_animationManager:deleteAnimations(group.animationNodes)
			end

			self.intervalAnimations = nil
		end
	end
end

function GC_AnimationNodes:update(dt)
	if self.isClient then
		if self.intervalAnimations ~= nil then
			if self.animationsRunning then
				for i = 1, self.numIntervalAnimations do
					local group = self.intervalAnimations[i]
					group.operatingTime = group.operatingTime - dt
					if group.operatingTime <= 0 then
						group.intervalId = group.intervalId + 1
						if group.intervalId > group.numIntervals then
							group.intervalId = 1
						end

						group.operatingTime = group.operatingTime + group.intervals[group.intervalId]

						if group.animationNodes ~= nil then
							if group.intervalActive then
								group.intervalActive = false
								g_animationManager:stopAnimations(group.animationNodes)
							else
								group.intervalActive = true
								g_animationManager:startAnimations(group.animationNodes)
							end
						end
					end
				end
				if not self.disableAnimationNodes  then
					self.disableAnimationNodes = true
				end

				self:raiseUpdate()
			else
				if self.disableAnimationNodes then
					self.disableAnimationNodes = false
					for i = 1, self.numIntervalAnimations do
						local group = self.intervalAnimations[i]
						if group.animationNodes ~= nil then
							group.intervalActive = false
							g_animationManager:stopAnimations(group.animationNodes)
							group.operatingTime = group.delayTime
						end
					end
				end
			end
		end
	end
end

function GC_AnimationNodes:setAnimationNodesState(state, forceState)
	if self.isClient then
		local setState = Utils.getNoNil(state, not self.animationsRunning)

		if self.animationsRunning ~= setState or forceState == true then
			self.animationsRunning = setState

			if self.standardAnimations ~= nil then
				for i = 1, #self.standardAnimations do
					local group = self.standardAnimations[i]
					if group.animationNodes ~= nil then
						if self.animationsRunning then
							g_animationManager:startAnimations(group.animationNodes)
						else
							g_animationManager:stopAnimations(group.animationNodes)
						end
					end
				end
			end

			if self.intervalAnimations ~= nil then
				self:raiseUpdate()
			end
		end
	end
end

function GC_AnimationNodes:getAnimationNodesActive()
	return self.animationsRunning
end