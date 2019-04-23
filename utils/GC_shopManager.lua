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
local debugIndex = g_company.debug:registerScriptName("GlobalCompany-GC_shopManager");

GC_shopManager = {};
g_company.shopManager = GC_shopManager;

function GC_shopManager:loadFromXML(modName, xmlFile)
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
			i = i + 1;
		end;	
		
		local categories = {};
		for name, category in pairs(g_storeManager.categories) do
			categories[category.orderId] = name:lower();
		end;
	end;
			
		i = 0;
		while true do
			local keySub = string.format("%s.sortCategories.category(%d)", key, i);
			if not hasXMLProperty(xmlFile, keySub) then
				break;
			end;
			local type = getXMLString(xmlFile, keySub.."#type");
			local name = getXMLString(xmlFile, keySub.."#name"):lower();
			local after = Utils.getNoNil(getXMLString(xmlFile, keySub.."#after"), "");
			local before = Utils.getNoNil(getXMLString(xmlFile, keySub.."#before"), "");
			
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
			local keySub = string.format("%s.removeItems.item(%d)", key, i);
			if not hasXMLProperty(xmlFile, keySub) then
				break;
			end;
			local xmlFilename = getXMLString(xmlFile, keySub.."#xmlFilename");
			xmlFilename = g_company.shopManager:getFullXmlFilename(xmlFilename, modName);
			
			local item = g_storeManager:getItemByXMLFilename(xmlFilename);
			g_storeManager:removeItemByIndex(item.id);
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
					
			local item = g_storeManager:getItemByXMLFilename(xmlFilename);
			item.categoryName = name:upper();
			
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





