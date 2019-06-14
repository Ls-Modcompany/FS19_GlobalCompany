





Gc_Gui_Errors = {};
Gc_Gui_Errors.xmlFilename = g_company.dir .. "gui/objects/GcMain_Errors.xml";
Gc_Gui_Errors.debugIndex = g_company.debug:registerScriptName("Gc_Gui_Errors");


local Gc_Gui_Errors_mt = Class(Gc_Gui_Errors);

function Gc_Gui_Errors:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = Gc_Gui_Errors_mt;
    end;
	local self = setmetatable({}, Gc_Gui_Errors_mt);
    self.name = "errors"

	return self;
end;

function Gc_Gui_Errors:onCreate() 

end;

function Gc_Gui_Errors:onOpen() 
    self.gui_errorsTable:removeElements();

	for _,text in pairs(g_company.debug.savedErrors) do
        if #text > 110 then
			local textTable = g_company.utils.stringWrap(text, 110, "", true)
			for _, lineText in pairs (textTable) do
				self.tmp_error = lineText
				self.gui_errorsTable:createItem();
			end
		else
			self.tmp_error = text
			self.gui_errorsTable:createItem();
		end

		-- self.tmp_error = text;
        -- self.gui_errorsTable:createItem();

        -- while self.textForNextLine ~= nil do
            -- self.tmp_error = "        " .. self.textForNextLine;
            -- self.gui_errorsTable:createItem();
        -- end;

    end;
    self.tmp_error = nil;       
end;

function Gc_Gui_Errors:onClose() 

end;

function Gc_Gui_Errors:onCreateErrorText(element) 
    self.textForNextLine = element:setText(self.tmp_error);
end;

