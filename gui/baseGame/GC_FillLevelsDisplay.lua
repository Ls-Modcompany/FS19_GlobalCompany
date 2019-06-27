--
-- GlobalCompany - BaseGui - GC_FillLevelsDisplay
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / GtX
-- @Date: 21.05.2018
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
--
-- 	v1.0.0.0 (21.05.2018):
-- 		- initial fs19 (GtX)
--
--
-- Notes:
--		- Concept and functions parts referenced from 'FillLevelsDisplay.lua'
--		- https://gdn.giants-software.com/documentation_scripting_fs19.php?version=engine&category=97&class=10207
--
--
-- ToDo:
--
--

GC_FillLevelsDisplay = {}
local GC_FillLevelsDisplay_mt = Class(GC_FillLevelsDisplay, HUDDisplayElement)

GC_FillLevelsDisplay.debugIndex = g_company.debug:registerScriptName("GC_FillLevelsDisplay")

GC_FillLevelsDisplay.MAX_LIST_COUNT = 10

GC_FillLevelsDisplay.COLOR = {
   BAR_BACKGROUND = {1,1,1,0.2},
   FILL_LEVEL_TEXT = {1,1,1,1},
   BAR_FILLED = {0.991,0.3865,0.01,1}
}

GC_FillLevelsDisplay.POSITION = {
   FILL_TYPE_FRAME = {0, 0},
   FILL_TYPE_TEXT = {44, 14},
   BACKGROUND = {60, -30},
   FILL_LEVEL_TEXT = {20, 52},
   HEADER_TEXT = {0, -26},
   MAIN_TITLE = {0, 10},
   BAR = {20, 34}
}

GC_FillLevelsDisplay.SIZE = {
   MAIN_TITLE = 30,
   BACKGROUND = {220, 1000},
   HORIZONTAL_SEPARATOR = {440, 1},
   VERTICAL_SEPARATOR = {1, 82},
   BAR = {180, 10},
   FILL_TYPE_FRAME = {180, 80}
}

local function clearTable(table)
    for k in pairs(table) do
        table[k] = nil
    end
end

function GC_FillLevelsDisplay.new(hudAtlasPath)
	local backgroundOverlay = GC_FillLevelsDisplay.createBackground()
	local self = GC_FillLevelsDisplay:superClass().new(GC_FillLevelsDisplay_mt, backgroundOverlay, nil)

	self.debugData = g_company.debug:getDebugData(GC_FillLevelsDisplay.debugIndex)

	self.uiScale = 1.0
	self.hudAtlasPath = hudAtlasPath

	self.object = nil
	self.debugActive = false -- Testing for GtX

	self.rightListItemFrames = {}
	self.leftListItemFrames = {}

	self.rightListLevelBars = {}
	self.leftListLevelBars = {}

	self.frameHeight = 0
	self.hasLeftList = true

	self.fillLevelTextSize = 0
	self.fillLevelTextOffsetX = 0
	self.fillLevelTextOffsetY = 0

	self.headerTextSize = 0
	self.headerTextOffsetX = 0
	self.headerTextOffsetY = 0

	self.fillTypeTextOffsetX = 0
	self.fillTypeTextOffsetY = 0

	self.rightFillLevelBuffer = {}
	self.rightFillLevelTextBuffer = {}
	self.rightFillTypeTextBuffer = {}

	self.leftFillLevelBuffer = {}
	self.leftFillLevelTextBuffer = {}
	self.leftFillTypeTextBuffer = {}

	self.leftText = ""
	self.rightText = ""
	self.mainHeaderText = ""

	self:storeOriginalPosition()
	self:storeScaledValues()

	self.backupTexts = {}
	self.backupTexts.right = g_company.languageManager:getText("GC_Input_Header_Backup", nil, "Inputs")
	self.backupTexts.left = g_company.languageManager:getText("GC_Output_Header_Backup", nil, "Outputs")

	self:createComponents(self.hudAtlasPath, inputDisplayManager)

	return self
