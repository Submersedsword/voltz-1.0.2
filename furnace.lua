-- Register electric furnace as a Craft Item
minetest.register_craftitem("voltz:furnace", {
    description = "Electric Furnace",
    inventory_image = "furnace.png",
    groups = {electric_furnace = 1}  -- Ensures it appears in searches and works universally
})
-- Function to update furnace smelting speed
local function update_furnace_speed(pos, power)
    local meta = core.get_meta(pos)
    local speed_multiplier = math.max(math.floor(power / 20), 1)  -- Scale power to speed
    meta:set_int("speed", speed_multiplier)
end

-- Electric Furnace Node
minetest.register_node("voltz:electric_furnace", {
    description = "Electric Furnace",
    tiles = {"electric_furnace.png"},
    groups = {cracky=3, stone=1},

    on_construct = function(pos)
        local meta = core.get_meta(pos)
        meta:set_int("power", 0)
        meta:set_int("speed", 1)  -- Default slow smelting
    end,

    -- Smelting logic
    on_timer = function(pos)
        local meta = core.get_meta(pos)
        local speed = meta:get_int("speed") or 1
        local inv = meta:get_inventory()
        local srclist = inv:get_list("src")
        local result, _ = minetest.get_craft_result({method = "cooking", width = 1, items = srclist})

        if result and result.item and not result.item:is_empty() then
            local dstlist = inv:get_list("dst")
            if inv:room_for_item("dst", result.item) then
                inv:remove_item("src", srclist[1])
                inv:add_item("dst", result.item)
                meta:set_float("fuel_time", 1 / speed)  -- Faster smelting with more power
                return true  -- Keep the timer running
            end
        end
        return false  -- Stop the timer if no items are smeltable
    end,

    on_metadata_inventory_put = function(pos, listname, index, stack, player)
        minetest.get_node_timer(pos):start(1)  -- Start smelting
    end,
})
local electricity = {
    max_capacity = 100,  -- Max voltage storage
    generation_rate = 10,  -- Power generated per second
}
-- Function to generate the power consumer formspec (Lamps & Furnace)
function get_consumer_formspec(pos)
    local meta = minetest.get_meta(pos)

    return table.concat({
        "formspec_version[4]",
        "size[6,4]",
        "label[2.3,0.5;Power Settings]",
        "checkbox[1,1.5;in_up;Accept Up;", meta:get_string("in_up") == "true" and "true" or "false", "]",
        "checkbox[3,1.5;in_down;Accept Down;", meta:get_string("in_down") == "true" and "true" or "false", "]",
        "checkbox[1,2.5;in_left;Accept Left;", meta:get_string("in_left") == "true" and "true" or "false", "]",
        "checkbox[3,2.5;in_right;Accept Right;", meta:get_string("in_right") == "true" and "true" or "false", "]",
        "checkbox[1,3.5;in_front;Accept Front;", meta:get_string("in_front") == "true" and "true" or "false", "]",
        "checkbox[3,3.5;in_back;Accept Back;", meta:get_string("in_back") == "true" and "true" or "false", "]",
        "button[2,3.5;3,0.8;save;Save Settings]",
        "button[4.5,3.5;2,0.8;close;Close]"
    }, "")
end

-- Handle power consumer UI settings (Fixes missing furnace UI)
-- Function to generate the electric furnace formspec
function get_furnace_formspec(pos)
    local meta = minetest.get_meta(pos)
    local power = meta:get_int("power") or 0
    local speed = meta:get_int("speed") or 1

    return table.concat({
        "formspec_version[4]",
        "size[8,6]",
        "label[3,0.5;Electric Furnace]",
        "label[1,1;Power Level: " .. power .. "V]",
        "label[1,1.5;Smelting Speed: x" .. speed .. "]",
        "list[current_name;src;2,2;1,1;]",  -- Input slot
        "image[3,2;1,1;gui_furnace_arrow_bg.png]",  -- Smelting arrow
        "list[current_name;dst;4,2;1,1;]",  -- Output slot
        "list[current_player;main;0,4;8,2;]",  -- Player inventory
        "listring[current_name;src]",
        "listring[current_player;main]",
        "listring[current_name;dst]",
        "listring[current_player;main]",
        "button[2.5,5;3,0.8;close;Close]"
    }, "")
