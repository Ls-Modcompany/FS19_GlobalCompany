-- 
-- Gui - Element - GC_Gui_pageSelector 
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 25.08.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--
-- 	v1.0.0.0 (25.08.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
--
--
-- ToDo:
--
--
--


GC_Gui_pageSelector = {};
local GC_Gui_pageSelector_mt = Class(GC_Gui_pageSelector, GC_Gui_element);

GC_Gui_pageSelector.debugIndex = g_company.debug:registerScriptName("GlobalCompany-GC_Gui_pageSelector");

function GC_Gui_pageSelector:new(gui, custom_mt)	
	if custom_mt == nil then
        custom_mt = GC_Gui_pageSelector_mt;
    end;
	local self = GC_Gui_element:new(gui, custom_mt);
	self.name = "pageSelector";
	
	self.skipFirstElement = true
	    
	return self;
end;

function GC_Gui_pageSelector:loadTemplate(templateName, xmlFile, key)
	GC_Gui_pageSelector:superClass().loadTemplate(self, templateName, xmlFile, key)

	if xmlFile ~= nil then
		self.currentPage = g_company.gui:getTemplateValueXML(xmlFile, "pageNameOnOpen", key, nil);
	end

	self:loadOnCreate()
end


function GC_Gui_pageSelector:copy(src)
	GC_Gui_pageSelector:superClass().copy(self, src)

	self:copyOnCreate()
end

function GC_Gui_pageSelector:delete()
	GC_Gui_pageSelector:superClass().delete(self)

end

function GC_Gui_pageSelector:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	return GC_Gui_pageSelector:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function GC_Gui_pageSelector:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	GC_Gui_pageSelector:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function GC_Gui_pageSelector:update(dt)
	GC_Gui_pageSelector:superClass().update(self, dt)	
end

function GC_Gui_pageSelector:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index)	
	
	
	
	GC_Gui_pageSelector:superClass().draw(self)
end

function GC_Gui_pageSelector:onOpen()
	GC_Gui_pageSelector:superClass().onOpen(self)
	if self.currentPage == nil then
		self:openPage(self:findFirstPageName())
	else
		self:openPage(self.currentPage)
	end
end

function GC_Gui_pageSelector:findFirstPageName()
	if self.currentPage == nil then
		local skipFirstElement = self.skipFirstElement
		for _, page in pairs(self.elements) do
			if skipFirstElement then
				skipFirstElement = false
			else
				return page.pageName
			end
		end
	end
end

function GC_Gui_pageSelector:openPage(pageName)
	local skipFirstElement = self.skipFirstElement
	local activePageIndx = -1
	for k, page in pairs(self.elements) do
		if skipFirstElement then
			skipFirstElement = false			
		else
			if page.pageName == pageName then
				page:setVisible(true)
				self.currentPage = page.pageName
				activePageIndx = k - 1
				self.gui:setPage(page)
			else
				page:setVisible(false)
			end
		end
	end
	
	if self.skipFirstElement then
		for _,buttons in pairs(self.elements) do
			for k, button in pairs(buttons.elements) do
				button:setSelected(k == activePageIndx)
			end
			break
		end
	end
end