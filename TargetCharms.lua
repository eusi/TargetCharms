local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata;
TARGETCHARMS_VERSION = GetMetadata and GetMetadata("TargetCharms", "Version") or "1.8.1";
TARGETCHARMS_DB_VERSION = "1.6.4";

local pendingSetup = false;

local function CanConfigure()
    if InCombatLockdown() then
        pendingSetup = true;
        return false;
    end
    return true;
end

local function HasWorldMarkers()
    return type(PlaceRaidMarker) == "function" and
        type(ClearRaidMarker) == "function" and
        (not IsRaidMarkerSystemEnabled or IsRaidMarkerSystemEnabled());
end

local function RegisterOptions(panel)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name);
        Settings.RegisterAddOnCategory(category);
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel);
    end
end

local Defaults = {
    ["TargetCharms"] = {
        ["X"] = nil,
        ["Y"] = nil,
        ["enabled"] = true,
        ["partyOnly"] = false,
        ["barscale"] = 1.0,
        ["Xspacing"] = 0,
        ["Yspacing"] = 0,
        ["draggable"] = true,
        ["toggleicon"] = false,
        ["alphaVal"] = 0.5,
        ["showontarget"] = true,
        ["buttonTemplate"] = ">1>5v6<2v3>7v8<4v_>0",
    },
    ["ReadyCharm"] = {
        ["X"] = nil,
        ["Y"] = nil,
        ["enabled"] = true,
        ["partyOnly"] = false,
        ["barscale"] = 1.0,
        ["draggable"] = true,
        ["alphaVal"] = 0.5,
        ["width"] = 60,
        ["text"] = TARGETCHARMS_READYCHECK_TEXT,
    },
    ["FlareCharms"] = {
        ["X"] = nil,
        ["Y"] = nil,
        ["enabled"] = true,
        ["partyOnly"] = false,
        ["barscale"] = 1.0,
        ["draggable"] = true,
        ["alphaVal"] = 0.5,
        ["Xspacing"] = 0,
        ["Yspacing"] = 0,
        ["showicons"] = false,
        ["buttonTemplate"] = ">DvW>RvS<BvG>PvY<OV_>X",
    },

};
local frameNames = {
    "TargetCharms",
    "TopCharm",
    "ReadyCharm",
    "TopReady",
    "FlareCharms",
    "TopFlare",
    "TargetCharmsSetup",
};
local buttonCharm = {
    ["TargetCharms"] = {},
    ["FlareCharms"] = {}
};
local texturePaths = {
    "interface\\targetingframe\\UI-RaidTargetingIcons.blp",
    "interface\\buttons\\UI-Quickslot.blp",
    "interface\\buttons\\UI-GroupLoot-Pass-Up.blp",
    "interface\\icons\\ability_hunter_snipershot.blp",
    "interface\\buttons\\UI-MinusButton-Up.blp"
};

function TargetCharms_msg(text)
    DEFAULT_CHAT_FRAME:AddMessage(TARGETCHARMS_MSG_TAG .. text);
end

function TargetCharms_DoReadyCheck()
    -- Ready checks cannot be initiated by addon code during combat on the
    -- modern UI. Avoid a blocked-action error if the button is clicked then.
    if InCombatLockdown() then
        return;
    end

    if C_PartyInfo and C_PartyInfo.DoReadyCheck then
        C_PartyInfo.DoReadyCheck();
    elseif DoReadyCheck then
        DoReadyCheck();
    end
end

function TargetCharms_Command(msg)
    msg = string.lower(msg or "")
    local cmd = string.match(msg, "^(%S+)")
    if cmd and cmd ~= "setup" then
        TargetCharms_msg(TARGETCHARMS_CMD_HELP);
    end
    ShowSetup();
    CheckReadyButtonViewState();
    CheckFrameViewState();
    CheckFlareFrameViewState();
end

function resetTop(frame, offset)

end

function TargetCharms_OnLoad(self)
    self:RegisterEvent("VARIABLES_LOADED");
    self:RegisterEvent("PARTY_LEADER_CHANGED");
    self:RegisterEvent("GROUP_ROSTER_UPDATE");
    self:RegisterEvent("PLAYER_TARGET_CHANGED");
    self:RegisterEvent("PLAYER_REGEN_ENABLED");
    self:RegisterEvent("PLAYER_REGEN_DISABLED");
    SLASH_TargetCharms1 = TARGETCHARMS_SLASH1;
    SLASH_TargetCharms2 = TARGETCHARMS_SLASH2;
    SlashCmdList["TargetCharms"] = TargetCharms_Command;
end

