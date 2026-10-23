local L = TargetCharmsSettingsText;
local Layout = TargetCharmsLayout;
local serial = 0;
local iconNames = { ["0"] = "clear", ["1"] = "star", ["2"] = "circle", ["3"] = "diamond",
    ["4"] = "triangle", ["5"] = "moon", ["6"] = "square", ["7"] = "cross", ["8"] = "skull",
    ["9"] = "target", B = "blue", G = "green", P = "purple", R = "red", Y = "yellow",
    O = "orange", S = "silver", W = "white", X = "clear", D = "handle", ["_"] = "empty" };
local colors = { B = {0, .5, 1}, G = {0, 1, .2}, P = {.5, 0, 1}, R = {1, 0, 0},
    Y = {1, 1, 0}, O = {1, .5, 0}, S = {.5, .5, .5}, W = {1, 1, 1} };
local worldIcons = { B = 6, G = 4, P = 3, R = 7, Y = 1, O = 2, S = 5, W = 8 };

local function Label(parent, text, x, y, width, style)
    local label = parent:CreateFontString(nil, "OVERLAY", style or "GameFontHighlightSmall");
    label:SetPoint("TOPLEFT", x, -y);
    label:SetWidth(width);
    label:SetJustifyH("LEFT");
    label:SetText(text);
    return label;
end

local function Tooltip(frame, title, description)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(title, 1, .82, 0);
        if description then GameTooltip:AddLine(description, 1, 1, 1, true); end
        GameTooltip:Show();
    end);
    frame:SetScript("OnLeave", function() GameTooltip:Hide(); end);
end

local function Button(parent, text, x, y, width, callback, help)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
    button:SetSize(width, 24);
    button:SetPoint("TOPLEFT", x, -y);
    button:SetText(text);
    button:SetScript("OnClick", callback);
    if help then Tooltip(button, text, help); end
    return button;
end

local function Editable(parent, x, y, width)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate");
    edit:SetSize(width, 24);
    edit:SetPoint("TOPLEFT", x, -y);
    edit:SetAutoFocus(false);
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
    return edit;
end

local function Confirm(key, message, callback)
    StaticPopupDialogs[key] = {
        text = message, button1 = L.confirm, button2 = L.cancel,
        OnAccept = callback, timeout = 0, whileDead = true, hideOnEscape = true,
        preferredIndex = 3,
    };
    StaticPopup_Show(key);
end

local function RefreshVisibility()
    CheckFrameViewState();
    CheckReadyButtonViewState();
    CheckFlareFrameViewState();
end

local function Apply(page, key, value)
    if InCombatLockdown() then return; end
    TargetCharms_Options[page.bar][key] = value;
    SetupTargetCharms();
    RefreshVisibility();
    UpdateGlobal();
    if page.owner.SyncVisibility then page.owner:SyncVisibility(); end
    if page.RefreshPreview then page:RefreshPreview(); end
end