end

function GC_FillLevelsDisplay:setObject(object, mainHeaderText, rightText, leftText)
	if object ~= self.object then
		self.object = object

		self.mainHeaderText = Utils.getNoNil(mainHeaderText, "")
		self.rightText = Utils.getNoNil(rightText, self.backupTexts.right)
		self.leftText = Utils.getNoNil(leftText, self.backupTexts.left)

		if self.debugActive then
			if self.object ~= nil then
				g_company.debug:writeDev(self.debugData, "New object %s has been set.", object)
			else
				g_company.debug:writeDev(self.debugData, "Object %s has been removed. Object is now nil!", object)
			end
		end
	end

	self.hasLeftList = true
end

function GC_FillLevelsDisplay:removeCurrentObject(object, force)
	if self.object ~= nil then
		if self.object == object or force == true then
			self.object = nil

			if self:getVisible() then
				self:setVisible(false, false)
			end

			if self.debugActive then
				if force then
					g_company.debug:writeDev(self.debugData, "Force removing any active object.")
				else
					g_company.debug:writeDev(self.debugData, "Removing object %s.", object)
				end
			end
		end
	end
end

function GC_FillLevelsDisplay.createBackground()
	local width, height = getNormalizedScreenValues(unpack(GC_FillLevelsDisplay.SIZE.BACKGROUND))
	local posX, posY = GC_FillLevelsDisplay.getBackgroundPosition(1, width)

	return Overlay:new(nil, posX, posY, width, height)
end

function GC_FillLevelsDisplay.getBackgroundPosition(scale, width)
	local offX, offY = getNormalizedScreenValues(unpack(GC_FillLevelsDisplay.POSITION.BACKGROUND))
	return 1 - g_safeFrameOffsetX - width - offX * scale, g_safeFrameOffsetY - offY * scale
end

function GC_FillLevelsDisplay:createComponents(hudAtlasPath, inputDisplayManager)
	local baseX, baseY = self:getPosition()
	local width, height = self:getWidth(), self:getHeight()

	self.mainFrame = self:createFrame(hudAtlasPath, baseX - width, baseY, width * 2, height)

	for i = 1, GC_FillLevelsDisplay.MAX_LIST_COUNT do
		local frame = self:createFillTypeFrame(hudAtlasPath, baseX, baseY, false)
		self.rightListItemFrames[i] = frame
		frame:setScale(self.uiScale, self.uiScale)
		self:addChild(frame)
	end

	for i = 1, GC_FillLevelsDisplay.MAX_LIST_COUNT do
		local frame = self:createFillTypeFrame(hudAtlasPath, baseX - width, baseY, true)
		self.leftListItemFrames[i] = frame
		frame:setScale(self.uiScale, self.uiScale)
		self:addChild(frame)
	end
end

function GC_FillLevelsDisplay:createFrame(hudAtlasPath, baseX, baseY, width, height)
	local frame = HUDFrameElement:new(hudAtlasPath, baseX, baseY, width, height)
	frame:setColor(unpack(HUD.COLOR.FRAME_BACKGROUND))
	self:addChild(frame)

	local posX, posY = baseX + width * 0.5, baseY
	local lineOverlay = Overlay:new(hudAtlasPath, posX, posY, frame.frameWidth, height - frame.frameHeight)
	lineOverlay:setUVs(getNormalizedUVs(HUDElement.UV.FILL))
	lineOverlay:setColor(unpack(HUDFrameElement.COLOR.FRAME))

	local lineElement = HUDElement:new(lineOverlay)
	self.centerLine = lineElement
	frame:addChild(lineElement)

	self.headerSeparator = self:createHorizontalSeparator(hudAtlasPath, baseX + width, baseY + height)
	frame:addChild(self.headerSeparator)

	return frame
end