--Code by Grayhoof (SCT)
function CloneTable(t)
    -- return a copy of the table t
    local new = {};                    -- create a new table
    local i, v = next(t, nil);        -- i is an index of t, v = t[i]
    while i do
        if type(v) == "table" then
            v = CloneTable(v);
        end
        new[i] = v;
        i, v = next(t, i);            -- get next index
    end
    return new;
end

function CopyValues(t, f)
    if (f ~= nil) then
        for i = 1, 5, 2 do
            --if ( f[frameNames[i]]~=nil) then
            for key, value in pairs(f[frameNames[i]] or {}) do
                t[frameNames[i]][key] = value;
            end
            --end
        end
    end
    return t;
end

function CopyOldValues(t, f)
    local temp = CloneTable(t);
    CopyValues(temp, f);
    return temp;
end

function CheckFrameViewState()
    if not TargetCharms_Options or not CanConfigure() then return; end
    local charmBar = _G[frameNames[2]];
    local options = TargetCharms_Options[frameNames[1]];
    local visibility = "show";
    if not options.enabled then
        visibility = "hide";
    elseif not IsInSetup() then
        local raidDenied = options.partyOnly and UnitInRaid("player") and
            not (UnitIsGroupAssistant("player") or UnitIsGroupLeader("player"));
        if raidDenied then
            visibility = "hide";
        elseif options.partyOnly and options.showontarget then
            visibility = "[group,@target,exists] show; hide";
        elseif options.partyOnly then
            visibility = "[group] show; hide";
        elseif options.showontarget then
            visibility = "[@target,exists] show; hide";
        end
    end
    -- Blizzard's secure driver keeps target visibility working in combat.
    RegisterStateDriver(charmBar, "visibility", visibility);
end

function CheckFlareFrameViewState()
    if not TargetCharms_Options then return; end
    if not CanConfigure() then return; end
    local bar = _G[frameNames[6]];
    local options = TargetCharms_Options[frameNames[5]];
    local visibility = "show";
    if not HasWorldMarkers() or not options.enabled then
        visibility = "hide";
    elseif not IsInSetup() then
        local raidDenied = options.partyOnly and UnitInRaid("player") and
            not (UnitIsGroupAssistant("player") or UnitIsGroupLeader("player"));
        if raidDenied then
            visibility = "hide";
        elseif options.partyOnly then
            visibility = "[group] show; hide";
        end
    end
    RegisterStateDriver(bar, "visibility", visibility);
end

-- Kept separate from secure marker frames: this is a normal UI button.
function CheckReadyButtonViewState()
    if not TargetCharms_Options then return; end
    local charmBar = _G[frameNames[4]];
    charmBar:Show();
    charmBar = _G[frameNames[3]];
    local options = TargetCharms_Options[frameNames[3]];
    if options.enabled and (IsInSetup() or not options.partyOnly or
        (GetNumGroupMembers() > 0 and (UnitIsGroupAssistant("player") or UnitIsGroupLeader("player")))) then
        charmBar:Show();
    else
        charmBar:Hide();
    end
end


function IsInSetup()
    local TargetCharmsSetup = _G[frameNames[7]];
    if TargetCharmsSetup ~= nil then
        if (TargetCharmsSetup:IsShown()) then
            return true;
        end
    end
    return false;
end

function SetTargetHideShow()
    CheckFrameViewState();
end

