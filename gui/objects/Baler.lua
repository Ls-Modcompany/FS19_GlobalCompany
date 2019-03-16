





Gc_Gui_Baler = {};
Gc_Gui_Baler.xmlFilename = g_company.dir .. "gui/objects/Baler.xml";
Gc_Gui_Baler.debugIndex = g_company.debug:registerScriptName("GC_GUI_Baler");

local Gc_Gui_Baler_mt = Class(Gc_Gui_Baler);

function Gc_Gui_Baler:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_Baler_mt;
    end;
	local self = setmetatable({}, Gc_Gui_Baler_mt);
			
	return self;
end;

function Gc_Gui_Baler:onCreate() end;

function Gc_Gui_Baler:setData(baler)
    self.baler = baler;
    self:updateButtons();
    
    self.gui_txt_title:setText(g_company.languageManager:getText(self.baler.title));
    self.gui_text_num:setText(self.baler.stackBalesTarget);
    self.gui_btn_auto:setActive(self.baler.autoOn);
    
    self:updateData();
end

function Gc_Gui_Baler:updateData()
    self.gui_txt_fillLevel:setText(string.format("%s %s",g_i18n:formatNumber(self.baler.fillLevel) , g_company.languageManager:getText("unit_liter")));
    self.gui_txt_fillLevelBunker:setText(string.format("%s %s",g_i18n:formatNumber(self.baler.fillLevelBunker) , g_company.languageManager:getText("unit_liter")));
    self.gui_txt_baleCounter:setText(string.format("%s %s",g_i18n:formatNumber(self.baler.baleCounter) , g_company.languageManager:getText("unit_pieces")));
    
    local isVisible = self.baler:getCanChangeFillType();
    local i = 1;
    for index,fillType in pairs(self.baler.fillTypes) do        
        self[string.format("gui_txt_fillType%s", i)]:setText(fillType.title);
        self[string.format("gui_btn_fillType%s", i)]:setActive(self.baler.activeFillTypeIndex == index);
        self[string.format("gui_txt_fillType%s", i)]:setDisabled(not isVisible);
        self[string.format("gui_btn_fillType%s", i)]:setDisabled(not isVisible);
        i = i + 1;
    end;

    if self.baler:getIsOn() then
        self.gui_btn_turnOnOff:setText(g_company.languageManager:getText("GC_baler_turnOff"));
    else
        self.gui_btn_turnOnOff:setText(g_company.languageManager:getText("GC_baler_turnOn"));
    end;

    self:updateButtonsTurnOnOff();       
end;

function Gc_Gui_Baler:onClickBtnFillType(element, para)  
    self.gui_btn_fillType1:setActive(self.gui_btn_fillType1.parameter == para);
    self.gui_btn_fillType2:setActive(self.gui_btn_fillType2.parameter == para);
    self.gui_btn_fillType3:setActive(self.gui_btn_fillType3.parameter == para); 

    local i = 1;
    for index,fillType in pairs(self.baler.fillTypes) do   
        if self[string.format("gui_btn_fillType%s", i)].parameter == para then
            self.baler:setFillTyp(index);
            break;
        end;
        i = i + 1;
    end;
end

function Gc_Gui_Baler:onClickBaleNum(element, para)  
    local num = self.baler.stackBalesTarget + tonumber(para);
    num = math.max(math.min(num, 4), 1);
    self.baler:setStackBalesTarget(num);
    self.gui_text_num:setText(num);
    self:updateButtons();
end

function Gc_Gui_Baler:updateButtons()
    self.gui_btn_addBale:setDisabled(self.baler.stackBalesTarget == 4);
    self.gui_btn_removeBale:setDisabled(self.baler.stackBalesTarget == 1);
end

function Gc_Gui_Baler:onClickClose()
    g_company.gui:closeActiveGui();
end;

function Gc_Gui_Baler:onClickBtnAutoOnOff(element)
    element:setActive(element:getActive());
    self.baler:setAutoOn(element.isActive);
    self:updateButtonsTurnOnOff();
end;

function Gc_Gui_Baler:onClickTurnOnOff()    
    if self.baler.state_baler == self.baler.STATE_OFF then
        self.baler:doTurnOn();
    else
        self.baler:doTurnOff();
    end;
end

function Gc_Gui_Baler:updateButtonsTurnOnOff()
    if self.baler.autoOn then
        self.gui_btn_turnOnOff:setDisabled(true);
    else
        if self.baler.state_baler == self.baler.STATE_OFF then
            self.gui_btn_turnOnOff:setDisabled(not self.baler:getCanTurnOn());
        else
            self.gui_btn_turnOnOff:setDisabled(false);
        end;
    end;
end;

function Gc_Gui_Baler:onClickUnload()    
    self.baler:doUnload();
end

