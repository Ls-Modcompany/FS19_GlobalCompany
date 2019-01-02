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
local debugIndex = g_debug.registerMod("GlobalCompany-Gui-Table");

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
	self:loadOnCreate();
end;

function GC_Gui_table:copy(src)
	GC_Gui_table:superClass().copy(self, src);
	
	self.itemWidth = src.itemWidth;
	self.itemHeight = src.itemHeight;
	self.itemMargin = src.itemMargin;
	
	self.maxItemsX = src.maxItemsX;
	self.maxItemsY = src.maxItemsY;
	
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
				elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
					eventUsed = true;
					self:scrollTable(1);
				end;
			end;		
		end;
	end;
	return eventUsed;
end;

function GC_Gui_table:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	GC_Gui_table:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);
end;

function GC_Gui_table:update(dt)
	GC_Gui_table:superClass().update(self, dt);
end;

function GC_Gui_table:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index);
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
	for _,element in pairs(self.items) do
		element.parent = nil;
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
end;

function GC_Gui_table:scrollTable(num)
	if num == nil then
		self.scrollCount = 0;
	else
		self.scrollCount = self.scrollCount + num;	
		
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
	self:updateVisibleItems();
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
		item:copy(self.itemTemplate);
		
		for _,element in pairs(self.itemTemplate.elements) do		
			self:createItemRec(self, element, item);
		end;
		
		self:addElement(item);
		return item;
	end;
	return nil;
end;

function GC_Gui_table:createItemRec(t, element, parent)
	local item = element:new(t.gui);
	item:copy(element);
	parent:addElement(item);
	for _,e in pairs(element.elements) do		
		t:createItemRec(t, e, item);
	end;
end;










