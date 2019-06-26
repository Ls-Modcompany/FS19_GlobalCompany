--
-- GlobalCompany - BaseGui - GC_ProductionFactoryGui
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany / GtX
-- @Date: 16.06.2019
-- @Version: 1.1.0.0
--
-- @Support: https://ls-modcompany.com
--
-- Changelog:
--
-- 	v1.1.0.0 (16.06.2019):
--		- New script [GC_ProductionFactoryGui] using Giants GUI. (GtX)
--		- Camera feature added and output sale support.
--
--
-- 	v1.0.0.0 (00.00.2019):
-- 		- initial fs19 'GC GUI Version' (kevink98)
--		- GC_FactoryBigGui.lua.
--
--
-- Notes:
--		- The GC GUI currently does not support controllers and this is important for the factory.
--
--
-- ToDo:
--
--


GC_ProductionFactoryGui = {}
local GC_ProductionFactoryGui_mt = Class(GC_ProductionFactoryGui, ScreenElement)

GC_ProductionFactoryGui.MAX_INT = 2147483647

GC_ProductionFactoryGui.debugIndex = g_company.debug:registerScriptName("GC_ProductionFactoryGui")

GC_ProductionFactoryGui.CONTROLS = {
	FULL_BACKGROUND = "fullBackgroundElement",
	FACTORY_BOX_LEFT = "factoryBoxLeft",
	FACTORY_BOX_RIGHT = "factoryBoxRight",
	INPUT_HEADER_TEXT = "inputHeaderText",
	OUTPUT_HEADER_TEXT = "outputHeaderText",
	PRODUCT_LINE_ITEM_LIST = "productLineItemList",
	PRODUCT_LINE_ITEM_TEMPLATE = "productLineItemTemplate",
	OVERVIEW_PAGE = "overviewPage",
	PRODUCT_LINES_PAGE = "productLinesPage",
	FACTORY_OVERVIEW_HEADER = "overviewDescHeader",
	FACTORY_OVERVIEW_TEXT = "overviewDescText",
	FACTORY_OVERVIEW_IMAGE = "factoryOverviewImage",
	BALANCE_TEXT = "balanceText",
	FACTORY_NAME_HEADER_TEXT = "factoryNameHeaderText",
	SELECTED_PRODUCT_LINE_HEADER = "selectedProductLineHeader",
	PRODUCT_LINE_STATUS_TEXT = "productLineStatusText",
	PRODUCT_LINE_OPERATION_TEXT = "productLineOperationText",
	INPUT_PRODUCT_ITEM_LIST = "inputProductItemList",
	INPUT_PRODUCT_ITEM_TEMPLATE = "inputProductItemTemplate",
	OUTPUT_LIST_BOX = "outputListBox",
	NO_OUTPUT_OVERLAY = "noOutputOverlay",
	OUTPUT_PRODUCT_ITEM_LIST = "outputProductItemList",
	OUTPUT_PRODUCT_ITEM_TEMPLATE = "outputProductItemTemplate",
	LEFT_BUTTON_BOX = "leftButtonBox",
	BUTTON_ADD = "buttonAdd",
	BUTTON_REMOVE = "buttonRemove",
	BUTTON_PURCHASE = "buttonPurchase",
	BUTTON_START = "buttonStart"
}

function GC_ProductionFactoryGui:new(l10n, messageCenter)
	if g_company == nil then
		local debugData = g_company.debug:getDebugData(GC_ProductionFactoryGui.debugIndex)
		g_company.debug:writeDev(debugData, "Failed to find 'Global Company' global variable.")
		return
	end

	local self = ScreenElement:new(nil, GC_ProductionFactoryGui_mt)

	self:registerControls(GC_ProductionFactoryGui.CONTROLS)

	self.l10n = l10n
	self.messageCenter = messageCenter

	self.isOpen = false
	self.lastMoney = nil

	self.liveCamera = nil
	self.updateTimer = 600

	self.buyLiters = 0
	self.numberToSpawn = 0

	self.confirmDialogLitres = nil
	self.outputIsProductSale = false

	self.defaultImage = g_company.dir .. "images/factoryDefault.dds"

	self.texts = {}

	-- Do this here so we support as many languages as possible :-)
	local incomeText = self.l10n:getText("shop_income")
	if incomeText:find("%:$") then
		self.texts.incomeText = incomeText:sub(1, -2)
	else
		self.texts.incomeText = incomeText
	end

	self.texts.disabled = g_company.languageManager:getText("GC_gui_disabled")
	self.texts.add = g_company.languageManager:getText("GC_gui_add", " ( + )")
	self.texts.remove = g_company.languageManager:getText("GC_gui_remove", " ( - )")
	self.texts.max = g_company.languageManager:getText("GC_gui_max", " ( + )")

	self.texts.percent = g_company.languageManager:getText("GC_gui_percent", ":")
	self.texts.lifeTime = g_company.languageManager:getText("GC_gui_lifeTimeIncome")

	self.texts.descriptionHeader = g_company.languageManager:getText("GC_gui_description", ":")

	self.texts.spawnPalletOne = g_company.languageManager:getText("GC_gui_spawnText1")
	self.texts.spawnPalletTwo = g_company.languageManager:getText("GC_gui_spawnText2")

	self.texts.confirmPurchase = g_company.languageManager:getText("GC_Factory_Purchase_Warning")

	self.debugData = g_company.debug:getDebugData(GC_ProductionFactoryGui.debugIndex)

	return self
