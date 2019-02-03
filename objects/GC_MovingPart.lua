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
g_company.movingPart = GC_MovingPart;

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
	self.animation:load(nodeId, true, key, xmlFile, nil, i3dMappings);

	self.mouseSpeedFactor = Utils.getNoNil(getXMLFloat(xmlFile, key.."#mouseSpeedFactor"), 1.0);

	self.axis = InputAction[getXMLString(xmlFile, key.."#axis")];

	self.animationState = 0;

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
	
	self.animation:setAnimationsState2(self.animationState);
	self.animationState = 0;
end;

function GC_MovingPart:addRemoveInputs()
	if self.eventId == nil then
		local _, eventId = g_inputBinding:registerActionEvent(self.axis, self, self.onMove, false, false, true, true);
		self.eventId = eventId;
	else
		g_inputBinding:removeActionEvent(self.eventId);
		self.eventId = nil;
	end;
end;

function GC_MovingPart:onMove(_,value,_,_,isMouse)
	if value > 0 then
		self.animationState = 1;
	elseif value < 0 then
		self.animationState = -1;
	end;
end

