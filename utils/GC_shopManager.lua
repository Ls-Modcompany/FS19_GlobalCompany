-- 
-- GlobalCompany - Utils - GC_shopManager
-- 
-- @Interface: 1.5.1.0 b6732
-- @Author: LS-Modcompany / kevink98
-- @Date: 03.11.2019
-- @Version: 1.2.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--
-- 	v1.2.0.0 (03.11.2019):
-- 		- add warning when xmlfilename not exist at remove
--		
-- 	v1.1.0.0 (05.08.2019):
-- 		- adaptation to patch 1.4.1.0 b5332
--
-- 	v1.0.0.0 (01.01.2019):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
-- 
-- 
-- ToDo:
-- sortCategories: type not used in script
-- 

GC_shopManager = {};
GC_shopManager.debugIndex = g_company.debug:registerScriptName("GlobalCompany-GC_shopManager");
g_company.shopManager = GC_shopManager;
g_company.shopManager.addCategorys = {};
g_company.shopManager.sortCategories = {};
g_company.shopManager.removeItems = {};
g_company.shopManager.changeCategorys = {};

function GC_shopManager:loadFromXML(modName, xmlFile)
	GC_shopManager.debugData = g_company.debug:getDebugData(GC_shopManager.debugIndex, g_company);

	local key = "globalCompany.shopManager";
	if hasXMLProperty(xmlFile, key) then
		local externalXml = getXMLString(xmlFile, string.format("%s#xmlFilename", key));
		if externalXml ~= nil then
			xmlFile = loadXMLFile("shopManager", g_company.utils.createModPath(modName, externalXml));
			key = "shopManager";
		end;	
		
		local i = 0;
		while true do
			local keySub = string.format("%s.addCategories.category(%d)", key, i);
			if not hasXMLProperty(xmlFile, keySub) then
				break;
			end;
			local type = getXMLString(xmlFile, keySub.."#type");
			local name = getXMLString(xmlFile, keySub.."#name");
			local title = g_company.languageManager:getText(getXMLString(xmlFile, keySub.."#title"));
			
			local image = getXMLString(xmlFile, keySub.."#image");		
			
			g_storeManager:addCategory(name, title, image, type, g_company.shopManager:getFullImagePath(image, modName));
			--table.insert(g_company.shopManager.addCategorys, {name=name, title=title, image=image, type=type, img=g_company.shopManager:getFullImagePath(image, modName)});	
			i = i + 1;
		end;	
			
		i = 0;
		while true do
			local keySub = string.format("%s.sortCategories.category(%d)", key, i);
			if not hasXMLProperty(xmlFile, keySub) then
				break;
			end;
			--local type = getXMLString(xmlFile, keySub.."#type");
			local name = getXMLString(xmlFile, keySub.."#name"):lower();
			local after = Utils.getNoNil(getXMLString(xmlFile, keySub.."#after"), "");
			local before = Utils.getNoNil(getXMLString(xmlFile, keySub.."#before"), "");
			
			table.insert(g_company.shopManager.sortCategories, {name=name, after=after, before=before});	
		
			i = i + 1;
		end;
		
		i = 0;
		while true do
			local keySub = string.format("%s.removeItems.item(%d)", key, i);
			if not hasXMLProperty(xmlFile, keySub) then
				break;
			end;
			local xmlFilename = getXMLString(xmlFile, keySub.."#xmlFilename");
			xmlFilename = g_company.shopManager:getFullXmlFilename(xmlFilename, modName);
			
			table.insert(g_company.shopManager.removeItems, xmlFilename);
			i = i + 1;
		end;
			
		i = 0;
		while true do
			local keySub = string.format("%s.changeCategory.item(%d)", key, i);
			if not hasXMLProperty(xmlFile, keySub) then
				break;
			end;
			local xmlFilename = getXMLString(xmlFile, keySub.."#xmlFilename");
			xmlFilename = g_company.shopManager:getFullXmlFilename(xmlFilename, modName);
			local name = getXMLString(xmlFile, keySub.."#category");
								
			table.insert(g_company.shopManager.changeCategorys, {xmlFilename=xmlFilename, name=name});
			i = i + 1;
		end;	

		if externalXml ~= nil then
			delete(xmlFile);	
		end;	
	end;
end;

function GC_shopManager:getFullXmlFilename(xmlFilename, modName)
	local lenght = xmlFilename:len();
	if xmlFilename:sub(0, 1) == "$" then
		return xmlFilename:sub(2, lenght);
	else
		return g_company.utils.createModPath(modName, xmlFilename);
	end; 
end;

function GC_shopManager:getFullImagePath(imagePath, modName)
	if imagePath:sub(0, 1) == "$" then
		return "";
	else
		return g_company.utils.createDirPath(modName);
	end; 
end;

function GC_shopManager:load()
	for _, data in pairs(g_company.shopManager.addCategorys) do				
		--g_storeManager:addCategory(data.name, data.title, data.image, data.type, data.img);
	end;
		
	local categories = {};
	for name, category in pairs(g_storeManager.categories) do
		categories[category.orderId] = name:lower();
	end;

	for _, data in pairs(g_company.shopManager.sortCategories) do				
		for k, cN in pairs(categories) do
			if cN == data.name then
				table.remove(categories, k);
				break;
			end;
		end; 
		
		for k,cN in pairs(categories) do
			if data.after:lower() == cN then
				table.insert(categories, k+1, data.name);
				break;
			elseif data.before:lower() == cN then
				table.insert(categories, k-1, data.name);
				break;
			end;
		end;
	end;
		
	if g_company.utils.getTableLength(categories) > 0 then
		for orderId, name in pairs(categories) do
			g_storeManager:getCategoryByName(name).orderId = orderId;
		end;
	end;
	
	for _, xmlFilename in pairs(g_company.shopManager.removeItems) do
		local item = g_storeManager:getItemByXMLFilename(xmlFilename);
		if item ~= nil then
			g_storeManager:removeItemByIndex(item.id);
		else
			g_company.debug:writeWarning(GC_shopManager.debugData, "Can't remove storeitem %s (not exist or already removed)", xmlFilename)
		end
	end

	for _, data in pairs(g_company.shopManager.changeCategorys) do
		local item = g_storeManager:getItemByXMLFilename(data.xmlFilename);
		item.categoryName = data.name:upper();
	end;
end;

g_company.addLoadable(GC_shopManager, GC_shopManager.load);