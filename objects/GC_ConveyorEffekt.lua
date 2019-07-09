-- 
-- GlobalCompany - Objects - ConveyorEffekt
-- 
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / kevink98
-- @Date: 13.12.2018
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
-- 	v1.1.0.0 (13.12.2018):
--		- convert in fs19 (kevink98)
--		
-- 	v1.0.0.0 (20.11.2018):
-- 		- initial fs17 (kevink98)
-- 
-- Notes:
-- 	This operates Client side only
-- 
-- 
-- ToDo:
--


GC_ConveyorEffekt = {};
GC_ConveyorEffekt_mt = Class(GC_ConveyorEffekt);

GC_ConveyorEffekt.debugIndex = g_company.debug:registerScriptName("GC_ConveyorEffekt");

GC_ConveyorEffekt.STATE_OFF = 0;
GC_ConveyorEffekt.STATE_TURNING_OFF = 1;
GC_ConveyorEffekt.STATE_ON = 2;
GC_ConveyorEffekt.STATE_TURNING_ON = 3;

g_company.conveyorEffekt = GC_ConveyorEffekt;

function GC_ConveyorEffekt:new(isServer, isClient)
	local self = {};

	setmetatable(self, GC_ConveyorEffekt_mt);

	self.isServer = isServer;
	self.isClient = isClient;
	
	self.lastFillTypeIndex = nil;

	return self;
end;

function GC_ConveyorEffekt:load(id, target, xmlFile, xmlKey, groupKey)
	self.target = target;

	self.debugData = g_company.debug:getDebugData(GC_ConveyorEffekt.debugIndex, target);

	if self.isClient then
		if groupKey == nil then
			groupKey = "conveyorEffect";
		end;
		
		self.shaders = {};
		local i = 0;
		while true do
			local key = string.format("%s.%s.shader(%d)", xmlKey, groupKey, i);
			if not hasXMLProperty(xmlFile, key) then
				break;
			end;
			
			local shader = {};
			shader.node = I3DUtil.indexToObject(id, getXMLString(xmlFile, key.."#node"), self.target.i3dMappings);
			shader.fadeTime = Utils.getNoNil(getXMLFloat(xmlFile, key.."#fadeTime"), 1) * 1000;
			shader.startDelay = Utils.getNoNil(getXMLFloat(xmlFile, key.."#startDelay"), 0) * 1000;
			shader.stopDelay = Utils.getNoNil(getXMLFloat(xmlFile, key.."#stopDelay"), 0) * 1000;
			shader.materialType = Utils.getNoNil(getXMLString(xmlFile, key.."#materialType"), "BELT");
			shader.materialTypeId = Utils.getNoNil(getXMLInt(xmlFile, key.."#materialTypeId"), 1);
			
			shader.scrollLength = Utils.getNoNil(getXMLFloat(xmlFile, key.."#scrollLength"), 1);
			shader.scrollSpeed = Utils.getNoNil(getXMLFloat(xmlFile, key.."#scrollSpeed"), 1) * 0.001;
			shader.speed = Utils.getNoNil(getXMLFloat(xmlFile, key.."#speed"), 0.1);
			
			shader.state = GC_ConveyorEffekt.STATE_OFF;
			shader.currentDelay = shader.startDelay;
			shader.scrollPosition = 0;
			
			shader.fadeCur = {0,0};
			shader.fadeDir = {0,0};		
			
			setVisibility(shader.node, false)

			setShaderParameter(shader.node, "morphPosition", 0.0, 1.0, 1.0, 0.0, false);		
			
			
			local backupFillType = FillType.WHEAT
			
			-- Allow a set FillType only
			local fillTypeName = getXMLString(xmlFile, key .. "#forcedFillType")
			if fillTypeName ~= nil then
				local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
				if fillTypeIndex ~= nil then
					backupFillType = fillTypeIndex
					shader.forcedFillType = fillTypeIndex
				end
			end
			
			-- For factory fillType changing
			if shader.forcedFillType == nil then
				shader.productName = getXMLString(xmlFile, key .. "#productName")
			end
			
			-- Set a fillType as a backup or fixed.
			local material = g_materialManager:getMaterial(backupFillType, shader.materialType, shader.materialTypeId)
			if material ~= nil then
				setMaterial(shader.node, material, 0)
			end

			table.insert(self.shaders, shader);
			
			i = i + 1;
		end;
	
		-- g_company.addUpdateable(self, self.update);
		if #self.shaders > 0 then
			g_company.addRaisedUpdateable(self);
			return true;
		end;
	end;
	
	return false;
end;

function GC_ConveyorEffekt:delete()
	if self.isClient then
		-- g_company.removeUpdateable(self);
		g_company.removeRaisedUpdateable(self);
	end;
end;

