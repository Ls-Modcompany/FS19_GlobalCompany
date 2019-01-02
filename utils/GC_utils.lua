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
-- 		- initial fs19 (kevink98)
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
		--print(tostring(t).." is not a 'table' value")
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
		local splitFilename = Utils.splitString(".", filename)
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



