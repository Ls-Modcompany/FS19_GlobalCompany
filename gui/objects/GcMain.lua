-- 
-- GlobalCompany - Gui - GcMain
-- 
-- @Interface: 1.3.0.1 b4009
-- @Author: LS-Modcompany / kevink98
-- @Date: 31.03.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (31.03.2019):
-- 		- initial fs19
-- 
-- Notes:
-- 
-- 
-- ToDo:
--
-- 

Gc_Gui_MainGui = {};
Gc_Gui_MainGui.xmlFilename = g_company.dir .. "gui/objects/GcMain.xml";
Gc_Gui_MainGui.debugIndex = g_company.debug:registerScriptName("Gc_Gui_MainGui");

source(g_company.dir .. "gui/objects/GcMain_Settings.lua");

local Gc_Gui_MainGui_mt = Class(Gc_Gui_MainGui);

function Gc_Gui_MainGui:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_MainGui_mt;
    end;
    local self = setmetatable({}, Gc_Gui_MainGui_mt);

    g_company.gui:loadGui(Gc_Gui_MainSettings, "gcMainSettings");
    
    self.backupItems = {};            
	return self;
end;

function Gc_Gui_MainGui:onCreate() 
    self.gui_menu:removeElement(self.gui_menuItem);
    
    for _, d in pairs(self.backupItems) do
        self:addMenuItem(d.imageFilename, d.imageUVs, d.gui, true);
    end;
    self.loadSettings = false;
end;

function Gc_Gui_MainGui:onOpen() 
    g_depthOfFieldManager:setBlurState(true)

    if not self.loadSettings then
        self:addMenuItem("g_gcUi2", "icon_settings2", g_company.gui:getGui("gcMainSettings"), true);
        self.loadSettings = true;
    end;
    
    if table.getn(self.gui_menu.elements) == 0 then
        g_company.gui:closeActiveGui();
    else
        local toOpen = Utils.getNoNil(self.activePage, 1);
        self:onClickMainMenu(self.gui_menu.elements[toOpen]);
        self.gui_menu.elements[toOpen]:setActive(true);
        
    end;
end;

function Gc_Gui_MainGui:onClose() 
    g_depthOfFieldManager:setBlurState(false);
end;

function Gc_Gui_MainGui:addMenuItem(imageFilename, imageUVs, gui, ignoreBackup)    
    local menuItem = GC_Gui_button:new(self.gui_menuItem.gui);
    menuItem:copy(self.gui_menuItem);   
    for _,element in pairs(self.gui_menuItem.elements) do
        local item = element:new(self.gui_menuItem.gui);
        item:copy(element);
        item:setImageFilename(imageFilename);
        item:setImageUv(imageUVs, true);
        menuItem:addElement(item);
    end;    
    menuItem.mainMenuGui = gui;
    self.gui_menu:addElement(menuItem);
    
    if not ignoreBackup then
        table.insert(self.backupItems, {gui=gui, imageFilename=imageFilename, imageUVs=imageUVs});
    end;
end;

function Gc_Gui_MainGui:onClickMainMenu(item)
    if  self.activeGui ~= nil then
        self.activeGui:closeGui();   
    end;
    self.activeGui = item.mainMenuGui;
    self.activeGui:openGui();   
    for i,e in pairs(self.gui_menu.elements) do
        if e == item then
            self.activePage = i;
            break;
        end;
    end;
end;

function Gc_Gui_MainGui:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	if self.activeGui ~= nil and self.activeGui.mouseEvent ~= nil then
		self.activeGui:mouseEvent(posX, posY, isDown, isUp, button, eventUsed);
	end;
end;

function Gc_Gui_MainGui:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	if self.activeGui ~= nil and self.activeGui.keyEvent ~= nil then
		self.activeGui:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	end;
end;

function Gc_Gui_MainGui:update(dt)
	if self.activeGui ~= nil and self.activeGui.update ~= nil then
		self.activeGui:update(dt);
	end;
end;

function Gc_Gui_MainGui:draw()
	if self.activeGui ~= nil and self.activeGui.draw ~= nil then
        self.activeGui:draw();
    end;
end;