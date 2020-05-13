--
-- GlobalCompany - Objects - GC_ProgrammFlow_GlobalFunctions
--
-- @Interface: 1.3.0.1 b4009
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.02.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (26.02.2020):
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

GC_ProgrammFlowGlobalFunctions = {}
g_company.programmFlowGlobalFunction = GC_ProgrammFlowGlobalFunctions

function GC_ProgrammFlowGlobalFunctions:registerToProgrammFlow(target, programmFlow)
    programmFlow:registerFunction(g_company.programmFlowGlobalFunction, g_company.programmFlowGlobalFunction.setFrictionVelocity, "setFrictionVelocity", target)




end

--[[   Enginefunction setFrictionVelocity
* 1 * -> Name of node(i3dMapping) (string) 
* 2 * -> Velocity (float)
]]--
function GC_ProgrammFlowGlobalFunctions:setFrictionVelocity(target, parameters)
    if g_server == nil then return end
    local parsedParameters = g_company.dataTypeConverter:parseParameters(parameters, " ")

    local node = I3DUtil.indexToObject(target.rootNode, parsedParameters[1], target.i3dMappings)
    setFrictionVelocity(node, parsedParameters[2])	
end