end

function GC_ProductionFactoryGui:setupFactoryData(factory, lineId)
	self.factory = factory
	self.lineId = lineId

	self:setupOverviewAndTexts(self.factory.guiData)
	if not self:setProductLines() then
		g_company.debug:writeError(self.debugData, "Failed to setup 'Product Lines' correctly!")
	end
end

function GC_ProductionFactoryGui:setupOverviewAndTexts(guiData)
	if guiData ~= nil then
		self.factoryNameHeaderText:setText(guiData.factoryTitle)

		if guiData.factoryCamera ~= nil then
			self.liveCamera = guiData.factoryCamera
		end

		if guiData.factoryImage ~= nil then
			self.factoryOverviewImage:setImageFilename(guiData.factoryImage)
		else
			self.factoryOverviewImage:setImageFilename(self.defaultImage)
		end

		if guiData.factoryDescription ~= nil then
			self.overviewDescHeader:setText(self.texts.descriptionHeader)
			self.overviewDescText:setText(guiData.factoryDescription)
		end

		if guiData.inputHeader ~= nil then
			self.inputHeaderText:setText(guiData.inputHeader)
		end

		if guiData.outputHeader ~= nil then
			self.outputHeaderText:setText(guiData.outputHeader)
		end
	end

	self.buttonAdd:setText(self.texts.add)
	self.buttonRemove:setText(self.texts.max)
end

function GC_ProductionFactoryGui:onOpen()
	GC_ProductionFactoryGui:superClass().onOpen(self)

	self.isOpen = true
	self.isUpdating = false

	self.pageSelector = {} -- Pretend to be 'TabbedMenu' to use input's.
	self.lastMoney = nil

	g_depthOfFieldManager:setBlurState(true)

	FocusManager:setFocus(self.productLineItemList)
end

function GC_ProductionFactoryGui:setProductLines()
	if self.factory == nil then
		return false
	end

	self.productLineItemList.ignoreUpdate = true
	self.productLineItemList:deleteListItems()

	local numProductLines = 0
	self.selectedIndexToLineId = {0}
	self.currentProductLineItemList = {}
	self.productLineElementMapping = {}

	self:setProductLineListItem({title = self.l10n:getText("ui_statisticViewOverview")}, 0)

	local productLines = self.factory.productLines
	for lineId, productLine in pairs(productLines) do
		if productLine.showInGUI then			
			self:setProductLineListItem(productLine, lineId)
			table.insert(self.selectedIndexToLineId, lineId)
		end
	end

	self.productLineItemList.ignoreUpdate = false
	self.productLineItemList:updateItemPositions()

	local numProductLines = #self.selectedIndexToLineId
	if numProductLines > 1 then
		if self.lineId ~= nil then
			local id = self.lineId + 1
			if id > 5 then
				self.productLineItemList:scrollTo(id, false)
			else
				self.productLineItemList:scrollTo(1, false)
			end
			self.productLineItemList:setSelectedIndex(id, true)
		else
			self.productLineItemList:scrollTo(1, false)
			self.productLineItemList:setSelectedIndex(1, true)
		end
	else
		self:onProductLineSelectionChanged(1)
	end

	local productionFactoryGui = self
	self.productLineItemList.onFocusEnter = function (self, ...)
		if self.selectedIndex > 0 and #self.listItems > 0 then
			local selectedIndex = self:getSelectedElementIndex()
			self.listItems[selectedIndex]:setSelected(true)
			if productionFactoryGui ~= nil then
				productionFactoryGui:productLineClearElementSelection(selectedIndex)
			end
		end
	end

	return true
end

