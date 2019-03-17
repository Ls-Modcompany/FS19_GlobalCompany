--
-- GlobalCompany - Additionals - GC_Objectinfo
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98 / aPuehri
-- @Date: 09.03.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (09.03.2019):
-- 		- initial fs19 (kevink98/aPuehri)
--
--
-- Notes:
--
--
-- ToDo:
--
--

Gc_Gui_ObjectInfo = {};
Gc_Gui_ObjectInfo.xmlFilename = g_company.dir .. "gui/objects/ObjectInfo.xml";
Gc_Gui_ObjectInfo.debugIndex = g_company.debug:registerScriptName("Gc_Gui_ObjectInfo");

local Gc_Gui_ObjectInfo_mt = Class(Gc_Gui_ObjectInfo);

function Gc_Gui_ObjectInfo:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_ObjectInfo_mt;
    end;
	return setmetatable({}, custom_mt);
end;

function Gc_Gui_ObjectInfo:onCreate() end;
function Gc_Gui_ObjectInfo:onOpen() end;
function Gc_Gui_ObjectInfo:update(dt) end;
function Gc_Gui_ObjectInfo:onClose() end;

function Gc_Gui_ObjectInfo:setData(line1, line2, line3)
    self.gui_line1:setText(line1);
    self.gui_line2:setText(line2);
	self.gui_line3:setText(line3);
end;