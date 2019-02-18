




ProductionFactoryPlaceable = {};
ProductionFactoryPlaceable_mt = Class(ProductionFactoryPlaceable, Placeable);
getfenv(0)["ProductionFactoryPlaceable"] = ProductionFactoryPlaceable;
InitObjectClass(ProductionFactoryPlaceable, "ProductionFactoryPlaceable");

g_company:addPlaceableType("ProductionFactoryPlaceable", "ProductionFactoryPlaceable", g_company.dir .. "placeables/GC_ProductionFactoryPlaceable.lua");

function ProductionFactoryPlaceable:new(isServer, isClient, customMt)
    local self = Placeable:new(isServer, isClient, customMt or ProductionFactoryPlaceable_mt);
    registerObjectClassName(self, "ProductionFactoryPlaceable");
    return self;
end

function ProductionFactoryPlaceable:delete()
    for _, production in ipairs(self.productions) do
        production:delete()
    end

    unregisterObjectClassName(self)  
    ProductionFactoryPlaceable:superClass().delete(self)
end

function ProductionFactoryPlaceable:deleteFinal()
    ProductionFactoryPlaceable:superClass().deleteFinal(self)
end

function ProductionFactoryPlaceable:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
    if not ProductionFactoryPlaceable:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
        return false
    end

    self.productions = {};

    local xmlFile = loadXMLFile("TempXML", xmlFilename)

    local i = 0
    while true do
        local productionKey = string.format("placeable.globalCompany.productionFactories.productionFactory(%d)", i)
        if not hasXMLProperty(xmlFile, productionKey) then
            break
        end
        local production = ProductionFactory:new(self.isServer, self.isClient);
        local indexName = getXMLString(xmlFile, productionKey .. "#index")
        if production:load(self.nodeId, productionKey, indexName, self) then
            table.insert(self.productions, production);
        else
            production:delete();
        end
        i = i + 1;
    end
    delete(xmlFile);

    return true;
end

function ProductionFactoryPlaceable:finalizePlacement()
    ProductionFactoryPlaceable:superClass().finalizePlacement(self);

    for _, production in ipairs(self.productions) do
        production:finalizePlacement();
        production:register(true)
    end    
end