function GC_ProductionFactoryGui:setProductLineListItem(productLine, lineId)
	self.currentProductLine = productLine
	self.currentProductLineId = lineId

	if lineId > 0 then
		self.productLineCanOperate = self.factory:getCanOperate(lineId)
		self.productLineElementMapping[lineId] = {}
	end

	local newListItem = self.productLineItemTemplate:clone(self.productLineItemList)
	newListItem:updateAbsolutePosition()
	
	-- table.insert(self.currentProductLineItemList, self.currentProductLine)
	--self.numProductLines = self.numProductLines + 1
	--self.currentProductLineItemList[lineId] = self.currentProductLine

	self.currentProductLine = nil
end

function GC_ProductionFactoryGui:onCreateProductLineName(element)
	if self.currentProductLine ~= nil then
		element:setText(self.currentProductLine.title)

		if self.currentProductLineId == 0 then
			element:applyProfile("productionLineListItemOverview")
		end
	end
end

function GC_ProductionFactoryGui:onCreateProductLineItem(element)
	if self.currentProductLine ~= nil and self.currentProductLineId == 0 then
		element:setVisible(false)
	end
end

function GC_ProductionFactoryGui:onCreateProductLineStatus(element)
	if self.currentProductLine ~= nil and self.currentProductLineId > 0 then
		self.productLineElementMapping[self.currentProductLineId].statusElement = element

		local statusText = self.texts.disabled
		if self.factory:getCanOperate(self.currentProductLineId) then
			if self.currentProductLine.active then
				statusText = self.l10n:getText("fieldJob_active")
			else
				statusText = self.l10n:getText("ui_off")
			end
		end

		element:setText(statusText)
	end
end

function GC_ProductionFactoryGui:onCreateProductLineProduction(element)
	if self.currentProductLine ~= nil and self.currentProductLineId > 0 then
		self.productLineElementMapping[self.currentProductLineId].outputPerHour = element

		if self.currentProductLine.active then
			element:setText(string.format(self.l10n:getText("shop_incomeValue"), self:formatVolume(self.currentProductLine.outputPerHour, true)))
		else
			element:setText(string.format(self.l10n:getText("shop_incomeValue"), self:formatVolume(0, true)))
		end
	end
end

function GC_ProductionFactoryGui:onProductLineSelectionChanged(selectedIndex)
	if not self.productLineItemList.ignoreUpdate then
		self.overviewActive = selectedIndex <= 1
		self.overviewPage:setVisible(self.overviewActive)
		self.productLinesPage:setVisible(not self.overviewActive)

		-- self.selectedProductLineId = selectedIndex - 1
		self.selectedProductLineId = Utils.getNoNil(self.selectedIndexToLineId[selectedIndex], 0)

		local leftButtonActive = true
		if self.overviewActive then
			leftButtonActive = self.liveCamera ~= nil
			if leftButtonActive then
				self.buttonStart:setText(self.l10n:getText("input_CAMERA_SWITCH"))
			end
		else
			self:setProductLinePage(self.selectedProductLineId, true)
		end

		self:setButtonState(leftButtonActive, false, false)
	end
end

function GC_ProductionFactoryGui:productLineClearElementSelection(selectedIndex)
	self:setButtonState(true, false, false)
	self.productLineElementSelected = true
	self:resetPurchaseAndPallets()

	self.inputProductItemList:clearElementSelection()
	self.outputProductItemList:clearElementSelection()
end

function GC_ProductionFactoryGui:onScrollInputProduct()
	if self.selectedOutput ~= nil or self.productLineElementSelected == true then
		self.inputProductItemList:clearElementSelection()
	end
end

function GC_ProductionFactoryGui:onScrollOutputProduct()
	if self.selectedInput ~= nil or self.productLineElementSelected == true then
		self.outputProductItemList:clearElementSelection()
	end
end