function TargetCharms_OnEvent(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        local setupFrame = _G[frameNames[7]];
        if setupFrame then setupFrame:Hide(); end
    end
    if event == "VARIABLES_LOADED" then
        if TargetCharms_OptionsGlobal == nil or TARGETCHARMS_DB_VERSION ~= TargetCharms_OptionsGlobal["Version"] then
            TargetCharms_OptionsGlobal = CopyOldValues(Defaults, Defaults);
            TargetCharms_OptionsGlobal["Version"] = TARGETCHARMS_DB_VERSION;
            TargetCharms_OptionsGlobal["Name"] = UnitName("player");
            TargetCharms_Options = CopyOldValues(TargetCharms_OptionsGlobal, TargetCharms_OptionsGlobal);
        end
        if TargetCharms_Options == nil or TARGETCHARMS_DB_VERSION ~= TargetCharms_Options["Version"] then
            TargetCharms_Options = CopyOldValues(TargetCharms_OptionsGlobal, TargetCharms_Options);
            CopyValues(TargetCharms_Options, TargetCharms_OptionsGlobal);
            TargetCharms_Options["Version"] = TARGETCHARMS_DB_VERSION;
        end

        SetupTargetCharms();

        local panel = CreateFrame("Frame", "TargetCharmsPanel", UIParent, "TargetCharmsPanelTemplate");
        local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
        description:SetPoint("TOPLEFT", 20, -24);
        description:SetWidth(420);
        description:SetJustifyH("LEFT");
        description:SetText(TargetCharmsSettingsText.intro);
        PanelShowButton:SetText(TargetCharmsSettingsText.targets .. " / " .. TargetCharmsSettingsText.world);
        PanelShowButton:SetWidth(320);
        PanelResetButton:SetText(TargetCharmsSettingsText.profiles);
        PanelResetButton:SetWidth(320);
        PanelResetButton:SetScript("OnClick", function()
            ShowSetup();
            local settings = _G[frameNames[7]];
            if settings and settings:IsShown() then settings:Select(4); end
        end);

        panel.name = "TargetCharms";
        panel.okay = function(self)
            -- TargetCharmsInterface_Close();
        end;
        panel.cancel = function(self)
            TargetCharmsPanel_CancelOrLoad();
        end;
        panel.refresh = function(self)
            TargetCharmsPanel_OnShow();
        end;
        panel.default = function(self)
            TargetCharms_Reset();
        end;
        panel.OnCommit = panel.okay;
        panel.OnDefault = panel.default;
        panel.OnRefresh = panel.refresh;
        RegisterOptions(panel);
        panel:Hide()

        TargetCharms_msg(TARGETCHARMS_VERSION .. " - " .. TARGETCHARMS_LOADED);
    end
    if not TargetCharms_Options then return; end
    if event == "PLAYER_REGEN_ENABLED" then TargetCharms_StopAllMoves(); end
    if event == "PLAYER_REGEN_ENABLED" and pendingSetup then
        pendingSetup = false;
        SetupTargetCharms();
    end
    if event ~= "PLAYER_TARGET_CHANGED" then
        CheckReadyButtonViewState();
        CheckFlareFrameViewState();
        if event == "PLAYER_REGEN_ENABLED" then
            --LockFlares();
        end
    end
    CheckFrameViewState();

end

function SetupTargetCharms()
    if not CanConfigure() then return; end
    SetupFrames();
    SetupButtons(frameNames[1], frameNames[1]);
    SetupButtons(frameNames[5], frameNames[5]);
    SetUpReadyButton();
    TargetCharms_UpdateMoveHandles();
end

function TargetCharms_Reset()
    if not CanConfigure() then return; end
    TargetCharms_Options = CopyValues(CloneTable(Defaults), Defaults);
    TargetCharms_Options["Version"] = TARGETCHARMS_DB_VERSION;
    TargetCharms_Options["Name"] = UnitName("player");
    local tmpFrame = _G[frameNames[1]];
    tmpFrame:SetScale(TargetCharms_Options[frameNames[1]]["barscale"]);
    tmpFrame:SetPoint("TOPLEFT", 0, 0);
    tmpFrame = _G[frameNames[2]];
    tmpFrame:ClearAllPoints()
    tmpFrame:SetPoint("TOPLEFT", _G["UIParent"], "TOP", 0, -20);
    tmpFrame:SetAlpha(TargetCharms_Options[frameNames[1]]["alphaVal"]);
    tmpFrame = _G[frameNames[4]];
    tmpFrame:SetAlpha(1);
    tmpFrame:SetScale(1);
    tmpFrame:ClearAllPoints();
    tmpFrame:SetPoint("TOPLEFT", _G["UIParent"], "TOP", 0, 0);
    tmpFrame = _G[frameNames[3]];
    tmpFrame:SetAlpha(TargetCharms_Options[frameNames[3]]["alphaVal"]);
    tmpFrame:SetScale(1);
    tmpFrame:ClearAllPoints();
    tmpFrame:SetPoint("TOPLEFT", 0, 0);
    tmpFrame:SetWidth(TargetCharms_Options[frameNames[3]]["width"]);
    tmpFrame = _G[frameNames[4]];
    tmpFrame:SetWidth(TargetCharms_Options[frameNames[3]]["width"]);
    tmpFrame = _G[frameNames[5]];
    tmpFrame:SetScale(TargetCharms_Options[frameNames[5]]["barscale"]);
    tmpFrame:SetPoint("TOPLEFT", 0, 0);
    tmpFrame = _G[frameNames[6]];
    tmpFrame:ClearAllPoints()
    tmpFrame:SetPoint("TOPLEFT", _G["UIParent"], "TOP", 100, 0);
    tmpFrame:SetAlpha(TargetCharms_Options[frameNames[5]]["alphaVal"]);
    tmpFrame = _G[frameNames[7]];
    if (tmpFrame ~= nil) then
        tmpFrame:ClearAllPoints();
        tmpFrame:SetPoint("CENTER", 0, 0);
    end
    UpdateGlobal();
    SetupTargetCharms();
    CheckFrameViewState();
    CheckReadyButtonViewState();
    CheckFlareFrameViewState();
end

function SetupFrames()
    if not CanConfigure() then return; end
    local tmpFrame = _G[frameNames[1]];
    if (TargetCharms_Options[frameNames[1]]["X"] ~= nil) then
        _G[frameNames[2]]:ClearAllPoints()
        _G[frameNames[2]]:SetPoint("BOTTOMLEFT", TargetCharms_Options[frameNames[1]]["X"], TargetCharms_Options[frameNames[1]]["Y"]);
    else
        _G[frameNames[2]]:ClearAllPoints()
        _G[frameNames[2]]:SetPoint("TOPLEFT", _G["UIParent"], "TOP", 0, -20);
    end
    tmpFrame:SetScale(TargetCharms_Options[frameNames[1]]["barscale"]);
    tmpFrame = _G[frameNames[2]];
    tmpFrame:SetAlpha(TargetCharms_Options[frameNames[1]]["alphaVal"]);
    tmpFrame = _G[frameNames[5]];
    if (TargetCharms_Options[frameNames[5]]["X"] ~= nil) then
        _G[frameNames[6]]:ClearAllPoints();
        _G[frameNames[6]]:SetPoint("BOTTOMLEFT", TargetCharms_Options[frameNames[5]]["X"], TargetCharms_Options[frameNames[5]]["Y"]);
    else
        _G[frameNames[6]]:ClearAllPoints()
        _G[frameNames[6]]:SetPoint("TOPLEFT", _G["UIParent"], "TOP", 100, 0);
    end
    tmpFrame:SetScale(TargetCharms_Options[frameNames[5]]["barscale"]);
    tmpFrame = _G[frameNames[6]];
    tmpFrame:SetAlpha(TargetCharms_Options[frameNames[5]]["alphaVal"]);
end

function SetUpReadyButton()
    local tmpFrame = _G[frameNames[4]];
    if (TargetCharms_Options[frameNames[3]]["X"] ~= nil) then
        _G[frameNames[4]]:ClearAllPoints();
        _G[frameNames[4]]:SetPoint("BOTTOMLEFT", TargetCharms_Options[frameNames[3]]["X"], TargetCharms_Options[frameNames[3]]["Y"]);
    else
        _G[frameNames[4]]:ClearAllPoints();
        _G[frameNames[4]]:SetPoint("TOPLEFT", _G["UIParent"], "TOP", 0, 0);
    end
    tmpFrame:SetAlpha(TargetCharms_Options[frameNames[3]]["alphaVal"]);
    tmpFrame:SetScale(TargetCharms_Options[frameNames[3]]["barscale"]);
    tmpFrame:SetWidth(TargetCharms_Options[frameNames[3]]["width"]);
    tmpFrame = _G[frameNames[3]];
    tmpFrame:SetWidth(TargetCharms_Options[frameNames[3]]["width"]);
    tmpFrame:SetText(TargetCharms_Options[frameNames[3]]["text"]);
end

function UpdateLocation(frameId, x, y)
    local frame = frameNames[frameId];
    TargetCharms_Options[frame]["X"] = x;
    TargetCharms_Options[frame]["Y"] = y;
    if TargetCharms_OptionsGlobal["Name"] == UnitName("player") then
        TargetCharms_OptionsGlobal[frame]["X"] = TargetCharms_Options[frame]["X"];
        TargetCharms_OptionsGlobal[frame]["Y"] = TargetCharms_Options[frame]["Y"];
    end
end

function MakeButton(frame, buttonNum, isWorldMarker)
    if not CanConfigure() then return; end
    local button = _G[frame .. "Charm" .. buttonNum];
    if button == nil then
        local template = isWorldMarker and "SecureCharmTemplate" or "CharmTemplate";
        button = CreateFrame("Button", frame .. "Charm" .. buttonNum, _G[frame], template)
        button:RegisterForClicks("AnyDown", "AnyUp");
        button:SetID(buttonNum);
        button:CreateTexture(button:GetName() .. "CharmTex");
        if isWorldMarker then
            local textureColor = button:CreateTexture(button:GetName() .. "TextureColor");
            textureColor:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4);
            textureColor:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4.5, 4.5);
            local textureIcon = button:CreateTexture(button:GetName() .. "TextureIcon");
        end
    end
    button.isDragHandle = false;
    button:SetHeight(32);
    button:SetWidth(32);
    -- Use native secure actions on every supported client, never insecure /wm macros.
    button:SetAttribute("*type1", isWorldMarker and "worldmarker" or "raidtarget");
    button:SetAttribute("type1", isWorldMarker and "worldmarker" or "raidtarget");
    button:SetAttribute("unit", "target");
    if isWorldMarker then
        _G[button:GetName() .. "TextureColor"]:SetTexture(nil);
        _G[button:GetName() .. "TextureIcon"]:SetTexture(nil);
    end
    return button;
