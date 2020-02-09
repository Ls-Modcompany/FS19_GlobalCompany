--
-- GlobalCompany - Objects - GlobalMarket
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / kevink98
-- @Date: 25.01.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (25.01.2020):
-- 		- initial fs17(kevink98)
--
-- Notes:
--
--
--
-- ToDo:
--
--

GC_GlobalMarket = {}
GC_GlobalMarket._mt = Class(GC_GlobalMarket)

GC_GlobalMarket.neededExeVersion = 1000;

GC_GlobalMarket.fillTypeTypes = {} 
GC_GlobalMarket.fillTypeTypes.SILO = 1 
GC_GlobalMarket.fillTypeTypes.CONVEYOR = 2 
GC_GlobalMarket.fillTypeTypes.PALLET = 3 
GC_GlobalMarket.fillTypeTypes.BALE = 4 
GC_GlobalMarket.fillTypeTypes.LIQUID = 5
GC_GlobalMarket.fillTypeTypes.WOOD = 6
GC_GlobalMarket.fillTypeTypes.CONVEYORANDBALE = 7

GC_GlobalMarket.priceTrends = {}
GC_GlobalMarket.priceTrends.DOWN = 1
GC_GlobalMarket.priceTrends.OK = 2
GC_GlobalMarket.priceTrends.UP = 3

GC_GlobalMarket.ownFillTypes = {}
GC_GlobalMarket.ownFillTypes.WOOD = -10

GC_GlobalMarket.baleToFilename = {}
GC_GlobalMarket.baleToFilename["GRASS_WINDROW"] = {g_company.dir .. "shop/buyableBales_grassRound.xml", g_company.dir .. "shop/buyableBales_grass.xml" }
GC_GlobalMarket.baleToFilename["DRYGRASS_WINDROW"] = {"data/objects/buyableBales/buyableBales_dryGrassRound.xml", "data/objects/buyableBales/buyableBales_dryGrass.xml"}
GC_GlobalMarket.baleToFilename["STRAW"] = {"data/objects/buyableBales/buyableBales_strawRound.xml", "data/objects/buyableBales/buyableBales_straw.xml"}
GC_GlobalMarket.baleToFilename["SILAGE"] = {"data/objects/buyableBales/buyableBales_silage.xml"}
GC_GlobalMarket.baleToFilename["COTTON"] = {nil, g_company.dir .. "shop/buyableBales_cotton.xml"}


GC_GlobalMarket.fillTypeToFilename = {}
GC_GlobalMarket.fillTypeToFilename["TREESAPLINGS"] = "data/objects/pallets/treeSaplingPallet/treeSaplingPallet.xml"
GC_GlobalMarket.fillTypeToFilename["WOOL"] = "data/objects/pallets/woolPallet/woolPallet.xml"
GC_GlobalMarket.fillTypeToFilename["EGG"] = "data/objects/pallets/eggBox/eggBox.xml"
GC_GlobalMarket.fillTypeToFilename["POPLAR"] = "data/objects/pallets/palletPoplar/palletPoplar.xml"
GC_GlobalMarket.fillTypeToFilename["WOODCHIPS"] = "data/objects/pallets/fillablePallet/fillablePallet.xml"
GC_GlobalMarket.fillTypeToFilename["SUGARBEET"] = "data/objects/pallets/fillablePallet/fillablePallet.xml"
GC_GlobalMarket.fillTypeToFilename["FORAGE"] = "data/objects/pallets/fillablePallet/fillablePallet.xml"
GC_GlobalMarket.fillTypeToFilename["FORAGE_MIXING"] = "data/objects/pallets/fillablePallet/fillablePallet.xml"
GC_GlobalMarket.fillTypeToFilename["CHAFF"] = "data/objects/pallets/fillablePallet/fillablePallet.xml"
--GC_GlobalMarket.fillTypeToFilename["SILAGE"] = "data/objects/pallets/fillablePallet/fillablePallet.xml"
GC_GlobalMarket.fillTypeToFilename["MANURE"] = "data/objects/pallets/fillablePallet/fillablePallet.xml"
GC_GlobalMarket.fillTypeToFilename["PIGFOOD"] = "data/objects/bigBagContainer/bigBagContainerPigFood.xml"

