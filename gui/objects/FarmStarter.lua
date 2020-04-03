
Gc_Gui_FarmStarter = {}
local Gc_Gui_FarmStarter_mt = Class(Gc_Gui_FarmStarter)
Gc_Gui_FarmStarter.xmlFilename = g_company.dir .. "gui/objects/FarmStarter.xml"
Gc_Gui_FarmStarter.debugIndex = g_company.debug:registerScriptName("Gc_Gui_FarmStarter")

function Gc_Gui_FarmStarter:new()
	local self = setmetatable({}, Gc_Gui_FarmStarter_mt)
    
	self.name = "farmStarter"	

	return self
end

function Gc_Gui_FarmStarter:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	  
end;

function Gc_Gui_FarmStarter:onOpen()
	
end

function Gc_Gui_FarmStarter:setData(farms, difficult)
    self.difficult = difficult

    self.gui_table:removeElements();
    
    for i,farm in pairs(farms) do
        self.tmp_farm = farm;
        local item = self.gui_table:createItem();
        item.parameter = i;
    end
    self.tmp_farm = nil;
end

function Gc_Gui_FarmStarter:onClose()
	
end

function Gc_Gui_FarmStarter:onCreate()
    
end

function Gc_Gui_FarmStarter:onClickClose()
    g_company.gui:closeGui("gc_farmStarter")
end

function Gc_Gui_FarmStarter:update(dt)

end

function Gc_Gui_FarmStarter:onCreateHeader(element)
    if self.tmp_farm ~= nil then
        element:setText(g_company.languageManager:getText(self.tmp_farm.header))
    end
end

function Gc_Gui_FarmStarter:onCreateDescription(element)
    if self.tmp_farm ~= nil then
        element:setText(g_company.languageManager:getText(self.tmp_farm.description))
    end
end

function Gc_Gui_FarmStarter:onCreatePreview(element)
    if self.tmp_farm ~= nil then
        if self.difficult == 1 then
            if self.tmp_farm.preview ~= nil then
                element:setImageFilename(self.tmp_farm.preview)
            end
        elseif self.difficult == 2 then
            if self.tmp_farm.preview2 ~= nil then
                element:setImageFilename(self.tmp_farm.preview2)
            end
        end
    end
end

function Gc_Gui_FarmStarter:onDoubleClickSetBox(element, parameter)
    g_company.farmStarter:continueLoading(tonumber(parameter)) 
    self:onClickClose()
end