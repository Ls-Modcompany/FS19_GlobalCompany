-- 
-- Gui - Element - OVERLAY 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.05.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui-Overlay");

GC_Gui_overlay = {};
local GC_Gui_overlay_mt = Class(GC_Gui_overlay, GC_Gui_element);
getfenv(0)["GC_Gui_overlay"] = GC_Gui_overlay;

function GC_Gui_overlay:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_overlay_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "overlay";
	
	self.imageColor = {1,1,1,1};
	self.imageColor_disabled = {1,1,1,1};
	self.imageColor_selected = {1,1,1,1};
	self.imageColor_disabledSelected = {1,1,1,1};
	
	self.uvs = {0, 0, 0, 1, 1, 0, 1, 1};
	self.uvs_selected = {0, 0, 0, 1, 1, 0, 1, 1};
	self.uvs_disabled = {0, 0, 0, 1, 1, 0, 1, 1};
	self.uvs_disabledSelected = {0, 0, 0, 1, 1, 0, 1, 1};
	
	self.borderLeftSize = 0;
	self.borderRightSize = 0;
	self.borderTopSize = 0;
	self.borderBottomSize = 0;
	
	self.borderLeftColor = 0;
	self.borderRightColor = 0;
	self.borderTopColor = 0;
	self.borderBottomColor = 0;

	self.scaleX = 1;
	self.scaleY = 1;
	
	self.rotation = 0;
	
	return self;
end;

function GC_Gui_overlay:loadTemplate(templateName, xmlFile, key, overlayName)
	GC_Gui_overlay:superClass().loadTemplate(self, templateName, xmlFile, key);
	
	if overlayName == nil then
		overlayName = "image";
	end;
	
	self.imageFilename = g_company.gui:getTemplateValue(templateName, overlayName .. "Filename");		
		
	self.uvs = g_company.gui:getTemplateValueUVs(templateName, overlayName .. "UVs", self.imageSize, self.uvs);
	self.uvs_selected = g_company.gui:getTemplateValueUVs(templateName, overlayName .. "UVs_selected", self.imageSize, self.uvs_selected);
	self.uvs_disabled = g_company.gui:getTemplateValueUVs(templateName, overlayName .. "UVs_disabled", self.imageSize, self.uvs_disabled);	
	self.uvs_disabledSelected = g_company.gui:getTemplateValueUVs(templateName, overlayName .. "UVs_disabledSelected", self.imageSize, self.uvs_disabledSelected);	
	
	self.imageColor = g_company.gui:getTemplateValueColor(templateName, overlayName .. "Color", self.imageColor);
	self.imageColor_disabled = g_company.gui:getTemplateValueColor(templateName, overlayName .. "Color_disabled", self.imageColor_disabled);
	self.imageColor_selected = g_company.gui:getTemplateValueColor(templateName, overlayName .. "Color_selected", self.imageColor_selected);	
	self.imageColor_disabledSelected = g_company.gui:getTemplateValueColor(templateName, overlayName .. "Color_disabledSelected", self.imageColor_disabledSelected);	
	
	self.isCamera = g_company.gui:getTemplateValueBool(templateName, "isCamera", false);	
	self.hasBorders = g_company.gui:getTemplateValueBool(templateName, "hasBorders", false);	
	if self.hasBorders then
		self.borders = GC_Gui_borders:new(self.gui);
		self.borders:loadTemplate(templateName, xmlFile, key);
		self:addElement(self.borders);
	end;
	
	self.rotation = g_company.gui:getTemplateValueNumber(templateName, "rotation", self.rotation);
	
	local uiElement = g_company.gui:getUiElement(self.imageFilename)
	if self.imageFilename == "g_baseUIFilename" then
        self.imageFilename = g_baseUIFilename;
	elseif self.imageFilename == "gc_uiElements1" then
        self.imageFilename = g_company.dir .. "images/ui_elements_1.dds";
	elseif uiElement ~= nil then
        self.imageFilename = uiElement;
    end;
	
	self.imageOverlay = createImageOverlay(self.imageFilename);
	self:loadOnCreate();
end;

