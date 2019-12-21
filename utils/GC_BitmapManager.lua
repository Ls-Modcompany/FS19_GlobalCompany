-- 
-- GlobalCompany - Bitmap Manager
-- 
-- @Interface: 1.4.0.0 b5008
-- @Author: LS-Modcompany
-- @Date: 08.09.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
--
-- 	v1.0.0.0 (08.09.2019):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
--
--
-- ToDo:
--
-- 


GC_BitmapManager = {};
GC_BitmapManager.debugIndex = g_company.debug:registerScriptName("GC_BitmapManager")

local GC_BitmapManager_mt = Class(GC_BitmapManager)

function GC_BitmapManager:new()
    local self = {}
	setmetatable(self, GC_BitmapManager_mt)

    self.debugData = g_company.debug:getDebugData(GC_BitmapManager.debugIndex)

    self.bitmapId = 0 -- based 1
    self.bitmaps = {}

    self.layerData = {}

    g_company.addSaveable(self, self.saveBitmaps)

	return self
end;

function GC_BitmapManager:getNextId()
    self.bitmapId = self.bitmapId + 1
    return self.bitmapId
end;

function GC_BitmapManager:loadBitMap(name, filename, numChannels, autosave)
    local haveWrongParams = false
    local success = false
    local createNew = false

    if name == nil or name == "" then
        g_company.debug:writeError(self.debugData, "loadBitMap: Have invalid name.")
        haveWrongParams = true
    end
    if filename == nil or filename == "" then
        g_company.debug:writeError(self.debugData, "loadBitMap: Have invalid filename.")
        haveWrongParams = true
    end
    if numChannels == nil or numChannels == 0 then
        g_company.debug:writeWarning(self.debugData, "loadBitMap: Have invalid numChannels. Set to 8")
        numChannels = 0
    end
    if autosave == nil then
        autosave = true
    end

    if haveWrongParams then
        return
    end

    local bitmap = {}
    bitmap.id = self:getNextId()
    bitmap.name = name
    bitmap.filename = filename
    bitmap.numChannels = numChannels
    bitmap.autosave = autosave
    bitmap.deletePng = ""

    bitmap.map = createBitVectorMap(bitmap.name)

    if self.mission ~= nil then
        if self.mission.missionInfo.isValid then
            bitmap.fullPath = string.format("%s/%s", self.mission.missionInfo.savegameDirectory, bitmap.filename)

            loadPath = ""
            if fileExists(bitmap.fullPath .. ".png") then
                loadPath = bitmap.fullPath .. ".png"
                bitmap.deletePng = loadPath
            elseif fileExists(bitmap.fullPath .. ".grle") then
                loadPath = bitmap.fullPath .. ".grle"
            end
            bitmap.fullPath = bitmap.fullPath .. ".grle"

            if loadPath ~= "" then
                success = loadBitVectorMapFromFile(bitmap.map, loadPath, bitmap.numChannels)
            else
                g_company.debug:writeModding(self.debugData, "loadBitMap: Can't find file %s -.png or -.grle - Create a new one", bitmap.fullPath)
            end
        end

        if not success then
            bitmap.size = getDensityMapSize(self.mission.terrainDetailId)
            loadBitVectorMapNew(bitmap.map, bitmap.size, bitmap.size, bitmap.numChannels, false)
            createNew = true
        end
        bitmap.mapSize = getBitVectorMapSize(bitmap.map)
        table.insert(self.bitmaps, bitmap)
        return bitmap.id, createNew
    else
        g_company.debug:writeError(self.debugData, "loadBitMap: no mission")
    end
    return nil, false
end

function GC_BitmapManager:saveBitmaps()
    for _,bitmap in pairs(self.bitmaps) do
        if bitmap.autosave and bitmap.map ~= 0 then
            saveBitVectorMapToFile(bitmap.map, bitmap.fullPath)
            --print(bitmap.fullPath)
            if bitmap.deletePng ~= "" then
                if fileExists(bitmap.deletePng) then
                    deleteFile(bitmap.deletePng)
                end
                bitmap.deletePng = false
            end
        end
    end
end

function GC_BitmapManager:saveBitmapById(id)
    for _,bitmap in pairs(self.bitmaps) do
        if bitmap.id == id and bitmap.map ~= 0 then
            saveBitVectorMapToFile(bitmap.map, bitmap.fullPath)
            break
        end
    end
end

function GC_BitmapManager:getBitmapById(id)
    for _,bitmap in pairs(self.bitmaps) do
        if bitmap.id == id then
            return bitmap
        end
    end
end

function GC_BitmapManager:loadLayerXML(xmlFilename)   
    local xmlFile = loadXMLFile("layers", xmlFilename)

    local i = 0
    while true do
        local key = string.format("layers.layer(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local layer = {}
        layer.id = getXMLString(xmlFile, key .. "#id")
        
        layer.colors = {}

        local j = 0
        while true do
            local key_color = string.format("%s.color(%d)", key, j)
            if not hasXMLProperty(xmlFile, key_color) then
                break
            end

            local color = {}
            color.value = getXMLInt(xmlFile, key_color .. "#value")
            color.r = getXMLFloat(xmlFile, key_color .. "#r")
            color.g = getXMLFloat(xmlFile, key_color .. "#g")
            color.b = getXMLFloat(xmlFile, key_color .. "#b")
            
            table.insert(layer.colors, color)

            j = j + 1
        end

        table.insert(self.layerData, layer)

        i = i + 1
    end
    delete(xmlFile)
end

function GC_BitmapManager:setOverlayStateColor(bitmap, bitmapMap)
    for _,layer in pairs(self.layerData) do
        if layer.id == bitmap.name then
            for _,color in pairs(layer.colors) do
                setDensityMapVisualizationOverlayStateColor(bitmap.overlay, bitmapMap.map, 0, 0, bitmapMap.numChannels, color.value, color.r, color.g, color.b)
            end
            break
        end
    end
end