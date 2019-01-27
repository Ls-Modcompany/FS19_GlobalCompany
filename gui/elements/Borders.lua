-- 
-- Gui - Element - BORDERS 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.05.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_debug.registerMod("GlobalCompany-Gui-Borders");

GC_Gui_borders = {};
local GC_Gui_borders_mt = Class(GC_Gui_borders, GC_Gui_element);
getfenv(0)["GC_Gui_borders"] = GC_Gui_borders;

function GC_Gui_borders:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_borders_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "borders";
	
	self.borderLeftSize = 0;
	self.borderRightSize = 0;
	self.borderTopSize = 0;
	self.borderBottomSize = 0;
	
	self.borderLeftSize_selected = 0;
	self.borderRightSize_selected = 0;
	self.borderTopSize_selected = 0;
	self.borderBottomSize_selected = 0;
	
	self.borderLeftSize_disabled = 0;
	self.borderRightSize_disabled = 0;
	self.borderTopSiz_disablede = 0;
	self.borderBottomSize_disabled = 0;
	
	self.borderLeftColor = {1,1,1,1};
	self.borderRightColor = {1,1,1,1};
	self.borderTopColor = {1,1,1,1};
	self.borderBottomColor = {1,1,1,1};
	
	self.borderLeftColor_selected = {1,1,1,1};
	self.borderRightColor_selected = {1,1,1,1};
	self.borderTopColor_selected = {1,1,1,1};
	self.borderBottomColor_selected = {1,1,1,1};
	
	self.borderLeftColor_disabled = {1,1,1,1};
	self.borderRightColor_disabled = {1,1,1,1};
	self.borderTopColor_disabled = {1,1,1,1};
	self.borderBottomColor_disabled = {1,1,1,1};
		
	return self;
end;

function GC_Gui_borders:loadTemplate(templateName, xmlFile, key)
	GC_Gui_borders:superClass().loadTemplate(self, templateName, xmlFile, key);
	
	if overlayName == nil then
		overlayName = "image";
	end;
	
	local imageFilename = g_baseUIFilename;	
		
	self.borderLeftSize = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderLeftSize"), self.outputSize, {self.borderLeftSize})[1];
	self.borderRightSize = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderRightSize"), self.outputSize, {self.borderRightSize})[1];
	self.borderTopSize = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderTopSize"), self.outputSize, {self.borderTopSize})[1];
	self.borderBottomSize = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderBottomSize"), self.outputSize, {self.borderBottomSize})[1];
	
	self.borderLeftSize_selected = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderLeftSize_selected"), self.outputSize, {self.borderLeftSize_selected})[1];
	self.borderRightSize_selected = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderRightSize_selected"), self.outputSize, {self.borderRightSize_selected})[1];
	self.borderTopSize_selected = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderTopSize_selected"), self.outputSize, {self.borderTopSize_selected})[1];
	self.borderBottomSize_selected = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderBottomSize_selected"), self.outputSize, {self.borderBottomSize_selected})[1];
	
	self.borderLeftSize_disabled = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderLeftSize_disabled"), self.outputSize, {self.borderLeftSize_disabled})[1];
	self.borderRightSize_disabled = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderRightSize_disabled"), self.outputSize, {self.borderRightSize_disabled})[1];
	self.borderTopSize_disabled = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderTopSize_disabled"), self.outputSize, {self.borderTopSize_disabled})[1];
	self.borderBottomSize_disabled = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "borderBottomSize_disabled"), self.outputSize, {self.borderBottomSize_disabled})[1];
	
	self.borderLeftColor = g_company.gui:getTemplateValueColor(templateName, "borderLeftColor", self.borderLeftColor);	
	self.borderRightColor = g_company.gui:getTemplateValueColor(templateName, "borderRightColor", self.borderRightColor);	
	self.borderTopColor = g_company.gui:getTemplateValueColor(templateName, "borderTopColor", self.borderTopColor);	
	self.borderBottomColor = g_company.gui:getTemplateValueColor(templateName, "borderBottomColor", self.borderBottomColor);	
	
	self.borderLeftColor_selected = g_company.gui:getTemplateValueColor(templateName, "borderLeftColor_selected", self.borderLeftColor_selected);	
	self.borderRightColor_selected = g_company.gui:getTemplateValueColor(templateName, "borderRightColor_selected", self.borderRightColor_selected);	
	self.borderTopColor_selected = g_company.gui:getTemplateValueColor(templateName, "borderTopColor_selected", self.borderTopColor_selected);	
	self.borderBottomColor_selected = g_company.gui:getTemplateValueColor(templateName, "borderBottomColor_selected", self.borderBottomColor_selected);	
	
	self.borderLeftColor_disabled = g_company.gui:getTemplateValueColor(templateName, "borderLeftColor_disabled", self.borderLeftColor_disabled);	
	self.borderRightColor_disabled = g_company.gui:getTemplateValueColor(templateName, "borderRightColor_disabled", self.borderRightColor_disabled);	
	self.borderTopColor_disabled = g_company.gui:getTemplateValueColor(templateName, "borderTopColor_disabled", self.borderTopColor_disabled);	
	self.borderBottomColor_disabled = g_company.gui:getTemplateValueColor(templateName, "borderBottomColor_disabled", self.borderBottomColor_disabled);	
	
	self.uv = GuiUtils.getUVs("10px 1010px 4px 4px", self.imageSize, {0,0,1,1});
	
	if self.borderLeftSize > 0 then
		self.imageLeft = createImageOverlay(imageFilename);
	end;
	if self.borderRightSize > 0 then
		self.imageRight = createImageOverlay(imageFilename);
	end;
	if self.borderTopSize > 0 then
		self.imageTop = createImageOverlay(imageFilename);
	end;
	if self.borderBottomSize > 0 then
		self.imageBottom = createImageOverlay(imageFilename);
	end;	
	self:loadOnCreate();
