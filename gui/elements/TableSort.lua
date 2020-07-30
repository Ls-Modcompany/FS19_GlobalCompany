-- 
-- Gui - Element - TableSort 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.10.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-Gui-TableSort");

GC_Gui_tableSort = {};

local GC_Gui_tableSort_mt = Class(GC_Gui_tableSort, GC_Gui_element);
-- getfenv(0)["GC_Gui_tableSort"] = GC_Gui_tableSort;
g_company.gui.inputElement = GC_Gui_tableSort;

function GC_Gui_tableSort:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = GC_Gui_tableSort_mt;
    end;
	
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "tableSort";
	
	self.sortDirection = 1
	
	return self;
end;

function GC_Gui_tableSort:loadTemplate(templateName, xmlFile, key)
	GC_Gui_tableSort:superClass().loadTemplate(self, templateName, xmlFile, key);
  
    self.buttonElement = GC_Gui_button:new(self.gui);
	self.buttonElement:loadTemplate(string.format("%s_button", templateName), xmlFile, key);
    self:addElement(self.buttonElement);
    
    self.overlayElement = GC_Gui_overlay:new(self.gui);
    self.overlayElement:loadTemplate(string.format("%s_overlay", templateName), xmlFile, key);
	self:addElement(self.overlayElement);
	
	self.size = GuiUtils.getNormalizedValues(g_company.gui:getTemplateValueXML(xmlFile, "tableSortSize", key), self.outputSize, self.size);
	self.buttonElement.size = self.size
	self.buttonElement.overlayElement.size = self.size
	
	if self.isTableTemplate then
		self.parent:setTableTemplate(self);
	end;
	self:loadOnCreate();
end;

function GC_Gui_tableSort:copy(src)
	GC_Gui_tableSort:superClass().copy(self, src);
	

	self:copyOnCreate();
end;

function GC_Gui_tableSort:delete()
	GC_Gui_tableSort:superClass().delete(self);

end;

function GC_Gui_tableSort:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	GC_Gui_tableSort:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end;

function GC_Gui_tableSort:keyEvent(unicode, sym, modifier, isDown, eventUsed)   
	GC_Gui_tableSort:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed);
end;

function GC_Gui_tableSort:update(dt)
    GC_Gui_tableSort:superClass().update(self, dt);
end;

function GC_Gui_tableSort:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index);	
	
	GC_Gui_tableSort:superClass().draw(self);
end;

function GC_Gui_tableSort:changeSortDirection()
	self.sortDirection = self.sortDirection * -1
	self:setSortIcon()
end

function GC_Gui_tableSort:setSortDirection(sortDirection)
	self.sortDirection = sortDirection
	self:setSortIcon()
end

function GC_Gui_tableSort:setSortIcon()	
	if self.sortDirection == 1 then
		self.overlayElement:setRotation(math.rad(0))
	else
		self.overlayElement:setRotation(math.rad(180))
	end
end

function GC_Gui_tableSort:sortTable(tableC)
	local needSort = {}
	for k,element in pairs(tableC.items) do
		table.insert(needSort, element.sortName)
	end
	table.sort(needSort, function(a, b) return a:lower() < b:lower() end)

	local newItems = {}

	for _,sortName in pairs(needSort) do
		local toDelete;
		for k,oE in pairs(tableC.items) do
			if sortName == oE.sortName then
				table.insert(newItems, oE)
				toDelete = k
				break
			end
		end
		table.remove(tableC.items, toDelete)
	end
	tableC.items = newItems
	
	if self.sortDirection == -1 then
		local i, j = 1, table.getn(tableC.items)
		while i < j do
			tableC.items[i], tableC.items[j] = tableC.items[j], tableC.items[i]
			i = i + 1
			j = j - 1
		end
	end
end