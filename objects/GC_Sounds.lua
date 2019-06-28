--
-- GlobalCompany - Objects - GC_Sounds
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 06.02.2019
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.1.0 (06.02.2019):
-- 		- change to 'raiseUpdate'
--
-- 	v1.1.0.0 (28.01.2019):
-- 		- convert to fs19
--
-- 	v1.0.0.0 (26.05.2018):
-- 		- initial fs17 (GtX)
--
-- Notes:
--		- Client Side Only.
--		- Parent script 'MUST' call delete()
--
--
-- ToDo:
--
--

GC_Sounds = {}
local GC_Sounds_mt = Class(GC_Sounds)

GC_Sounds.debugIndex = g_company.debug:registerScriptName("GC_Sounds")

g_company.sounds = GC_Sounds

function GC_Sounds:new(isServer, isClient, customMt)
	local self = {}
	setmetatable(self, customMt or GC_Sounds_mt)

	self.isServer = isServer
	self.isClient = isClient

	self.soundsRunning = false
	self.disableSoundEffects = false
	
	self.numIntervalSounds = 0

	return self
end

function GC_Sounds:load(nodeId, target, xmlFile, xmlKey, baseDirectory)
	if nodeId == nil or target == nil then
		return false
	end

	self.debugData = g_company.debug:getDebugData(GC_Sounds.debugIndex, target)

	self.rootNode = nodeId
	self.target = target

	self.baseDirectory = GlobalCompanyUtils.getParentBaseDirectory(target, baseDirectory)

	local returnValue = false
	if self.isClient then
		if hasXMLProperty(xmlFile, xmlKey .. ".sounds") then
			local i = 0
			while true do
				local key = string.format("%s.sounds.sound(%d)", xmlKey, i)
				if not hasXMLProperty(xmlFile, key) then
					break
				end

				local sound = {}

				local soundNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#geSoundNode"), self.target.i3dMappings)
				if soundNode ~= nil then
					-- Only use if 'soundNode' has a valid 'AUDIO_SOURCE' ClassId.
					if getHasClassId(soundNode, ClassIds.AUDIO_SOURCE) then
						sound.node = soundNode
						setVisibility(soundNode, false)
					else
						g_company.debug:writeModding(self.debugData, "'geSoundNode' at '%s' (%s) is not a valid AUDIO_SOURCE!", key, getName(soundNode))
					end
				else
					sound.sample = g_soundManager:loadSampleFromXML(xmlFile, key, "sample", self.baseDirectory, self.rootNode, 0, AudioGroup.ENVIRONMENT, self.target.i3dMappings, self)
				end

				if sound.sample ~= nil or sound.node ~= nil then
					-- Operating sequence must be multiplies of two. These numbers will then loop.  6 8 4 4 = on(6 sec) off(8 sec) on(4 sec) off(4 sec)
					local intervals = g_company.xmlUtils.getEvenTableFromXMLString(xmlFile, key .. "#operatingSequence", 2, true, false, 1000, self.debugData)
					if intervals ~= nil then
						-- This is the number of 'seconds' before the operation will start each time sound is requested to start.
						local startDelay = Utils.getNoNil(getXMLInt(xmlFile, key .. "#startDelay"), 0)
						startDelay = math.max(startDelay, 0)
						local operatingTime = 0
						if startDelay > 0 then
							operatingTime = startDelay * 1000
						end

						sound.intervalId = 0
						sound.intervals = intervals
						sound.numIntervals = #intervals
						sound.intervalActive = false
						sound.delayTime = operatingTime
						sound.operatingTime = operatingTime

						if self.intervalSounds == nil then
							self.intervalSounds = {}
							returnValue = true
						end

						table.insert(self.intervalSounds, sound)						
					else
						if self.standardSounds == nil then
							self.standardSounds = {}
							returnValue = true
						end

						table.insert(self.standardSounds, sound)
					end

					sound = nil
				end
				i = i + 1
			end
		end

		if hasXMLProperty(xmlFile, xmlKey .. ".operateSounds") then
			local key = xmlKey .. ".operateSounds"

			self.operateSamples = {}
			self.operateSamples.start = g_soundManager:loadSampleFromXML(xmlFile, key, "start", self.baseDirectory, self.rootNode, 1, AudioGroup.ENVIRONMENT, self.target.i3dMappings, self)
			self.operateSamples.run = g_soundManager:loadSampleFromXML(xmlFile, key, "run", self.baseDirectory, self.rootNode, 0, AudioGroup.ENVIRONMENT, self.target.i3dMappings, self)
			self.operateSamples.stop = g_soundManager:loadSampleFromXML(xmlFile, key, "stop", self.baseDirectory, self.rootNode, 1, AudioGroup.ENVIRONMENT, self.target.i3dMappings, self)

			returnValue = true
		end

		if self.intervalSounds ~= nil then
			self.numIntervalSounds = #self.intervalSounds
			g_company.addRaisedUpdateable(self)
		end
	end

	return returnValue