end;

function GC_Gui_borders:copy(src)
	GC_Gui_borders:superClass().copy(self, src);
	
	self.borderLeftSize = src.borderLeftSize;
	self.borderRightSize = src.borderRightSize;
	self.borderTopSize = src.borderTopSize;
	self.borderBottomSize = src.borderBottomSize;
	
	self.borderLeftSize_selected = src.borderLeftSize_selected;
	self.borderRightSize_selected = src.borderRightSize_selected;
	self.borderTopSize_selected = src.borderTopSize_selected;
	self.borderBottomSize_selected = src.borderBottomSize_selected;
	
	self.borderLeftSize_disabled = src.borderLeftSize_disabled;
	self.borderRightSize_disabled = src.borderRightSize_disabled;
	self.borderTopSize_disabled = src.borderTopSize_disabled;
	self.borderBottomSize_disabled = src.borderBottomSize_disabled;
	
	self.borderLeftColor = src.borderLeftColor;
	self.borderRightColor = src.borderRightColor;
	self.borderTopColor = src.borderTopColor;
	self.borderBottomColor = src.borderBottomColor;
	
	self.borderLeftColor_selected = src.borderLeftColor_selected;
	self.borderRightColor_selected = src.borderRightColor_selected;
	self.borderTopColor_selected = src.borderTopColor_selected;
	self.borderBottomColor_selected = src.borderBottomColor_selected;
	
	self.borderLeftColor_disabled = src.borderLeftColor_disabled;
	self.borderRightColor_disabled = src.borderRightColor_disabled;
	self.borderTopColor_disabled = src.borderTopColor_disabled;
	self.borderBottomColor_disabled = src.borderBottomColor_disabled;
	
	self.uv = src.uv;
	self.imageLeft = src.imageLeft;
	self.imageRight = src.imageRight;
	self.imageTop = src.imageTop;
	self.imageBottom = src.imageBottom;
	self:copyOnCreate();
end;

function GC_Gui_borders:setImageFilename(filename)
	self.imageOverlay = createImageOverlay(filename);
end;

function GC_Gui_borders:delete()
	GC_Gui_borders:superClass().delete(self);
	if self.imageOverlay ~= nil then
		delete(self.imageOverlay);
		self.imageOverlay = nil;
	end;
end;

function GC_Gui_borders:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	GC_Gui_borders:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed);
end;

function GC_Gui_borders:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	GC_Gui_borders:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);
end;

function GC_Gui_borders:update(dt)
	GC_Gui_borders:superClass().update(self, dt);
end;

