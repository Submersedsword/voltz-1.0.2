-- Register Voltbox as an Item
minetest.register_craftitem("voltz:voltbox", {
    description = "Infinite Energy Storage Box",
    inventory_image = "voltbox.png",
    groups = {energy_source = 1}  -- Ensures it appears in searches
})

-- Global Electricity Table
local electricity = {
    capacity = 100  -- Max capacity (Voltbox has infinite power)
}

-- Function to check if a position contains a wire
local function is_wire(pos)
    local node = minetest.get_node(pos).name  -- Fixed incorrect `names`
    return voltz.wire_types and voltz.wire_types[node] ~= nil  -- Ensure `voltz.wire_types` exists
end

-- Function to spread power through connected wires
local function spread_power(pos, power_level, visited)
    if not visited then visited = {} end  -- Store visited nodes
    local pos_hash = minetest.pos_to_string(pos)
    if visited[pos_hash] then return end  -- Prevent infinite recursion
    visited[pos_hash] = true

    local positions = {
        {x = pos.x + 1, y = pos.y, z = pos.z},
        {x = pos.x - 1, y = pos.y, z = pos.z},
        {x = pos.x, y = pos.y, z = pos.z + 1},
        {x = pos.x, y = pos.y, z = pos.z - 1},
        {x = pos.x, y = pos.y + 1, z = pos.z},
        {x = pos.x, y = pos.y - 1, z = pos.z}
    }

    for _, neighbor_pos in ipairs(positions) do
        local node = minetest.get_node(neighbor_pos).name
        local wire_info = voltz.wire_types and voltz.wire_types[node]

        if wire_info then  -- If the neighbor is a wire
            local meta = minetest.get_meta(neighbor_pos)
            local current_power = meta:get_int("power") or 0
            if current_power < power_level then
                meta:set_int("power", power_level)
                spread_power(neighbor_pos, power_level - wire_info.loss, visited)  -- Reduce power by loss
            end
        end
    end
end

-- Register Voltbox as a Node
minetest.register_node("voltz:voltbox", {
    description = "Infinite Energy Storage Box",
    tiles = {"voltbox.png"},
    is_ground_content = true,
    groups = {cracky = 3, stone = 1, energy_source = 1},

    -- Right-click UI
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        if clicker and clicker:is_player() then
            minetest.show_formspec(clicker:get_player_name(), "voltz:electricity_ui", minetest.get_formspec())
        end
    end,

    -- Initialize metadata and spread power
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        if meta then
            meta:set_string("infotext", "Infinite Energy Box")
            spread_power(pos, electricity.capacity)
        end
    end,
})

-- Handle UI button actions
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "voltz:electricity_ui" and fields.close then
        return
    end
end)

-- ABM to Continuously Spread Power
minetest.register_abm({
    nodenames = {"voltz:voltbox"},
    interval = 1,  -- Runs every second
    chance = 1,  -- Runs always
    action = function(pos, node)
        spread_power(pos, electricity.capacity)
    end
})
