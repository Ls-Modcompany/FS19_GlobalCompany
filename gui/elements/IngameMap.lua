-- 
-- Gui - Element - IngameMap 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.10.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui-IngameMap");

GC_Gui_ingameMap = {};

local GC_Gui_ingameMap_mt = Class(GC_Gui_ingameMap, GC_Gui_element);
-- getfenv(0)["GC_Gui_ingameMap"] = GC_Gui_ingameMap;
g_company.gui.ingamemapElement = GC_Gui_ingameMap;

function GC_Gui_ingameMap:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_ingameMap_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "ingameMap";
	
	self.zoomFactor = 8
	self.lastPxPosX = 0
	self.lastPxPosY = 0
	self.lastPxPosY = 0
	self.lastSize = self.zoomFactor * 128

	self.bitmaps = {}
	
	return self;
end;

function GC_Gui_ingameMap:loadTemplate(templateName, xmlFile, key)
	GC_Gui_ingameMap:superClass().loadTemplate(self, templateName, xmlFile, key);
    
    self.overlayElement = GC_Gui_overlay:new(self.gui);
    self.overlayElement:loadTemplate(string.format("%s_overlay", templateName), xmlFile, key);
    self.overlayElement:setImageFilename(g_currentMission.mapImageFilename)
    self:addElement(self.overlayElement);
	
	if self.isTableTemplate then
		self.parent:setTableTemplate(self);
	end;
	self:loadOnCreate();
end;

function GC_Gui_ingameMap:copy(src)
	GC_Gui_ingameMap:superClass().copy(self, src);
	

	self:copyOnCreate();
end;

function GC_Gui_ingameMap:delete()
	GC_Gui_ingameMap:superClass().delete(self);
end;


function GC_Gui_ingameMap:onOpen()
	
	self:loadBitmap()

end;

function GC_Gui_ingameMap:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	if not self:getDisabled() then
		eventUsed = GC_Gui_ingameMap:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
		
		
		if not eventUsed then

			local clickZone = {};		
			clickZone[1] = self.drawPosition[1]
			clickZone[2] = self.drawPosition[2] + self.size[2]
			clickZone[3] = self.drawPosition[1] + self.size[1]
			clickZone[4] = self.drawPosition[2] + self.size[2]
			clickZone[5] = self.drawPosition[1] + self.size[1]
			clickZone[6] = self.drawPosition[2]
			clickZone[7] = self.drawPosition[1]
			clickZone[8] = self.drawPosition[2]

			if g_company.gui:checkClickZone(posX, posY, clickZone, self.isRoundButton) then
				if not self.mouseEntered then
					self.mouseEntered = true;	

					if self.callback_onEnter ~= nil then
						self.gui[self.callback_onEnter](self.gui, self, self.parameter)
					end
				end
				
				if isDown and button == Input.MOUSE_BUTTON_WHEEL_UP then
                    self:zoom(-1, posX, posY)
                    eventUsed = true
                end
                if isDown and button == Input.MOUSE_BUTTON_WHEEL_DOWN then
                    self:zoom(1, posX, posY)
                    eventUsed = true
				end
				
                if isDown and button == Input.MOUSE_BUTTON_LEFT then
                    eventUsed = true
                    if not self.mouseDown then
                        self.mouseDown = true
                        self.lastMousePosX = posX
                        self.lastMousePosY = posY
                    end
                end
                if isUp and button == Input.MOUSE_BUTTON_LEFT then
                    self.mouseDown = false
                end

                if self.mouseDown then
					self:move(posX, posY)					
                    self.lastMousePosX = posX
                    self.lastMousePosY = posY
				end
			else
				if self.mouseEntered then
					self.mouseDown = false
					self.mouseEntered = false					
					if self.callback_onLeave ~= nil then
						self.gui[self.callback_onLeave](self.gui, self, self.parameter)
					end;
				end
			end
		end
	end
	return eventUsed
end;

function GC_Gui_ingameMap:keyEvent(unicode, sym, modifier, isDown, eventUsed)   
	GC_Gui_ingameMap:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);
end;