function GC_ProductionFactoryGui:setProductLinePage(lineId, doPageCreate)
	if lineId <= 0 then
		return
	end

	local selectedProductLine = self.factory.productLines[lineId]
	self:updateProductLineListItem(selectedProductLine, lineId, lineId)

	if doPageCreate then
		self.selectedProductLineHeader:setText(selectedProductLine.title)

		local productionFactoryGui = self
		local inputProducts = selectedProductLine.inputs
		if inputProducts ~= nil then
			self.inputProductItemList.ignoreUpdate = true
			self.inputProductItemList:deleteListItems()

			self.currentInputItemList = {}
			self.inputElementMapping = {}

			for id, inputProduct in pairs(inputProducts) do
				self.currentInputProduct = inputProduct
				self.currentInputProductId = id
				self.inputElementMapping[id] = {}

				local newListItem = self.inputProductItemTemplate:clone(self.inputProductItemList)
				newListItem:updateAbsolutePosition()
				table.insert(self.currentInputItemList, self.currentInputProduct)

				self.currentInputProduct = nil
			end

			self.inputProductItemList.ignoreUpdate = false
			self.inputProductItemList:updateItemPositions()

			self.inputProductItemList.onFocusEnter = function (self, ...)
				if self.selectedIndex > 0 and #self.listItems > 0 then
					local selectedIndex = self:getSelectedElementIndex()
					self.listItems[selectedIndex]:setSelected(true)
					if productionFactoryGui ~= nil then
						productionFactoryGui.productLineElementSelected = nil
						productionFactoryGui:onInputProductSelectionChanged(selectedIndex)
					end
				end
			end
		end

		self.outputIsProductSale = false
		self.currentOutputItemList = nil
		self.currentProductSaleItemList = nil

		local displayOutputs = false
		if not self.factory.disableAllOutputGUI then
			local outputProducts = selectedProductLine.outputs
			if outputProducts == nil and selectedProductLine.productSale ~= nil then
				self.outputIsProductSale = true
				outputProducts = selectedProductLine.productSale
			end

			if outputProducts ~= nil then
				displayOutputs = true
				self.outputProductItemList.ignoreUpdate = true
				self.outputProductItemList:deleteListItems()

				self.outputElementMapping = {}

				if self.outputIsProductSale then
					self.currentOutputProduct = outputProducts
					self.currentOutputProductId = 1
					self.outputElementMapping[self.currentOutputProductId] = {}

					local newListItem = self.outputProductItemTemplate:clone(self.outputProductItemList)
					newListItem:updateAbsolutePosition()

					self.currentProductSaleItemList = outputProducts
				else
					self.currentOutputItemList = {}

					for id, outputProduct in pairs(outputProducts) do
						self.currentOutputProduct = outputProduct
						self.currentOutputProductId = id
						self.outputElementMapping[id] = {}

						local newListItem = self.outputProductItemTemplate:clone(self.outputProductItemList)
						newListItem:updateAbsolutePosition()
						table.insert(self.currentOutputItemList, self.currentOutputProduct)

						self.currentOutputProduct = nil
					end
				end

				self.currentOutputProduct = nil

				self.outputProductItemList.ignoreUpdate = false
				self.outputProductItemList:updateItemPositions()

				self.outputProductItemList.onFocusEnter = function (self, ...)
					if self.selectedIndex > 0 and #self.listItems > 0 then
						local selectedIndex = self:getSelectedElementIndex()
						self.listItems[selectedIndex]:setSelected(true)
						if productionFactoryGui ~= nil then
							productionFactoryGui.productLineElementSelected = nil
							productionFactoryGui:onOutputProductSelectionChanged(selectedIndex)
						end
					end
				end
			end
		end

		self.outputListBox:setVisible(displayOutputs)
		self.noOutputOverlay:setVisible(not displayOutputs)

		self:productLineClearElementSelection(self.selectedProductLineId)
	else
		self:updateProductLinePage(false)
	end
end

function GC_ProductionFactoryGui:updateProductLinePage(updateListItems)
	if self.selectedProductLineId == nil or self.selectedProductLineId <= 0 then
		return
	end

	local selectedProductLine = self.factory.productLines[self.selectedProductLineId]
	if selectedProductLine ~= nil then
		if updateListItems then
			for lineId, productLine in pairs (self.factory.productLines) do
				self:updateProductLineListItem(productLine, lineId, self.selectedProductLineId)
			end
		end

		if self.currentInputItemList ~= nil then
			for inputId, _ in pairs (self.currentInputItemList) do
				local elements = self.inputElementMapping[inputId]
				if elements ~= nil then
					local inputProduct = selectedProductLine.inputs[inputId]
					elements.fillLevel:setText(self:formatVolume(inputProduct.fillLevel, true))
					self:updateStatusBar(elements.statusBar, elements.statusBarSize, inputProduct, true, false)
					elements.percent:setText(MathUtil.getFlooredPercent(inputProduct.fillLevel, inputProduct.capacity) .. "%")
				end
			end
		end

		if self.currentOutputItemList ~= nil then
			for outputId, _ in pairs (self.currentOutputItemList) do
				local elements = self.outputElementMapping[outputId]
				if elements ~= nil then
					local outputProduct = selectedProductLine.outputs[outputId]
					if elements.fillLevel ~= nil then
						elements.fillLevel:setText(self:formatVolume(outputProduct.fillLevel, true))
					end
					if elements.statusBar ~= nil then
						self:updateStatusBar(elements.statusBar, elements.statusBarSize, outputProduct, false, false)
					end
					if elements.percent ~= nil then
						elements.percent:setText(MathUtil.getFlooredPercent(outputProduct.fillLevel, outputProduct.capacity) .. "%")
					end
				end
			end
		elseif self.currentProductSaleItemList ~= nil then
			local elements = self.outputElementMapping[1]
			if elements ~= nil then
				local productSale = selectedProductLine.productSale
				elements.incomePerHour:setText(self.l10n:formatMoney(productSale.incomePerHour, 0, true, true))
				self:updateStatusBar(elements.statusBar, elements.statusBarSize, productSale, true, true)
				elements.percent:setText(MathUtil.getFlooredPercent(productSale.productivityHours, 24) .. "%")

				if productSale.lifeTimeIncome < GC_ProductionFactoryGui.MAX_INT then
					elements.lifeTimeIncome:setText(self.l10n:formatMoney(productSale.lifeTimeIncome, 0, true, true))
				else
					elements.lifeTimeIncome:setText(self.l10n:formatMoney(productSale.lifeTimeIncome, 0, true, true) .. " +")
				end
			end
		end
	end