GC_GlobalMarket.fillTypeMapping = {}
GC_GlobalMarket.fillTypeMapping["GRASS"] = "GRASS_WINDROW"
GC_GlobalMarket.fillTypeMapping["DRYGRASS"] = "DRYGRASS_WINDROW"
GC_GlobalMarket.fillTypeMapping["ROUNDBALE_GRASS"] = "GRASS_WINDROW"
GC_GlobalMarket.fillTypeMapping["ROUNDBALE_DRYGRASS"] = "DRYGRASS_WINDROW"
GC_GlobalMarket.fillTypeMapping["ROUNDBALE_WHEAT"] = "STRAW"
GC_GlobalMarket.fillTypeMapping["ROUNDBALE_BARLEY"] = "STRAW"
GC_GlobalMarket.fillTypeMapping["SQUAREBALE_WHEAT"] = "STRAW"
GC_GlobalMarket.fillTypeMapping["SQUAREBALE_BARLEY"] = "STRAW"

function GC_GlobalMarket:new()
    local self = setmetatable({}, GC_GlobalMarket._mt)

    self.paths = {}
    self.paths.mainFolder = getUserProfileAppPath() .. "GlobalCompany_GlobalMarket"
    self.paths.isOnlineFile = self.paths.mainFolder .. "/globalMarketOnline.xml"
    self.paths.fillTypesData = self.paths.mainFolder .. "/fillTypesData.xml"
    self.paths.folderGetFromServer = self.paths.mainFolder .. "/getFromServer"
    self.paths.folderSendToServer = self.paths.mainFolder .. "/sendToServer"
    self.paths.fileForManualSynch = self.paths.mainFolder .. "/doManualSynch.xml"
    self.paths.fileForManualSynchReady = self.paths.mainFolder .. "/doManualSynchReady.xml"

    createFolder(self.paths.mainFolder);
    createFolder(self.paths.folderGetFromServer);
    createFolder(self.paths.folderSendToServer);

    self.isFirstOnline = false
    self.haveFile = false

    self.onChangeFillTypes = {}
    self.runManualSynch = {}
    self.runManualSynchState = false

    g_company.addUpdateable(self, self.update);
    self.timer2sec = 20000

    self.markets = {}
    self.marketId = 0

    self.storeXmlToCapacity = {}

    return self
end

function GC_GlobalMarket:getIsOnline()
    if fileExists(self.paths.isOnlineFile) then
        self.haveFile = true
        local xmlFile = loadXMLFile("gc_globalMarket", self.paths.isOnlineFile)
        local version = getXMLInt(xmlFile, "gc_globalMarket.version")
        delete(xmlFile)
        return version >= g_company.globalMarket.neededExeVersion
    end
    self.haveFile = false
    return false
end

function GC_GlobalMarket:registerMarket(market)
    self.marketId = self.marketId + 1
    self.markets[self.marketId] = market
    return self.marketId
end

function GC_GlobalMarket:unregisterMarket(id)
    self.markets[id] = nil
end

