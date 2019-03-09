





Gc_Gui_Baler = {};
Gc_Gui_Baler.xmlFilename = g_company.dir .. "gui/objects/Baler.xml";
Gc_Gui_Baler.debugIndex = g_company.debug:registerScriptName("GC_GUI_Baler");

local Gc_Gui_Baler_mt = Class(Gc_Gui_Baler);



function Gc_Gui_Baler:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_Baler_mt;
    end;
	local self = setmetatable({}, Gc_Gui_Baler_mt);
			
	return self;
end;

function Gc_Gui_Baler:onCreate()


end;

function Gc_Gui_Baler:onOpen()
    
end

function Gc_Gui_Baler:update(dt)

end

function Gc_Gui_Baler:onClose(element)

end

function Gc_Gui_Baler:setData(hotel)
    self.hotel = hotel;
end