local function Checkbox(page, key, title, description, x, y)
    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate");
    check:SetSize(26, 26);
    check:SetPoint("TOPLEFT", x, -y);
    check:SetHitRectInsets(0, -222, 0, 0);
    local label = Label(check, title, 28, 6, 222);
    Tooltip(check, title, description);
    check:SetScript("OnClick", function(self) Apply(page, key, self:GetChecked() and true or false); end);
    page.refreshers[#page.refreshers + 1] = function(options) check:SetChecked(options[key]); end;
    return check, label;
end

local function Slider(page, title, help, x, y, minimum, maximum, step, getter, setter, formatter)
    serial = serial + 1;
    local slider = CreateFrame("Slider", "TargetCharmsSettingSlider" .. serial, page, "OptionsSliderTemplate");
    slider:SetPoint("TOPLEFT", x, -y);
    slider:SetSize(222, 16);
    slider:SetMinMaxValues(minimum, maximum);
    slider:SetValueStep(step);
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true); end
    _G[slider:GetName() .. "Low"]:SetText("");
    _G[slider:GetName() .. "High"]:SetText("");
    _G[slider:GetName() .. "Text"]:SetText("");
    Label(page, title, x, y - 22, 168, "GameFontNormalSmall");
    local valueText = Label(page, "", x + 168, y - 22, 54);
    valueText:SetJustifyH("RIGHT");
    Tooltip(slider, title, help);
    slider:SetScript("OnValueChanged", function(self, value)
        if page.refreshing then return; end
        value = math.floor(value / step + .5) * step;
        valueText:SetText(formatter and formatter(value) or string.format("%d", value));
        setter(value);
    end);
    page.refreshers[#page.refreshers + 1] = function(options)
        local value = getter(options);
        slider:SetValue(value);
        valueText:SetText(formatter and formatter(value) or string.format("%d", value));
    end;
    return slider;
end

local function OptionSlider(page, key, title, help, x, y, minimum, maximum, step, formatter)
    return Slider(page, title, help, x, y, minimum, maximum, step,
        function(options) return options[key]; end,
        function(value) Apply(page, key, value); end, formatter);
end

local function Percent(value) return string.format("%d%%", math.floor(value * 100 + .5)); end

local function PaintIcon(button, icon, world, overlays)
    button.texture:SetTexture(nil);
    button.symbol:SetTexture(nil);
    button.caption:SetText("");
    local number = tonumber(icon);
    if world and colors[icon] then
        local c = colors[icon];
        button.texture:SetColorTexture(c[1], c[2], c[3]);
        number = overlays and worldIcons[icon] or nil;
    elseif icon == "0" or icon == "X" then
        button.texture:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up");
    elseif icon == "D" then
        button.caption:SetText("·");
    elseif icon == "9" then
        button.texture:SetTexture("Interface\\Icons\\ability_hunter_snipershot");
    elseif icon == "_" then button.caption:SetText("·"); end
    if number and number >= 1 and number <= 8 then
        local index = number - 1;
        button.symbol:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons");
        button.symbol:SetTexCoord((index % 4) / 4, (index % 4 + 1) / 4,
            math.floor(index / 4) / 4, (math.floor(index / 4) + 1) / 4);
    end
end

local function AddPreview(page)
    local area = CreateFrame("Frame", nil, page);
    area:SetPoint("TOPLEFT", 8, -465);
    area:SetSize(510, 170);
    local background = area:CreateTexture(nil, "BACKGROUND");
    background:SetAllPoints();
    background:SetColorTexture(.02, .02, .02, .65);
    local buttons = {};
    local hint = Label(page, L.previewHelp, 8, 642, 510);
    local status = Label(page, "", 8, 354, 510, "GameFontHighlightSmall");
    page.layoutStatus = status;
    function page:RefreshPreview()
        local options = TargetCharms_Options[self.bar];
        local template = options.buttonTemplate;
        local slots = Layout.Decode(template, self.world, options.Xspacing, options.Yspacing);
        local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge;
        for _, slot in ipairs(slots) do
            left = math.min(left, slot.x); top = math.min(top, slot.y);
            right = math.max(right, slot.x + slot.size); bottom = math.max(bottom, slot.y + slot.size);
        end
        local scale = #slots == 0 and 1 or math.min(1, 490 / math.max(1, right - left), 150 / math.max(1, bottom - top));
        for i = 1, 20 do
            local button = buttons[i];
            local slot = slots[i];
            if slot then
                if not button then
                    button = CreateFrame("Button", nil, area);
                    button.texture = button:CreateTexture(nil, "ARTWORK");
                    button.texture:SetAllPoints();
                    button.symbol = button:CreateTexture(nil, "OVERLAY");
                    button.symbol:SetPoint("TOPLEFT", 3, -3);
                    button.symbol:SetPoint("BOTTOMRIGHT", -3, 3);
                    button.caption = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
                    button.caption:SetAllPoints();
                    button.selection = button:CreateTexture(nil, "OVERLAY");
                    button.selection:SetAllPoints();
                    button.selection:SetColorTexture(1, .82, 0, .45);
                    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
                    buttons[i] = button;
                end
                button:ClearAllPoints();
                button:SetPoint("TOPLEFT", 10 + (slot.x - left) * scale, -10 - (slot.y - top) * scale);
                button:SetSize(slot.size * scale, slot.size * scale);
                PaintIcon(button, slot.icon, self.world, options.showicons);
                button.selection:SetShown(self.selectedOffset == slot.offset);
                local offset = slot.offset;
                Tooltip(button, L[iconNames[slot.icon]] or slot.icon, L.previewHelp);
                button:SetScript("OnClick", function()
                    if InCombatLockdown() then return; end
                    local selected = self.selectedOffset;
                    self.selectedOffset = nil;
                    if selected and selected ~= offset then
                        local current = TargetCharms_Options[self.bar].buttonTemplate;
                        local a, b = string.sub(current, selected + 1, selected + 1), string.sub(current, offset + 1, offset + 1);
                        local parts = {};
                        for p = 1, #current do
                            parts[p] = p == selected + 1 and b or (p == offset + 1 and a or string.sub(current, p, p));
                        end
                        Apply(self, "buttonTemplate", table.concat(parts));
                        self:Refresh();
                    elseif not selected then
                        self.selectedOffset = offset;
                    end
                    self:RefreshPreview();
                end);
                button:Show();
            elseif button then button:Hide(); end
        end
        local columns = Layout.Columns(template, self.world);
        if columns then
            local order = Layout.Order(template, self.world);
            status:SetText(string.format(L.dimensions, columns, math.ceil(#order / columns)));
        else status:SetText(L.custom); end
        if self.selectedOffset then
            local icon = string.sub(template, self.selectedOffset + 1, self.selectedOffset + 1);
            hint:SetText(string.format(L.selected, L[iconNames[icon]] or icon));
        else hint:SetText(L.previewHelp); end
    end
end

local function Arrange(page, columns)
    if InCombatLockdown() then return; end
    local order, handle = Layout.Order(TargetCharms_Options[page.bar].buttonTemplate, page.world);
    -- Generated padding is needed for predecessor-relative anchors, but must
    -- not become extra empty rows when the next grid shape is chosen.
    if Layout.Columns(TargetCharms_Options[page.bar].buttonTemplate, page.world) then
        while order[#order] == "_" do table.remove(order); end
    end
    local template = Layout.Grid(order, columns, handle);
    page.selectedOffset = nil;
    if template then Apply(page, "buttonTemplate", template); end
    page:Refresh();
    if not template then page.layoutStatus:SetText(L.tooMany); end
end

local function AddArrangement(page)
    Label(page, L.arrangement, 8, 282, 510, "GameFontNormal");
    local columnsSlider = Slider(page, L.columns, L.columnsHelp, 8, 328, 1, 20, 1,
        function(options) return Layout.Columns(options.buttonTemplate, page.world) or 0; end,
        function(value) Arrange(page, value); end,
        function(value) return value == 0 and "—" or string.format("%d", value); end);
    page.refreshers[#page.refreshers + 1] = function(options)
        local order = Layout.Order(options.buttonTemplate, page.world);
        columnsSlider:SetMinMaxValues(1, math.max(1, #order));
        columnsSlider:SetValue(Layout.Columns(options.buttonTemplate, page.world) or 1);
    end;
    -- A custom arrangement has no column value. The status explains this and
    -- the slider only writes a new template after an explicit interaction.
    Button(page, L.horizontal, 8, 395, 118, function() Arrange(page, 20); end);
    Button(page, L.vertical, 136, 395, 118, function() Arrange(page, 1); end);
    Button(page, L.grid, 264, 395, 118, function() Arrange(page, 3); end);
    Button(page, L.original, 392, 395, 126, function()
        page.selectedOffset = nil;
        Apply(page, "buttonTemplate", page.world and ">DvW>RvS<BvG>PvY<OV_>X" or ">1>5v6<2v3>7v8<4v_>0");
        page:Refresh();
    end, L.originalHelp);
    Label(page, L.preview, 8, 438, 510, "GameFontNormal");
    AddPreview(page);
    local advanced = CreateFrame("Frame", nil, page);
    advanced:SetAllPoints();
    advanced:Hide();
    Button(page, L.advanced, 8, 692, 246, function()
        advanced:SetShown(not advanced:IsShown());
        page:SetHeight(advanced:IsShown() and 930 or 730);
    end);
    Button(page, L.alternate, 272, 692, 246, function()
        page.selectedOffset = nil;
        Apply(page, "buttonTemplate", page.world and ">DVY>SVB<OVP>RVW<GV_>X" or ">4>8v7<3v2>6v5<1v_>0");
        page:Refresh();
    end, L.alternateHelp);
    local edit = Editable(advanced, 14, 736, 366);
    edit:SetMaxLetters(40);
    local errorText = Label(advanced, "", 8, 872, 510);
    errorText:SetTextColor(1, .35, .25);
    local function SaveCode()
        if InCombatLockdown() then return; end
        local value = edit:GetText();
        if not Layout.Validate(value, page.world) then errorText:SetText(L.invalid); return; end
        page.selectedOffset = nil;
        Apply(page, "buttonTemplate", value);
        edit:ClearFocus();
        page:Refresh();
    end
    edit:SetScript("OnEnterPressed", SaveCode);
    Button(advanced, L.apply, 396, 736, 122, SaveCode);
    Label(advanced, L.codeHelp, 8, 775, 510);
    Label(advanced, page.world and L.worldCodes or L.targetCodes, 8, 824, 510);
    page.refreshers[#page.refreshers + 1] = function(options)
        edit:SetText(options.buttonTemplate);
        edit:ClearFocus();
        errorText:SetText("");
        page.selectedOffset = nil;
    end;
end

local function AddToolbar(page)
    local ready = page.bar == "ReadyCharm";
    Label(page, L.visibility, 8, 10, 510, "GameFontNormal");
    page.enabledCheck = Checkbox(page, "enabled", L.enabled, L.enabledHelp, 4, 34);
    Checkbox(page, "partyOnly", L.group, L.groupHelp, 270, 34);
    Checkbox(page, "draggable", L.draggable, L.dragHelp, 4, 68);
    if page.bar == "TargetCharms" then
        Checkbox(page, "showontarget", L.targetOnly, L.targetHelp, 270, 68);
        Checkbox(page, "toggleicon", L.toggle, L.toggleHelp, 4, 102);
    elseif page.world then
        Checkbox(page, "showicons", L.overlays, L.overlayHelp, 4, 102);
    end
    Label(page, L.appearance, 8, 150, 510, "GameFontNormal");
    OptionSlider(page, "barscale", L.scale, L.scale, 8, 196, .02, 2, .02, Percent);
    OptionSlider(page, "alphaVal", L.opacity, L.opacityHelp, 282, 196, 0, 1, .05, Percent);
    if ready then
        OptionSlider(page, "width", L.width, L.width, 8, 252, 1, 200, 1);
        Label(page, L.buttonText, 8, 290, 510, "GameFontNormal");
        local edit = Editable(page, 14, 320, 366);
        local function SaveText()
            if InCombatLockdown() then return; end
            Apply(page, "text", edit:GetText());
            edit:ClearFocus();
        end
        edit:SetScript("OnEnterPressed", SaveText);
        edit:SetScript("OnEditFocusLost", SaveText);
        Button(page, L.apply, 396, 320, 122, SaveText);
        page.refreshers[#page.refreshers + 1] = function(options) edit:SetText(options.text); end;
        Label(page, L.readyHelp, 8, 382, 510);
        Label(page, L.dragHelp, 8, 448, 510);
    else
        OptionSlider(page, "Xspacing", L.horizontalGap, L.gapHelp, 8, 252, -20, 20, 1);
        OptionSlider(page, "Yspacing", L.verticalGap, L.gapHelp, 282, 252, -20, 20, 1);
        AddArrangement(page);
    end
end

local function AddProfiles(page)
    Label(page, L.profileTitle, 8, 10, 510, "GameFontNormal");
    Label(page, L.profileHelp, 8, 42, 510);
    local main = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate");
    main:SetSize(26, 26);
    main:SetPoint("TOPLEFT", 4, -126);
    main:SetHitRectInsets(0, -470, 0, 0);
    Label(main, L.main, 28, 6, 470);
    Tooltip(main, L.main, L.profileHelp);
    main:SetScript("OnClick", function(self)
        if InCombatLockdown() then return; end
        UpdateGlobal();
        TargetCharms_OptionsGlobal.Name = self:GetChecked() and UnitName("player") or nil;
        UpdateGlobal();
        page:Refresh();
    end);
    local source = Label(page, "", 8, 168, 510);
    local copy = Button(page, L.copy, 8, 202, 510, function()
        Confirm("TARGETCHARMS_COPY_PROFILE", L.copyConfirm, function()
            if not InCombatLockdown() then CopySetup(); end
        end);
    end, L.copyHelp);
    Label(page, L.copyHelp, 8, 240, 510);
    Label(page, L.helpTitle, 8, 304, 510, "GameFontNormal");
    Label(page, L.help, 8, 338, 510);
    Button(page, L.reset, 8, 526, 246, function()
        Confirm("TARGETCHARMS_RESET_SETTINGS", L.resetConfirm, function()
            if InCombatLockdown() then return; end
            TargetCharms_Reset();
            page.owner:Refresh();
        end);
    end, L.resetHelp);
    Label(page, L.resetHelp, 8, 564, 510);
    page.refreshers[#page.refreshers + 1] = function()
        local name = TargetCharms_OptionsGlobal.Name;
        main:SetChecked(name == UnitName("player"));
        source:SetText(string.format(L.source, name or L.none));
        copy:SetEnabled(name ~= nil and name ~= UnitName("player"));
    end;
end

function TargetCharms_CreateSettings()
    local frame = CreateFrame("Frame", "TargetCharmsSetup", UIParent, "BackdropTemplate");
    frame:Hide();
    frame:SetSize(780, 730);
    frame:SetPoint("CENTER");
    frame:SetFrameStrata("DIALOG");
    frame:SetToplevel(true);
    frame:SetMovable(true);
    frame:EnableMouse(true);
    frame:SetClampedToScreen(true);
    frame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 32,
        edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}});
    local header = CreateFrame("Frame", nil, frame);
    header:SetPoint("TOPLEFT", 8, -8);
    header:SetSize(730, 36);
    header:EnableMouse(true);
    header:RegisterForDrag("LeftButton");
    header:SetScript("OnDragStart", function() frame:StartMoving(); end);
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); end);
    Label(header, "TargetCharms  " .. TARGETCHARMS_VERSION, 10, 8, 650, "GameFontNormalLarge");
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
    close:SetPoint("TOPRIGHT", -3, -3);
    close:SetScript("OnClick", HideSetup);
    Label(frame, L.intro, 20, 50, 738);
    Label(frame, L.saved, 20, 689, 574);
    Button(frame, L.close, 630, 683, 128, HideSetup);
    frame.pages, frame.tabs, frame.visibilityToggles = {}, {}, {};
    local definitions = {
        {"TargetCharms", L.targets, L.targetUsage}, {"FlareCharms", L.world, L.worldHelp},
        {"ReadyCharm", L.ready, L.readyHelp}, {nil, L.profiles, L.profileHelp},
    };
    function frame:SyncVisibility()
        for bar, toggle in pairs(self.visibilityToggles) do
            toggle:SetChecked(TargetCharms_Options[bar].enabled);
        end
        for _, page in ipairs(self.pages) do
            if page.enabledCheck then page.enabledCheck:SetChecked(TargetCharms_Options[page.bar].enabled); end
        end
    end
    function frame:Refresh()
        for _, page in ipairs(self.pages) do page:Refresh(); end
        self:SyncVisibility();
    end
    function frame:Select(index)
        self.activeTab = index;
        for i, page in ipairs(self.pages) do
            page.scroll:SetShown(i == index);
            self.tabs[i]:SetEnabled(i ~= index);
        end
        self.pages[index]:Refresh();
    end
    for index, definition in ipairs(definitions) do
        local tabIndex = index;
        local tab = Button(frame, definition[2], 18, 100 + (index - 1) * 42, 166, function() frame:Select(tabIndex); end, definition[3]);
        frame.tabs[index] = tab;
        local scroll = CreateFrame("ScrollFrame", "TargetCharmsSettingsScroll" .. index, frame, "UIPanelScrollFrameTemplate");
        scroll:SetPoint("TOPLEFT", 202, -94);
        scroll:SetPoint("BOTTOMRIGHT", -44, 62);
        local page = CreateFrame("Frame", nil, scroll);
        page:SetSize(530, index <= 2 and 730 or 630);
        scroll:SetScrollChild(page);
        page.bar, page.world = definition[1], definition[1] == "FlareCharms";
        page.refreshers, page.owner, page.scroll = {}, frame, scroll;
        function page:Refresh()
            self.refreshing = true;
            local options = self.bar and TargetCharms_Options[self.bar];
            for _, refresh in ipairs(self.refreshers) do refresh(options); end
            self.refreshing = false;
            if self.RefreshPreview then self:RefreshPreview(); end
        end
        scroll:EnableMouseWheel(true);
        scroll:SetScript("OnMouseWheel", function(self, delta)
            self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 40)));
        end);
        if page.bar then AddToolbar(page); else AddProfiles(page); end
        if page.world then
            local available = type(PlaceRaidMarker) == "function" and type(ClearRaidMarker) == "function" and
                (not IsRaidMarkerSystemEnabled or IsRaidMarkerSystemEnabled());
            if not available then Label(frame, L.noWorld, 20, 466, 164); end
        end
        frame.pages[index] = page;
    end
    Label(frame, L.toolbarVisibility, 20, 300, 164, "GameFontNormalSmall");
    for index = 1, 3 do
        local bar, title = definitions[index][1], definitions[index][2];
        local toggle = CreateFrame("CheckButton", "TargetCharmsToggle" .. bar, frame, "UICheckButtonTemplate");
        toggle:SetSize(26, 26);
        toggle:SetPoint("TOPLEFT", 16, -330 - (index - 1) * 34);
        toggle:SetHitRectInsets(0, -136, 0, 0);
        Label(toggle, title, 28, 6, 136);
        Tooltip(toggle, title, L.enabledHelp);
        toggle:SetScript("OnClick", function(self)
            if InCombatLockdown() then return; end
            TargetCharms_Options[bar].enabled = self:GetChecked() and true or false;
            SetupTargetCharms();
            RefreshVisibility();
            UpdateGlobal();
            frame:SyncVisibility();
        end);
        frame.visibilityToggles[bar] = toggle;
    end
    frame:SetScript("OnShow", function(self)
        self:SetScale(math.min(1, (UIParent:GetWidth() - 30) / 780, (UIParent:GetHeight() - 30) / 730));
        self:Select(self.activeTab or 1);
        self:Refresh();
    end);
    frame:SetScript("OnHide", function()
        GameTooltip:Hide();
        UpdateGlobal();
        if not InCombatLockdown() then LockFlares(); end
        RefreshVisibility();
    end);
    UISpecialFrames[#UISpecialFrames + 1] = "TargetCharmsSetup";
    return frame;
end