end

function GC_ProductionFactoryGui:updateProductLineListItem(productLine, productLineId, currentProductLineId)
	if productLine ~= nil and productLineId ~= nil then
		local buttonText = self.texts.disabled
		local statusText = self.texts.disabled
		local operationText = "N/A"

		local productLineCanOperate = self.factory:getCanOperate(productLineId)
		if productLineCanOperate then
			if productLine.active then
				statusText = self.l10n:getText("fieldJob_active")
				buttonText = self.l10n:getText("action_stop")
			else
				statusText = self.l10n:getText("ui_off")
				buttonText = self.l10n:getText("button_start")
			end
		end

		if currentProductLineId ~= nil and currentProductLineId > 0 then
			if productLineId == currentProductLineId then
				if productLine.autoStart then
					if productLine.userStopped then
						if not productLineCanOperate then
							buttonText = self.l10n:getText("ui_auto")
						end

						operationText = self.l10n:getText("ui_off")
					else
						if not productLineCanOperate then
							buttonText = self.l10n:getText("ui_auto")
						end

						operationText = self.l10n:getText("ui_on")
					end
				end

				self.buttonStart:setText(buttonText)
				self.productLineStatusText:setText(statusText)
				self.productLineOperationText:setText(operationText)

				if self.selectedInput ~= nil and self.factory:canBuyProduct() then
					self:setButtonState(nil, (self.selectedInput.capacity - self.selectedInput.fillLevel) > 0, false)
				end
			end
		end

		local elementMapping = self.productLineElementMapping[productLineId]
		if elementMapping ~= nil then
			if elementMapping.statusElement ~= nil then
				elementMapping.statusElement:setText(statusText)
			end

			if elementMapping.outputPerHour ~= nil then
				local outputPerHour = 0
				if productLine.active then
					outputPerHour = productLine.outputPerHour
				end
				elementMapping.outputPerHour:setText(string.format(self.l10n:getText("shop_incomeValue"), self:formatVolume(outputPerHour, true)))
			end
		end
	end
end

function GC_ProductionFactoryGui:updateStatusBar(statusBar, statusBarSize, product, isInput, isProductSale)
	local barValue = 0
	if not isProductSale then
		barValue = MathUtil.clamp(product.fillLevel / product.capacity, 0, 1)
	else
		barValue = MathUtil.clamp(product.productivityHours / 24, 0, 1)
	end

	if barValue < 0.15 then
		if isInput then
			statusBar:applyProfile("productStatusBarLow")
		else
			statusBar:applyProfile("productStatusBarNormal")
		end
	elseif barValue < 0.50 then
		statusBar:applyProfile("productStatusBarMedium")
	else
		if isInput then
			statusBar:applyProfile("productStatusBarNormal")
		else
			statusBar:applyProfile("productStatusBarLow")
		end
	end

	statusBar:setSize(statusBarSize * barValue)
end

function GC_ProductionFactoryGui:onInputProductSelectionChanged(selectedIndex)
	if not self.inputProductItemList.ignoreUpdate then
		self:resetPurchaseAndPallets()
		self:setPurchaseAmount()

		local buttonState = false
		local inputs = self.factory:getInputs(self.selectedProductLineId)
		if inputs ~= nil then
			self.selectedInput = inputs[selectedIndex]

			if self.selectedInput ~= nil and (self.selectedInput.capacity - self.selectedInput.fillLevel) > 0 then
				buttonState = self.factory:canBuyProduct()
			end
		end

		self:setButtonState(nil, buttonState, false)

		self.productLineItemList:clearElementSelection()
		self.outputProductItemList:clearElementSelection()
	end
end

