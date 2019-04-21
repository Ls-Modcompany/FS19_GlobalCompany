-- 
-- Gui - Element - TABLE 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.05.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui-Table");

GC_Gui_table = {};
local GC_Gui_table_mt = Class(GC_Gui_table, GC_Gui_element);
getfenv(0)["GC_Gui_table"] = GC_Gui_table;

GC_Gui_table.ORIENTATION_X = 1;
GC_Gui_table.ORIENTATION_Y = 2;

GC_Gui_table.TYP_TABLE = 1;
GC_Gui_table.TYP_LIST = 2;

function GC_Gui_table:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_table_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "table";
	
	self.items = {};
	self.itemTemplate = nil;
	self.orientation = GC_Gui_table.ORIENTATION_X;
	self.type = GC_Gui_table.TYP_TABLE;
	
	self.itemWidth = 0.1;
	self.itemHeight = 0.1;
	self.itemMargin = {0,0,0,0};
	
	self.maxItemsX = 5;
	self.maxItemsY = 1;
	
	self.scrollCount = 0;
	self.selectRow = 0;
	
	return self;
end;

function GC_Gui_table:loadTemplate(templateName, xmlFile, key, overlayName)
	GC_Gui_table:superClass().loadTemplate(self, templateName, xmlFile, key);	
	
	self.itemWidth = unpack(GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "itemWidth"), {self.outputSize[1]}, {self.itemWidth}));
	self.itemHeight = unpack(GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "itemHeight"), {self.outputSize[2]}, {self.itemHeight}));
	self.itemMargin = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValue(templateName, "itemMargin"), self.outputSize, self.itemMargin);
	
	self.maxItemsX = g_company.gui:getTemplateValueNumber(templateName, "maxItemsX", self.maxItemsX);
	self.maxItemsY = g_company.gui:getTemplateValueNumber(templateName, "maxItemsY", self.maxItemsY);

	self.hasSlider = g_company.gui:getTemplateValueBool(templateName, "hasSlider", false);	
	
	local orientation = g_company.gui:getTemplateValue(templateName, "orientation");	

	if orientation == "x" then
		self.orientation = GC_Gui_table.ORIENTATION_X;
	elseif orientation == "y" then
		self.orientation = GC_Gui_table.ORIENTATION_Y;
	end;
	if self.maxItemsX == 1 then
		self.typ = GC_Gui_table.TYP_TABLE;
	else
		self.typ = GC_Gui_table.TYP_LIST;
	end;

	if self.hasSlider then
		self.slider = GC_Gui_slider:new();
		self.slider:loadTemplate(string.format( "%sSlider",templateName), xmlFile, key);
		self.slider.parent = self;
		--self:addElement(self.slider);
		if self.id ~= nil then
			self.gui[string.format("%s_slider",self.id)] = self.slider;
		end;
		self.slider:setController(self);
	end;

	self:loadOnCreate();
end;

function GC_Gui_table:copy(src)
	GC_Gui_table:superClass().copy(self, src);
	
	self.itemWidth = src.itemWidth;
	self.itemHeight = src.itemHeight;
	self.itemMargin = src.itemMargin;
	
	self.maxItemsX = src.maxItemsX;
	self.maxItemsY = src.maxItemsY;

	self.hasSlider = src.hasSlider;
	
	self.orientation = src.orientation;
	self:copyOnCreate();
end;

function GC_Gui_table:delete()
	GC_Gui_table:superClass().delete(self);
	
end;

function GC_Gui_table:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)	
	if not self:getDisabled() then
		eventUsed = GC_Gui_table:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
	
		if not eventUsed and g_company.gui:checkClickZoneNormal(posX, posY, self.drawPosition[1], self.drawPosition[2], self.size[1], self.size[2]) then
			if isDown then
				if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
					eventUsed = true;
					self:scrollTable(-1);
					if self.hasSlider then
						self.slider:setPosition(self.scrollCount);
					end;
				elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
					eventUsed = true;
					self:scrollTable(1);
					if self.hasSlider then
						self.slider:setPosition(self.scrollCount);
					end;
				end;
			end;		
		end;

		if not eventUsed and self.slider ~= nil then
			self.slider:mouseEvent(posX, posY, isDown, isUp, button, eventUsed);
		end;
	end;
	return eventUsed;