function GC_FillLevelsDisplay:createHorizontalSeparator(hudAtlasPath, leftPosX, posY)
	local width, height = self:scalePixelToScreenVector(GC_FillLevelsDisplay.SIZE.HORIZONTAL_SEPARATOR)
	height = math.max(height, 1 / g_screenHeight)

	local overlay = Overlay:new(hudAtlasPath, leftPosX, posY - height * 0.5, width, height)
	overlay:setUVs(getNormalizedUVs(HUDElement.UV.FILL))
	overlay:setColor(unpack(InputHelpDisplay.COLOR.SEPARATOR))

	return HUDElement:new(overlay)
end

function GC_FillLevelsDisplay:createFillTypeFrame(hudAtlasPath, baseX, baseY, isLeft)
	local frameWidth, frameHeight = getNormalizedScreenValues(unpack(GC_FillLevelsDisplay.SIZE.FILL_TYPE_FRAME))
	local frameX, frameY = getNormalizedScreenValues(unpack(GC_FillLevelsDisplay.POSITION.FILL_TYPE_FRAME))
	local posX, posY = baseX + frameX, baseY + frameY

	local frameOverlay = Overlay:new(nil, posX, posY, frameWidth, frameHeight)
	local frame = HUDElement:new(frameOverlay)
	frame:setVisible(false)

	self:createFillTypeBar(hudAtlasPath, frame, posX, posY, isLeft)

	return frame
end

function GC_FillLevelsDisplay:createFillTypeBar(hudAtlasPath, frame, baseX, baseY, isLeft)
	local width, height = getNormalizedScreenValues(unpack(GC_FillLevelsDisplay.SIZE.BAR))
	local barX, barY = getNormalizedScreenValues(unpack(GC_FillLevelsDisplay.POSITION.BAR))
	local posX, posY = baseX + barX, baseY + barY

	local bgOverlay = Overlay:new(hudAtlasPath, posX, posY, width, height)
	bgOverlay:setUVs(getNormalizedUVs(HUDElement.UV.FILL))
	bgOverlay:setColor(unpack(GC_FillLevelsDisplay.COLOR.BAR_BACKGROUND))
	frame:addChild(HUDElement:new(bgOverlay))

	local fillOverlay = Overlay:new(hudAtlasPath, posX, posY, width, height)
	fillOverlay:setUVs(getNormalizedUVs(HUDElement.UV.FILL))
	fillOverlay:setColor(unpack(GC_FillLevelsDisplay.COLOR.BAR_FILLED))

	local fillBarElement = HUDElement:new(fillOverlay)
	frame:addChild(fillBarElement)

	if isLeft then
		table.insert(self.leftListLevelBars, fillBarElement)
	else
		table.insert(self.rightListLevelBars, fillBarElement)
	end
end

function GC_FillLevelsDisplay:setScale(uiScale)
	local maxUiScale = math.min(uiScale, 1.0)

	GC_FillLevelsDisplay:superClass().setScale(self, maxUiScale, maxUiScale)

	local currentVisibility = self:getVisible()
	self:setVisible(true, false)
	self.uiScale = maxUiScale

	local posX, posY = GC_FillLevelsDisplay.getBackgroundPosition(maxUiScale, self:getWidth())
	self:setPosition(posX, posY)

	self:storeOriginalPosition()
	self:setVisible(currentVisibility, false)
	self:storeScaledValues()
end