function GC_ProductionFactoryGui:onOutputProductSelectionChanged(selectedIndex)
	if not self.outputProductItemList.ignoreUpdate then
		self:resetPurchaseAndPallets()
		self:setPalletSpawnAmount()

		local outputs = self.factory:getOutputs(self.selectedProductLineId)
		if outputs ~= nil then
			self.selectedOutput = outputs[selectedIndex]
		end

		local buttonState = self.selectedOutput ~= nil and self.selectedOutput.objectSpawner ~= nil
		self:setButtonState(nil, buttonState, false)

		self.productLineItemList:clearElementSelection()
		self.inputProductItemList:clearElementSelection()
	end
end

function GC_ProductionFactoryGui:onCreateProductName(element, argument)
	if argument == "OUTPUT" then
		if self.currentOutputProduct ~= nil then
			element:setText(self.currentOutputProduct.title)
		end
	else
		if self.currentInputProduct ~= nil then
			element:setText(self.currentInputProduct.title)
		end
	end
end

function GC_ProductionFactoryGui:onCreateProductFillLevel(element, argument)
	if argument == "OUTPUT" then
		if self.currentOutputProduct ~= nil then
			if self.outputIsProductSale then
				self.outputElementMapping[self.currentOutputProductId].incomePerHour = element
				element:setText(self.l10n:formatMoney(self.currentOutputProduct.incomePerHour, 0, true, true))
			else
				self.outputElementMapping[self.currentOutputProductId].fillLevel = element
				element:setText(self:formatVolume(self.currentOutputProduct.fillLevel, true))
			end
		end
	else
		if self.currentInputProduct ~= nil then
			self.inputElementMapping[self.currentInputProductId].fillLevel = element
			element:setText(self:formatVolume(self.currentInputProduct.fillLevel, true))
		end
	end
end

function GC_ProductionFactoryGui:onCreateProductStatusBar(element, argument)
	if argument == "OUTPUT" then
		if self.currentOutputProduct ~= nil then
			local size = element.size[1]
			self.outputElementMapping[self.currentOutputProductId].statusBarSize = size
			self.outputElementMapping[self.currentOutputProductId].statusBar = element

			local isProductSale = self.currentOutputProduct.productivityHours ~= nil
			self:updateStatusBar(element, size, self.currentOutputProduct, false, isProductSale)
		end
	else
		if self.currentInputProduct ~= nil then
			local size = element.size[1]
			self.inputElementMapping[self.currentInputProductId].statusBarSize = size
			self.inputElementMapping[self.currentInputProductId].statusBar = element

			self:updateStatusBar(element, size, self.currentInputProduct, true, false)
		end
	end
end

function GC_ProductionFactoryGui:onCreateProductPercent(element, argument)
	if argument == "OUTPUT" then
		if self.currentOutputProduct ~= nil then
			self.outputElementMapping[self.currentOutputProductId].percent = element

			if self.outputIsProductSale then
				element:setText(MathUtil.getFlooredPercent(self.currentOutputProduct.productivityHours, 24) .. "%")
			else
				element:setText(MathUtil.getFlooredPercent(self.currentOutputProduct.fillLevel, self.currentOutputProduct.capacity) .. "%")
			end
		end
	else
		if self.currentInputProduct ~= nil then
			self.inputElementMapping[self.currentInputProductId].percent = element
			element:setText(MathUtil.getFlooredPercent(self.currentInputProduct.fillLevel, self.currentInputProduct.capacity) .. "%")
		end
	end
end

function GC_ProductionFactoryGui:onCreateProductCapacity(element, argument)
	if argument == "OUTPUT" then
		if self.currentOutputProduct ~= nil then
			if self.outputIsProductSale then
				element:setText(self.l10n:formatMoney(self.currentOutputProduct.lifeTimeIncome, 0, true, true))
				self.outputElementMapping[self.currentOutputProductId].lifeTimeIncome = element
			else
				element:setText(self:formatVolume(self.currentOutputProduct.capacity, true))
			end
		end
	else
		if self.currentInputProduct ~= nil then
			element:setText(self:formatVolume(self.currentInputProduct.capacity, true))
		end
	end
end

function GC_ProductionFactoryGui:onCreateInputProductFillTypes(element, argument)
	if self.currentInputProduct ~= nil then
		element:setText(self.currentInputProduct.concatedFillTypeTitles)
	end
end

function GC_ProductionFactoryGui:onCreateOutputFillLevelText(element)
	if self.currentOutputProduct ~= nil then
		if self.outputIsProductSale then
			element:setText(string.format(self.l10n:getText("shop_incomeValue"), self.texts.incomeText))
		else
			element:setText(self.l10n:getText("info_fillLevel") .. ":")
		end
	end
end

