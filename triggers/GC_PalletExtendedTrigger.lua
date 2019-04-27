--
-- GlobalCompany - Triggers - GC_PalletExtendedTrigger
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98 
-- @Date: 08.03.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.0.0.0 (08.03.2018):
-- 		- initial fs19 (kevink98)
--
-- Notes:
--
-- ToDo:
--
--


GC_PalletExtendedTrigger = {};

local GC_PalletExtendedTrigger_mt = Class(GC_PalletExtendedTrigger, Object);
InitObjectClass(GC_PalletExtendedTrigger, "GC_PalletExtendedTrigger");
GC_PalletExtendedTrigger.debugIndex = g_company.debug:registerScriptName("GC_PalletExtendedTrigger");

g_company.baleTrigger = GC_PalletExtendedTrigger;

GC_PalletExtendedTrigger.MODE_COUNTER = 0;

function GC_PalletExtendedTrigger:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GC_PalletExtendedTrigger_mt;
	end;

	local self = Object:new(isServer, isClient, customMt);

	self.triggerManagerRegister = true;

	return self;
end

function GC_PalletExtendedTrigger:load(nodeId, target, xmlFile, xmlKey, reference, mode)
	if nodeId == nil or target == nil then
		return false;
	end;

	self.debugData = g_company.debug:getDebugData(GC_PalletExtendedTrigger.debugIndex, target);

	self.rootNode = nodeId;
	self.target = target;
    self.reference = reference;
    self.mode = mode;
	
	self.palletsInside = {};

	if xmlFile ~= nil and xmlKey ~= nil then
		local palletTriggerNode = getXMLString(xmlFile, xmlKey .. "#palletTriggerNode");
		if not self:setTriggerNode(palletTriggerNode) then
			g_company.debug:logWrite(self.debugData, GC_DebugUtils.MODDING, "Error loading 'palletTriggerNode' %s!", palletTriggerNode);
		end;
	end;

    return true;
end;

function GC_PalletExtendedTrigger:setTriggerNode(palletTriggerNode)
	if palletTriggerNode ~= nil then
		self.palletTriggerNode = I3DUtil.indexToObject(self.rootNode, palletTriggerNode, self.target.i3dMappings);
		if self.palletTriggerNode ~= nil then
            addTrigger(self.palletTriggerNode, "palletTriggerCallback", self);
            
            self.childTriggers = {};
            for i=1, getNumOfChildren(self.palletTriggerNode) do
                local childTrigger = getChildAt(self.palletTriggerNode, i-1);
                addTrigger(childTrigger, "palletTriggerCallback", self);
                table.insert(self.childTriggers, childTrigger);
            end;

			return true;
		end;
	end;

	return false;
end;

function GC_PalletExtendedTrigger:delete()
	if self.palletTriggerNode ~= nil then
		removeTrigger(self.palletTriggerNode);
    end;
    for _, trigger in pairs(self.childTriggers) do
        removeTrigger(trigger);
    end;
end;

function GC_PalletExtendedTrigger:palletTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local object = g_currentMission:getNodeObject(otherId)
	if object ~= nil and object.typeName == "palletExtended" then
        if onEnter then	
            self.palletsInside[object] = object;
            if self.target.onEnterPalletExtendedTrigger ~= nil then
                self.target:onEnterPalletExtendedTrigger(self.reference, object);
            end;
        elseif onLeave then
            self.palletsInside[object] = nil;
            if self.target.onLeavePalletExtendedTrigger ~= nil then
                self.target:onLeavePalletExtendedTrigger(self.reference, object);
            end;
        end;
	end;
end;

function GC_PalletExtendedTrigger:getFullFillLevel()
    local fillLevel = 0;
    for _, object in pairs(self.palletsInside) do
        fillLevel = fillLevel + object:getFillLevel();
    end;
    return fillLevel;
end;

function GC_PalletExtendedTrigger:getFullFillLevelByFillType(filltype)
    local fillLevel = 0;
    for _, object in pairs(self.palletsInside) do
        if object:getFillTyp() == filltype then
            fillLevel = fillLevel + object:getFillLevel();
        end;
    end;
    return fillLevel;
end;

function GC_PalletExtendedTrigger:getAvailableFillTypes()
    local fillTypes = {};
    for _, object in pairs(self.palletsInside) do
        table.insert(fillTypes, object:getFillTyp());
    end;
    return fillTypes;
end;