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

GlobalCompanyUtils = {}
g_company.utils = GlobalCompanyUtils

function GlobalCompanyUtils.createModPath(modFileName, filename)
	return g_modsDirectory .. modFileName .. "/" .. filename
end

function GlobalCompanyUtils.createDirPath(modFileName)
	return g_modsDirectory .. modFileName .. "/"
end

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
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end

	return count
end

function GlobalCompanyUtils.isTableEmpty(t)
	return next(t) == nil
end

function GlobalCompanyUtils.getFileExtension(filename)
	local extensionType

	if filename ~= nil and type(filename) == "string" then
		local lastPeriod, _ = filename:find(".[^.]*$")
		if lastPeriod ~= nil then
			extensionType = filename:sub(lastPeriod + 1)
		end
	end

	return extensionType
end

function GlobalCompanyUtils.getGreater(constant, variable, factor)
	local value = constant
	if variable ~= nil and variable > factor then
		value = variable
	end

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
	if x == nil then
		return 0
	end

	if y ~= nil then
		return x + GlobalCompanyUtils.addition(y,...)
	else
		return x
	end
end

-- Similar to splitString except this allows you to use the stingValue as the 'key' and insert a table value.
-- @param string strg = the string you want to use.
-- @param string sep = the separator value you want to use. (Optional) (Default " ")
-- @param boolean toKey = type of table to create. (Optional)
-- @param ..... val = any value you want to insert at the table positions. (Optional) (Default = sting.sub)
function GlobalCompanyUtils.stringToTable(strg, sep, toKey, val)
	local separator = " "
	if sep ~= nil then
		separator = sep
	end

	local newTable = {}
	if strg ~= nil then
		local position = 1

		for i = 1, string.len(strg) do
			local stringStart, stringEnd = string.find(strg, separator, position, true)
			if not stringStart then
				break
			end

			local value = string.sub(strg, position, stringStart - 1)
			if toKey ~= nil and toKey then
				local addValue = Utils.getNoNil(val, value)
				newTable[value] = addValue
			else
				table.insert(newTable, value)
			end

			position = stringEnd + 1
		end

		local value = string.sub(strg, position)
		if toKey ~= nil and toKey then
			local addValue = Utils.getNoNil(val, value)
			newTable[value] = addValue
		else
			table.insert(newTable, value)
		end
	end

	return newTable
end

function GlobalCompanyUtils.removeModEventListener(listener)
		g_company.debug:print("DEV WARNING: 'GlobalCompanyUtils.removeModEventListener' is a depreciated function in GC FS19. Use GIANTS builtIn 'removeModEventListener(self)' instead.");
	return removeModEventListener(listener)

	-- local deleteKey = 0
	-- for k,list in pairs(g_modEventListeners) do
		-- if list == listener then
			-- deleteKey = k
		-- end
	-- end
	-- table.remove(g_modEventListeners, deleteKey)
end

function GlobalCompanyUtils.splitString(s, delimiter)
	local result = {}
	for match in (s..delimiter):gmatch("(.-)"..delimiter) do
		table.insert(result, match)
	end

	return result
end

function GlobalCompanyUtils.find(str, search)
	return str:find(search)
end

-- Split the 'mod script' className and return only the script name.
-- @param table object = object to get class name from.
-- @param string backupString = backup string to display if there is a problem. (Optional)
-- @return string splitClassName = script class name with mod name removed.
function GlobalCompanyUtils.getSplitClassName(object, backupString)
	local splitClassName = ""

	if backupString ~= nil then
		splitClassName = tostring(backupString)
	end

	if object ~= nil and type(object) == "table" then
		local fullClassName = object.className
		if fullClassName ~= nil then
			local start, _ = string.find(fullClassName, ".", 1, true)
			if start ~= nil then
				splitClassName = string.sub(fullClassName, start + 1)
			end
		end
	end

	return splitClassName
end

