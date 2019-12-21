-- 
-- Gui - Element - GC_Gui_page 
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


GC_Gui_page = {}
local GC_Gui_page_mt = Class(GC_Gui_page, GC_Gui_element)

GC_Gui_page.debugIndex = g_company.debug:registerScriptName("GlobalCompany-GC_Gui_page")

function GC_Gui_page:new(gui, custom_mt)	
	if custom_mt == nil then
        custom_mt = GC_Gui_page_mt
    end
	local self = GC_Gui_element:new(gui, custom_mt)

    self.debugData = g_company.debug:getDebugData(GC_Gui_page.debugIndex, g_company);
    
	return self
end


function GC_Gui_page:loadTemplate(templateName, xmlFile, key)
	GC_Gui_page:superClass().loadTemplate(self, templateName, xmlFile, key)
    
	if xmlFile ~= nil then
		self.pageName = g_company.gui:getTemplateValueXML(xmlFile, "pageName", key, nil);
		self.pageHeader = g_company.gui:getTemplateValueXML(xmlFile, "pageHeader", key, nil);
	end
	
	if self.pageName == nil then
		g_company.debug:writeError(self.debugData, "No pagename defined.")
	end

	self:loadOnCreate()
end


function GC_Gui_page:copy(src)
	GC_Gui_page:superClass().copy(self, src)

	self:copyOnCreate()
end

function GC_Gui_page:delete()
	GC_Gui_page:superClass().delete(self)

end

function GC_Gui_page:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	return GC_Gui_page:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function GC_Gui_page:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	GC_Gui_page:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function GC_Gui_page:update(dt)
	GC_Gui_page:superClass().update(self, dt)
end

function GC_Gui_page:draw(index)
	self.drawPosition[1], self.drawPosition[2] = g_company.gui:calcDrawPos(self, index)	
	
	
	
	GC_Gui_page:superClass().draw(self)
end