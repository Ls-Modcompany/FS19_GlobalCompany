
Gc_Gui_Market = {}
local Gc_Gui_Market_mt = Class(Gc_Gui_Market)
Gc_Gui_Market.xmlFilename = g_company.dir .. "gui/objects/GcMain_Market.xml"
Gc_Gui_Market.debugIndex = g_company.debug:registerScriptName("Gc_Gui_Market")

function Gc_Gui_Market:new()
	local self = setmetatable({}, Gc_Gui_Market_mt)
    
	self.name = "factories"	
	


	return self
end

function Gc_Gui_Market:keyEvent(unicode, sym, modifier, isDown, eventUsed)

end;

function Gc_Gui_Market:onOpen()
end

function Gc_Gui_Market:onClose()
	
end

function Gc_Gui_Market:onCreate()
end

function Gc_Gui_Market:onClickClose()
    g_company.gui:closeActiveGui()
end

function Gc_Gui_Market:update(dt)
	
end
