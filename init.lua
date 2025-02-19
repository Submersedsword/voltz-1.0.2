voltz = {}
for _, voltz in ipairs ({"electric", "furnace", "lamps", "voltbox", "wire"})
do
dofile(minetest.get_modpath ("voltz") .. "/" .. voltz .. ".lua")
end
