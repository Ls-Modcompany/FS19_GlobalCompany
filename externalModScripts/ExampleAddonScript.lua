
--[[Mod 'modDesc' requirements.

<extraSourceFiles>
	<sourceFile filename="ExampleAddonScript.lua" />
</extraSourceFiles>

<globalCompany minimumVersion="1.0.0.0">
	<customClasses>
		<customClass name="Example"/>
	</customClasses>
</globalCompany>

]]--


Example = {}

-- @param string customEnvironment = filename.
-- @param string baseDirectory = file path to mod.
-- @param integer xmlFile = globalCompany.xml. (Only when active in mod!) Note: This will be closed by Global Company.
function Example:initGlobalCompany(customEnvironment, baseDirectory, xmlFile)
	if g_company == nil or Example.isInitiated ~= nil then
		return
	end

	Example.debugIndex = g_company.debug:registerScriptName("GC_AddonScript_Example")
	Example.modName = customEnvironment
	Example.isInitiated = true;


	-- Add if needed.
	addModEventListener(Example)

	
	-- Custom Code as needed.
	
end

-- Only with 'ModEventListener' 
function Example:loadMap(i3dFilePath)
	if g_company ~= nil then
		self.debugData = g_company.debug:getDebugData(Example.debugIndex, nil, Example.modName)

		-- Custom Code as needed.

	end
end

-- Only with 'ModEventListener' and as needed. (Empty functions are not required in FS19!) 
function Example:delete()
	if g_company ~= nil then
		-- Custom Code as needed.
	end;
end

-- Only with 'ModEventListener' and as needed. (Empty functions are not required in FS19!) 
function Example:update(dt)
	if g_company ~= nil then
		-- Custom Code as needed.
	end;
end





