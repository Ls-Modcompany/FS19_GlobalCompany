--
-- GlobalCompany - DebugManager
--
-- @Interface: 1.5.1.0 b6730
-- @Author: LS-Modcompany
-- @Date: 18.01.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.0.0.0 (18.01.2020):
--

GC_DebugManager = {}
GC_DebugManager._mt = Class(GC_DebugManager)

GC_DebugManager.constant_count = 0
local function getNextCount() 
    GC_DebugManager.constant_count = GC_DebugManager.constant_count + 1
    return GC_DebugManager.constant_count
end

GC_DebugManager.REGISTERCLASS = getNextCount()

function GC_DebugManager:new()
    
    local self = {}
    setmetatable(self, GC_DebugManager._mt)

    self.registeredClassesIds = 0
    self.registeredClassesByName = {}
    self.registeredClassesById = {}

    self.savedErrors = {}


    self.printTextHeader = "  [LSMC - GlobalCompany > GC_DebugManager]"

    return self
end

function GC_DebugManager:registerClass(className, isSpec)
    if type(className) ~= "string" then
        self.printError("%s - 'registerClass' failed! %s is not a string value.", self.printTextHeader, tostring(scriptName))
        return
    end

    if self.registeredClassesByName[className] == nil then
        self.registeredClassesIds = self.registeredClassesIds + 1
        self.registeredClassesByName[className] = self.registeredClassesIds
        self.registeredClassesById[self.registeredClassesIds] = className

        return self.registeredClassesIds
    elseif not isSpec then
        self.printError("%s - Script name %s is already registered! Registered Script Id = %d", className, self.registeredClassesByName[className])
    else
        return self.registeredClasses[className]
    end
end

function GC_DebugManager:printError(format, ...)
    local text = string.format(format, ...)
    print(text)
    table.insert(self.savedErrors, text)
end

function GC_DebugManager:createDebugObject(isServer, isClient, scriptDebugInfo, target, customEnvironment)
    return GC_DebugManagerObject:new(isServer, isClient, scriptDebugInfo, target, customEnvironment)
end

GC_DebugManagerObject = {}
GC_DebugManagerObject._mt = Class(GC_DebugManagerObject)

function GC_DebugManagerObject:new(isServer, isClient, scriptDebugInfo, target, customEnvironment)
    local self = {}
    setmetatable(self, GC_DebugManagerObject._mt)
    
    self.isServer = isServer
    self.isClient = isClient
    self.customEnvironment = customEnvironment

    local modname
    local scriptname = g_company.debugManager.registeredClassesById[scriptDebugInfo]

    if target ~= nil then
        self.target = target.debug
        if self.customEnvironment ~= nil then
            modname = tostring(self.customEnvironment)
        elseif self.target.customEnvironment ~= nil then
            modname = tostring(self.target.customEnvironment)
        end
    else
        if self.customEnvironment ~= nil then
            modname = tostring(self.customEnvironment)
        end
    end

    self.printTextHeader = string.format("  [LSMC - GlobalCompany] - [%s] - [%s]", modname, scriptname)

    return self
end