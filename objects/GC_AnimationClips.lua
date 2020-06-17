--
-- GlobalCompany - Objects - GC_AnimationClips
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 03.04.2019
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
--
-- 	v1.1.0.0 (03.04.2019):
-- 		- convert to fs19
--		- add interval option
--
-- 	v1.0.0.0 (22.04.2018):
-- 		- initial fs17 ()
--
-- Notes:
--
--		- Client Side Only.
--		- Parent script 'MUST' call delete().
--
-- ToDo:
--
--

GC_AnimationClips = {}
local GC_AnimationClips_mt = Class(GC_AnimationClips)

GC_AnimationClips.debugIndex = g_company.debug:registerScriptName("GC_AnimationClips")

g_company.animationClips = GC_AnimationClips

function GC_AnimationClips:new(isServer, isClient, customMt)
	local self = {}
	setmetatable(self, customMt or GC_AnimationClips_mt)

	self.isServer = isServer
	self.isClient = isClient

	self.standardAnimationClips = nil
	self.intervalAnimationClips = nil

	self.animationClipsActive = false
	self.disableAnimationClips = false

	return self
end

function GC_AnimationClips:load(nodeId, target, xmlFile, xmlKey, runOnServer)
	if nodeId == nil or target == nil then
		return false
	end

	self.rootNode = nodeId
	self.target = target

	self.runOnServer = runOnServer or false

	self.debugData = g_company.debug:getDebugData(GC_AnimationClips.debugIndex, target)

	local returnValue = false
	if self.isClient or runOnServer then
		local i = 0
		while true do
			local key = string.format("%s.animationClips.animationClip(%d)", xmlKey, i)
			if not hasXMLProperty(xmlFile, key) then
				break
			end

			local node = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#node"), self.target.i3dMappings)
			if node ~= nil then
				local clipName = getXMLString(xmlFile, key .. "#name")
				if clipName then
					local animCharSet = getAnimCharacterSet(node)
					local clip = getAnimClipIndex(animCharSet, clipName)
					if clip ~= nil then
						local entry = {}
						entry.clipIndex = clip
						entry.animCharSet = animCharSet
						entry.animDuration = getAnimClipDuration(animCharSet, clip)
						entry.startTime = 0.0

						-- Custom animationClip start time.
						local startTime = getXMLFloat(xmlFile, key .. "#startTime")
						if startTime ~= nil and startTime > 0.0 then
							entry.startTime = math.min(startTime, entry.animDuration)
						end

						-- Speed scale animation will run at.
						entry.animationSpeedScale = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#animSpeedScale"), 1)

						-- Allow animation looping and extra options.
						entry.animTrackLoop = Utils.getNoNil(getXMLBool(xmlFile, key .. "#animTrackLoop"), true)
						if entry.animTrackLoop then
							entry.resetTrackOnStop = Utils.getNoNil(getXMLBool(xmlFile, key .. "#resetOnStop"), true)
							entry.randomStartTime = Utils.getNoNil(getXMLBool(xmlFile, key .. "#randomStartTime"), false)
						end

						-- Hide then animation node or given node (nodeToHide) when animationClip is 'OFF'.
						entry.hideWhenOff = Utils.getNoNil(getXMLBool(xmlFile, key .. "#hideWhenOff"), false)
						if entry.hideWhenOff then
							local nodeToHide = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#nodeToHide"), self.target.i3dMappings)
							entry.hideNode = Utils.getNoNil(nodeToHide, node)
							setVisibility(entry.hideNode , false)
						end

						entry.enabled = false
						assignAnimTrackClip(entry.animCharSet, 0, entry.clipIndex)
						setAnimTrackLoopState(entry.animCharSet, 0, entry.animTrackLoop)
						setAnimTrackSpeedScale(entry.animCharSet, 0, entry.animationSpeedScale)

						-- Operating sequence must be multiplies of two. These numbers will then loop.  6 8 4 4 = on(6 sec) off(8 sec) on(4 sec) off(4 sec)
						local intervals = g_company.xmlUtils.getEvenTableFromXMLString(xmlFile, key .. "#operatingSequence", 2, true, false, 1000, self.debugData)
						if intervals ~= nil then
							-- This is the number of 'seconds' before the operation will start each time animation is requested to start.
							local startDelay = Utils.getNoNil(getXMLInt(xmlFile, key .. "#startDelay"), 0)
							startDelay = math.max(startDelay, 0)
							local operatingTime = 0
							if startDelay > 0 then
								operatingTime = startDelay * 1000
							end

							entry.intervalId = 0
							entry.intervals = intervals
							entry.numIntervals = #intervals
							entry.intervalActive = false
							entry.delayTime = operatingTime
							entry.operatingTime = operatingTime

							if self.intervalAnimationClips == nil then
								self.intervalAnimationClips = {}
								returnValue = true
							end

							table.insert(self.intervalAnimationClips, entry)
						else
							if self.standardAnimationClips == nil then
								self.standardAnimationClips = {}
								returnValue = true
							end

							table.insert(self.standardAnimationClips, entry)
						end
					else
						g_company.debug:writeModding(self.debugData, "Animation Clip '%s' does not exist on node '%s' at %s", clipName, getName(node), key)
					end
				end
			end

			i = i + 1
		end

		if self.intervalAnimationClips ~= nil then
			g_company.addRaisedUpdateable(self)
		end

		self:setAnimationClipsState(false, true)
	end

	return returnValue
