-- 
-- GUI-FakeGui
-- 
-- @Interface: 1.4.4.0 1.4.4RC8
-- @Author: kevink98 
-- @Date: 22.06.2017
-- @Version: 1.0.0
-- 
-- @Support: LS-Modcompany
-- 

FakeGui = {};
FakeGui.guiInformations = {};
FakeGui.guiInformations.guiXml = "gui/FakeGui.xml";
getfenv(0)["GC_Gui_FakeGui"] = FakeGui;

local FakeGui_mt = Class(FakeGui, ScreenElement);

function FakeGui:new(target, custom_mt)
    return ScreenElement:new(target, FakeGui_mt);
end;
function FakeGui:onCreate() 
	self.exit = true;
end;

function FakeGui:update(dt)
	FakeGui:superClass().update(self, dt);
end
function FakeGui:onOpen()
    FakeGui:superClass().onOpen(self);	
end
function FakeGui:onClose(element)
    FakeGui:superClass().onClose(self);
end
function FakeGui:onClickBack()
	if self.exit then
		g_company.gui:closeActiveGui();
		g_gui:showGui("");
	end;
end;
function FakeGui:setExit(val)
	self.exit = val;	
end;