function GC_Gui_overlay:copy(src)
	GC_Gui_overlay:superClass().copy(self, src);
	
	self:setImageFilename(src.imageFilename);
	self.uvs = src.uvs;
	self.uvs_selected = src.uvs_selected;
	self.uvs_disabled = src.uvs_disabled;
	self.uvs_disabledSelected = src.uvs_disabledSelected;
	
	self.imageColor = src.imageColor;
	self.imageColor_disabled = src.imageColor_disabled;
	self.imageColor_selected = src.imageColor_selected;
	self.imageColor_disabledSelected = src.imageColor_disabledSelected;
	
	self.rotation = src.rotation;
	self.hasBorders = src.hasBorders;
	
	if self.hasBorders then
		self.borders = GC_Gui_borders:new(self.gui);
		self.borders:copy(src.borders);
		self:addElement(self.borders);
	end;
	
	--self.imageOverlay = createImageOverlay(self.imageFilename);
	self:copyOnCreate();
end;

function GC_Gui_overlay:setImageFilename(filename)
	local uiElement = g_company.gui:getUiElement(filename)
	if uiElement ~= nil then
		filename = uiElement;
	end;
	self.imageFilename = filename;
	self.imageOverlay = createImageOverlay(self.imageFilename);
end;

function GC_Gui_overlay:setImageOverlay(overlay)
	self.imageOverlay = overlay;
end;

function GC_Gui_overlay:delete()
	GC_Gui_overlay:superClass().delete(self);
	if self.imageOverlay ~= nil and self.imageOverlay ~= 0 then
		delete(self.imageOverlay);
		self.imageOverlay = nil;
	end;
end;

function GC_Gui_overlay:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	GC_Gui_overlay:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed);
end;

function GC_Gui_overlay:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	GC_Gui_overlay:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);
end;

function GC_Gui_overlay:update(dt)
	GC_Gui_overlay:superClass().update(self, dt);
end;

function GC_Gui_overlay:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index);
	if self:getVisible() then
		if self.isCamera then
			setOverlayRotation(self.imageOverlay, self.rotation, self.size[1] * 0.5, self.size[2] * 0.5);
			renderOverlay(self.imageOverlay, self.drawPosition[1], self.drawPosition[2], self.size[1], self.size[2]);
		else
			setOverlayRotation(self.imageOverlay, self.rotation, self.size[1] * 0.5, self.size[2] * 0.5);
			setOverlayUVs(self.imageOverlay, unpack(self:getUVs()));
			setOverlayColor(self.imageOverlay, unpack(self:getImageColor()));
			
			local sizeX = math.max(self.size[1], 1 / g_screenWidth);
			local sizeY = math.max(self.size[2], 1 / g_screenHeight);			
			renderOverlay(self.imageOverlay, self.drawPosition[1], self.drawPosition[2], sizeX * self.scaleX, sizeY * self.scaleY);
		end;
	end;

	GC_Gui_overlay:superClass().draw(self);
end;

function GC_Gui_overlay:setScale(x,y)
	self.scaleX = x;
	self.scaleY = Utils.getNoNil(y,self.scaleY);
end;

function GC_Gui_overlay:setUV(str)
	self.uvs = GuiUtils.getUVs(str, self.imageSize, nil);
end;

function GC_Gui_overlay:getUVs()
    if self:getDisabled() and self:getIsSelected() then
        return self.uvs_disabledSelected;
	elseif self:getDisabled() then
        return self.uvs_disabled;
    elseif self:getIsSelected() then
        return self.uvs_selected;
    else
        return self.uvs;
    end;
end;

function GC_Gui_overlay:getImageColor()
    if self:getDisabled() and self:getIsSelected() then
        return self.imageColor_disabledSelected;
	elseif self:getDisabled() then
        return self.imageColor_disabled;
    elseif self:getIsSelected() then
        return self.imageColor_selected;
    else
        return self.imageColor;
    end;
end;

function GC_Gui_overlay:setRotation(rotation)
	self.rotation = rotation;
end;

function GC_Gui_overlay:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter);
	end;
	GC_Gui_overlay:superClass().onOpen(self);
end;

function GC_Gui_overlay:setImageUv(uv, all)
	if g_company.gui.template.uvs[uv] ~= nil then
		self.uvs = GuiUtils.getUVs(g_company.gui.template.uvs[uv], self.imageSize, self.default);
		if all then
			self.uvs_selected = self.uvs;
			self.uvs_disabled = self.uvs;
		end;
	end;
end;












