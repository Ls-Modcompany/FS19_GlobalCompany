--
-- GlobalCompany - Objects - GC_ProgrammFlow
--
-- @Interface: 1.3.0.1 b4009
-- @Author: LS-Modcompany / kevink98
-- @Date: 24.02.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (24.02.2020):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
--
-- ToDo:
--
--
--

GC_ProgrammFlow = {}
GC_ProgrammFlow._mt = Class(GC_ProgrammFlow, g_company.gc_class)
InitObjectClass(GC_ProgrammFlow, "GC_ProgrammFlow")

function GC_ProgrammFlow:new(isServer, isClient, customMt)
	return GC_ProgrammFlow:superClass():new(GC_ProgrammFlow._mt, isServer, isClient, scriptDebugInfo)
end

function GC_ProgrammFlow:load(rootNode, target, xmlFile, xmlKey, parentClass)
    GC_ProgrammFlow:superClass().load(self)
    
    self.rootNode = rootNode
    self.target = target
    self.parentClass = parentClass

    self.variables = {}
    self.functions = {}
    self.loops = {}
    self.triggers = {}

    self.init = {}
    self:loadXmlRecursive(xmlFile, xmlKey .. ".init", self.init)
    self:runRecursive(self.init)

    local i = 0
    while true do
        local triggerKey = string.format("%s.triggers.trigger(%d)", xmlKey, i)
        if not hasXMLProperty(xmlFile, triggerKey) then
            break
        end

        local trigger = {}
        
        trigger.className = getXMLString(xmlFile, triggerKey .. "#class")
        trigger.trigger = target.triggerManager:addTrigger(g_company[trigger.className], target.rootNode, target, xmlFile, triggerKey, {})
        trigger.trigger.programmFlow = self
                    
        trigger.events = {}
        local j = 0
        while true do
            local eventKey = string.format("%s.event(%d)", triggerKey, j)
            if not hasXMLProperty(xmlFile, eventKey) then
                break
            end
            local event = {}
            event.mode = getXMLString(xmlFile, eventKey .. "#mode")
            event.set = getXMLString(xmlFile, eventKey .. "#set")
            event.value = getXMLString(xmlFile, eventKey .. "#value")

            table.insert(trigger.events, event)

            j = j + 1
        end

        table.insert(self.triggers, trigger)

        i = i + 1
    end

    
    i = 0
    while true do
        local loopKey = string.format("%s.loops.loop(%d)", xmlKey, i)
        if not hasXMLProperty(xmlFile, loopKey) then
            break
        end

        local loop = {}

        loop.updateCounterMs = 0
        loop.updateMs = getXMLInt(xmlFile, loopKey .. "#updateMs")
        
        self:loadXmlRecursive(xmlFile, loopKey, loop)
        table.insert(self.loops, loop)

        i = i + 1
    end

    if g_company.utils.getTableLength(self.loops) > 0 then
        g_company.addUpdateable(self, self.update)
    end


    return true
end

function GC_ProgrammFlow:finalizePlacement()
    GC_ProgrammFlow:superClass().finalizePlacement(self)	
end
    

function GC_ProgrammFlow:delete()
	GC_ProgrammFlow:superClass().delete(self)
    g_company.removeUpdateable(self, self.update)
end

function GC_ProgrammFlow:readStream(streamId, connection)
	GC_ProgrammFlow:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then	
    end
end

function GC_ProgrammFlow:writeStream(streamId, connection)
	GC_ProgrammFlow:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
    end
end

function GC_ProgrammFlow:update(dt)
    GC_ProgrammFlow:superClass().update(self, dt)
    
    self.currentDt = dt

    for _,loop in pairs(self.loops) do
        local run = false
        if loop.updateMs == nil then
            run = true
        else
            loop.updateCounterMs = loop.updateCounterMs + dt
            if loop.updateCounterMs >= loop.updateMs then
                loop.updateCounterMs = loop.updateCounterMs - loop.updateMs
                run = true
            end
        end

        if run then
            self:runRecursive(loop)
        end        
    end
end