function GC_GlobalMarket:update(dt)
    self.timer2sec = self.timer2sec + dt    

    --timer: 2 sec
    if self.timer2sec >= 2000 then
        self.timer2sec = self.timer2sec - 2000

        if not self.isFirstOnline and self:getIsOnline() then
            self:loadFillTypes()
            self.isFirstOnline = true
        end

        local updateGui = false
        local files = Files:new(self.paths.folderGetFromServer)
        for _,file in pairs(files.files) do           
            local fullPath = self.paths.folderGetFromServer .. "/" .. file.filename
            local xmlFile = loadXMLFile("gc_globalMarket_getFromServer", fullPath)
            local money = getXMLInt(xmlFile, "gc_globalMarket_getFromServer.money")
            local fillLevel = getXMLInt(xmlFile, "gc_globalMarket_getFromServer.fillLevel")
            local sell = getXMLInt(xmlFile, "gc_globalMarket_getFromServer.sell")
            local marketId = getXMLInt(xmlFile, "gc_globalMarket_getFromServer.marketId")
            local fillType = getXMLString(xmlFile, "gc_globalMarket_getFromServer.fillType")
            local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillType)

            local farmId = g_currentMission:getFarmId()
            if sell == 1 then
                if self.isServer then
                    g_currentMission:addMoney(money, farmId, MoneyType.HARVEST_INCOME, true, false)
                else
                    g_client:getServerConnection():sendEvent(GC_GmSendMoneyEvent:new(money, farmId))		
                end
            else
                if self.isServer then
                    g_currentMission:addMoney(-money, farmId, MoneyType.HARVEST_INCOME, true, false)
                else
                    g_client:getServerConnection():sendEvent(GC_GmSendMoneyEvent:new(-money, farmId))		
                end
                if self.markets[marketId] ~= nil then
                    self.markets[marketId]:addFillLevelFromClient(farmId, fillLevel, fillTypeIndex)
                else
                    print(string.format("Invalid market id %s", marketId))                    
                end
            end
            updateGui = true
            g_company.utils.deleteFile(fullPath)
        end
        
        if updateGui and g_company.gui:getGuiIsOpen("gc_globalMarket") then
            self:loadFillTypes()
            g_company.gui:getGui("gc_globalMarket").classGui:loadTableSell()
            g_company.gui:getGui("gc_globalMarket").classGui:loadTableBuy()
        end

        if self.runManualSynchState and fileExists(self.paths.fileForManualSynchReady) then
            self:loadFillTypes()
            for _,s in pairs(self.runManualSynch) do
                s.func(s.target)
            end
            self.runManualSynch = {}
            self.runManualSynchState = false
            g_company.utils.deleteFile(self.paths.fileForManualSynchReady)
        end
    end
end

function GC_GlobalMarket:loadFillTypes()    
    if self.isFirstOnline and not self:getIsOnline() then
        return
    end

    self.fillTypes = {}
    local changeFillTypes = {}
    self.fillTypeToType = {}
    for _,i in pairs(GC_GlobalMarket.fillTypeTypes) do
        self.fillTypes[i] = {}
        changeFillTypes[i] = {}
    end

    if not fileExists(self.paths.fillTypesData) then
        return
    end
    
    local xmlFile = loadXMLFile("gc_globalMarket_fillTypesData", self.paths.fillTypesData)
    
    local i = 0
    while true do
        local key = string.format("gc_globalMarket_fillTypesData.fillTypes.fillType(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local fillType = {}
        fillType.name = getXMLString(xmlFile, key .. "#name")
        fillType.fillLevel = getXMLInt(xmlFile, key .. "#fillLevel")
        fillType.minPrice = getXMLInt(xmlFile, key .. "#minPrice") / 1000
        fillType.maxPrice = getXMLInt(xmlFile, key .. "#maxPrice") / 1000
        fillType.actualPrice = getXMLInt(xmlFile, key .. "#actualPrice") / 1000
        fillType.type = getXMLInt(xmlFile, key .. "#type")
        fillType.priceTrend = getXMLInt(xmlFile, key .. "#priceTrend")
        
        if fillType.type == GC_GlobalMarket.fillTypeTypes.WOOD then
            fillType.index = GC_GlobalMarket.ownFillTypes.WOOD
        else
            fillType.index = g_fillTypeManager:getFillTypeIndexByName(fillType.name)
        end
        if fillType.index ~= nil then
            self.fillTypeToType[fillType.index] = fillType.type
            self.fillTypes[fillType.type][fillType.index] = fillType
            changeFillTypes[fillType.type][fillType.index] = true
        end

        i = i + 1
    end
    
	for _, changeFillTypesE in pairs(self.onChangeFillTypes) do
		changeFillTypesE.func(changeFillTypesE.target, changeFillTypes)
	end
end

function GC_GlobalMarket:setFillTypesForServer(fillTypes)
    self.fillTypes = {}
    for typ, tab in pairs(fillTypes) do
        self.fillTypes[typ] = {}
        for fillTypeIndex, _ in pairs(tab) do
            self.fillTypes[typ][fillTypeIndex] = {}
        end
    end
end

function GC_GlobalMarket:getProvidedFillTypes(fillTyp)
    if self.fillTypes == nil then
        return {}
    end

    local fillTypes = {}
    for typ, tab in pairs(self.fillTypes) do
        for _,typ2 in pairs(fillTyp) do
            if typ == typ2 then
                for index, _ in pairs(tab) do
                    fillTypes[index] = true
                end
            end
        end
    end
    return fillTypes
end

function GC_GlobalMarket:getFillTypesByType(typ)
    return self.fillTypes[typ]
end

function GC_GlobalMarket:getIsFillTypeFromType(fillTypeIndex, types)
    for _,typ in pairs(types) do
        if self.fillTypes[typ] ~= nil and self.fillTypes[typ][fillTypeIndex] ~= nil then
            return true
        end
    end
    return false
end

function GC_GlobalMarket:getPalletFilenameFromFillTypeIndex(fillTypeIndex) 
    local path = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex).palletFilename
    local name = string.upper(g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex))
    if path == nil then
        path = self.fillTypeToFilename[name]
    end
    if name == "COTTON" then
        path = nil
    end
    return path
