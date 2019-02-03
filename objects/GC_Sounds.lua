--
-- GlobalCompany - Objects - GC_Sounds
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 28.01.2019
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
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

GC_Sounds = {};

local GC_Sounds_mt = Class(GC_Sounds, Object);
InitObjectClass(GC_Sounds, "GC_Sounds");

GC_Sounds.debugIndex = g_company.debug:registerScriptName("Sounds");

g_company.sounds = GC_Sounds;

function GC_Sounds:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_Sounds_mt;
	end;

	local self = Object:new(isServer, isClient, customMt);

	self.soundsRunning = false;
	self.disableSoundEffects = false;

	return self;
end;

function GC_Sounds:load(nodeId, target, xmlFile, xmlKey, path)
	if nodeId == nil or target == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' paramater = %s, 'target' paramater = %s 'xmlFile' paramater = %s, 'xmlKey' paramater = %s";
		g_company.debug:logWrite(GC_Sounds.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, target ~= nil, xmlFile ~= nil, xmlKey ~= nil);
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_Sounds.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;

	local filePath = g_currentMission.baseDirectory;
	if self.target.baseDirectory ~= nil and self.target.baseDirectory ~= "" then
		filePath = self.target.baseDirectory;
	end;
	if path ~= nil and path ~= "" then
		filePath = path;
	end;

	if self.isClient then
		if hasXMLProperty(xmlFile, xmlKey .. ".sounds") then
			local i = 0;
			while true do
				local key = string.format("%s.sounds.sound(%d)", xmlKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;

				local sound = {};

				local soundNode = I3DUtil.indexToObject(self.rootNode, getXMLString(xmlFile, key .. "#geSoundNode"), self.target.i3dMappings);
				if soundNode ~= nil then
					sound.node = soundNode;
					setVisibility(soundNode, false); -- Use sound source already in GE.
				else
					sound.sample = g_soundManager:loadSampleFromXML(xmlFile, key, "sample", filePath, self.rootNode, 0, AudioGroup.ENVIRONMENT, self.target.i3dMappings, self);
				end;

				if sound.sample ~= nil or sound.node ~= nil then
					local operatingInterval = Utils.getNoNil(getXMLFloat(xmlFile, key.."#operatingIntervalSeconds"), 0);
					if operatingInterval > 0 then
						local stoppedInterval = Utils.getNoNil(getXMLFloat(xmlFile, key.."#stoppedIntervalSeconds"), operatingInterval);
						local delayStart = Utils.getNoNil(getXMLBool(xmlFile, key.."#delayedStart"), false);
						local operatingTime = 0;
						if delayStart then
							operatingTime = stoppedInterval * 1000;
						end;

						sound.active = false;
						sound.delayTime = operatingTime;
						sound.operatingInterval = operatingInterval * 1000;
						sound.stoppedInterval = stoppedInterval * 1000;
						sound.interval = operatingTime;
						sound.operatingTime = operatingTime;

						if self.intervalSounds == nil then
							self.intervalSounds = {};
						end;

						table.insert(self.intervalSounds, sound);
					else
						if self.standardSounds == nil then
							self.standardSounds = {};
						end;

						table.insert(self.standardSounds, sound);
					end;
				end;
				i = i + 1;
			end;
		end;

		if hasXMLProperty(xmlFile, xmlKey .. ".operateSounds") then
			local key = xmlKey .. ".operateSounds";

			self.operateSamples = {};
			self.operateSamples.start = g_soundManager:loadSampleFromXML(xmlFile, key, "start", filePath, self.rootNode, 1, AudioGroup.ENVIRONMENT, self.target.i3dMappings, self);
			self.operateSamples.run = g_soundManager:loadSampleFromXML(xmlFile, key, "run", filePath, self.rootNode, 0, AudioGroup.ENVIRONMENT, self.target.i3dMappings, self);
			self.operateSamples.stop = g_soundManager:loadSampleFromXML(xmlFile, key, "stop", filePath, self.rootNode, 1, AudioGroup.ENVIRONMENT, self.target.i3dMappings, self);
		end;
	end;

	if self.intervalSounds ~= nil then
		self:register(true);
	end;

	return true;
end;

function GC_Sounds:delete()
	if self.isRegistered then
		self:unregister(true);
	end;

	if self.isClient then
		if self.operateSamples ~= nil then
			g_soundManager:deleteSamples(self.operateSamples);
		end;

		if self.intervalSounds ~= nil then
			for i = 1, #self.intervalSounds do
				if self.intervalSounds[i].sample ~= nil then
					g_soundManager:deleteSample(self.intervalSounds[i].sample);
				end;
			end;
		end;

		if self.standardSounds ~= nil then
			for i = 1, #self.standardSounds do
				if self.standardSounds[i].sample ~= nil then
					g_soundManager:deleteSample(self.standardSounds[i].sample);
				end;
			end;
		end;
	end;
end;

function GC_Sounds:update(dt)
	if self.isClient then
		if self.intervalSounds ~= nil then
			if self.soundsRunning then
				for _, sound in pairs (self.intervalSounds) do
					sound.operatingTime = sound.operatingTime - dt;
					if sound.operatingTime <= 0 then
						if sound.sample ~= nil then
							if sound.active then
								sound.active = false;
								g_soundManager:stopSample(sound.sample);
								sound.interval = sound.stoppedInterval;
							else
								sound.active = true;
								g_soundManager:playSample(sound.sample);
								sound.interval = sound.operatingInterval;
							end;
						elseif sound.node ~= nil then
							if sound.active then
								sound.active = false;
								setVisibility(sound.node, false);
								sound.interval = sound.stoppedInterval;
							else
								sound.active = true;
								setVisibility(sound.node, true);
								sound.interval = sound.operatingInterval;
							end;
						end;
						sound.operatingTime = sound.operatingTime + sound.interval;
					end;
				end;
				if not self.disableSoundEffects  then
					self.disableSoundEffects = true;
				end;

				self:raiseActive();
			else
				if self.disableSoundEffects then
					self.disableSoundEffects = false;
					for _, sound in pairs (self.intervalSounds) do
						if sound.sample ~= nil then
							sound.active = false;
							g_soundManager:stopSample(sound.sample);
							sound.operatingTime = sound.delayTime;
						elseif sound.node ~= nil then
							sound.active = false;
							setVisibility(sound.node, false);
							sound.operatingTime = sound.delayTime;
						end;
					end;
				end;
			end;
		end;
	end;
end;

function GC_Sounds:setSoundsState(forceActive)
	if self.isClient then
		if forceActive ~= nil then
			self.soundsRunning = forceActive;
		else
			self.soundsRunning = not self.soundsRunning;
		end;

		if self.operateSamples ~= nil then
			if self.soundsRunning then
				g_soundManager:stopSample(self.operateSamples.stop);
				g_soundManager:playSample(self.operateSamples.start);
				g_soundManager:playSample(self.operateSamples.run, 0, self.operateSamples.start);
			else
				g_soundManager:stopSample(self.operateSamples.start);
				g_soundManager:stopSample(self.operateSamples.run);
				g_soundManager:playSample(self.operateSamples.stop);
			end;
		end;

		if self.standardSounds ~= nil then
			for i = 1, #self.standardSounds do
				if self.standardSounds[i].sample ~= nil then
					if self.soundsRunning then
						g_soundManager:playSample(self.standardSounds[i].sample);
					else
						g_soundManager:stopSample(self.standardSounds[i].sample);
					end;
				elseif self.standardSounds[i].node ~= nil then
					setVisibility(self.standardSounds[i].node, self.soundsRunning);
				end;
			end;
		end;

		if self.intervalSounds ~= nil then
			self:raiseActive();
		end;
	else
		g_company.debug:writeDev(self.debugData, "'setSoundsState' is a client only function!");
	end;
end;

function GC_Sounds:getSoundsActive()
	return self.soundsRunning;
end;