function GC_ProgrammFlow:loadXmlRecursive(xmlFile, elementKey, element)
    if not hasXMLProperty(xmlFile, elementKey) then
        return
    end

    element.code = {}

    local i = 0
    while true do
        local actionKey = string.format("%s.action(%d)", elementKey, i)
        if not hasXMLProperty(xmlFile, actionKey) then
            break
        end
        local typ = getXMLString(xmlFile, actionKey .. "#type")
        if typ == "if" then
            local if_ = {
                typ = typ,
                value = getXMLString(xmlFile, actionKey .. "#value"),
                compare = getXMLString(xmlFile, actionKey .. "#compare"),
                compareValue = getXMLString(xmlFile, actionKey .. "#compareValue") 
            }
            
            if_.then_ = {}
            if_.elseif_ = {}
            if_.else_ = {}

            self:loadXmlRecursive(xmlFile, actionKey .. ".then", if_.then_)
            self:loadXmlRecursive(xmlFile, actionKey .. ".elseif", if_.elseif_)
            self:loadXmlRecursive(xmlFile, actionKey .. ".else", if_.else_)

            table.insert(element.code, if_)
        elseif typ == "math" then
            table.insert(element.code, {
                typ = typ,
                operator = getXMLString(xmlFile, actionKey .. "#operator"),
                value1 = getXMLString(xmlFile, actionKey .. "#value1"),
                value2 = getXMLString(xmlFile, actionKey .. "#value2"),
                set = getXMLString(xmlFile, actionKey .. "#set")
            })
        elseif typ == "print" then
            table.insert(element.code, {
                typ = typ,
                text = getXMLString(xmlFile, actionKey .. "#text")
            })
        else
            table.insert(element.code, {
                typ = "functionVar",
                call = getXMLString(xmlFile, actionKey .. "#call"),
                parameters = getXMLString(xmlFile, actionKey .. "#parameters"),
                value = getXMLString(xmlFile, actionKey .. "#value"),
                set = getXMLString(xmlFile, actionKey .. "#set") 
            })
        end

        i = i + 1
    end
end

function GC_ProgrammFlow:registerFunction(target, func, name, secTarget)
    table.insert(self.functions, {target = target, func = func, name=name, secTarget=secTarget})
end

function GC_ProgrammFlow:runFunction(name, parameters)
    for _,data in pairs(self.functions) do
        if data.name == name then
            if data.secTarget ~= nil then
                return data.func(data.target, data.secTarget, parameters)
            else
                return data.func(data.target, parameters)
            end
        end
    end
end

function GC_ProgrammFlow:runRecursive(element)
    for _,action in pairs(element.code) do
        if action.typ == "functionVar" then
            if action.call ~= nil then
                if action.set ~= nil then
                    self.variables[action.set] = self:runFunction(action.call, action.parameters)
                else
                    self:runFunction(action.call, action.parameters)
                end
            elseif action.value ~= nil then
                self.variables[action.set] = g_company.dataTypeConverter:parseValue(action.value)
            end
        elseif action.typ == "math" then
            self:runMath(action)
        elseif action.typ == "print" then
            print(self:getVariableValue(action.text))
        elseif action.typ == "if" then
            if self:checkIf(action) then
                if action.then_.code ~= nil then
                    self:runRecursive(action.then_)
                end
            else
                if action.else_.code ~= nil then
                    self:runRecursive(action.else_)
                end
            end
        end
    end
end

function GC_ProgrammFlow:getVariableValue(variableName)
    if self.variables[variableName] ~= nil then
        return self.variables[variableName]
    elseif variableName == "dt" then
        return Utils.getNoNil(self.currentDt, 0)
    else
        return g_company.dataTypeConverter:parseValue(variableName)
    end
end

function GC_ProgrammFlow:checkIf(action)
    local value = self:getVariableValue(action.value)        
    local compareValue = self:getVariableValue(action.compareValue) --g_company.dataTypeConverter:convertValueToDataTypeByValue
   
    if value == nil then
        print(string.format("if - value is nil %s %s %s", action.value, action.compare, action.compareValue))
        return false
    end
    if action.compare ~= nil and compareValue == nil then
        print(string.format("compareValue - value is nil %s %s %s", action.value, action.compare, action.compareValue))
        return false
    end

    if action.compare == "<" or action.compare == "lt" then
        return value < compareValue
    elseif action.compare == "<=" or action.compare == "lte" then
        return value <= compareValue    
    elseif action.compare == ">" or action.compare == "gt" then
        return value > compareValue
    elseif action.compare == ">=" or action.compare == "gte" then
        return value >= compareValue
    elseif action.compare == "==" or action.compare == "e" then
        return value == compareValue
    elseif action.compare == "~=" or action.compare == "ne" then
        return value ~= compareValue
    elseif action.compare == nil then
        return value
    end
end

function GC_ProgrammFlow:onCallEvent(trigger, mode)
    for _,triggerE in pairs(self.triggers) do
        if triggerE.trigger == trigger then
            for _,event in pairs(triggerE.events) do
                if event.mode == mode then
                    self.variables[event.set] = g_company.dataTypeConverter:parseValue(event.value)
                    return
                end
            end
        end
    end
end

function GC_ProgrammFlow:runMath(action)
    local value1 = self:getVariableValue(action.value1)        
    local value2 = self:getVariableValue(action.value2)
    
    if action.operator == "+" then
        self.variables[action.set] = value1 + value2
    elseif action.operator == "-" then
        self.variables[action.set] = value1 - value2
    elseif action.operator == "*" then
        self.variables[action.set] = value1 * value2
    elseif action.operator == "/" then
        self.variables[action.set] = value1 / value2
    end
end