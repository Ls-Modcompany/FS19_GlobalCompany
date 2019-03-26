





Gc_Gui_Settings = {};
Gc_Gui_Settings.xmlFilename = g_company.dir .. "gui/objects/Settings.xml";
Gc_Gui_Settings.debugIndex = g_company.debug:registerScriptName("Gc_Gui_Settings");

local Gc_Gui_Settings_mt = Class(Gc_Gui_Settings);

function Gc_Gui_Settings:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_Settings_mt;
    end;
	local self = setmetatable({}, Gc_Gui_Settings_mt);
			
	return self;
end;

function Gc_Gui_Settings:onCreate() end;

function Gc_Gui_Settings:onOpen() 
    self.gui_btn_settings_1:setActive(g_company.settings:getSetting("extendedPlaceable"));
    self.gui_btn_settings_2:setActive(g_company.settings:getSetting("objectInfo"));
    self.gui_btn_settings_3:setActive(g_company.settings:getSetting("horseHelper"));
    self.gui_btn_settings_4:setActive(g_company.settings:getSetting("moreTrees"));
end;

function Gc_Gui_Settings:onClickBtnSetting(btn, parameter)
    g_company.settings:setSetting(parameter, btn:getActive());
end;