function GC_Gui_borders:draw(index)		
	if self.imageLeft ~= nil then
		local  x = self.parent.drawPosition[1];
		local  y = self.parent.drawPosition[2];
		local  sx = self:getBorderLeftSize();
		local  sy = self.parent.size[2];	
		setOverlayUVs(self.imageLeft, unpack(self.uv));
		setOverlayColor(self.imageLeft, unpack(self:getBorderLeftColor()));
		renderOverlay(self.imageLeft, x,y,sx,sy);
	end;
	if self.imageRight ~= nil then
		local  x = self.parent.drawPosition[1] + self.parent.size[1] - self:getBorderRightSize();
		local  y = self.parent.drawPosition[2];
		local  sx = self:getBorderRightSize();
		local  sy = self.parent.size[2];	
		setOverlayUVs(self.imageRight, unpack(self.uv));
		setOverlayColor(self.imageRight, unpack(self:getBorderRightColor()));
		renderOverlay(self.imageRight, x,y,sx,sy);
	end;
	if self.imageTop ~= nil then
		local  x = self.parent.drawPosition[1];
		local  y = self.parent.drawPosition[2] + self.parent.size[2] - self:getBorderTopSize();
		local  sx = self.parent.size[1];
		local  sy = self:getBorderTopSize();
		setOverlayUVs(self.imageTop, unpack(self.uv));
		setOverlayColor(self.imageTop, unpack(self:getBorderTopColor()));
		renderOverlay(self.imageTop, x,y,sx,sy);
	end;
	if self.imageBottom ~= nil then
		local  x = self.parent.drawPosition[1];
		local  y = self.parent.drawPosition[2];
		local  sx = self.parent.size[1];
		local  sy = self:getBorderBottomSize();	
		setOverlayUVs(self.imageBottom, unpack(self.uv));
		setOverlayColor(self.imageBottom, unpack(self:getBorderBottomColor()));
		renderOverlay(self.imageBottom, x,y,sx,sy);
	end;
	GC_Gui_borders:superClass().draw(self,index);
end;

function GC_Gui_borders:getBorderLeftColor()
    if self:getDisabled() then
        return self.borderLeftColor_disabled;
    elseif self:getIsSelected() then
        return self.borderLeftColor_selected;
    else
        return self.borderLeftColor;
    end;
end;

function GC_Gui_borders:getBorderRightColor()
    if self:getDisabled() then
        return self.borderRightColor_disabled;
    elseif self:getIsSelected() then
        return self.borderRightColor_selected;
    else
        return self.borderRightColor;
    end;
end;

function GC_Gui_borders:getBorderTopColor()
    if self:getDisabled() then
        return self.borderTopColor_disabled;
    elseif self:getIsSelected() then
        return self.borderTopColor_selected;
    else
        return self.borderTopColor;
    end;
end;

function GC_Gui_borders:getBorderBottomColor()
    if self:getDisabled() then
        return self.borderBottomColor_disabled;
    elseif self:getIsSelected() then
        return self.borderBottomColor_selected;
    else
        return self.borderBottomColor;
    end;
end;

function GC_Gui_borders:getBorderLeftSize()
    if self:getDisabled() then
        return self.borderLeftSize_disabled;
    elseif self:getIsSelected() then
        return self.borderLeftSize_selected;
    else
        return self.borderLeftSize;
    end;
end;

function GC_Gui_borders:getBorderRightSize()
    if self:getDisabled() then
        return self.borderRightSize_disabled;
    elseif self:getIsSelected() then
        return self.borderRightSize_selected;
    else
        return self.borderRightSize;
    end;
end;

function GC_Gui_borders:getBorderTopSize()
    if self:getDisabled() then
        return self.borderTopSize_disabled;
    elseif self:getIsSelected() then
        return self.borderTopSize_selected;
    else
        return self.borderTopSize;
    end;
end;

function GC_Gui_borders:getBorderBottomSize()
    if self:getDisabled() then
        return self.borderBottomSize_disabled;
    elseif self:getIsSelected() then
        return self.borderBottomSize_selected;
    else
        return self.borderBottomSize;
    end;
end;

function GC_Gui_borders:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter);
	end;
	GC_Gui_borders:superClass().onOpen(self);
end;