end

function SetupButtons(frameInfo, frameTarget)
    if not CanConfigure() then return; end
    local buttonString = TargetCharms_Options[frameInfo]["buttonTemplate"];
    local maxlen = strlen(buttonString);
    if mod(maxlen, 2) == 1 then
        maxlen = maxlen - 1
    end
    local buttonNum = 1;
    if maxlen > 40 then
        maxlen = 40;
    end

    local t
    for t = 1, maxlen, 2 do
        FormatButton(frameTarget, buttonNum, strsub(buttonString, t, t), strsub(buttonString, t + 1, t + 1), TargetCharms_Options[frameInfo]["Xspacing"], TargetCharms_Options[frameInfo]["Yspacing"]);
        buttonNum = buttonNum + 1;
    end

    for t = buttonNum, 20 do
        local button = _G[frameTarget .. "Charm" .. t];
        if button ~= nil then
            button:Hide();
        end
    end
end

function FormatButton(frame, buttonNum, posChar, typeNum, xSpacing, ySpacing)
    if not CanConfigure() then return false; end
    local button;
    if frame == frameNames[1] then
        if typeNum == TARGETCHARMS_CHARM0 then
            button = MakeButton(frame, buttonNum, false);
            MakeCharm(frame, button, buttonNum, 0, 2, 0.15, 0.85, 0.15, 0.85, 0, 0, 32, 32);
            button:Show();
        elseif typeNum == TARGETCHARMS_CHARM1 then
            button = MakeButton(frame, buttonNum, false);
            MakeCharm(frame, button, buttonNum, 1, 1, 0, 0.25, 0, 0.25, 2, -2, 28, 28);
            button:Show();
        elseif typeNum == TARGETCHARMS_CHARM2 then
            button = MakeButton(frame, buttonNum, false);
            MakeCharm(frame, button, buttonNum, 2, 1, 0.25, 0.5, 0, 0.25, 2, -2, 28, 28);
            button:Show();
        elseif typeNum == TARGETCHARMS_CHARM3 then
            button = MakeButton(frame, buttonNum, false);
            MakeCharm(frame, button, buttonNum, 3, 1, 0.5, 0.75, 0, 0.25, 2, -2, 28, 28);
            button:Show();
        elseif typeNum == TARGETCHARMS_CHARM4 then
            button = MakeButton(frame, buttonNum, false);
            MakeCharm(frame, button, buttonNum, 4, 1, 0.75, 1, 0, 0.25, 2, -2, 28, 28);
            button:Show();
        elseif typeNum == TARGETCHARMS_CHARM5 then
            button = MakeButton(frame, buttonNum, false);
            MakeCharm(frame, button, buttonNum, 5, 1, 0, 0.25, 0.25, 0.5, 2, -2, 28, 28);
            button:Show();
        elseif typeNum == TARGETCHARMS_CHARM6 then
            button = MakeButton(frame, buttonNum, false);
            MakeCharm(frame, button, buttonNum, 6, 1, 0.25, 0.5, 0.25, 0.5, 2, -2, 28, 28);
            button:Show();
        elseif typeNum == TARGETCHARMS_CHARM7 then
            button = MakeButton(frame, buttonNum, false);
            MakeCharm(frame, button, buttonNum, 7, 1, 0.5, 0.75, 0.25, 0.5, 2, -2, 28, 28);
            button:Show();
        elseif typeNum == TARGETCHARMS_CHARM8 then
            button = MakeButton(frame, buttonNum, false);
            MakeCharm(frame, button, buttonNum, 8, 1, 0.75, 1, 0.25, 0.5, 2, -2, 28, 28);
            button:Show();
        elseif typeNum == TARGETCHARMS_CHARM9 then
            button = MakeButton(frame, buttonNum, false);
            MakeCharm(frame, button, buttonNum, 9, 4, 0, 1, 0, 1, 0, 0, 32, 32);
            button:Show();
        else
            button = MakeButton(frame, buttonNum, false);
            button:Hide();
        end
    else
        if typeNum == TARGETCHARMS_DRAG then
            button = MakeButton(frame, buttonNum, true);
            button.isDragHandle = true;
            button:SetAttribute("type1", nil);
            button:SetAttribute("*type1", nil);
            button:SetHeight(16);
            button:SetWidth(16);
            SetTexture(button, _G[button:GetName() .. "CharmTex"], 5, 0, 1, 0, 1, 0, 0, 16, 16);
            -- Retain the old 16px layout slot without displaying a second grip.
            button:Hide();
        elseif typeNum == TARGETCHARMS_BLUEFLARE then
            button = MakeButton(frame, buttonNum, true);
            MakeCharm(frame, button, buttonNum, 1, 2, 0.15, 0.85, 0.15, 0.85, 0, 0, 32, 32);
            if TargetCharms_Options[frameNames[5]]["showicons"] then
                SetTexture(button, _G[button:GetName() .. "TextureIcon"], 1, 0.25, 0.5, 0.25, 0.5, 6, -5, 20, 20);
            else
                _G[button:GetName() .. "TextureIcon"]:SetTexture();
            end
            local textureColor = _G[button:GetName() .. "TextureColor"];
            textureColor:SetColorTexture(0, .5, 1);

            button:Show();
        elseif typeNum == TARGETCHARMS_GREENFLARE then
            button = MakeButton(frame, buttonNum, true);
            MakeCharm(frame, button, buttonNum, 2, 2, 0.15, 0.85, 0.15, 0.85, 0, 0, 32, 32);
            if TargetCharms_Options[frameNames[5]]["showicons"] then
                SetTexture(button, _G[button:GetName() .. "TextureIcon"], 1, 0.75, 1, 0, 0.25, 6, -5, 20, 20);
            else
                _G[button:GetName() .. "TextureIcon"]:SetTexture();
            end
            local textureColor = _G[button:GetName() .. "TextureColor"];
            textureColor:SetColorTexture(0, 1, .2);

            button:Show();
        elseif typeNum == TARGETCHARMS_PURPLEFLARE then
            button = MakeButton(frame, buttonNum, true);
            MakeCharm(frame, button, buttonNum, 3, 2, 0.15, 0.85, 0.15, 0.85, 0, 0, 32, 32);
            if TargetCharms_Options[frameNames[5]]["showicons"] then
                SetTexture(button, _G[button:GetName() .. "TextureIcon"], 1, 0.5, 0.75, 0, 0.25, 6, -5, 20, 20);
            else
                _G[button:GetName() .. "TextureIcon"]:SetTexture();
            end
            local textureColor = _G[button:GetName() .. "TextureColor"];
            textureColor:SetColorTexture(.5, 0, 1);

            button:Show();
        elseif typeNum == TARGETCHARMS_REDFLARE then
            button = MakeButton(frame, buttonNum, true);
            MakeCharm(frame, button, buttonNum, 4, 2, 0.15, 0.85, 0.15, 0.85, 0, 0, 32, 32);
            if TargetCharms_Options[frameNames[5]]["showicons"] then
                SetTexture(button, _G[button:GetName() .. "TextureIcon"], 1, 0.5, 0.75, 0.25, 0.5, 6, -5, 20, 20);
            else
                _G[button:GetName() .. "TextureIcon"]:SetTexture();
            end
            local textureColor = _G[button:GetName() .. "TextureColor"];
            textureColor:SetColorTexture(1, 0, 0);

            button:Show();
        elseif typeNum == TARGETCHARMS_YELLOWFLARE then
            button = MakeButton(frame, buttonNum, true);
            MakeCharm(frame, button, buttonNum, 5, 2, 0.15, 0.85, 0.15, 0.85, 0, 0, 32, 32);
            if TargetCharms_Options[frameNames[5]]["showicons"] then
                SetTexture(button, _G[button:GetName() .. "TextureIcon"], 1, 0, 0.25, 0, 0.25, 6, -5, 20, 20);
            else
                _G[button:GetName() .. "TextureIcon"]:SetTexture();
            end
            local textureColor = _G[button:GetName() .. "TextureColor"];
            textureColor:SetColorTexture(1, 1, 0);

            button:Show();
        elseif typeNum == TARGETCHARMS_ORANGEFLARE then
            button = MakeButton(frame, buttonNum, true);
            MakeCharm(frame, button, buttonNum, 6, 2, 0.15, 0.85, 0.15, 0.85, 0, 0, 32, 32);
            if TargetCharms_Options[frameNames[5]]["showicons"] then
                SetTexture(button, _G[button:GetName() .. "TextureIcon"], 1, 0.25, 0.5, 0, 0.25, 6, -5, 20, 20);
            else
                _G[button:GetName() .. "TextureIcon"]:SetTexture();
            end
            local textureColor = _G[button:GetName() .. "TextureColor"];
            textureColor:SetColorTexture(1, .5, 0);

            button:Show();
        elseif typeNum == TARGETCHARMS_SILVERFLARE then
            button = MakeButton(frame, buttonNum, true);
            MakeCharm(frame, button, buttonNum, 7, 2, 0.15, 0.85, 0.15, 0.85, 0, 0, 32, 32);
            if TargetCharms_Options[frameNames[5]]["showicons"] then
                SetTexture(button, _G[button:GetName() .. "TextureIcon"], 1, 0, 0.25, 0.25, 0.5, 6, -5, 20, 20);
            else
                _G[button:GetName() .. "TextureIcon"]:SetTexture();
            end
            local textureColor = _G[button:GetName() .. "TextureColor"];
            textureColor:SetColorTexture(.5, .5, .5);

            button:Show();
        elseif typeNum == TARGETCHARMS_WHITEFLARE then
            button = MakeButton(frame, buttonNum, true);
            MakeCharm(frame, button, buttonNum, 8, 2, 0.15, 0.85, 0.15, 0.85, 0, 0, 32, 32);
            if TargetCharms_Options[frameNames[5]]["showicons"] then
                SetTexture(button, _G[button:GetName() .. "TextureIcon"], 1, 0.75, 1, 0.25, 0.5, 6, -5, 20, 20);
            else
                _G[button:GetName() .. "TextureIcon"]:SetTexture();
            end
            local textureColor = _G[button:GetName() .. "TextureColor"];
            textureColor:SetColorTexture(1, 1, 1);

            button:Show();
        elseif typeNum == TARGETCHARMS_CLEARFLARE then
            button = MakeButton(frame, buttonNum, true);
            MakeCharm(frame, button, buttonNum, 0, 2, 0.15, 0.85, 0.15, 0.85, 0, 0, 32, 32);
            SetTexture(button, _G[button:GetName() .. "TextureIcon"], 3, 0, 1, 0, 1, 3, -2, 26, 26);
            _G[button:GetName() .. "TextureColor"]:SetTexture();

            button:Show();
        else
            button = MakeButton(frame, buttonNum, true);
            button:Hide();
        end
    end
    if button ~= nil then
        if frame == frameNames[5] and not button.isDragHandle then
            local marker = buttonCharm[frame][buttonNum] or 0;
            button:SetAttribute("marker", marker ~= 0 and marker or nil);
            button:SetAttribute("action", marker ~= 0 and "set" or "clear");
            if not HasWorldMarkers() or marker > (NUM_WORLD_RAID_MARKERS or 8) then
                button:Hide();
            end
        end
        button:ClearAllPoints();
        if strlower(posChar) == TARGETCHARMS_POSITION_DOWN then
            button:SetPoint("TOPLEFT", _G[frame .. "Charm" .. tostring(buttonNum - 1)], "BOTTOMLEFT", 0, 0 - ySpacing);
        elseif posChar == TARGETCHARMS_POSITION_UP then
            button:SetPoint("BOTTOMLEFT", _G[frame .. "Charm" .. tostring(buttonNum - 1)], "TOPLEFT", 0, 0 + ySpacing);
        elseif posChar == TARGETCHARMS_POSITION_RIGHT then
            button:SetPoint("TOPLEFT", _G[frame .. "Charm" .. tostring(buttonNum - 1)], "TOPRIGHT", 0 + xSpacing, 0);
        elseif posChar == TARGETCHARMS_POSITION_LEFT then
            button:SetPoint("TOPRIGHT", _G[frame .. "Charm" .. tostring(buttonNum - 1)], "TOPLEFT", 0 - xSpacing, 0);
        else
            --ERROR--
            button:SetPoint("TOPLEFT", _G[frame .. "Charm" .. tostring(buttonNum - 1)], "TOPRIGHT", 0, 0 - ySpacing);
            buttonCharm[frame][buttonNum] = 0;
            button:Hide();
            print(TARGETCHARMS_ERROR_INVALIDCHAR);
            return false;
        end
    end
    return true;
