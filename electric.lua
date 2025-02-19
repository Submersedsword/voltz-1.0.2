local electricity = {
    voltz = 0,  -- Default energy state
    capacity = 100,  -- Maximum storage capacity
    generation_rate = 10,  -- Energy produced per tick
    loss_rate = 5,  -- Power loss per wire connection
    heat_loss = 2  -- Power loss per connected machine (e.g., lamps, furnaces)
}

-- Function to generate electricity (e.g., power plants, solar panels)
function electricity.generate(amount)
    electricity.voltz = math.min(electricity.voltz + amount, electricity.capacity)
end

-- Function to consume electricity (e.g., machines, furnaces)
function electricity.consume(amount)
    if electricity.voltz >= amount then
        electricity.voltz = electricity.voltz - amount
        return true  -- Successfully consumed power
    else
        return false  -- Not enough power
    end
end

-- Function to check if a node is a wire
local function is_wire(pos)
    local node = minetest.get_node(pos)
    return voltz.wire_types[node.name] ~= nil  -- Checks all registered wire types
end

-- Function to spread power through connected wires
local function spread_power(pos, power_level, visited)
    if power_level <= 0 then return end  -- Stop spreading if no power left
    if not visited then visited = {} end  -- Track visited nodes
    local pos_hash = minetest.pos_to_string(pos)
    if visited[pos_hash] then return end  -- Prevent infinite recursion
    visited[pos_hash] = true

    local positions = {
        {x = pos.x + 1, y = pos.y, z = pos.z}, {x = pos.x - 1, y = pos.y, z = pos.z},
        {x = pos.x, y = pos.y, z = pos.z + 1}, {x = pos.x, y = pos.y, z = pos.z - 1},
        {x = pos.x, y = pos.y + 1, z = pos.z}, {x = pos.x, y = pos.y - 1, z = pos.z}
    }

    for _, neighbor_pos in ipairs(positions) do
        local node = minetest.get_node(neighbor_pos)
        local wire_info = voltz.wire_types[node.name]

        if wire_info then
            local meta = minetest.get_meta(neighbor_pos)
            local current_power = meta:get_int("power") or 0
            local new_power = math.max(power_level - wire_info.loss, 0)  -- Apply wire loss

            if new_power > current_power then
                meta:set_int("power", new_power)
                spread_power(neighbor_pos, new_power, visited)  -- Continue spreading power
            end
        elseif minetest.get_item_group(node.name, "energy_device") > 0 then
            -- If a connected node is an energy-consuming device, apply heat loss
            local meta = minetest.get_meta(neighbor_pos)
            local device_power = math.max(power_level - electricity.heat_loss, 0)
            meta:set_int("power", device_power)
        end
    end
end

-- Function to update power every second
local function update_electricity()
    electricity.generate(electricity.generation_rate)  -- Generate power per tick
    minetest.after(1, update_electricity)  -- Schedule next update
end

-- Start the electricity update loop
minetest.after(1, update_electricity)

-- ABM to Maintain Power Flow
minetest.register_abm({
    nodenames = {"voltz:wire", "voltz:wire_low", "voltz:wire_high"},
    interval = 1,  -- Runs every second
    chance = 1,
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        local power = meta:get_int("power") or 0

        -- Debugging: Log wire power levels
        minetest.log("action", "[Voltz] Wire at " .. minetest.pos_to_string(pos) .. " has power: " .. power)

        -- Recalculate and spread power properly
        spread_power(pos, power)
    end
})

-- ABM for Electric Furnaces & Lamps
minetest.register_abm({
    nodenames = {"voltz:lamp_off", "voltz:lamp_dim", "voltz:lamp_bright", "voltz:electric_furnace"},
    interval = 1,
    chance = 1,
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        local power = meta:get_int("power") or 0

        -- Debugging: Log power level of devices
        minetest.log("action", "[Voltz] Device at " .. minetest.pos_to_string(pos) .. " has power: " .. power)

        -- Reduce power based on heat loss
        if power > 0 then
            local new_power = math.max(power - electricity.heat_loss, 0)
            meta:set_int("power", new_power)
        end
    end
})

-- Function to get electricity formspec
function minetest.get_formspec()
    local percent = (electricity.voltz / electricity.capacity) * 3  -- Scale for UI
    return table.concat({
        "formspec_version[4]",
        "size[6,4]",
        "label[2.3,0.5;Electricity Status]",
        "image[1.5,1.5;3,0.5;gui_progress_bg.png]",  -- Background bar
        "image[1.5,1.5;", percent, ",0.5;gui_progress_bar.png]",  -- Power bar
        "button[1.5,3;3,0.8;close;Close]"
    }, "")
end

return electricity  -- Export the electricity system for other mod files.