function GC_FillLevelsDisplay:storeScaledValues()
	self.headerTextSize = self:scalePixelToScreenHeight(HUDElement.TEXT_SIZE.DEFAULT_TITLE)
	self.mainHeaderTextSize = self:scalePixelToScreenHeight(GC_FillLevelsDisplay.SIZE.MAIN_TITLE)
	self.headerTextOffsetX, self.headerTextOffsetY = self:scalePixelToScreenVector(GC_FillLevelsDisplay.POSITION.HEADER_TEXT)
	self.mainHeaderTextOffsetX, self.mainHeaderTextOffsetY = self:scalePixelToScreenVector(GC_FillLevelsDisplay.POSITION.MAIN_TITLE)

	self.fillLevelTextSize = self:scalePixelToScreenHeight(HUDElement.TEXT_SIZE.DEFAULT_TEXT)
	self.fillLevelTextOffsetX, self.fillLevelTextOffsetY = self:scalePixelToScreenVector(GC_FillLevelsDisplay.POSITION.FILL_LEVEL_TEXT)
	self.fillTypeTextOffsetX, self.fillTypeTextOffsetY = self:scalePixelToScreenVector(GC_FillLevelsDisplay.POSITION.FILL_TYPE_TEXT)

	self.frameHeight = self:scalePixelToScreenVector(GC_FillLevelsDisplay.SIZE.FILL_TYPE_FRAME) * 0.8
end

function GC_FillLevelsDisplay:getMainFrameDimensions(width, height)
	local rightBuffer = #self.rightFillLevelBuffer
	local leftBuffer = #self.leftFillLevelBuffer

	return width * 2, self.frameHeight * math.max(rightBuffer, leftBuffer) + (self.frameHeight * 0.8)
end

function GC_FillLevelsDisplay:update(dt)
	GC_FillLevelsDisplay:superClass().update(self, dt)

	if self.object ~= nil then
		self:updateFillLevelBuffers()

		if #self.rightFillLevelBuffer > 0 then
			local width, height = self:getMainFrameDimensions(self:getWidth(), self:getHeight())
			self.mainFrame:setDimension(width, height)

			self.centerLine:setDimension(nil, height)

			if self.hasLeftList and #self.leftFillLevelBuffer <= 0 then
				self.hasLeftList = false
			end

			if not self:getVisible() and self.animation:getFinished() then
				self:setVisible(true, true)
			end

			self:updateFillLevelFrames()
		elseif self:getVisible() and self.animation:getFinished() then
			self:setVisible(false, true)
			self.object = nil
		end
	end
end

function GC_FillLevelsDisplay:updateFillLevelBuffers()
	clearTable(self.rightFillLevelBuffer)
	clearTable(self.rightFillTypeTextBuffer)
	clearTable(self.rightFillLevelTextBuffer)

	for _, frame in pairs(self.rightListItemFrames) do
		frame:setVisible(false)
	end

	if self.hasLeftList then
		clearTable(self.leftFillLevelBuffer)
		clearTable(self.leftFillTypeTextBuffer)
		clearTable(self.leftFillLevelTextBuffer)

		for _, frame in pairs(self.leftListItemFrames) do
			frame:setVisible(false)
		end
	end

	self.object:getFillLevelInformation(self.rightFillLevelBuffer, self.leftFillLevelBuffer)
end

function GC_FillLevelsDisplay:updateFillLevelFrames()
	local _, yOffset = self:getPosition()

	for i, fillLevelInformation in pairs(self.rightFillLevelBuffer) do
		local value = 0

		if fillLevelInformation.capacity > 0 then
			value = fillLevelInformation.fillLevel / fillLevelInformation.capacity
		end

		local frame = self.rightListItemFrames[i]
		frame:setVisible(true)

		local fillBar = self.rightListLevelBars[i]
		local _, yScale = fillBar:getScale()
		fillBar:setScale(MathUtil.clamp(value, 0, 1) * self.uiScale, yScale)

		local posX, posY = frame:getPosition()
		frame:setPosition(posX, yOffset)

		local fillText = string.format("%d (%d%%)", MathUtil.round(fillLevelInformation.fillLevel), math.max(100 * value, 0))
		self.rightFillLevelTextBuffer[i] = fillText

		self.rightFillTypeTextBuffer[i] = fillLevelInformation.title

		yOffset = yOffset + self.frameHeight
	end

	if self.hasLeftList then
		_, yOffset = self:getPosition()

		for i, fillLevelInformation in pairs(self.leftFillLevelBuffer) do
			local value = 0

			if fillLevelInformation.capacity > 0 then
				value = fillLevelInformation.fillLevel / fillLevelInformation.capacity
			end

			local frame = self.leftListItemFrames[i]
			frame:setVisible(true)

			local fillBar = self.leftListLevelBars[i]
			local _, yScale = fillBar:getScale()
			fillBar:setScale(MathUtil.clamp(value, 0, 1) * self.uiScale, yScale)

			local posX, posY = frame:getPosition()
			frame:setPosition(posX, yOffset)

			local fillText = string.format("%d (%d%%)", MathUtil.round(fillLevelInformation.fillLevel), math.max(100 * value, 0))
			self.leftFillLevelTextBuffer[i] = fillText

			self.leftFillTypeTextBuffer[i] = fillLevelInformation.title

			yOffset = yOffset + self.frameHeight
		end
	end
