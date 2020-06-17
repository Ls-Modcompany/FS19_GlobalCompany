--
-- GlobalCompany - Additionals - GC_FarmStarter
--
-- @Interface: 1.4.1.0 b5332
-- @Author: LS-Modcompany / aPuehri
-- @Date: 29.03.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (9.03.2020):
-- 		- initial fs19
--
--
-- Notes:
--
--
-- ToDo:
-- 
--
--

GC_FarmStarter = {}
GC_FarmStarter._mt = Class(GC_FarmStarter)
InitObjectClass(GC_FarmStarter, "GC_FarmStarter")

GC_FarmStarter.carrerScreen_startGame_stored = Mission00.loadMapFinished

g_company.farmStarter = GC_FarmStarter
g_company.farmStarter.runFirst = false

function GC_FarmStarter.loadMapFinished(s, node, arguments, callAsyncCallback)
    local continueLoading = false
    if g_company.farmStarter.runFirst == false then
        g_company.farmStarter.savedParameters_target = s
        g_company.farmStarter.savedParameters_values = {node, arguments, callAsyncCallback}
        g_company.farmStarter.used = false

        if (s.missionInfo.playTime == 0 or s.missionInfo.playTime == nil) and not s.missionDynamicInfo.isMultiplayer and s.missionInfo.difficulty < 3 then
            g_company.farmStarter.farms = {}

            local xmlPath = s.baseDirectory .. "globalCompany.xml"
            if not fileExists(xmlPath) then
                continueLoading = true
                xmlPath = s.baseDirectory .. "xml/globalCompany.xml"
                if fileExists(xmlPath) then
                    continueLoading = false
                end
            end
            
            if not continueLoading then
                local xmlFile = loadXMLFile("globalCompany", xmlPath)


                if hasXMLProperty(xmlFile, "globalCompany.farmStarter") then                
                    local i = 0
                    while true do
                        local key = string.format("globalCompany.farmStarter.farm(%d)", i)
                        if not hasXMLProperty(xmlFile, key) then
                            break
                        end

                        local farm = {
                            header = Utils.getNoNil(getXMLString(xmlFile, key .. "#header"), string.format("Header %s", i+1)),
                            description = Utils.getNoNil(getXMLString(xmlFile, key .. "#description"), string.format("Description %s", i+1)),
                            preview = s.baseDirectory .. getXMLString(xmlFile, key .. "#preview"),
                            preview2 = s.baseDirectory .. getXMLString(xmlFile, key .. "#preview2"),
                            xmlItems = s.baseDirectory .. getXMLString(xmlFile, key .. ".items"),
                            xmlVehicles = s.baseDirectory .. getXMLString(xmlFile, key .. ".vehicles"),
                            money1 = getXMLInt(xmlFile, key .. ".money1"),
                            money2 = getXMLInt(xmlFile, key .. ".money2"),
                        }

                        farm.farmlands = {}
                        local j = 0
                        while true do
                            local key2 = string.format("%s.farmlands.farmland(%d)", key, j)    
                            if not hasXMLProperty(xmlFile, key2) then
                                break
                            end    
                            table.insert(farm.farmlands, getXMLInt(xmlFile, key2))
                            j = j + 1
                        end           

                        table.insert(g_company.farmStarter.farms, farm)                
                        i = i + 1
                    end   
                    g_company.gui:openGuiWithData("gc_farmStarter", false, g_company.farmStarter.farms, s.missionInfo.difficulty)
                    g_company.farmStarter.used = true
                else
                    continueLoading = true
                end        
            end
        else
            continueLoading = true
        end
    end

    if g_company.farmStarter.runFirst == false then
        g_company.farmStarter.runFirst = true
        return continueLoading
    end 
    return continueLoading or g_company.farmStarter.runFirst
end

function GC_FarmStarter:continueLoading(farmId)       
    if g_company.farmStarter.used and farmId ~= nil and g_company.farmStarter.farms[farmId] ~= nil then
        local farm = g_company.farmStarter.farms[farmId]
        g_company.farmStarter.buyFarmlands = farm.farmlands
        if g_company.farmStarter.savedParameters_target.missionInfo.difficulty == 1 then
            g_company.farmStarter.changeMoney = farm.money1
            g_company.farmStarter.savedParameters_target.missionInfo.vehiclesXMLLoad = farm.xmlVehicles
            g_company.farmStarter.savedParameters_target.missionInfo.itemsXMLLoad = farm.xmlItems
        elseif g_company.farmStarter.savedParameters_target.missionInfo.difficulty == 2 then
            g_company.farmStarter.changeMoney = farm.money2
            g_company.farmStarter.savedParameters_target.missionInfo.itemsXMLLoad = farm.xmlItems
        end
    end 
    FSBaseMission.loadMapFinished(g_company.farmStarter.savedParameters_target, unpack(g_company.farmStarter.savedParameters_values))
end

function GC_FarmStarter:onStartMission()
	if g_company.farmStarter.used and g_currentMission:getIsServer() and not g_currentMission.missionInfo.isValid and not g_currentMission.missionDynamicInfo.isMultiplayer then	        
        if g_company.farmStarter.changeMoney ~= nil then
            local money = (g_currentMission:getMoney(1) * -1) + g_company.farmStarter.changeMoney                    
            g_currentMission:addMoney(money, 1, MoneyType.TRANSFER, true)
        end        
        if g_company.farmStarter.buyFarmlands ~= nil then
            for _,farmlandId in pairs(g_company.farmStarter.buyFarmlands) do
                g_farmlandManager:consoleCommandBuyFarmland(farmlandId)
            end
        end
    end
end

-- make sure, that we append it at very last, that we can break all other appended functions
function GC_FarmStarter:loadMap()
    FSBaseMission.loadMapFinished = g_company.utils.interruptFunction(FSBaseMission.loadMapFinished, GC_FarmStarter.loadMapFinished)
end

FSBaseMission.loadMap = Utils.appendedFunction(FSBaseMission.loadMap, GC_FarmStarter.loadMap)
Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, GC_FarmStarter.onStartMission)

function GC_FarmStarter:loadFromXMLFile(xmlFile, key, resetVehicles)    
    local oldValue = self.boughtWithFarmland
    self.boughtWithFarmland = Utils.getNoNil(getXMLBool(xmlFile, key .. "#boughtWithFarmland"), self.boughtWithFarmland)

    if self.boughtWithFarmland ~= oldValue then
        if self.boughtWithFarmland then
            if self.isServer then
                self:updateOwnership(true)
            end
            g_farmlandManager:addStateChangeListener(self)
        end
    end
end

function GC_FarmStarter:saveToXMLFile(xmlFile, key, usedModNames)   
    setXMLBool(xmlFile, key.."#boughtWithFarmland", self.boughtWithFarmland)
end 

Placeable.loadFromXMLFile = g_company.utils.appendedFunction2(Placeable.loadFromXMLFile, GC_FarmStarter.loadFromXMLFile)
Placeable.saveToXMLFile = g_company.utils.appendedFunction2(Placeable.saveToXMLFile, GC_FarmStarter.saveToXMLFile)