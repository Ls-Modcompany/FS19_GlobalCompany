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
-- 		- initial fs19 (GtX, kevink98)
--
-- Notes:
--
--
-- ToDo:
--
--

GlobalCompanyXmlUtils = {}
g_company.xmlUtils = GlobalCompanyXmlUtils

function GlobalCompanyXmlUtils:getXmlKey(xmlFile, baseKey, key, indexName)
	g_company.debug:printToLog("DEV WARNING", "'g_company.xmlUtils:getXmlKey()' is depreciated, use 'g_company.xmlUtils:findXMLKey()' instead.")

	local xmlKey = string.format("%s.%s", baseKey, key)
	return GlobalCompanyXmlUtils:findXMLKey(xmlFile, xmlKey, indexName)
end

function GlobalCompanyXmlUtils:findXMLKey(xmlFile, xmlKey, index, keyName)
	local foundKey

	if xmlFile ~= nil and xmlFile ~= 0 then
		local indexName = keyName or "indexName"

		if xmlKey ~= nil then
			local i = 0
			while true do
				local key = string.format("%s(%d)", xmlKey, i)
				if not hasXMLProperty(xmlFile, key) then
					break
				end

				local foundName = getXMLString(xmlFile, string.format("%s#%s", key, indexName))
				if foundName == index then
					foundKey = key
					break
				end
				i = i + 1
			end
		end
	end

	return foundKey
end

function GlobalCompanyXmlUtils:getXMLFileAndKey(filename, baseDirectory, xmlKey, indexKeyName, indexKey)
	local xmlFile, foundKey

	local xmlFilename = Utils.getFilename(filename, baseDirectory)
	if xmlFilename ~= nil and fileExists(xmlFilename) then
		xmlFile = loadXMLFile("TempXML", xmlFilename)
		foundKey = GlobalCompanyXmlUtils:findXMLKey(xmlFile, xmlKey, indexKeyName, indexKey)
	end

	return xmlFile, foundKey
end

function GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, key, count, returnRadians, debugData, constant)
	local stringValue = getXMLString(xmlFile, key)
	if stringValue ~= nil then
		local stringTable = StringUtil.splitString(" ", stringValue)
		if #stringTable >= count then
			stringValue = {}
			for i = 1, count do
				local number = tonumber(stringTable[i])
				if returnRadians == true then
					stringValue[i] = math.rad(number)
				else
					stringValue[i] = number
				end
			end

			return stringValue
		else
			if debugData ~= nil then
				g_company.debug:writeModding(debugData, "%d-vector given, %d-vector required at %s", #stringTable, count, key)
			else
				g_company.debug:print("    ERROR: %d-vector given, %d-vector required at %s", #stringTable, count, key);
			end
		end
	end

	return constant
end

-- Uses 'modulo operation' to return a table with an EVEN key value based on the given 'moduloValue'.
-- 'multiplier' can't be used with 'returnRadians' and will be ignored.
function GlobalCompanyXmlUtils.getEvenTableFromXMLString(xmlFile, key, moduloValue, returnNumbers, returnRadians, multiplier, debugData)
	local stringValue = getXMLString(xmlFile, key)
	if stringValue ~= nil then
		local stringTable = StringUtil.splitString(" ", stringValue)
		local tableLength = #stringTable
		moduloValue = g_company.utils.getGreater(1, moduloValue, 0)
		if (tableLength % moduloValue) == 0 then
			if returnNumbers == true then
				multiplier = g_company.utils.getGreater(1, multiplier, 0)
				stringValue = {}
				for i = 1, tableLength do
					local number = tonumber(stringTable[i])
					if returnRadians == true then
						stringValue[i] = math.rad(number)
					else
						stringValue[i] = number * multiplier
					end
				end

				return stringValue
			else
				return stringTable
			end
		else
			if debugData ~= nil then
				g_company.debug:writeModding(debugData, "Odd number of values '%d' given at %s", tableLength, key)
			else
				g_company.debug:print("    ERROR: Odd number of values '%d' given at %s", tableLength, key);
			end
		end
	end

	return
end


function GlobalCompanyXmlUtils.getXMLInt(xmlFile, xmlKey, constant)
	local value = getXMLInt(xmlFile, xmlKey)
	if value == nil then
		return constant
	end

	return value
end

function GlobalCompanyXmlUtils.getXMLString(xmlFile, xmlKey, constant)
	local value = getXMLString(xmlFile, xmlKey)
	if value == nil then
		return constant
	end

	return value
end

function GlobalCompanyXmlUtils.getXMLFloat(xmlFile, xmlKey, constant)
	local value = getXMLFloat(xmlFile, xmlKey)
	if value == nil then
		return constant
	end

	return value
end

function GlobalCompanyXmlUtils.getXMLBool(xmlFile, xmlKey, constant)
	local value = getXMLBool(xmlFile, xmlKey)
	if value == nil then
		return constant
	end

	return value
end

function GlobalCompanyXmlUtils.getXMLValue(getType, xmlFile, xmlKey, constant)
	local value = getType(xmlFile, xmlKey) --or constant
	if value == nil then
		return constant
	end

	return value
end

function GlobalCompanyXmlUtils.indexToObject(nodeId, xmlFile, xmlKey, i3dMappings)
	return I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey), target.i3dMappings)
end















