--
-- GlobalCompany - BaseGui - GC_AnimalDeliveryDialog
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 15.06.2019
-- @Version: 1.0.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
--		- v1.0.0.0 (15.06.2019):
-- 		- initial fs19 ()
--
--
-- Notes:
--
--
-- ToDo:
--
--


GC_AnimalDeliveryDialog = {}
local GC_AnimalDeliveryDialog_mt = Class(GC_AnimalDeliveryDialog, YesNoDialog)

GC_AnimalDeliveryDialog.CONTROLS = {
	ANIMAL_TYPE_ICON = "animalTypeIcon",
	ANIMAL_DESC_TEXT = "animalDescText",
	NUMBER_TO_ADD_ELEMENT = "numberToAddElement",
	MESSAGE_BACKGROUND = "messageBackground",
	NO_BUTTON = "noButton",
	YES_BUTTON = "yesButton"
}

function GC_AnimalDeliveryDialog:new()
	local self = YesNoDialog:new(nil, GC_AnimalDeliveryDialog_mt)
	
	self:registerControls(GC_AnimalDeliveryDialog.CONTROLS)

	self.numberSelected = 0
	self.isButtonDisabled = false
	
	self.animalType = nil
	self.iconFilename = ""

	return self
end

function GC_AnimalDeliveryDialog:setDialogData(animalsInTrailer, capacity)
	local animalsTable = {"    0"}

	if #animalsInTrailer > 0 then
		local animal = animalsInTrailer[1]
		local subType = animal:getSubType()

		self.animalType = subType.type
		self.animalFillTypeDesc = subType.fillTypeDesc

		self.animalTitle = self.animalFillTypeDesc.title
		self.iconFilename = self.animalFillTypeDesc.hudOverlayFilenameSmall		
		
		local maxToMove = math.min(#animalsInTrailer, capacity)
		for i = 1, maxToMove do			
			table.insert(animalsTable, string.format("    %d", i))
		end

		self.animalTypeIcon:setImageFilename(self.animalFillTypeDesc.hudOverlayFilenameSmall)
		self.messageBackground:setVisible(capacity <= 0)		
	else
		animalsTable[1] = "    N/A"
		self.animalTypeIcon:setImageFilename(nil)
		self.messageBackground:setVisible(false)
	end
	
	self.numberToAddElement:setTexts(animalsTable)
    self.numberToAddElement:setState(1, true)
	self:setYesButtonDisabled(true)
end

function GC_AnimalDeliveryDialog:onClickOk()
    if self.isButtonDisabled then
        return
    end

	local selectedCount = Utils.getNoNil(self.numberSelected, 0)
    self:sendCallback(selectedCount)
end

function GC_AnimalDeliveryDialog:onClickBack(forceBack, usedMenuButton)
	if (self.isCloseAllowed or forceBack) and not usedMenuButton then
		self:close()
		
		self:sendCallback(0)
		
		return false
	else
		return true
	end
end

function GC_AnimalDeliveryDialog:onClickNumberToDeliver(index)
	self.numberSelected = index - 1
	
	self:setYesButtonDisabled(self.numberSelected <= 0)

	local width = self.animalDescText:getTextWidth()
    self.animalTypeIcon:setPosition(self.animalDescText.position[1] - width * 0.5 - self.animalTypeIcon.margin[3], nil)
end

function GC_AnimalDeliveryDialog:setYesButtonDisabled(disabled)
	self.isButtonDisabled = disabled;
	self.yesButton:setDisabled(disabled)
end