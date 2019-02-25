-- 
-- GlobalCompany - XML Utils
-- 
-- @Interface: --
-- @Author: LS-Modcompany
-- @Date: 01.02.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (01.02.2019):
-- 		- initial fs19 ()
-- 
-- Notes:
-- 
-- 
-- ToDo:
--
-- 

GlobalCompanyXmlUtils = {};
g_company.xmlUtils = GlobalCompanyXmlUtils;

function GlobalCompanyXmlUtils:getXmlKey(xmlFile, baseKey, key, indexName)
	g_company.debug:printToLog("DEV WARNING", "'g_company.xmlUtils:getXmlKey()' is depreciated, use 'g_company.xmlUtils:findXMLKey()' instead.");
	
	local xmlKey = string.format("%s.%s", baseKey, key);
	return GlobalCompanyXmlUtils:findXMLKey(xmlFile, xmlKey, indexName)
end;

function GlobalCompanyXmlUtils:findXMLKey(xmlFile, xmlKey, index, keyName)
	local foundKey;
	
	if xmlFile ~= nil and xmlFile ~= 0 then		
		local indexName = keyName or "indexName";
			
		if xmlKey ~= nil then			
			local i = 0;
			while true do
				local key = string.format("%s(%d)", xmlKey, i);
				if not hasXMLProperty(xmlFile, key) then
					break;
				end;
		
				local foundName = getXMLString(xmlFile, string.format("%s#%s", key, indexName));
				if foundName == index then
					foundKey = key;
					break;
				end;
				i = i + 1;
			end;
		end;
	end;

	return foundKey;
end;

function GlobalCompanyXmlUtils:getXMLFileAndKey(filename, baseDirectory, xmlKey, indexKeyName, indexKey)
	local xmlFile, foundKey;
	
	local xmlFilename = Utils.getFilename(filename, baseDirectory);
	if xmlFilename ~= nil and fileExists(xmlFilename) then
		xmlFile = loadXMLFile("TempXML", xmlFilename);
		foundKey = GlobalCompanyXmlUtils:findXMLKey(xmlFile, xmlKey, indexKeyName, indexKey);
	end;

	return xmlFile, foundKey;	
end;