end

function MakeCharm(frame, button, buttonNum, id, textureID, o1, o2, o3, o4, a1, a2, w, h)
    buttonCharm[frame][buttonNum] = id;
    if frame == frameNames[1] and button:GetAttribute("type1") == "raidtarget" then
        button:SetAttribute("marker", id);
        if id == 0 then
            button:SetAttribute("action", "clear");
        elseif TargetCharms_Options[frameNames[1]]["toggleicon"] then
            button:SetAttribute("action", "toggle");
        else
            button:SetAttribute("action", "set");
        end
    end
    local texture = _G[button:GetName() .. "CharmTex"];
    SetTexture(button, texture, textureID, o1, o2, o3, o4, a1, a2, w, h);
end

function SetTexture(button, texture, textureID, o1, o2, o3, o4, a1, a2, w, h)
    texture:SetPoint("TOPLEFT", button, "TOPLEFT", a1, a2);
    texture:SetWidth(w);
    texture:SetHeight(h);
    texture:SetTexture(texturePaths[textureID]);
    texture:SetTexCoord(o1, o2, o3, o4)
end

function SelectTarget(frame, targetId, btn, name)
    -- Compatibility entry point only. Current buttons execute secure actions.
    if btn ~= "LeftButton" or InCombatLockdown() then return; end
    local charmId = buttonCharm[frame][tonumber(targetId)];
    if (frame == frameNames[1]) then
        if (not TargetCharms_Options[frameNames[1]]["toggleicon"]) then
            if (GetRaidTargetIndex("target") ~= charmId) then
                SetRaidTarget("target", charmId)
            end
        else
            SetRaidTargetIcon("target", charmId)
        end
    else
        if charmId ~= 0 then
            PlaceRaidMarker(charmId)
        else
            ClearRaidMarker()
        end
    end

