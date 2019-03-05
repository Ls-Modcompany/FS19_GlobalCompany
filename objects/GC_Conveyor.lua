-- 
-- GlobalCompany - Objects - Conveyor
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 13.12.2018
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--
-- 	v1.0.0.0 (03.03.2019):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
-- 	This operates Client side only
-- 
-- 
-- ToDo:
-- check if scripts work in fs19!
--


GC_Conveyor = {};
getfenv(0)["GC_Conveyor"] = GC_Conveyor;

GC_Conveyor.debugIndex = g_company.debug:registerScriptName("GlobalCompany-GC_Conveyor");

GC_Conveyor.STATE_OFF = 0;
GC_Conveyor.STATE_TURNING_OFF = 1;
GC_Conveyor.STATE_ON = 2;
GC_Conveyor.STATE_TURNING_ON = 3;

GC_Conveyor_mt = Class(GC_Conveyor);
InitObjectClass(GC_Conveyor, "GC_Conveyor");

function GC_Conveyor:new(isServer, isClient)
	local self = {};

	setmetatable(self, GC_Conveyor_mt);

	self.isServer = isServer;
	self.isClient = isClient;

	return self;
end;

function GC_Conveyor:load(id, target, xmlFile, baseKey)
	self.target = target;

	self.debugData = g_company.debug:getDebugData(GC_Conveyor.debugIndex, target);

	if self.isClient then
		self.shaders = {};
		local i = 0;
		while true do
			local key = string.format(baseKey..".shader(%d)", i);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;
			local shader = {};
			shader.node = I3DUtil.indexToObject(id, getXMLString(xmlFile, key.."#node"), self.target.i3dMappings);
			shader.startDelay = Utils.getNoNil(getXMLFloat(xmlFile, key.."#startDelay"), 0) * 1000;
			shader.stopDelay = Utils.getNoNil(getXMLFloat(xmlFile, key.."#stopDelay"), 0) * 1000;
			
			shader.scrollLength = Utils.getNoNil(getXMLFloat(xmlFile, key.."#scrollLength"), 1);
			shader.scrollSpeed = Utils.getNoNil(getXMLFloat(xmlFile, key.."#scrollSpeed"), 1) * 0.001;
			shader.direction = Utils.getNoNil(getXMLString(xmlFile, key.."#direction"), "X"):lower();
			shader.invers = Utils.getNoNil(getXMLString(xmlFile, key.."#invers"), false);
			
			shader.state = GC_Conveyor.STATE_OFF;
			shader.currentDelay = shader.startDelay;
			shader.scrollPosition = 0;				
			
			table.insert(self.shaders, shader);
			
			i = i + 1;
		end;
		
		g_company.addUpdateable(self, self.update);
	end;
	
	return true;
end;

function GC_Conveyor:delete()
	if self.isClient then
		g_company.removeUpdateable(self);
	end;
end;

function GC_Conveyor:update(dt)
	if self.isClient then
		for _, shader in pairs(self.shaders) do 
			if shader.state ~= GC_Conveyor.STATE_OFF then
				shader.currentDelay = shader.currentDelay - dt;
				if shader.currentDelay <= 0 then	
                    shader.scrollPosition = (shader.scrollPosition + dt*shader.scrollSpeed) % shader.scrollLength; 	
                    local value = shader.scrollPosition;
                    if shader.invers then
                        value = value * -1;
                    end;    
                    if shader.direction == "x" then				
                        setShaderParameter(shader.node, "offsetUV", value,0,-100,100, false);
                    else
                        setShaderParameter(shader.node, "offsetUV", 0,value,-100,100, false);
                    end;
				end;		
			end;		
		end;
	end;
end;

function GC_Conveyor:start(shader)
	if self.isServer then
		if shader ~= nil then
			self:startShader(shader);
		else
			for _, shader in pairs(self.shaders) do 
				self:startShader(shader);
			end;
		end;
	end;
end;

function GC_Conveyor:stop(shader)
	if self.isServer then
		if shader ~= nil then
			self:stopShader(shader);
		else
			for _, shader in pairs(self.shaders) do 
				self:stopShader(shader);
			end;
		end;
	end;
end;

--Dont call from outside!! Only form GC_Conveyor.start!
function GC_Conveyor:startShader(shader)
	if shader.state ~= GC_Conveyor.STATE_TURNING_ON and shader.state ~= GC_Conveyor.STATE_ON then
		shader.state = GC_Conveyor.STATE_TURNING_ON;
		shader.currentDelay = shader.startDelay;
		return true;
	end;
	return false;
end;

--Dont call from outside!! Only form GC_Conveyor.stop!
function GC_Conveyor:stopShader(shader)
	if shader.state ~= GC_Conveyor.STATE_TURNING_OFF and shader.state ~= GC_Conveyor.STATE_OFF then
		shader.state = GC_Conveyor.STATE_TURNING_OFF;
		shader.currentDelay = shader.stopDelay;
		return true;
	end;
	return false;
end;

function GC_Conveyor:resetShader(shader)
	if self.isServer then
		shader.state = GC_Conveyor.STATE_OFF;
	end;
end;

function GC_Conveyor:getIsOn(shader, index)
	if shader ~= nil then
		return shader.state == GC_Conveyor.STATE_ON;
	elseif index ~= nil and self.shaders[index] ~= nil then
		return self.shaders[index].state == GC_Conveyor.STATE_ON;
	elseif table.getn(self.shaders) > 0 then
		local isOn = true;
		for k, shader in pairs(self.shaders) do 
			if shader.state ~= GC_Conveyor.STATE_ON then
				isOn = false;
				break;
			end;
		end;
		return isOn;
	end;
	return false;
end;

function GC_Conveyor:getIsOff(shader, index)
	if shader ~= nil then
		return shader.state == GC_Conveyor.STATE_OFF;
	elseif index ~= nil and self.shaders[index] ~= nil then
		return self.shaders[index].state == GC_Conveyor.STATE_OFF;
	elseif table.getn(self.shaders) > 0 then
		local isOff = true;
		for k, shader in pairs(self.shaders) do 
			if shader.state ~= GC_Conveyor.STATE_OFF then
				isOff = false;
				break;
			end;
		end;
		return isOff;
	else
		return false;
	end;
end;