function GlobalCompanyUtils.getNumbersFromString(stringValue, count, returnRadians, debugData, constant)
	if stringValue ~= nil then
		local stringTable = StringUtil.splitString(" ", stringValue)
		if #stringTable >= count then
			stringValue = {}
			for i = 1, count do
				local number = tonumber(stringTable[i]);
				if returnRadians == true then
					stringValue[i] = math.rad(number);
				else
					stringValue[i] = number;
				end;
			end

			return stringValue
		else
			if debugData ~= nil then
				g_company.debug:writeModding(debugData, "%d-vector given, %d-vector required.", #stringTable, count)
			else
				g_company.debug:print("    ERROR: %d-vector given, %d-vector required.", #stringTable, count);
			end
		end
	end

	return constant
end

-- Uses 'modulo operation' to return a table with an EVEN key value based on the given 'moduloValue'.
-- 'multiplier' can't be used with 'returnRadians' and will be ignored.
function GlobalCompanyUtils.getEvenTableFromString(stringValue, moduloValue, returnNumbers, returnRadians, multiplier, debugData)
	if stringValue ~= nil then
		local stringTable = StringUtil.splitString(" ", stringValue)
		local tableLength = #stringTable
		moduloValue = GlobalCompanyUtils.getGreater(1, moduloValue, 0)
		if (tableLength % moduloValue) == 0 then
			if returnNumbers == true then
				multiplier = GlobalCompanyUtils.getGreater(1, multiplier, 0)
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
				g_company.debug:writeModding(debugData, "Odd number of values '%d' given.", tableLength)
			else
				g_company.debug:print("    ERROR: Odd number of values '%d' given.", tableLength);
			end
		end
	end

	return
end

-- Looking for [PREFIX] 'GC_' or 'SRS_'
function GlobalCompanyUtils.getHasPrefix(text)
	local stringStart, stringEnd = text:find("_", 1, true)
	if stringStart ~= nil then
		local prefix = text:sub(1, stringStart - 1)
		if prefix == "GC" or prefix == "SRS"  then
			return true
		end
	end

	return false
end

-- Remove Prefix and Suffix from the modName and return Root Mod Name only.
-- Example: FS19_MyGreatMod_update > MyGreatMod
function GlobalCompanyUtils.getRootModName(modName)
	if modName:sub(1, 5) == "FS19_" then
		if modName:sub(-7) == "_update" then
			return modName:sub(6, modName:len() - 7)
		else
			return modName:sub(6)
		end
	else
		if modName:sub(-7) == "_update" then
			return modName:sub(1, modName:len() - 7)
		else
			return modName:sub(1)
		end
	end
end

function GlobalCompanyUtils.getParentBaseDirectory(parent, baseDirectory)
	if baseDirectory == nil then
		if parent ~= nil then
			baseDirectory = GlobalCompanyUtils.getCorrectValue(parent.baseDirectory, g_currentMission.baseDirectory, "")
		else
			baseDirectory = g_currentMission.baseDirectory
		end
	end

	return baseDirectory
end

-- This is acts like 'Utils.getNoNil' except you can set your own ignore value.
function GlobalCompanyUtils.getCorrectValue(value, newValue, ignoreValue)
	if value == nil or value == ignoreValue then
		return newValue
	end

	return value
end

function GlobalCompanyUtils.getCorrectNumberValue(value, newValue, minValue, maxValue)
	if maxValue == nil then
		maxValue = math.huge
	end

	if value == nil or value < minValue or value > maxValue then
		return newValue
	end

	return value
end

function GlobalCompanyUtils.getEdgeNumber(value, minValue, maxValue)
	if value < minValue then
		return minValue
	elseif value > maxValue then
		return maxValue
	end
	return value
end

-- Part code from http://lua-users.org/wiki/StringRecipes
-- add insert to table option and first line indent matching.
function GlobalCompanyUtils.stringWrap(str, limit, indent, returnTable)
	if str == nil then
		if returnTable then
			return {}
		end
		
		return ""
	end
	
	limit = limit or 140
	indent = indent or ""

	local start, _ = string.find(str, "%w")
	if start > 1 then
		for i = 1, start - 1 do
			indent = indent .. " "
		end
	end
	
	local position = 1 - #indent
	local function check(sp, st, word, fi)
		if fi - position > limit then
			position = st - #indent
			
			return "\n" .. indent .. word
		end
	end
	
	local newString, _ = str:gsub("(%s+)()(%S+)()", check)
	
	if returnTable == true then
		local stringTable = {}
		for line in string.gmatch(newString, "[^\r\n]+") do
			table.insert(stringTable, line)
		end
		
		return stringTable
	else
		return newString
	end
end

function GlobalCompanyUtils.convertNumberToBits(num,bits)
	bits = bits or math.max(1, select(2, math.frexp(num)))
	local t = {}    
	local str = ""
	for b = bits, 1, -1 do
		t[b] = math.fmod(num, 2)
		str = t[b] .. str
		num = math.floor((num - t[b]) / 2)
	end
	return t, str
end

function GlobalCompanyUtils.getValueOfBits(bits, start, lenght)
	return tonumber(bits:reverse():sub(start + 1, start + lenght):reverse(), 2)
end

function GlobalCompanyUtils.floatEqual(lhs, rhs, epsilon)
	return math.abs(lhs - rhs) < epsilon
end

function GlobalCompanyUtils.deleteFile(path)
	getfenv(0)["deleteFile"](path)
end

function GlobalCompanyUtils.deleteFileIfExists(path)
	if fileExists(path) then
		GlobalCompanyUtils.deleteFile(path)
		return true
	end
	return false
end

function GlobalCompanyUtils.teleportVehicleWithRotation(posX, posZ, rotY)
	local vehicleCombos = {}
	local vehicles = {}
	local function addVehiclePositions(vehicle)
		local x,y,z = getWorldTranslation(vehicle.rootNode)
		table.insert(vehicles, {vehicle=vehicle, offset={worldToLocal(g_currentMission.controlledVehicle.rootNode, x,y,z)}})

		for _, impl in pairs(vehicle:getAttachedImplements()) do
			addVehiclePositions(impl.object)
			table.insert(vehicleCombos, {vehicle=vehicle, object=impl.object, jointDescIndex=impl.jointDescIndex, inputAttacherJointDescIndex=impl.object:getActiveInputAttacherJointDescIndex()})
		end

		for i=table.getn(vehicle:getAttachedImplements()), 1, -1 do
			vehicle:detachImplement(1, true)
		end
		vehicle:removeFromPhysics()
	end

	addVehiclePositions(g_currentMission.controlledVehicle)

	for k, data in pairs(vehicles) do
		local x,z = posX, posZ
		if k > 1 then
			x,_,z = localToWorld(g_currentMission.controlledVehicle.rootNode, unpack(data.offset))
		end
		local _,ry,_ = getWorldRotation(data.vehicle.rootNode)
		ry = Utils.getNoNil(rotY, ry)
		data.vehicle:setRelativePosition(x, 0.5, z, ry, true)
		data.vehicle:addToPhysics()
	end

	for _, combo in pairs(vehicleCombos) do
		combo.vehicle:attachImplement(combo.object, combo.inputAttacherJointDescIndex, combo.jointDescIndex, true, nil, nil, false);
	end
end