end

function GC_FillLevelsDisplay:draw()
	GC_FillLevelsDisplay:superClass().draw(self)

	if self:getVisible() then
		local baseX, baseY = self:getPosition()
		local height, width = self:getHeight(), self:getWidth()

		self:drawHeaders(baseX, baseY, height, width)

		for i, fillLevelText in ipairs(self.rightFillLevelTextBuffer) do
			local posX = baseX + width - self.fillLevelTextOffsetX
			local posY = baseY + (i - 1) * self.frameHeight + self.fillLevelTextOffsetY
			setTextColor(unpack(GC_FillLevelsDisplay.COLOR.FILL_LEVEL_TEXT))
			setTextBold(false)
			setTextAlignment(RenderText.ALIGN_RIGHT)
			renderText(posX, posY, self.fillLevelTextSize, fillLevelText)

			if self.rightFillTypeTextBuffer[i] ~= nil then
				local posY = baseY + (i - 1) * self.frameHeight + self.fillTypeTextOffsetY
				renderText(posX, posY, self.fillLevelTextSize, self.rightFillTypeTextBuffer[i])
			end
		end

		if self.hasLeftList then
			for i, fillLevelText in ipairs(self.leftFillLevelTextBuffer) do
				local posX = baseX - self.fillLevelTextOffsetX
				local posY = baseY + (i - 1) * self.frameHeight + self.fillLevelTextOffsetY
				setTextColor(unpack(GC_FillLevelsDisplay.COLOR.FILL_LEVEL_TEXT))
				setTextBold(false)
				setTextAlignment(RenderText.ALIGN_RIGHT)
				renderText(posX, posY, self.fillLevelTextSize, fillLevelText)

				if self.leftFillTypeTextBuffer[i] ~= nil then
					local posY = baseY + (i - 1) * self.frameHeight + self.fillTypeTextOffsetY
					renderText(posX, posY, self.fillLevelTextSize, self.leftFillTypeTextBuffer[i])
				end
			end
		end
	end
end

function GC_FillLevelsDisplay:drawHeaders(baseX, baseY, height, width)
	_, height = self:getMainFrameDimensions(width, height)

	setTextColor(unpack(ContextActionDisplay.COLOR.ACTION_TEXT))
	setTextBold(false)
	setTextAlignment(RenderText.ALIGN_CENTER)

	local posX, posY = baseX, baseY + height + self.mainHeaderTextOffsetY
	renderText(posX, posY, self.mainHeaderTextSize, self.mainHeaderText)

	posX, posY = baseX + (width * 0.5), baseY + height + self.headerTextOffsetY
	self.headerSeparator:setPosition(baseX - width, posY + (self.headerTextOffsetY * 0.5))
	renderText(posX, posY, self.headerTextSize, self.rightText)

	posX = baseX - (width * 0.5)
	renderText(posX, posY, self.headerTextSize, self.leftText)
	setTextAlignment(RenderText.ALIGN_LEFT)
end