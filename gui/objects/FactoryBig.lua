





Gc_Gui_FactoryBig = {};
Gc_Gui_FactoryBig.xmlFilename = g_company.dir .. "gui/objects/FactoryBig.xml";
Gc_Gui_FactoryBig.debugIndex = g_company.debug:registerScriptName("Gc_Gui_FactoryBig");

local Gc_Gui_FactoryBig_mt = Class(Gc_Gui_FactoryBig);

function Gc_Gui_FactoryBig:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_FactoryBig_mt;
    end;
	local self = setmetatable({}, Gc_Gui_FactoryBig_mt);
			
	return self;
end;

function Gc_Gui_FactoryBig:onCreate() end;

function Gc_Gui_FactoryBig:onOpen() 
    g_depthOfFieldManager:setBlurState(true)
end;

function Gc_Gui_FactoryBig:onClose() 
    g_depthOfFieldManager:setBlurState(false)
end;

