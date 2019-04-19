

Gc_Gui_FactorySmall = {};
Gc_Gui_FactorySmall.xmlFilename = g_company.dir .. "gui/objects/FactorySmall.xml";
Gc_Gui_FactorySmall.debugIndex = g_company.debug:registerScriptName("Gc_Gui_FactorySmall");

local Gc_Gui_FactorySmall_mt = Class(Gc_Gui_FactorySmall);

function Gc_Gui_FactorySmall:new(target, custom_mt)
	local self = {};
	setmetatable(self, customMt or Gc_Gui_FactorySmall_mt);
	
	return self;
end;

function Gc_Gui_FactorySmall:onCreate()
end;

function Gc_Gui_FactorySmall:onOpen()
	--g_depthOfFieldManager:setBlurState(true)
end;

function Gc_Gui_FactorySmall:update(dt)
end;

function Gc_Gui_FactorySmall:onClose()
	--g_depthOfFieldManager:setBlurState(false)
end;

function Gc_Gui_FactorySmall:setData(fabric, lineId)
    self.currentFactory = fabric;
    self.currentLineId = lineId;
	
	
	self.gui_productLineName:setText(fabric.productLines[lineId].title);
end




