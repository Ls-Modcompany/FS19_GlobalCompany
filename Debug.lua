-- 
-- Debug
-- 
-- @Interface: 1.4.4.0 1.4.4RC8
-- @Author: kevink98 / LS-Modcompany
-- @Date: 17.12.2017
-- @Version: 1.0.0.0
-- 
-- Level informations:
--	-1: 	Errors
-- 	 0: 	Warnings, Important Informations
--	 1: 	Short additionals Informations
--	 2: 	Modding Informations
-- 	 3: 	Load Informations
-- 

Debug = {};
getfenv(0)["g_debug"] = Debug;

Debug.writeModdingInformations = false;

Debug.START = 0;
Debug.TEXT = 1;

Debug.numLevels = 20;
Debug.ERROR = -1;
Debug.WARNING = 0;
Debug.INFORMATIONS = 1;
Debug.MODDING = 2;
Debug.LOAD = 3;
Debug.ONCREATE = 4;
Debug.TABLET = 5;

Debug.printLevel = {};
for i = -1, Debug.numLevels do
	Debug.printLevel[i] = false;
end;

--set default Level
Debug.printLevel[-2] = true;
Debug.printLevel[Debug.ERROR] = true;
Debug.printLevel[0] = true;
Debug.printLevel[1] = true;
Debug.printLevel[3] = true; --

Debug.registerMods = {};
Debug.registerModsCount = 0;
function Debug.registerMod(name)
	Debug.registerModsCount = Debug.registerModsCount + 1;
	table.insert(Debug.registerMods, name);
	return Debug.registerModsCount;
end;

function Debug.setLevel(level, value)
	if level > 0 then
		Debug.printLevel[level] = value;
	end;
end;

function Debug.write(modIndex, level, message, ...)
	if Debug.printLevel[level] then
		local prefix = "";
		if level == Debug.ERROR then
			prefix = "ERROR: ";
		elseif level == Debug.WARNING then
			prefix = "WARNING: ";
		elseif level == Debug.INFORMATIONS then
			prefix = "INFO: ";
		end;
		if modIndex ~= nil and Debug.registerMods[modIndex] ~= nil then
			print("[LSMC - " .. Debug.registerMods[modIndex] .. "] " .. prefix .. string.format(message,...));
		else
			print("[LSMC - Debug] illegal mod!");
		end;		
	end;
end;

function Debug.writeBlock(modIndex, level, block, message, ...)
	if Debug.printLevel[level] then
		if block == Debug.START then
			if modIndex ~= nil and Debug.registerMods[modIndex] ~= nil then
				print("[LSMC - " .. Debug.registerMods[modIndex] .. "] " .. string.format(message,...));
			else
				print("[LSMC - Debug] illegal mod!");
			end;	
		elseif block == Debug.TEXT then
			if modIndex ~= nil and Debug.registerMods[modIndex] ~= nil then
				print("	   " .. string.format(message,...));
			else
				print("[LSMC - Debug] illegal mod!");
			end;	
		end;
	end;
end;


