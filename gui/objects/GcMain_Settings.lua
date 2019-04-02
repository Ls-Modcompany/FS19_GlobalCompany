





Gc_Gui_MainSettings = {};
Gc_Gui_MainSettings.xmlFilename = g_company.dir .. "gui/objects/GcMain_Settings.xml";
Gc_Gui_MainSettings.debugIndex = g_company.debug:registerScriptName("Gc_Gui_MainSettings");


local Gc_Gui_MainSettings_mt = Class(Gc_Gui_MainSettings);

function Gc_Gui_MainSettings:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_MainSettings_mt;
    end;
	local self = setmetatable({}, Gc_Gui_MainSettings_mt);
        self.name = "settings"
	return self;
end;

function Gc_Gui_MainSettings:onCreate() 

end;

function Gc_Gui_MainSettings:onOpen() 
    self:loadSettings();
end;

function Gc_Gui_MainSettings:onClose() 

end;

function Gc_Gui_MainSettings:loadSettings()
    self.gui_btn_settings_1:setActive(g_company.settings:getSetting("extendedPlaceable"));
    self.gui_btn_settings_2:setActive(g_company.settings:getSetting("objectInfo"));
    self.gui_btn_settings_3:setActive(g_company.settings:getSetting("horseHelper"));
    self.gui_btn_settings_4:setActive(g_company.settings:getSetting("moreTrees"));
end;

function Gc_Gui_MainSettings:onClickBtnSetting(btn, parameter)
    g_company.settings:setSetting(parameter, btn:getActive());
end;