function GC_ProductionFactoryGui:onCreateOutputPercentText(element)
	if self.currentOutputProduct ~= nil then
		if self.outputIsProductSale then
			element:setText(string.format(self.l10n:getText("shop_maintenanceValue"), self.l10n:getText("statistic_productivity")))
		else
			element:setText(self.texts.percent)
		end
	end
end

function GC_ProductionFactoryGui:onCreateOutputCapacityText(element)
	if self.currentOutputProduct ~= nil then
		if self.outputIsProductSale then
			element:setText(self.texts.lifeTime)
		else
			element:setText(self.l10n:getText("shop_capacity"))
		end
	end
end

function GC_ProductionFactoryGui:update(dt)
	GC_ProductionFactoryGui:superClass().update(self, dt)

	if g_currentMission ~= nil and g_currentMission.player ~= nil then
		local farm = g_farmManager:getFarmById(g_currentMission.player.farmId)
		if self.lastMoney ~= farm.money then
			self:updateBalanceText(farm.money)
		end
	end

	self.updateTimer = self.updateTimer - dt
	if self.updateTimer < 0 then
		self:updateProductLinePage(true)
		self.updateTimer = 600
	end
end

function GC_ProductionFactoryGui:onClose(element)
	GC_ProductionFactoryGui:superClass().onClose(self)

	self.isOpen = false
	self:setLiveCamera(false, true)

	--g_currentMission:resetGameState()
	--self.messageCenter:unsubscribeAll(self)

	g_depthOfFieldManager:setBlurState(false)
end

function GC_ProductionFactoryGui:onClickBack()
	GC_ProductionFactoryGui:superClass().onClickBack(self)
	self:changeScreen()
end

function GC_ProductionFactoryGui:onClickOk()
	if not self.buttonsLeftActive then
		return
	end

	GC_ProductionFactoryGui:superClass().onClickOk(self)

	if self.overviewActive then
		if self.liveCamera ~= nil then
			self:setLiveCamera(not self.liveCameraActive, false)
		end
	else
		if self.selectedProductLineId ~= nil and self.selectedProductLineId > 0 then
			local productLine = self.factory.productLines[self.selectedProductLineId]
			if self.factory:getCanOperate(self.selectedProductLineId) then
				self.factory:setFactoryState(self.selectedProductLineId, not productLine.active)
			else
				self.factory:setFactoryState(self.selectedProductLineId, false, not productLine.userStopped)
			end

			self:setProductLinePage(self.selectedProductLineId, false)
		end
	end
end

function GC_ProductionFactoryGui:onClickActivate()
	if self.buttonsRightActive then
		if self.selectedInput ~= nil then
			local buyLiters = self.buyLiters
			if buyLiters > 0 then
				self.confirmDialogLitres = buyLiters
				local validLitres, price = self.factory:getProductBuyPrice(self.selectedInput, buyLiters)
				--local text = string.format(self.texts.confirmPurchase, self.selectedInput.title, self:formatVolume(validLitres, true), self.l10n:formatMoney(price, 0, true, true))
				local text = string.format("Please confirm the following purchase. \n\nInput Product:  %s\nVolume:  %s\nCost:  %s", self.selectedInput.title, self:formatVolume(validLitres, true), self.l10n:formatMoney(price, 0, true, true))

				g_gui:showYesNoDialog({text = text, title = "", callback = self.onConfirmPurchase, target = self})
			end
		elseif self.selectedOutput ~= nil then
			self.factory:spawnPalletFromOutput(self.selectedOutput, self.numberToSpawn)
			self:setProductLinePage(self.selectedProductLineId, false)

			self.numberToSpawn = 0
			self:setPalletSpawnAmount()
		end
	end
end

function GC_ProductionFactoryGui:onConfirmPurchase(confirm)
	if self.selectedInput ~= nil then
		if confirm then
			self.factory:doProductPurchase(self.selectedInput, self.buyLiters)
			self:setProductLinePage(self.selectedProductLineId, false)
			self.buyLiters = 0
		else
			self.buyLiters = 0
			self:setPurchaseAmount(self.selectedInput, self.confirmDialogLitres)
		end
	end

	self.confirmDialogLitres = nil
end

function GC_ProductionFactoryGui:onPageNext()
	if self.buttonsRightActive then
		if self.selectedInput ~= nil then
			self:setPurchaseAmount(self.selectedInput, 500)
		elseif self.selectedOutput ~= nil then
			self:setPalletSpawnAmount(self.selectedOutput, 1)
		end

		self:playAddRemoveSample()
	end
end