end;

function GC_Gui_table:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	GC_Gui_table:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);
	if self.slider ~= nil then
		self.slider:keyEvent(unicode, sym, modifier, isDown, eventUsed);
	end;
end;

function GC_Gui_table:update(dt)
	GC_Gui_table:superClass().update(self, dt);
	if self.slider ~= nil then
		self.slider:update(dt);
	end;
end;

function GC_Gui_table:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index);
	if self.slider ~= nil then
		self.slider:draw(index);
	end;
	GC_Gui_table:superClass().draw(self,index);
end;

function GC_Gui_table:setTableTemplate(element)
	self.itemTemplate = element;
	self:removeElement(element);
end;

function GC_Gui_table:addElement(element)
	if not element.isTableTemplate then
		if element.parent ~= nil then
			element.parent:removeElement(element)
		end;
		element:setParent(self);
		table.insert(self.items, element)
		self:updateVisibleItems();
	end;
end;

function GC_Gui_table:removeElements()
	for _,element in pairs(self.elements) do
		element.parent = nil;
		element:delete();
	end;
	self.items = {};
	self.elements = {};
end;

function GC_Gui_table:updateVisibleItems()	
	self.elements = {};
	
	local start;
	if self.orientation == GC_Gui_table.ORIENTATION_X then
		start = self.scrollCount * self.maxItemsY + 1;
	elseif self.orientation == GC_Gui_table.ORIENTATION_Y then
		start = self.scrollCount * self.maxItemsX + 1;
	end;
	local maxNum = self.maxItemsX * self.maxItemsY;
	
	for k,element in pairs(self.items) do
		if k >= start and k < start + maxNum then
			table.insert(self.elements, element);
		end;
		if k >= maxNum + start then
			break;
		end;
	end;
	if self.hasSlider then
		self.slider:updateItems()
	end;
end;

function GC_Gui_table:setPosition(pos)
	if self.scrollCount ~= pos then
		self.scrollCount = pos;
		self:scrollItems();
	end;
end;

function GC_Gui_table:scrollTable(num)
	if num == nil then
		self.scrollCount = 0;
	else
		self.scrollCount = self.scrollCount + num;	
		
		self:scrollItems();
	end;
	self:updateVisibleItems();
end;

function GC_Gui_table:scrollItems()
	local m,s,e;
	if self.orientation == GC_Gui_table.ORIENTATION_X then
		m = self.maxItemsY;
	elseif self.orientation == GC_Gui_table.ORIENTATION_Y then
		m = self.maxItemsX;
	end;			
	self:updateVisibleItems(); --#Pfusch am Mod
	if self.maxItemsY*self.maxItemsX - table.getn(self.elements) >= m then
		self.scrollCount = self.scrollCount - 1;
	end;
	
	if self.scrollCount < 0 then
		self.scrollCount = 0;
	end;
end;

function GC_Gui_table:setActive(state, e)
	for _,element in pairs(self.items) do
		if e ~= element then
			element:setActive(state);
		end;
	end;
end;

function GC_Gui_table:setSelected(state, e)	
	if state == nil then
		state = false;
	end;
	for _,element in pairs(self.items) do
		if e ~= element then
			element:setSelected(state, true);
		end;
	end;
end;

function GC_Gui_table:createItem()
	if self.itemTemplate ~= nil then
		local item = GC_Gui_button:new(self.gui);
		self:addElement(item);
		item:copy(self.itemTemplate);
		for _,element in pairs(self.itemTemplate.elements) do		
			self:createItemRec(self, element, item);
		end;
		
		return item;
	end;
	return nil;
end;

function GC_Gui_table:createItemRec(t, element, parent)
	local item = element:new(t.gui);
	parent:addElement(item);
	item:copy(element);
	for _,e in pairs(element.elements) do		
		t:createItemRec(t, e, item);
	end;
end;

function GC_Gui_table:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter);
	end;
	GC_Gui_table:superClass().onOpen(self);
end;