end

function SetFrameScale(scale, id)
    if not CanConfigure() then return; end
    local tmpFrame = _G[frameNames[id]];
    tmpFrame:SetScale(scale);
end

function MoveFlares()
    if not CanConfigure() then return; end
    local frame = _G[frameNames[5]];
    frame:EnableMouse(true);
    _G[frameNames[5] .. "_Tex"]:SetColorTexture(0, 1, 0);
    _G[frameNames[5] .. "Text"]:SetText(TARGETCHARMS_OPTIONS_FLARE_MOVE_TEXT);

    for buttonNum = 1, 20 do
        local button = _G[frameNames[5] .. "Charm" .. buttonNum];
        if button ~= nil then
            button:Hide();
        end
    end

    local frame = _G["FlareMoveButton"];
    frame:SetText(TARGETCHARMS_OPTIONS_FLARE_LOCK_BUTTON);
end

function LockFlares()
    if (not InCombatLockdown()) then
        local frame = _G[frameNames[5]];
        frame:EnableMouse(false);
        _G[frameNames[5] .. "_Tex"]:SetTexture();
        _G[frameNames[5] .. "Text"]:SetText();

        local button = _G["FlareMoveButton"];
        if button ~= nil then
            button:SetText(TARGETCHARMS_OPTIONS_FLARE_MOVE_BUTTON);
        end
        SetupButtons(frameNames[5], frameNames[5]);
    end
