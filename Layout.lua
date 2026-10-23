-- Layout helpers deliberately read and write the original buttonTemplate format.
TargetCharmsLayout = {};
local Layout = TargetCharmsLayout;

function Layout.Validate(template, world)
    if type(template) ~= "string" or #template == 0 or #template > 40 or #template % 2 ~= 0 then
        return false;
    end
    local allowed = world and "BGPRYOSWDX_" or "0123456789_";
    for i = 1, #template, 2 do
        if not string.find("><^vV", string.sub(template, i, i), 1, true) or
            not string.find(allowed, string.sub(template, i + 1, i + 1), 1, true) then
            return false;
        end
    end
    return true;
end

-- Coordinates use a top-left origin, just like the runtime button anchors.
function Layout.Decode(template, world, xs, ys)
    local slots = {};
    local x, y, previousSize = 0, 0, 1;
    for i = 1, math.min(#template - 1, 39), 2 do
        local direction = string.lower(string.sub(template, i, i));
        local icon = string.sub(template, i + 1, i + 1);
        local size = world and icon == "D" and 16 or 32;
        if direction == ">" then x = x + previousSize + (xs or 0);
        elseif direction == "<" then x = x - size - (xs or 0);
        elseif direction == "v" then y = y + previousSize + (ys or 0);
        elseif direction == "^" then y = y - size - (ys or 0); end
        slots[#slots + 1] = {icon = icon, x = x, y = y, size = size, offset = i};
        previousSize = size;
    end
    return slots;
end

-- Read the visible order spatially, including custom layouts and blank slots.
function Layout.Order(template, world)
    local slots = Layout.Decode(template, world, 0, 0);
    table.sort(slots, function(a, b)
        if a.y ~= b.y then return a.y < b.y; end
        if a.x ~= b.x then return a.x < b.x; end
        return a.offset < b.offset;
    end);
    local order, handle = {}, false;
    for _, slot in ipairs(slots) do
        if world and slot.icon == "D" then handle = true;
        else order[#order + 1] = slot.icon; end
    end
    return order, handle;
end

-- Snake traversal keeps every anchor relative to its predecessor, while the
-- icons themselves retain their left-to-right reading order in every row.
-- A partial final row is padded with the existing invisible spacer token.
function Layout.Grid(order, columns, handle)
    if #order == 0 then return handle and ">D" or ""; end
    columns = math.max(1, math.min(#order, math.floor(columns)));
    local result = handle and {">D"} or {};
    local rows = math.ceil(#order / columns);
    for row = 1, rows do
        local reverse = row % 2 == 0;
        local count = math.min(columns, #order - (row - 1) * columns);
        -- Even rows start at the right edge of the preceding full row.
        local width = reverse and columns or count;
        for step = 1, width do
            local column = reverse and (columns - step + 1) or step;
            local icon = order[(row - 1) * columns + column] or "_";
            local direction = row == 1 and step == 1 and ">" or
                (step == 1 and "v" or (reverse and "<" or ">"));
            result[#result + 1] = direction .. icon;
        end
    end
    local template = table.concat(result);
    if #template > 40 then return nil; end
    return template;
end

function Layout.Columns(template, world)
    local order, handle = Layout.Order(template, world);
    for columns = 1, #order do
        if Layout.Grid(order, columns, handle) == template then return columns; end
    end
end