function GC_Gui_ingameMap:update(dt)
    GC_Gui_ingameMap:superClass().update(self, dt);
end;

function GC_Gui_ingameMap:zoom(value, posX, posY)
	local oldZoom = self.zoomFactor
	self.zoomFactor = g_company.utils.getCorrectNumberValue(self.zoomFactor + value, self.zoomFactor, 1, 8)

	if self.zoomFactor == oldZoom then 
		return
	end	

	local factorX = (posX - self.drawPosition[1]) / self.size[1]
	local factorY = 1 - (posY - self.drawPosition[2]) / self.size[2]

	self.lastPxPosX = math.ceil(self.lastPxPosX + 128 * factorX * value * -1)
	self.lastPxPosY = math.ceil(self.lastPxPosY + 128 * factorY * value * -1)

	self.lastSize = self.zoomFactor * 128

	self.lastPxPosX = self:checkEdges(self.lastPxPosX)
	self.lastPxPosY = self:checkEdges(self.lastPxPosY)
	
	self.overlayElement:setUV(string.format("%spx %spx %spx %spx", self.lastPxPosX, self.lastPxPosY, self.lastSize, self.lastSize))
end

function GC_Gui_ingameMap:checkEdges(lastPos)
	if lastPos < 0 then
		return 0
	elseif lastPos + self.lastSize > 1024 then
		return lastPos - ((lastPos + self.lastSize) - 1024)
	end
	return lastPos
end

function GC_Gui_ingameMap:move(posX, posY)
	self.lastPxPosX = self.lastPxPosX + ((self.lastMousePosX - posX) / self.size[1] * self.lastSize)
	self.lastPxPosY = self.lastPxPosY + ((posY - self.lastMousePosY) / self.size[2] * self.lastSize)

	self.lastPxPosX = self:checkEdges(self.lastPxPosX)
	self.lastPxPosY = self:checkEdges(self.lastPxPosY)

	self.overlayElement:setUV(string.format("%spx %spx %spx %spx", self.lastPxPosX, self.lastPxPosY, self.lastSize, self.lastSize))
end

function GC_Gui_ingameMap:registerBitmap(name, bitmapId, state)
	self.bitmaps[bitmapId] = {name=name, overlay=nil, active=state or false}
end

function GC_Gui_ingameMap:unregisterBitmap()
	self.bitmaps[bitmapId] = nil
end

function GC_Gui_ingameMap:setActiveBitmap(bitmapId, state)
	self.bitmaps[bitmapId].active = state or not self.bitmaps[bitmapId].active
end

function GC_Gui_ingameMap:loadBitmap()
	for bitmapId, data in pairs(self.bitmaps) do
		local bitmap = g_company.bitmapManager:getBitmapById(bitmapId);
		self.bitmaps[bitmapId].overlay = createDensityMapVisualizationOverlay(data.name, 1024,1024)

		if GS_IS_CONSOLE_VERSION or (g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission:getIsServer()) then
			setDensityMapVisualizationOverlayUpdateTimeLimit(self.bitmaps[bitmapId].overlay, 10)
		else
			setDensityMapVisualizationOverlayUpdateTimeLimit(self.bitmaps[bitmapId].overlay, 20)
		end

		resetDensityMapVisualizationOverlay(self.bitmaps[bitmapId].overlay)

		g_company.bitmapManager:setOverlayStateColor(self.bitmaps[bitmapId], bitmap)		
		
		generateDensityMapVisualizationOverlay(self.bitmaps[bitmapId].overlay)
	end
end

function GC_Gui_ingameMap:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index);	
	
	GC_Gui_ingameMap:superClass().draw(self);

	for bitmapId, data in pairs(self.bitmaps) do
		if data.active then
			if getIsDensityMapVisualizationOverlayReady(data.overlay) then
				setOverlayUVs(data.overlay, unpack(GuiUtils.getUVs(string.format("%spx %spx %spx %spx", self.lastPxPosX, self.lastPxPosY, self.lastSize, self.lastSize), self.imageSize, nil)));	
				renderOverlay(data.overlay, self.drawPosition[1], self.drawPosition[2], self.size[1], self.size[2]);
			end
		end
	end
end