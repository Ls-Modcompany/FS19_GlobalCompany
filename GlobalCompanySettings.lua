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
	--self.isClient = g_client ~= nil;    
    
	self.debugData = g_company.debug:getDebugData(GlobalCompanySettings.debugIndex, g_company);

    self.settings = {};
    self.loadedSettings = {};

    self.needSynch = false;
    g_company.addUpdateable(self, self.update);	

	self.eventId_setSetting = g_company.eventManager:registerEvent(self, self.setSettingEvent);
	self.eventId_loadSettings = g_company.eventManager:registerEvent(self, self.loadSettingsEvent, true);
	self.eventId_loadSettings2 = g_company.eventManager:registerEvent(self, self.loadSettingsEvent2, true);
    return self;
end

function GlobalCompanySettings:initSetting(name, default)
    if g_server == nil then
        return;
    end;
    if self.settings[name] == nil then
        if self.loadedSettings[name] ~= nil then
            default = self.loadedSettings[name];
        end;
        self.settings[name] = default;
    else
        g_company.debug:writeDev(self.debugData, "InitSetting: Setting %s already exist", name);
    end;
end

function GlobalCompanySettings:setSetting(name, value, noEventSend)
	self:setSettingEvent({name, value}, noEventSend); 
end

function GlobalCompanySettings:setSettingEvent(data, noEventSend)
	g_company.eventManager:createEvent(self.eventId_setSetting, data, false, noEventSend);
    if self.settings[data[1]] ~= nil and data[2] ~= nil then
        self.settings[data[1]] = data[2];
    else
        g_company.debug:writeDev(self.debugData, "SetSetting: Setting %s not exist", data[1]);        
    end;
end

function GlobalCompanySettings:getSetting(name)
    return self.settings[name];
end

function GlobalCompanySettings:haveSetting(name)
    return self.settings[name] ~= nil;
end

function GlobalCompanySettings:loadSettings()   
    if g_server == nil then
        self.needSynch = true;
        return;
    end;
    
	if g_server ~= nil then 	
		local savegameIndex = g_currentMission.missionInfo.savegameIndex;
		local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
		if savegameFolderPath == nil then
			savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), savegameIndex);
		end;
		if fileExists(savegameFolderPath .. '/globalCompany.xml') then
			local xmlFile = loadXMLFile("globalCompany", savegameFolderPath .. '/globalCompany.xml',"globalCompany");
            local key = "globalCompany";
            if hasXMLProperty(xmlFile, key) then   
                local i = 0;
                while true do
                    local settingKey = string.format("%s.settings.setting(%d)", key, i);
                    if not hasXMLProperty(xmlFile, settingKey) then
                        break;
                    end;

                    local name = getXMLString(xmlFile, settingKey .. "#name");
                    local value = getXMLBool(xmlFile, settingKey .. "#value");
                    g_company.settings.loadedSettings[name] = value;
                    i = i + 1;
                end;
            end;
			delete(xmlFile);
		end;
	end;
end

function GlobalCompanySettings:loadSettingsEvent(data, noEventSend)   
    if g_server == nil then
        g_company.eventManager:createEvent(self.eventId_loadSettings, {}, false, noEventSend);
    else
        self:loadSettingsEvent2();
    end;
end;

function GlobalCompanySettings:loadSettingsEvent2(data, noEventSend)   
    if g_server ~= nil then
        g_company.eventManager:createEvent(self.eventId_loadSettings2, self.settings, true, noEventSend);
    else
        self.settings = data;
    end;
end;

function GlobalCompanySettings:saveSettings()
    if g_server ~= nil then 		
		local savegameIndex = g_currentMission.missionInfo.savegameIndex;
		local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
		if savegameFolderPath == nil then
			savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), savegameIndex);
		end;
        --if fileExists(savegameFolderPath .. '/globalCompany.xml') then

        --end;
        local xmlFile = createXMLFile("globalCompany", savegameFolderPath .. '/globalCompany.xml',"globalCompany");
        local key = "globalCompany";
        
        local i = 0;
        for name, value in pairs(g_company.settings.settings) do
            setXMLString(xmlFile, string.format("%s.settings.setting(%d)#name", key, i), name);
            setXMLBool(xmlFile, string.format("%s.settings.setting(%d)#value", key, i), value);
            i = i + 1;
        end;

        saveXMLFile(xmlFile);
        delete(xmlFile);
	end;
end

function GlobalCompanySettings:update(dt)
    if self.needSynch then
        self:loadSettingsEvent();
        self.needSynch = false;
    end;
    g_company.removeUpdateable(self, self.update);	
end;