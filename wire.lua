-- Register Wire as a Craft Item
minetest.register_craftitem("voltz:wire", {
    description = "Electric Wire",
    inventory_image = "wire.obj",
    groups = {energy_cable = 1}  -- Ensures it appears in searches
})

-- Define wire types and their power loss rates
voltz.wire_types = {
    ["voltz:wire"] = { loss = 10 },       -- Standard wire
    ["voltz:wire_low"] = { loss = 15 },   -- Loses more power
    ["voltz:wire_high"] = { loss = 5 },   -- More efficient
}

-- Function to check if a node is a power source
local function is_power_source(pos)
    local node = minetest.get_node(pos).name
    return minetest.get_item_group(node, "energy_source") > 0
end

-- Function to check if a node is a valid wire
local function is_wire(pos)
    local node = minetest.get_node(pos)
    return voltz.wire_types[node.name] ~= nil
end

-- Function to find the nearest power source and transmit power
local function find_and_transmit_power(pos, visited)
    if not visited then visited = {} end  -- Track visited nodes
    local pos_hash = minetest.pos_to_string(pos)
    if visited[pos_hash] then return 0 end  -- Prevent infinite loops
    visited[pos_hash] = true

    local max_power = 0
    local power_source_found = false

    local positions = {
        {x = pos.x + 1, y = pos.y, z = pos.z}, {x = pos.x - 1, y = pos.y, z = pos.z},
        {x = pos.x, y = pos.y, z = pos.z + 1}, {x = pos.x, y = pos.y, z = pos.z - 1},
        {x = pos.x, y = pos.y + 1, z = pos.z}, {x = pos.x, y = pos.y - 1, z = pos.z}
    }

    -- Check for power sources
    for _, neighbor_pos in ipairs(positions) do
        if is_power_source(neighbor_pos) then
            local meta = minetest.get_meta(neighbor_pos)
            local power = meta:get_int("power") or 0
            max_power = math.max(max_power, power)
            power_source_found = true
        end
    end

    -- If connected to a power source, spread power through wires
    if power_source_found then
        for _, neighbor_pos in ipairs(positions) do
            local node = minetest.get_node(neighbor_pos)
            local wire_info = voltz.wire_types[node.name]

            if wire_info then
                local meta = minetest.get_meta(neighbor_pos)
                local adjusted_power = math.max(max_power - wire_info.loss, 0)

                -- Set wire power and continue spreading
                meta:set_int("power", adjusted_power)
                find_and_transmit_power(neighbor_pos, visited)
            end
        end
    end

    return max_power
end

-- Function to update wire power levels
local function update_wire_power(pos)
    local meta = minetest.get_meta(pos)
    local power = find_and_transmit_power(pos)

    -- If power is found, store it in the wire
    meta:set_int("power", power)

    -- Debugging: Log power levels in console
    minetest.log("action", "[Voltz] Wire at " .. minetest.pos_to_string(pos) .. " updated power: " .. power)
end

-- Register Standard Wire
minetest.register_node("voltz:wire", {
    description = "Electric Wire",
    drawtype = "mesh",
    mesh = "wire.obj",
    tiles = {"wire.png"},
    groups = {cracky = 2, oddly_breakable_by_hand = 1, energy_cable = 1},
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("power", 0)
    end,
    after_place_node = function(pos, placer, itemstack, pointed_thing)
        minetest.after(0.1, function() update_wire_power(pos) end)  -- Ensure power updates
    end
})

-- Register Low Voltage Wire
minetest.register_node("voltz:wire_low", {
    description = "Low Voltage Wire",
    drawtype = "mesh",
    mesh = "wire.obj",
    tiles = {"wire_low.png"},
    groups = {cracky = 2, oddly_breakable_by_hand = 1, energy_cable = 1},
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("power", 0)
    end,
    after_place_node = function(pos, placer, itemstack, pointed_thing)
        minetest.after(0.1, function() update_wire_power(pos) end)
    end
})

-- Register High Voltage Wire
minetest.register_node("voltz:wire_high", {
    description = "High Voltage Wire",
    drawtype = "mesh",
    mesh = "wire.obj",
    tiles = {"wire_high.png"},
    groups = {cracky = 2, oddly_breakable_by_hand = 1, energy_cable = 1},
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("power", 0)
    end,
    after_place_node = function(pos, placer, itemstack, pointed_thing)
        minetest.after(0.1, function() update_wire_power(pos) end)
    end
})

-- ABM to Maintain Power Flow
minetest.register_abm({
    nodenames = {"voltz:wire", "voltz:wire_low", "voltz:wire_high"},
    interval = 1,  -- Runs every second
    chance = 1,
    action = function(pos, node)
        update_wire_power(pos)  -- Refresh wire power dynamically
    end
})