function GC_ProductionFactoryGui:onPagePrevious()
	if self.buttonsRightActive then
		if self.selectedInput ~= nil then
			self:setPurchaseAmount(self.selectedInput, -500)
		elseif self.selectedOutput ~= nil then
			self:setPalletSpawnAmount(self.selectedOutput, -1)
		end

		self:playAddRemoveSample()
	end
end

function GC_ProductionFactoryGui:setButtonState(leftState, rightState, force)
	if (leftState ~= nil and leftState ~= self.buttonsLeftActive) or force then
		self.buttonsLeftActive = leftState

		self.buttonStart:setVisible(leftState)
		self.buttonStart:setDisabled(not leftState)
	end

	if (rightState ~= nil and rightState ~= self.buttonsRightActive) or force then
		self.buttonsRightActive = rightState

		self.leftButtonBox:setVisible(rightState)
		self.buttonPurchase:setDisabled(not rightState)
		self.buttonRemove:setDisabled(not rightState)
		self.buttonAdd:setDisabled(not rightState)
	end
end

function GC_ProductionFactoryGui:setPurchaseAmount(input, litres)
	local purchaseText, removeText = "", self.texts.max

	if input ~= nil and litres ~= nil then
		self.buyLiters = self.factory:changeBuyLiters(input, litres, self.buyLiters)
		local validLitres, price = self.factory:getProductBuyPrice(input, self.buyLiters)
		purchaseText = string.format("%s ( %s ) ( %s )", self.l10n:getText("button_buy"), self:formatVolume(validLitres, false), self.l10n:formatMoney(price, 0, true, true))

		if validLitres > 0 then
			removeText = self.texts.remove
		end
	else
		purchaseText = string.format("%s ( %s ) ( %s )", self.l10n:getText("button_buy"), self:formatVolume(0, false), self.l10n:formatMoney(0, 0, true, true))
	end

	self.buttonPurchase:setText(purchaseText)
	self.buttonRemove:setText(removeText)
end

function GC_ProductionFactoryGui:setPalletSpawnAmount(output, number)
	local spawnText, removeText = "", self.texts.max

	if output ~= nil and number ~= nil then
		self.numberToSpawn = self.factory:changeNumberToSpawn(output, number, self.numberToSpawn)
		if self.numberToSpawn > 1 then
			spawnText = string.format(self.texts.spawnPalletTwo, self.numberToSpawn)
		else
			spawnText = string.format(self.texts.spawnPalletOne, self.numberToSpawn)
		end

		if self.numberToSpawn > 0 then
			removeText = self.texts.remove
		end
	else
		spawnText = string.format(self.texts.spawnPalletOne, "0")
	end

	self.buttonPurchase:setText(spawnText)
	self.buttonRemove:setText(removeText)
end

function GC_ProductionFactoryGui:resetPurchaseAndPallets()
	if self.selectedInput ~= nil and self.confirmDialogLitres == nil then
		self.buyLiters = 0
		self.selectedInput = nil
	end

	if self.selectedOutput ~= nil then
		self.numberToSpawn = 0
		self.selectedOutput = nil
	end
end

function GC_ProductionFactoryGui:updateBalanceText(money)
	self.lastMoney = money
	self.balanceText:setText(self.l10n:formatMoney(money, 0, true, true))
	if money > 0 then
		self.balanceText:setTextColor(1, 1, 1, 1)
	else
		self.balanceText:setTextColor(0.2832, 0.0091, 0.0091, 1)
	end
end

function GC_ProductionFactoryGui:setLiveCamera(activateCamera, isClose)
	local active = true

	self.liveCameraActive = activateCamera
	if self.liveCameraActive then
		if self.liveCamera ~= nil then
			self.originalCamera = getCamera()
			if self.originalCamera ~= nil then
				active = false
				setCamera(self.liveCamera)
				self.buttonStart:setText(self.l10n:getText("ui_statisticViewOverview"))
			end
		end
	else
		if self.originalCamera ~= nil then
			setCamera(self.originalCamera)
			self.originalCamera = nil
			self.buttonStart:setText(self.l10n:getText("input_CAMERA_SWITCH"))
		end
	end

	self.factoryBoxLeft:setVisible(active)
	self.factoryBoxRight:setVisible(active)
	self.fullBackgroundElement:setVisible(active)

	if not isClose and self.isOpen then
		g_depthOfFieldManager:setBlurState(active)
	end
end

function GC_ProductionFactoryGui:playAddRemoveSample()
	if not self.nextClickSoundMuted then
		self:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
	end
end

function GC_ProductionFactoryGui:formatVolume(litres, useLongName)
	if litres == nil then
		litres = 0
	end

	return self.l10n:formatNumber(litres, 0) .. " " .. self.l10n:getVolumeUnit(useLongName)
end