end

function GC_Sounds:delete()
	if self.isClient then
		if self.operateSamples ~= nil then
			g_soundManager:deleteSamples(self.operateSamples)
			self.operateSamples = nil
		end

		if self.intervalSounds ~= nil then
			for i = 1, self.numIntervalSounds do
				if self.intervalSounds[i].sample ~= nil then
					g_soundManager:deleteSample(self.intervalSounds[i].sample)
				end
			end
			self.intervalSounds = nil

			g_company.removeRaisedUpdateable(self)
		end

		if self.standardSounds ~= nil then
			for i = 1, #self.standardSounds do
				if self.standardSounds[i].sample ~= nil then
					g_soundManager:deleteSample(self.standardSounds[i].sample)
				end
			end
			self.standardSounds = nil
		end
	end
end

function GC_Sounds:update(dt)
	if self.isClient then
		if self.intervalSounds ~= nil then
			if self.soundsRunning then
				for i = 1, self.numIntervalSounds do
					local sound = self.intervalSounds[i]
					sound.operatingTime = sound.operatingTime - dt
					if sound.operatingTime <= 0 then
						sound.intervalId = sound.intervalId + 1
						if sound.intervalId > sound.numIntervals then
							sound.intervalId = 1
						end

						sound.operatingTime = sound.operatingTime + sound.intervals[sound.intervalId]
						
						if sound.sample ~= nil then
							if sound.intervalActive then
								sound.intervalActive = false
								g_soundManager:stopSample(sound.sample)
							else
								sound.intervalActive = true
								g_soundManager:playSample(sound.sample)
							end
						elseif sound.node ~= nil then
							if sound.intervalActive then
								sound.intervalActive = false
								setVisibility(sound.node, false)
							else
								sound.intervalActive = true
								setVisibility(sound.node, true)
							end
						end
					end
				end
				if not self.disableSoundEffects  then
					self.disableSoundEffects = true
				end

				self:raiseUpdate()
			else
				if self.disableSoundEffects then
					self.disableSoundEffects = false
					for i = 1, self.numIntervalSounds do
						local sound = self.intervalSounds[i]
						if sound.sample ~= nil then
							sound.intervalActive = false
							g_soundManager:stopSample(sound.sample)
							sound.operatingTime = sound.delayTime
						elseif sound.node ~= nil then
							sound.intervalActive = false
							setVisibility(sound.node, false)
							sound.operatingTime = sound.delayTime
							sound.intervalId = 0
						end
					end
				end
			end
		end
	end
end

function GC_Sounds:setSoundsState(state, forceState)
	if self.isClient then
		local setState = Utils.getNoNil(state, not self.soundsRunning)

		if self.soundsRunning ~= setState or forceState == true then
			self.soundsRunning = setState

			if self.operateSamples ~= nil then
				if self.soundsRunning then
					g_soundManager:stopSample(self.operateSamples.stop)
					g_soundManager:playSample(self.operateSamples.start)
					g_soundManager:playSample(self.operateSamples.run, 0, self.operateSamples.start)
				else
					g_soundManager:stopSample(self.operateSamples.start)
					g_soundManager:stopSample(self.operateSamples.run)
					g_soundManager:playSample(self.operateSamples.stop)
				end
			end

			if self.standardSounds ~= nil then
				for i = 1, #self.standardSounds do
					local sound = self.standardSounds[i]
					if sound.sample ~= nil then
						if self.soundsRunning then
							g_soundManager:playSample(sound.sample)
						else
							g_soundManager:stopSample(sound.sample)
						end
					elseif sound.node ~= nil then
						setVisibility(sound.node, self.soundsRunning)
					end
				end
			end

			if self.intervalSounds ~= nil then
				self:raiseUpdate()
			end
		end
	end
end

function GC_Sounds:getSoundsActive()
	return self.soundsRunning
end