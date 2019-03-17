--
-- GlobalCompany - Settings
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 16.03.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (16.03.2019):
--
--
-- Notes:
--
--
-- ToDo:
--
--
--



GlobalCompanySettings = {};
local GlobalCompanySettings_mt = Class(GlobalCompanySettings);
InitObjectClass(GlobalCompanySettings, "GlobalCompanySettings");

GlobalCompanySettings.debugIndex = g_company.debug:registerScriptName("GlobalCompany-Settings");


function GlobalCompanySettings:load()
    local self = setmetatable({}, GlobalCompanySettings_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_client ~= nil;    
    
	self.debugData = g_company.debug:getDebugData(GlobalCompanySettings.debugIndex, g_company);

    self.settings = {};

    return self;
end

function GlobalCompanySettings:initSetting(target, name, default, dataTyp)
    if self.settings[name] == nil then
        self.settings[name] = {value=default, target=target, dataTyp=dataTyp};
    else
        g_company.debug:writeDev(self.debugData, "InitSetting: Setting %s already exist", name);
    end;
end

function GlobalCompanySettings:setSetting(name, value)
    if self.settings[name] ~= nil and value ~= nil then
        self.settings[name].value = value;
    else
        g_company.debug:writeDev(self.debugData, "SetSetting: Setting %s not exist", name);        
    end;
end

function GlobalCompanySettings:getSetting(name, ignoreWarning)
    if self.settings[name] ~= nil then
        return self.settings[name].value;
    elseif not ignoreWarning then
        g_company.debug:writeDev(self.debugData, "GetSetting: Setting %s not exist", name);
    end;
end

function GlobalCompanySettings:loadSettings()


end

function GlobalCompanySettings:saveSettings()


end