end

function GC_AnimationClips:delete()
	if self.isClient or runOnServer then
		if self.intervalAnimationClips ~= nil then
			g_company.removeRaisedUpdateable(self)
		end
	end
end

function GC_AnimationClips:update(dt)
	if self.isClient or runOnServer then
		if self.intervalAnimationClips ~= nil then
			if self.animationClipsActive then
				for i = 1, #self.intervalAnimationClips do
					local entry = self.intervalAnimationClips[i]
					entry.operatingTime = entry.operatingTime - dt
					if entry.operatingTime <= 0 then
						entry.intervalId = entry.intervalId + 1
						if entry.intervalId > entry.numIntervals then
							entry.intervalId = 1
						end

						entry.operatingTime = entry.operatingTime + entry.intervals[entry.intervalId]

						if entry.intervalActive then
							entry.intervalActive = false
							GC_AnimationClips.updateAnimationClip(entry, false)
						else
							entry.intervalActive = true
							GC_AnimationClips.updateAnimationClip(entry, true)
						end
					end
				end

				if not self.disableAnimationClips then
					self.disableAnimationClips = true
				end

				self:raiseUpdate()
			else
				if self.disableAnimationClips then
					self.disableAnimationClips = false
					for i = 1, #self.intervalAnimationClips do
						local entry = self.intervalAnimationClips[i]
						if entry.intervalActive then
							entry.intervalActive = false
							GC_AnimationClips.updateAnimationClip(entry, false)
							entry.operatingTime = entry.delayTime
							entry.intervalId = 0
						end
					end
				end
			end
		end
	end
end

function GC_AnimationClips:setAnimationClipsState(state, forceState)
	if self.isClient or runOnServer then
		local setState = Utils.getNoNil(state, not self.animationClipsActive)

		if self.animationClipsActive ~= setState or forceState == true then
			self.animationClipsActive = setState

			if self.standardAnimationClips ~= nil then
				for i = 1, #self.standardAnimationClips do
					local entry = self.standardAnimationClips[i]
					GC_AnimationClips.updateAnimationClip(entry, self.animationClipsActive)
				end
			end

			if self.intervalAnimationClips ~= nil then
				self:raiseUpdate()
			end
		end
	end
end

function GC_AnimationClips.updateAnimationClip(entry, isActive)
	if entry.hideWhenOff and entry.hideNode ~= nil then
		setVisibility(entry.hideNode, isActive)
	end

	if isActive then
		if entry.animTrackLoop then
			if not entry.enabled then
				entry.enabled = true
				enableAnimTrack(entry.animCharSet, 0)
				if entry.randomStartTime then
					setAnimTrackTime(entry.animCharSet, 0, math.random(0.0, entry.duration))
				end
			end
		else
			if not entry.enabled then
				entry.enabled = true
				enableAnimTrack(entry.animCharSet, 0)
				setAnimTrackTime(entry.animCharSet, 0, entry.startTime)
				setAnimTrackSpeedScale(entry.animCharSet, 0, entry.animationSpeedScale)
			end
		end
	else
		if entry.animTrackLoop then
			if entry.enabled then
				entry.enabled = false
				if entry.resetTrackOnStop then
					setAnimTrackTime(entry.animCharSet, 0, entry.startTime, true)
				end
				disableAnimTrack(entry.animCharSet, 0)
			end
		else
			if entry.enabled then
				entry.enabled = false
				local animTrackTime = getAnimTrackTime(entry.animCharSet, 0)
				enableAnimTrack(entry.animCharSet, 0)
				setAnimTrackTime(entry.animCharSet, 0, animTrackTime)
				setAnimTrackSpeedScale(entry.animCharSet, 0, -entry.animationSpeedScale)
			end
		end
	end
end

function GC_AnimationClips:getAnimationClipActive()
	return self.animationClipsActive
end

function GC_AnimationClips:resetClipByIndex(index)
	local entry = self.standardAnimationClips[index]
	setAnimTrackTime(entry.animCharSet, 0, entry.startTime)
	disableAnimTrack(entry.animCharSet, 0)
end

function GC_AnimationClips:setTimeByIndex(index, time)
	local entry = self.standardAnimationClips[index]
	entry.enabled = true
	enableAnimTrack(entry.animCharSet, 0)
	setAnimTrackTime(entry.animCharSet, 0, time)
	self.animationClipsActive = true
end