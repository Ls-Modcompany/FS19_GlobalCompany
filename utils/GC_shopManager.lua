-- 
-- GlobalCompany - SRSManager - GC_shopManager
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 01.01.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
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
local debugIndex = g_debug.registerMod("GlobalCompany-GC_i3dLoader");

GC_shopManager = {};
g_company.shopManager = GC_shopManager;

function GC_shopManager:loadFromXML(modName, xmlPath)
	local xmlFile = loadXMLFile("shopManager", xmlPath);	
	
	local i = 0;
	while true do
		local key = string.format("shopManager.addCategories.category(%d)", i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;
		local type = getXMLString(xmlFile, key.."#type");
		local name = getXMLString(xmlFile, key.."#name");
		local title = g_company.languageManager:getText(getXMLString(xmlFile, key.."#title"));
		
		local image = getXMLString(xmlFile, key.."#image");		
		g_storeManager:addCategory(name, title, image, type, g_company.shopManager:getFullImagePath(image, modName));
		i = i + 1;
	end;	
	
	local categories = {};
	for name, category in pairs(g_storeManager.categories) do
		categories[category.orderId] = name:lower();
	end;
		
	i = 0;
	while true do
		local key = string.format("shopManager.sortCategories.category(%d)", i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;
		local type = getXMLString(xmlFile, key.."#type");
		local name = getXMLString(xmlFile, key.."#name"):lower();
		local after = Utils.getNoNil(getXMLString(xmlFile, key.."#after"), "");
		local before = Utils.getNoNil(getXMLString(xmlFile, key.."#before"), "");
		
		for k, cN in pairs(categories) do
			if cN == name then
				table.remove(categories, k);
				break;
			end;
		end; 
		
		for k,cN in pairs(categories) do
			if after:lower() == cN then
				table.insert(categories, k+1, name);
				break;
			elseif before:lower() == cN then
				table.insert(categories, k-1, name);
				break;
			end;
		end;
		i = i + 1;
	end;
	
	if i > 0 then
		for orderId, name in pairs(categories) do
			g_storeManager:getCategoryByName(name).orderId = orderId;
		end;
	end;
	
	i = 0;
	while true do
		local key = string.format("shopManager.removeItems.item(%d)", i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;
		local xmlFilename = getXMLString(xmlFile, key.."#xmlFilename");
		xmlFilename = g_company.shopManager:getFullXmlFilename(xmlFilename, modName);
		
		local item = g_storeManager:getItemByXMLFilename(xmlFilename);
		g_storeManager:removeItemByIndex(item.id);
		i = i + 1;
	end;
		
	i = 0;
	while true do
		local key = string.format("shopManager.changeCategory.item(%d)", i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;
		local xmlFilename = getXMLString(xmlFile, key.."#xmlFilename");
		xmlFilename = g_company.shopManager:getFullXmlFilename(xmlFilename, modName);
		local name = getXMLString(xmlFile, key.."#category");
				
		local item = g_storeManager:getItemByXMLFilename(xmlFilename);
		item.categoryName = name:upper();
		
		i = i + 1;
	end;	
	
	delete(xmlFile);
	return true;
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