end

function ShowSetup()
    if not CanConfigure() then
        TargetCharms_msg("Setup is unavailable during combat.");
        return;
    end
    --InterfaceOptionsFrame_OpenToCategory("TargetCharms");
    local setupFrame = _G[frameNames[7]];
    if setupFrame == nil then
        setupFrame = TargetCharms_CreateSettings();
    end
    setupFrame:Show();
    setupFrame:Refresh();
    CheckFrameViewState();
    CheckReadyButtonViewState();
    CheckFlareFrameViewState();
end

function HideSetup()
    local setupFrame = _G[frameNames[7]];
    if setupFrame ~= nil then
        setupFrame:Hide();
    end
    UpdateGlobal();
end

function TargetCharmsInterface_Close()
end

function TargetCharmsPanel_Close()
end

function TargetCharmsPanel_CancelOrLoad()
end

function TargetCharmsPanel_OnShow()
end

function CopySetup()
    if not CanConfigure() then return; end
    HideSetup();
    TargetCharms_Options = CopyOldValues(CloneTable(TargetCharms_OptionsGlobal), TargetCharms_OptionsGlobal);
    SetupTargetCharms();
    ShowSetup();
end

function UpdateGlobal()
    if TargetCharms_OptionsGlobal["Name"] == UnitName("player") then
        TargetCharms_OptionsGlobal = CopyOldValues(CloneTable(TargetCharms_OptionsGlobal), TargetCharms_Options);
    end
end 

-- All toolbars move exclusively through their dedicated four-arrow grip.
function TargetCharms_StartDrag(self, button)
    if InCombatLockdown() or not TargetCharms_Options then return; end
    if button == "RightButton" and IsControlKeyDown() then
        ShowSetup();
        return;
    end
    if not self.isMoveHandle or button ~= "LeftButton" then return; end
    local options = TargetCharms_Options[self.barName];
    if options and options.enabled and options.draggable then
        local root = self.moveRoot;
        root:StartMoving();
        self.draggingRoot = root;
    end
end

function TargetCharms_StopDrag(self)
    local root = self.draggingRoot;
    if not root or InCombatLockdown() then return; end
    root:StopMovingOrSizing();
    UpdateLocation(root:GetID(), root:GetLeft(), root:GetTop() - root:GetHeight());
    root:SetUserPlaced(false);
    self.draggingRoot = nil;
end