function GC_ConveyorEffekt:update(dt)
	if self.isClient then
		for _, shader in pairs(self.shaders) do 
			if shader.state ~= GC_ConveyorEffekt.STATE_OFF then
				shader.currentDelay = shader.currentDelay - dt;
				
				if shader.currentDelay <= 0 then	
					shader.fadeCur[1] = math.max(0, math.min(1, shader.fadeCur[1] + shader.fadeDir[1] * (dt / shader.fadeTime)));
					shader.fadeCur[2] = math.max(0, math.min(1, shader.fadeCur[2] + shader.fadeDir[2] * (dt / shader.fadeTime)));
					shader.scrollPosition = (shader.scrollPosition + dt*shader.scrollSpeed) % shader.scrollLength;

					setShaderParameter(shader.node, "morphPosition", shader.fadeCur[1], shader.fadeCur[2], 0.1, shader.speed, false);    					
					setShaderParameter(shader.node, "offsetUV", shader.scrollPosition,0,-100,100, false);

					local isVisible = true;					
					if shader.state == GC_ConveyorEffekt.STATE_TURNING_ON and shader.fadeCur[1] == shader.fadeDir[1] and shader.fadeCur[2] == shader.fadeDir[2] then
						shader.state = GC_ConveyorEffekt.STATE_ON;
					elseif shader.state == GC_ConveyorEffekt.STATE_TURNING_OFF and shader.fadeCur[1] == shader.fadeDir[1] and shader.fadeCur[2] == shader.fadeDir[2] then
						shader.state = GC_ConveyorEffekt.STATE_OFF;
						shader.fadeCur[1] = 0;
						shader.fadeCur[2] = 0;
						isVisible = false;
					end;
					setVisibility(shader.node, isVisible);
				end;

				self:raiseUpdate();
			end;		
		end;
	end;
end;

function GC_ConveyorEffekt:setState(state, shader)
	if self.isClient then
		if state then
			self:start(shader);
		else
			self:stop(shader);
		end;
	end;
end;

function GC_ConveyorEffekt:start(shader)
	if shader ~= nil then
		self:startShader(shader);
	else
		for _, shader in pairs(self.shaders) do 
			self:startShader(shader);
		end;
	end;
	
	self:raiseUpdate();
end;

function GC_ConveyorEffekt:stop(shader)
	if shader ~= nil then
		self:stopShader(shader);
	else
		for _, shader in pairs(self.shaders) do 
			self:stopShader(shader);
		end;
	end;
	
	self:raiseUpdate();
end;

--Dont call from outside!! Only form GC_ConveyorEffekt.start!
function GC_ConveyorEffekt:startShader(shader)
	if shader.state ~= GC_ConveyorEffekt.STATE_TURNING_ON and shader.state ~= GC_ConveyorEffekt.STATE_ON then
		shader.state = GC_ConveyorEffekt.STATE_TURNING_ON;
		shader.currentDelay = shader.startDelay;
		shader.fadeDir = {0, 1};
        shader.fadeCur = {0, 0};
		return true;
	end;
	return false;
end;

--Dont call from outside!! Only form GC_ConveyorEffekt.stop!
function GC_ConveyorEffekt:stopShader(shader)
	if shader.state ~= GC_ConveyorEffekt.STATE_TURNING_OFF and shader.state ~= GC_ConveyorEffekt.STATE_OFF then
		shader.state = GC_ConveyorEffekt.STATE_TURNING_OFF;
		shader.currentDelay = shader.stopDelay;
		shader.fadeDir = {1, 1};
		return true;
	end;
	return false;
end;

function GC_ConveyorEffekt:resetShader(shader)
	if self.isClient then
		shader.fadeCur = {0, 0};
		shader.fadeDir = {0, 1};
		setShaderParameter(shader.node, "morphPosition", shader.fadeCur[1], shader.fadeCur[2], 0.1, shader.speed, false);
		shader.state = GC_ConveyorEffekt.STATE_OFF;
	end;
end;

function GC_ConveyorEffekt:setMorphPosition(shader, fade1, fade2)
	setShaderParameter(shader.node, "morphPosition", fade1, fade2, 0.1, shader.speed, false);
end;

function GC_ConveyorEffekt:getIsOn(shader, index)
	if shader ~= nil then
		return shader.state == GC_ConveyorEffekt.STATE_ON;
	elseif index ~= nil and self.shaders[index] ~= nil then
		return self.shaders[index].state == GC_ConveyorEffekt.STATE_ON;
	elseif table.getn(self.shaders) > 0 then
		local isOn = true;
		for k, shader in pairs(self.shaders) do 
			if shader.state ~= GC_ConveyorEffekt.STATE_ON then
				isOn = false;
				break;
			end;
		end;
		return isOn;
	end;
	return false;
end;

function GC_ConveyorEffekt:getIsOff(shader, index)
	if shader ~= nil then
		return shader.state == GC_ConveyorEffekt.STATE_OFF;
	elseif index ~= nil and self.shaders[index] ~= nil then
		return self.shaders[index].state == GC_ConveyorEffekt.STATE_OFF;
	elseif table.getn(self.shaders) > 0 then
		local isOff = true;
		for k, shader in pairs(self.shaders) do 
			if shader.state ~= GC_ConveyorEffekt.STATE_OFF then
				isOff = false;
				break;
			end;
		end;
		return isOff;
	else
		return false;
	end;
end;

function GC_ConveyorEffekt:getFadeTime(shader, index)
	if shader ~= nil then
		return shader.fadeTime;
	elseif index ~= nil and self.shaders[index] ~= nil then
		return self.shaders[index].fadeTime;
	else 
		return 0;
	end;
end;

function GC_ConveyorEffekt:setFillType(fillType)
	for _,shader in pairs(self.shaders) do
		if shader.materialType ~= nil and shader.materialTypeId ~= nil then
			local material = g_materialManager.materials[fillType][shader.materialType][shader.materialTypeId]
			if material ~= nil then
				setMaterial(shader.node, material, 0);
			--else
				--Debug.write(debugIndex, Debug.ERROR, "Material can't set for fillType %s", fillType);
			end;
		end;
	end;
end;