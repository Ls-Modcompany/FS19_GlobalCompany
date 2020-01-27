--
-- GlobalCompany - Objects - GC_PlaceableDigitalDisplay
--
-- @Interface: 1.5.1.0 b6730
-- @Author: LS-Modcompany
-- @Date: 21.12.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.0.0.0 (21.12.2019):
-- 		- initial fs19 ()
--
-- Notes:
--
--
-- ToDo:
--
--

local scriptDebugInfo = g_company.debugManager:registerClass("GC_PlaceableDigitalDisplay")

GC_PlaceableDigitalDisplay = {}
GC_PlaceableDigitalDisplay._mt = Class(GC_PlaceableDigitalDisplay, g_company.gc_class)
InitObjectClass(GC_PlaceableDigitalDisplay, "GC_PlaceableDigitalDisplay")

getfenv(0)["GC_PlaceableDigitalDisplay"] = GC_PlaceableDigitalDisplay

function GC_PlaceableDigitalDisplay:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	return GC_PlaceableDigitalDisplay:superClass():new(GC_PlaceableDigitalDisplay._mt, isServer, isClient, scriptDebugInfo, xmlFilename, baseDirectory, customEnvironment, "GC_PlaceableDigitalDisplay");
end

function GC_PlaceableDigitalDisplay:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	GC_PlaceableDigitalDisplay:superClass().load(self)

	self.rootNode = nodeId
	self.indexName = indexName
	self.isPlaceable = isPlaceable

	self.triggerManager = GC_TriggerManager:new(self)
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings")

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId")
	if self.saveId == nil then
		self.saveId = "ProductionFactory_" .. indexName
	end

	self.lines = {}
	self.lenghts = {}
	self.lineNums = 0
	while true do
		local lineKey = string.format("%s.lines.line(%d)", xmlKey, self.lineNums)
		if not hasXMLProperty(xmlFile, lineKey) then
			break
		end
		self.lineNums = self.lineNums + 1

		local nodeStr = getXMLString(xmlFile, lineKey .. "#node")
		local lenght = getXMLFloat(xmlFile, lineKey .. "#lenght")
		if nodeStr ~= nil and nodeStr ~= "" then
			local node = I3DUtil.indexToObject(self.rootNode, nodeStr, self.i3dMappings)
			self.lines[self.lineNums] = node
			self.lenghts[self.lineNums] = lenght
		end
	end	
	
	self.playerTrigger = self.triggerManager:addTrigger(GC_PlayerTrigger, self.rootNode, self , xmlFile, string.format("%s.playerTrigger", xmlKey), nil, true, g_company.languageManager:getText("GC_placeableDigDisplay_openGui"))
			
	self.screenTexts = {}

	g_company.addRaisedUpdateable(self)

	return true
end

function GC_PlaceableDigitalDisplay:finalizePlacement()
	GC_PlaceableDigitalDisplay:superClass().finalizePlacement(self)	
	self.eventId_setSceenText = self:registerEvent(self, self.setScreenTextEvent, true, false);
end

function GC_PlaceableDigitalDisplay:delete()
	if self.triggerManager ~= nil then
		self.triggerManager:removeAllTriggers()
	end
	g_company.removeRaisedUpdateable(self)

	GC_PlaceableDigitalDisplay:superClass().delete(self)
end

function GC_PlaceableDigitalDisplay:readStream(streamId, connection)
	GC_PlaceableDigitalDisplay:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:readStream(streamId, connection)
		end

		local n = streamReadInt8(streamId)
		for j=1, n do
			local i = streamReadInt8(streamId)
			local text = streamReadString(streamId)
			self.screenTexts[i] = text
		end
	end
end

function GC_PlaceableDigitalDisplay:writeStream(streamId, connection)
	GC_PlaceableDigitalDisplay:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:writeStream(streamId, connection)
		end

		streamWriteInt8(streamId, table.getn(self.screenTexts))
		for i, text in pairs(self.screenTexts) do
			streamWriteInt8(streamId, i)
			streamWriteString(streamId, text)
		end
		self:raiseUpdate()
	end
end

function GC_PlaceableDigitalDisplay:readUpdateStream(streamId, timestamp, connection)
	GC_PlaceableDigitalDisplay:superClass().readUpdateStream(self, streamId, timestamp, connection)
end

function GC_PlaceableDigitalDisplay:writeUpdateStream(streamId, connection, dirtyMask)
	GC_PlaceableDigitalDisplay:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
end

function GC_PlaceableDigitalDisplay:loadFromXMLFile(xmlFile, key)
	GC_PlaceableDigitalDisplay:superClass().loadFromXMLFile(self, xmlFile, key)
	local j = 0
	while true do 
		local lineKey = string.format("%s.lines.line(%d)", key, j)
		if not hasXMLProperty(xmlFile, lineKey) then
			break
		end

		local i = getXMLInt(xmlFile, lineKey .. "#num")
		local text = getXMLString(xmlFile, lineKey .. "#text")
		self.screenTexts[i] = text

		j = j + 1
	end

	return true
end

function GC_PlaceableDigitalDisplay:saveToXMLFile(xmlFile, key, usedModNames)	
	GC_PlaceableDigitalDisplay:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)
	local j = 0
	for i, text in pairs(self.screenTexts) do
		if text ~= nil and text ~= "" then
			setXMLInt(xmlFile, string.format("%s.lines.line(%d)#num", key, j), i)
			setXMLString(xmlFile, string.format("%s.lines.line(%d)#text", key, j), text)
			j = j + 1
		end
	end
end

function GC_PlaceableDigitalDisplay:update(dt)
	GC_PlaceableDigitalDisplay:superClass().update(self, dt)
	for i, node in pairs(self.lines) do
		if self.screenTexts[i] ~= nil and self.screenTexts[i] ~= "" then
			local x, y, z = getWorldTranslation(node)
			local rx, ry, rz = getWorldRotation(node)
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextColor(0, 1, 0, 1)

			local text = self.screenTexts[i]
			if self.lenghts[i] ~= nil then
				text = g_company.utils.limitTextToWidth(text, 0.2, self.lenghts[i], false, "..")
			end
			
			renderText3D(x,y,z, rx,ry,rz, 0.2, text)
			
			self:raiseUpdate()
		end
	end
end

function GC_PlaceableDigitalDisplay:playerTriggerCanAddActivatable()
    return true
end

function GC_PlaceableDigitalDisplay:playerTriggerActivated()
    g_company.gui:openGuiWithData("gc_placeableDigitalDisplay", false, self)
end

function GC_PlaceableDigitalDisplay:setScreenTexts(texts, onlyChanges)
	local synchText = {}
	if onlyChanges then
		for i=1, self.lineNums do
			if texts[i] ~= self.screenTexts[i] then
				synchText[i] = texts[i]
			end
		end	
	else
		synchText = texts
	end
	self:setScreenTextEvent(synchText);
end

function GC_PlaceableDigitalDisplay:setScreenTextEvent(data, noEventSend)
	self:raiseEvent(self.eventId_setSceenText, data, noEventSend)

	for i, text in pairs(data) do
		self.screenTexts[i] = text
	end	
	if self.isClient then
		self:raiseUpdate()
	end
end