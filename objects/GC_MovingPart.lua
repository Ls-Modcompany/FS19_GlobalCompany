-- 
-- GlobalCompany - Objects - MovingParts
-- 
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 02.02.2019
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
-- 	v1.0.0.0 (02.02.2019):
-- 
-- ToDo:
-- 


GC_MovingPart = {};
getfenv(0)["GC_MovingPart"] = GC_MovingPart;

GC_MovingPart_mt = Class(GC_MovingPart, Object);
InitObjectClass(GC_MovingPart, "GC_MovingPart");

function GC_MovingPart:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_MovingPart_mt;
	end;

	return Object:new(isServer, isClient, customMt);
end;

function GC_MovingPart:load(nodeId, xmlFile, key, i3dMappings)
	GC_MovingPart:superClass().delete(self, nodeId, xmlFile, key, i3dMappings);
	
	self.animation = GC_Animations:new(self.isServer, self.isClient);
	self.animation:load(nodeId, true, nil, xmlFile, key, i3dMappings);

	self.axis = getXMLString(xmlFile, key .. "#axis");
	self.iconName = getXMLString(xmlFile, key .. "#iconName");
	self.mouseSpeedFactor = Utils.getNoNil(getXMLFloat(xmlFile, key.."#mouseSpeedFactor"), 1.0);
		
	self.axisIndex = InputBinding[self.axis];
		
	return true;
end;



function GC_MovingPart:delete()
	GC_MovingPart:superClass().delete(self);
end

function GC_MovingPart:readStream(streamId, connection)
	GC_MovingPart:superClass().readStream(self, streamId, connection);
end;

function GC_MovingPart:writeStream(streamId, connection)
	GC_MovingPart:superClass().writeStream(self, streamId, connection);
end;

function GC_MovingPart:readUpdateStream(streamId, timestamp, connection)
	GC_MovingPart:superClass().readUpdateStream(self, streamId, timestamp, connection);
end;

function GC_MovingPart:writeUpdateStream(streamId, connection, dirtyMask)
	GC_MovingPart:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);
end;

function GC_MovingPart:update(dt)
	GC_MovingPart:superClass().update(self, dt);
	
	
	local move, axisType = getInputAxis(self.axisActionIndex);

	if axisType == InputBinding.INPUTTYPE_MOUSE_AXIS then
		move = move * self.mouseSpeedFactor;
	else
		move = move * g_gameSettings:getValue("vehicleArmSensitivity")
	end

	local rotSpeed = 0;

	print(move)

end;


function GC_MovingPart:mouseEvent(posX, posY, isDown, isUp, button)
    GC_MovingPart:superClass().mouseEvent(self, posX, posY, isDown, isUp, button);

end