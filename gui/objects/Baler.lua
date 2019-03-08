

local debugIndex = g_debug.registerMod("GC_GUI_Baler");

Gc_Gui_Baler = {};
Gc_Gui_Baler.xmlFilename = g_company.dir .. "gui/objects/Baler.xml";



local SRShotel_mt = Class(Gc_Gui_Baler);



function Gc_Gui_Baler:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = SRShotel_mt;
    end;
	local self = setmetatable({}, SRShotel_mt);
	
	
	
	return self;
end;

function Gc_Gui_Baler:onCreate()


end;

function Gc_Gui_Baler:onOpen()
    
end

function Gc_Gui_Baler:update(dt)

end

function Gc_Gui_Baler:onClose(element)

end

function Gc_Gui_Baler:setData(hotel)
    self.hotel = hotel;
end

----------------------------------------------------------  onOpen  ----------------------------------------------------------
function Gc_Gui_Baler:onOpenHeader(element)
    if self.hotel ~= nil then
        element:setText(string.format("%s %s: %s", self.hotel:getTypName(), g_company.languageManager:getText("srs_hotel_purchase"), self.hotel:getHotelName()));
    end;
end

function Gc_Gui_Baler:onOpenNeedPersonal(element)
    if self.hotel ~= nil then
        element:setText(self:getNeedPersonalText());
    end;
end

function Gc_Gui_Baler:onOpenLucrativeness(element)
    if self.hotel ~= nil then
        element:setText(self.hotel:getLucrativeness());
    end;
end

function Gc_Gui_Baler:onOpenStars(element, parameter)
    local starNum = tonumber(parameter);
    if self.hotel ~= nil and starNum ~= nil then
        local starHotel = self.hotel:getStars();
        element:setSelected(starNum <= starHotel);
    end;
end

function Gc_Gui_Baler:onOpenBuyText(element)
    if self.hotel ~= nil and element.setText ~= nil then
       element:setText(string.format("%s %s", self.hotel:getTypName(), g_company.languageManager:getText("srs_hotel_buy")));
    end;
end

function Gc_Gui_Baler:onOpenInfoText(element)
    if self.hotel ~= nil then
        element:setText(string.format(g_company.languageManager:getText("srs_hotel_infoText"), self.hotel:getHotelName()));
    end;
end

function Gc_Gui_Baler:onOpenCamera(element)
    if self.hotel ~= nil then	
        local id = g_company.cameraUtil:getRenderOverlayId(self.hotel.camera, element.size[1], element.size[2]);
        updateRenderOverlay(id)
        element:setImageOverlay(id);
    end;
end

----------------------------------------------------------  onClick  ----------------------------------------------------------
function Gc_Gui_Baler:onClickBuy()
    if self.hotel ~= nil then
        local header = string.format(g_company.languageManager:getText("srs_hotel_buyDialog_header"), self.hotel:getTypName(), self.hotel:getHotelName())
        local text = string.format(g_company.languageManager:getText("srs_hotel_buyDialog_text"), self.hotel:getTypName(), self.hotel:getHotelName(), self.hotel:getPriceText());

        g_company.gui:openMultiDialog(self, header, text, g_company.gui.MULTIDIALOG_MODE_YES_NO, g_company.gui.MULTIDIALOG_SIGN_QUESTION);
    end;
end;

----------------------------------------------------------  Utils  ----------------------------------------------------------
function Gc_Gui_Baler:getNeedPersonalText()
    local ret = "";
    if self.hotel ~= nil then
        for _,personal in pairs(self.hotel.personals) do
            if ret == "" then
                ret = string.format("%sx %s", personal.num, g_company.srsManager.personalMarket:getJobNameById(personal.jobId));
            else
                ret = string.format("%s, %sx %s", ret, personal.num, g_company.srsManager.personalMarket:getJobNameById(personal.jobId));
            end;
        end;
    end;
    return ret;
end;

function Gc_Gui_Baler:multiDialogOnClick(result)
    if result then        
        --add Event for MpSynch
        g_currentMission:addMoney(self.hotel:getPrice() * -1, g_currentMission:getFarmId(), MoneyType.OTHER, true, true);
        g_company.gui:closeActiveGui();
        self.hotel:setBought();
    end;
end;





