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
	local xmlKey = string.format("%s.%s", baseKey, key);

	if indexName ~= nil then
		local i = 0;
		while true do
			local indexNameKey = string.format("%s.%s(%d)", baseKey, key, i);
			if not hasXMLProperty(xmlFile, indexNameKey) then
				break;
			end;

			local factoryIndex = getXMLString(xmlFile, indexNameKey .. "#indexName");
			if factoryIndex == indexName then
				xmlKey = indexNameKey;
				break;
			end;
			i = i + 1;
		end;
	end;

	return xmlKey;
end;