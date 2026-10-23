-- Separate, non-action grips give all three toolbars the same interaction.
-- The old D layout token stays a hidden 16px slot for saved-layout compatibility.
local bars = {
    {name = "TargetCharms", root = "TopCharm", title = "targets"},
    {name = "FlareCharms", root = "TopFlare", title = "world"},
    {name = "ReadyCharm", root = "TopReady", title = "ready"},
};
local arrow = {
    "      #      ", "     ###     ", "    # # #    ", "      #      ",
    "  #   #   #  ", " ##   #   ## ", "#############", " ##   #   ## ",
    "  #   #   #  ", "      #      ", "    # # #    ", "     ###     ", "      #      ",
};

local function CreateGrip(info)
    local grip = CreateFrame("Button", info.name .. "MoveHandle", _G[info.name]);
    grip:SetSize(24, 24);
    grip.isMoveHandle, grip.barName, grip.moveRoot = true, info.name, _G[info.root];
    local background = grip:CreateTexture(nil, "BACKGROUND");
    background:SetAllPoints();
    background:SetColorTexture(.08, .1, .14, .95);
    -- Draw a crisp four-arrow icon using native textures on every client.
    for row, pixels in ipairs(arrow) do
        for first, run in string.gmatch(pixels, "()(#+)") do
            local texture = grip:CreateTexture(nil, "ARTWORK");
            texture:SetColorTexture(1, .82, .25);
            texture:SetSize(#run * 1.2, 1.2);
            texture:SetPoint("TOPLEFT", 4.2 + (first - 1) * 1.2, -4.2 - (row - 1) * 1.2);
        end
    end
    grip:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
    grip:SetScript("OnMouseDown", TargetCharms_StartDrag);
    grip:SetScript("OnMouseUp", TargetCharms_StopDrag);
    grip:SetScript("OnHide", function(self) TargetCharms_StopDrag(self); end);
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(TargetCharmsSettingsText[info.title], 1, .82, 0);
        GameTooltip:AddLine(TargetCharmsSettingsText.dragHelp, 1, 1, 1, true);
        GameTooltip:Show();
    end);
    grip:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    return grip;
end

function TargetCharms_UpdateMoveHandles()
    if InCombatLockdown() then return; end
    for _, info in ipairs(bars) do
        local options = TargetCharms_Options[info.name];
        local grip = _G[info.name .. "MoveHandle"] or CreateGrip(info);
        local left, top = 0, 0;
        if options.buttonTemplate then
            for _, slot in ipairs(TargetCharmsLayout.Decode(options.buttonTemplate, info.name == "FlareCharms", options.Xspacing, options.Yspacing)) do
                left = math.min(left, slot.x); top = math.min(top, slot.y);
            end
        end
        grip:ClearAllPoints();
        grip:SetPoint("TOPRIGHT", _G[info.name], "TOPLEFT", left - 4, -top);
        grip:SetShown(options.enabled and options.draggable);
    end
end

function TargetCharms_StopAllMoves()
    for _, info in ipairs(bars) do
        local grip = _G[info.name .. "MoveHandle"];
        if grip then TargetCharms_StopDrag(grip); end
    end
end