end

function GC_GlobalMarket:getPriceTrendByFillType(fillTypeIndex)
    return self.fillTypes[self.fillTypeToType[fillTypeIndex]][fillTypeIndex].priceTrend
end

function GC_GlobalMarket:addOnChangeFillTypes(target, func)
	table.insert(self.onChangeFillTypes, {func=func, target=target});
end

function GC_GlobalMarket:calculateActualPrice(fillTypeIndex, level)    
    return self.fillTypes[self.fillTypeToType[fillTypeIndex]][fillTypeIndex].actualPrice * level
end

function GC_GlobalMarket:sellBuyOnMarket(fillTypeIndex, fillLevelDelta, sell, marketId)  
    local freeFile = ""
    local i = 0
    while true do
        local searchPath = string.format("%s/%s.xml", self.paths.folderSendToServer, i)
        if not fileExists(searchPath) then
            freeFile = searchPath
            break;
        end
        i = i + 1
    end

    local xmlFile = createXMLFile("gc_globalMarket_sendToServer", freeFile,"gc_globalMarket_sendToServer");
    local key = "gc_globalMarket_sendToServer"
    
    if fillTypeIndex == GC_GlobalMarket.ownFillTypes.WOOD then
        setXMLString(xmlFile, string.format("%s.sendToServer.fillType", key), "wood")
    else
        setXMLString(xmlFile, string.format("%s.sendToServer.fillType", key), g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex))
    end
    setXMLInt(xmlFile, string.format("%s.sendToServer.fillLevel", key), fillLevelDelta)
    setXMLInt(xmlFile, string.format("%s.sendToServer.marketId", key), marketId)
    if sell then
        setXMLInt(xmlFile, string.format("%s.sendToServer.sell", key), 1)
    else
        setXMLInt(xmlFile, string.format("%s.sendToServer.sell", key), 0)
    end
    
    saveXMLFile(xmlFile);
    delete(xmlFile);
end

function GC_GlobalMarket:doManualSynch(target, func)    
    local xmlFile = createXMLFile("gc_globalMarket_manualSynch", self.paths.fileForManualSynch,"gc_globalMarket_manualSynch");   
    saveXMLFile(xmlFile);
    delete(xmlFile);

    self.runManualSynchState = true
    table.insert(self.runManualSynch, {
        target = target,
        func = func
    })
end

function GC_GlobalMarket:getCapacityByStoreXml(path, isPallet)
    local capacity = 0
    local numBales = 0
    if self.storeXmlToCapacity[paths] ~= nil then
        capacity = self.storeXmlToCapacity[paths]
    else
        local xmlFile = loadXMLFile("tempXml", path)  
        if isPallet then   
            local key = "vehicle.fillUnit.fillUnitConfigurations.fillUnitConfiguration.fillUnits.fillUnit"
            if hasXMLProperty(xmlFile, key) then
                capacity = getXMLInt(xmlFile, key .. "#capacity")
            end    
        else  
            local key = "vehicle.storeData.specs.capacity"
            if hasXMLProperty(xmlFile, key) then
                capacity = getXMLInt(xmlFile, key)                
            end    

            key = "vehicle.buyableBale.balePositions"
            while true do
                if hasXMLProperty(xmlFile, string.format("%s.balePosition(%d)", key, numBales)) then
                    numBales = numBales + 1
                else
                    break
                end  
            end
        end
        delete(xmlFile)
    end
    if capacity ~= 0 then
        self.storeXmlToCapacity[path] = capacity
    end
    return capacity, numBales
end