end

-- Electric Furnace Node
minetest.register_node("voltz:electric_furnace", {
    description = "Electric Furnace",
    tiles = {"electric_furnace.png"},
    groups = {cracky=3, stone=1},

    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("power", 0)
        meta:set_int("speed", 1)
        meta:get_inventory():set_size("src", 1)  -- Input slot
        meta:get_inventory():set_size("dst", 1)  -- Output slot
    end,

    -- Right-click opens formspec
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        if clicker and clicker:is_player() then
            core.show_formspec(clicker:get_player_name(), "voltz:furnace_ui" .. minetest.pos_to_string(pos), get_furnace_formspec(pos))
        end
    end,

    -- Smelting logic (runs on timer)
    on_timer = function(pos)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        local speed = meta:get_int("speed") or 1

        local src_stack = inv:get_stack("src", 1)
        if src_stack:is_empty() then return false end  -- No items to smelt

        local result = minetest.get_craft_result({ method = "cooking", width = 1, items = { src_stack } })
        if result and not result.item:is_empty() then
            if inv:room_for_item("dst", result.item) then
                inv:remove_item("src", src_stack:get_name())
                inv:add_item("dst", result.item)
                minetest.get_node_timer(pos):start(5 / speed)  -- Adjust speed based on power
                return true
            end
        end
        return false
    end,

    -- Start smelting when items are placed in the input slot
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
        if listname == "src" then
            minetest.get_node_timer(pos):start(5)  -- Default speed
        end
    end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if not player or not formname or not fields then return end  

    if formname:match("^voltz:consumer_ui") then
        local pos_str = formname:match("voltz:consumer_ui(.+)")
        if not pos_str then return end  

        local pos = minetest.string_to_pos(pos_str)
        if not pos then return end  

        local meta = minetest.get_meta(pos)

        if fields.save then
            meta:set_string("in_up", fields.in_up == "true" and "true" or "false")
            meta:set_string("in_down", fields.in_down == "true" and "true" or "false")
            meta:set_string("in_left", fields.in_left == "true" and "true" or "false")
            meta:set_string("in_right", fields.in_right == "true" and "true" or "false")
            meta:set_string("in_front", fields.in_front == "true" and "true" or "false")
            meta:set_string("in_back", fields.in_back == "true" and "true" or "false")
        end
    end
end)

-- Function to generate the electric furnace formspec
function get_furnace_formspec(pos)
    local meta = minetest.get_meta(pos)
    local power = meta:get_int("power") or 0
    local speed = meta:get_int("speed") or 1

    return table.concat({
        "formspec_version[4]",
        "size[8,7]",  -- Increased the size to fit all elements
        "label[3,0.5;Electric Furnace]",
        "label[1,1;Power Level: " .. power .. "V]",
        "label[1,1.5;Smelting Speed: x" .. speed .. "]",
        "list[current_name;src;2,2;1,1;]",  -- Input slot
        "image[3,2;1,1;gui_furnace_arrow_bg.png]",  -- Smelting arrow
        "list[current_name;dst;4,2;1,1;]",  -- Output slot
        "list[current_player;main;0,3.5;8,4;]",  -- Player inventory (properly aligned)
        "listring[current_name;src]",
        "listring[current_player;main]",
        "listring[current_name;dst]",
        "listring[current_player;main]",
        "button[3,6;2,1;close;Close]"  -- Larger button for easier interaction
    }, "")
end

-- Electric Furnace Node (Fixed Formspect Display)
minetest.register_node("voltz:electric_furnace", {
    description = "Electric Furnace",
    tiles = {"electric_furnace.png"},
    groups = {cracky=3, stone=1},

    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("power", 0)
        meta:set_int("speed", 1)
        local inv = meta:get_inventory()
        inv:set_size("src", 1)  -- Input slot
        inv:set_size("dst", 1)  -- Output slot
    end,

    -- Right-click opens the correct, larger formspec
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        if clicker and clicker:is_player() then
            core.show_formspec(clicker:get_player_name(), "voltz:furnace_ui" .. minetest.pos_to_string(pos), get_furnace_formspec(pos))
        end
    end,

    -- Smelting logic (runs on timer)
    on_timer = function(pos)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        local speed = meta:get_int("speed") or 1

        local src_stack = inv:get_stack("src", 1)
        if src_stack:is_empty() then return false end  -- No items to smelt

        local result = minetest.get_craft_result({ method = "cooking", width = 1, items = { src_stack } })
        if result and not result.item:is_empty() then
            if inv:room_for_item("dst", result.item) then
                inv:remove_item("src", src_stack:get_name())
                inv:add_item("dst", result.item)
                minetest.get_node_timer(pos):start(5 / speed)  -- Adjust speed based on power
                return true
            end
        end
        return false
    end,

    -- Start smelting when items are placed in the input slot
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
        if listname == "src" then
            minetest.get_node_timer(pos):start(5)  -- Default speed
        end
    end,
})

-- Function to generate the electric furnace formspec
function get_furnace_formspec(pos)
    local meta = minetest.get_meta(pos)
    local power = meta:get_int("power") or 0
    local speed = meta:get_int("speed") or 1
    local progress = meta:get_float("progress") or 0

    -- Generate a dynamic smelting progress bar
    local progress_bar = "image[3,2;1,1;gui_furnace_arrow_bg.png^[lowpart:" ..
        (progress * 100) .. ":gui_furnace_arrow.png]"

    return table.concat({
        "formspec_version[4]",
        "size[8,7]",  -- Corrected formspec size
        "label[3,0.5;Electric Furnace]",
        "label[1,1;Power Level: " .. power .. "V]",
        "label[1,1.5;Smelting Speed: x" .. speed .. "]",
        "list[current_name;src;2,2;1,1;]",  -- Input slot
        progress_bar,  -- Smelting arrow with progress
        "list[current_name;dst;4,2;1,1;]",  -- Output slot
        "list[current_player;main;0,3.5;8,4;]",  -- Player inventory
        "listring[current_name;src]",
        "listring[current_player;main]",
        "listring[current_name;dst]",
        "listring[current_player;main]",
        "button[3,6;2,1;close;Close]"  -- Properly positioned close button
    }, "")
end

-- Electric Furnace Node (Fixed Formspect Display)
minetest.register_node("voltz:electric_furnace", {
    description = "Electric Furnace",
    tiles = {"electric_furnace.png"},
    groups = {cracky=3, stone=1},

    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("power", 0)
        meta:set_int("speed", 1)
        meta:set_float("progress", 0)
        local inv = meta:get_inventory()
        inv:set_size("src", 1)  -- Single input slot
        inv:set_size("dst", 1)  -- Single output slot
    end,

    -- Right-click opens the proper 1-to-1 smelting interface
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        if clicker and clicker:is_player() then
            core.show_formspec(clicker:get_player_name(), "voltz:furnace_ui" .. minetest.pos_to_string(pos), get_furnace_formspec(pos))
        end
    end,

    -- Smelting logic (runs on timer)
    on_timer = function(pos)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        local speed = meta:get_int("speed") or 1

        local src_stack = inv:get_stack("src", 1)
        if src_stack:is_empty() then 
            meta:set_float("progress", 0)  -- Reset progress if no item
            return false 
        end  

        local result = minetest.get_craft_result({ method = "cooking", width = 1, items = { src_stack } })
        if result and not result.item:is_empty() then
            if inv:room_for_item("dst", result.item) then
                meta:set_float("progress", meta:get_float("progress") + (0.1 * speed))  -- Increase smelting progress

                if meta:get_float("progress") >= 1 then  -- Complete smelting
                    inv:remove_item("src", src_stack:get_name())
                    inv:add_item("dst", result.item)
                    meta:set_float("progress", 0)  -- Reset progress bar
                end

                minetest.get_node_timer(pos):start(1)  -- Continue processing
                return true
            end
        end
        return false
    end,

    -- Start smelting when items are placed in the input slot
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
        if listname == "src" then
            minetest.get_node_timer(pos):start(1)  -- Start smelting process
        end
    end,
})


-- Default directional power output settings
local function get_default_directions()
    return { up = true, down = true, left = true, right = true, front = true, back = true }
end



