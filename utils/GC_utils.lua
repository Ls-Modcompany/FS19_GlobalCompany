-- 
-- GlobalCompany - Utils
-- 
-- @Interface: --
-- @Author: LS-Modcompany
-- @Date: 3.12.2018
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (31.12.2018):
-- 		- initial fs19 (kevink98, GtX)
-- 
-- Notes:
-- 
-- 
-- ToDo:
--
-- 

GlobalCompanyUtils = {};
g_company.utils = GlobalCompanyUtils;

function GlobalCompanyUtils.createModPath(modFileName, filename)
	return g_modsDirectory .. modFileName .. "/" .. filename;	
end;

function GlobalCompanyUtils.createDirPath(modFileName)
	return g_modsDirectory .. modFileName .. "/";	
end;

-- Code from http://lua-users.org/wiki/SplitJoin
-- kevink98: remove parameter "pat" and replace it with '[\\/]+'
function GlobalCompanyUtils.split(str)
	local t = {}
	local fpat = "(.-)" .. '[\\/]+'
	local last_end = 1
	local s, e, cap = str:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(t,cap)
		end
		last_end = e+1
		s, e, cap = str:find(fpat, last_end)
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		table.insert(t, cap)
	end
	return t
end

function GlobalCompanyUtils.getTableLength(t)
	if t == nil or type(t) ~= "table" then
		return 0
	end

	local count = 0
    for _ in pairs(t) do
        count = count + 1
    end

    return count
end

function GlobalCompanyUtils.getFileExt(filename)
    local extensionType = nil
	
	if filename ~= nil then
		local splitFilename = StringUtil.splitString(".", filename)
		-- Make sure we only take the final table item in case the file path has '.' in it.
		extensionType = splitFilename[#splitFilename]
    end
	
    return extensionType
end

function GlobalCompanyUtils.getGreater(constant, variable, factor)
	local value = constant
	if variable ~= nil and variable > factor then
		value = variable
	end;
	return value
end

function GlobalCompanyUtils.getLess(constant, variable, factor)
	local value = constant
	if variable ~= nil and variable < factor then
		value = variable
	end
	return value
end

function GlobalCompanyUtils.addition(x,y,...)
	if x == nil then return 0; end;
	if y ~= nil then return x + GlobalCompanyUtils.addition(y,...); else return x; end;
end;


-- Similar to splitString except this allows you to use the stingValue as the 'key' and insert a table value.
-- @param string strg = the string you want to use.
-- @param string sep = the separator value you want to use. (Optional) (Default " ")
-- @param boolean toKey = type of table to create. (Optional)
-- @param ..... val = any value you want to insert at the table positions. (Optional) (Default = sting.sub)
function GlobalCompanyUtils.stringToTable(strg, sep, toKey, val)
	local separator = " ";
	if sep ~= nil then
		separator = sep;
	end;
	
	local newTable = {};	
	if strg ~= nil then
		local position = 1;
		
		for i = 1, string.len(strg) do
			local stringStart, stringEnd = string.find(strg, separator, position, true);
			if not stringStart then
				break;
			end;
			
			local value = string.sub(strg, position, stringStart - 1);
			if toKey ~= nil and toKey then
				local addValue = Utils.getNoNil(val, value)
				newTable[value] = addValue;
			else
				table.insert(newTable, value);
			end;
	
			position = stringEnd + 1;
		end;
		
		local value = string.sub(strg, position);
		if toKey ~= nil and toKey then
			local addValue = Utils.getNoNil(val, value)
			newTable[value] = addValue;
		else
			table.insert(newTable, value);
		end;
	end;
	
	return newTable;
end;

function GlobalCompanyUtils.removeModEventListener(listener)
	local deleteKey = 0;
	for k,list in pairs(g_modEventListeners) do
		if list == listener then
			deleteKey = k;
		end;
	end;
	table.remove(g_modEventListeners, deleteKey);
end;

function GlobalCompanyUtils.splitString(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function GlobalCompanyUtils.find(str, search)
	return str:find(search);
end; 


-- Split the 'mod script' className and return only the script name.
-- @param table object = object to get class name from.
-- @param string backupString = backup string to display if there is a problem. (Optional)
-- @return string splitClassName = script class name with mod name removed.
function GlobalCompanyUtils.getSplitClassName(object, backupString)
	local splitClassName = "";
	
	if backupString ~= nil then
		splitClassName = tostring(backupString);
	end;
	
	if object ~= nil and type(object) == "table" then
		local fullClassName = object.className;
		if fullClassName ~= nil then
			local start, _ = string.find(fullClassName, ".", 1, true);
			if start ~= nil then
				splitClassName = string.sub(fullClassName, start + 1);
			end;
		end;
	end;
	
	return splitClassName;
end;


function GlobalCompanyUtils.getNumbersFromString(xmlFile, key, count, returnRadians, debugData)
    local stringValue = getXMLString(xmlFile, key);	
	if stringValue ~= nil and count ~= nil then	
		local stringTable = StringUtil.splitString(" ", stringValue);
		if #stringTable >= count then
			stringValue = {};		
			for i = 1, count do
				if returnRadians == true then
					table.insert(stringValue, math.rad(tonumber(stringTable[i])));
				else
					table.insert(stringValue, tonumber(stringTable[i]));
				end;
			end;
		else
			if debugData ~= nil then
				g_company.debug:writeModding(debugData, "%d-vector given, %d-vector required at %s", #stringTable, count, key);
			else
				print(string.format("    ERROR: %d-vector given, %d-vector required at %s", #stringTable, count, key));
			end;
			stringValue = nil;
		end;
	end;

   return stringValue;
end;

-- Looking for [ PREFIX GC_ or SRS_ ] e.g 'input_GC_OpenDoor' or 'gui_GC_Capacity_Shown' or 'GC_OpenDoor' or 'SRS_OpenDoor' --
function GlobalCompanyUtils.getHasPrefix(text)
	local splitText = StringUtil.splitString("_", text)
	if #splitText > 1 then
		local prefix = splitText[1];
		if "input" == prefix or "gui" == prefix then
			prefix = splitText[2];
			if "GC" == prefix or "SRS" == prefix then
				return true;
			end;
		else
			if "GC" == prefix or "SRS" == prefix then
				return true;
			end;
		end;
	end;
	
	return false;
end;


