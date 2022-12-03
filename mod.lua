MOD_NAME = "storage_drawer"
EMPTY_SPRITE = 920
function register()
    return {
        name = MOD_NAME,
        hooks = {"click", "destroy", "scroll", "ready", "clock"},
        modules = {"drawer", "shipping_bin", "flower_box", "builder_box", "auto_crafter", "inserter"}
    }
end

function init()
    drawer_check = init_drawer()
    shipping_check = init_shipping()
    flower_box_check = init_flower_box()
    builder_box_check = init_builder_box()
    crafter_check = init_crafter()
    inserter_check = init_inserter()

    if drawer_check == "Success" and shipping_check == "Success" and
        flower_box_check == "Success" and builder_box_check == "Success" and crafter_check == "Success" and inserter_check == "Success" then
        return "Success"
    end
end

function ready()
    flower_box_ready()
    builder_box_ready()
    crafter_ready()
    inserter_ready()
    EMPTY_SPRITE = api_get_sprite("zzzzz_zzzzz")
end

function click(button, click_type)
    if click_type ~= "PRESSED" then return end
    click_drawer(button, click_type)
    click_flower_box(button, click_type)
    click_builder_box(button, click_type)
    click_crafter(button, click_type)
    click_inserter(button, click_type)
end

function destroy(id, x, y, oid, fields)
    state = api_game_state()
    if state.game_loading then return end

    if oid == FULL_DRAWER_ID then
        destroy_drawer(id, x, y, oid, fields)
    elseif oid == FULL_FLOWER_BOX_ID then
        destroy_flower_box(id, x, y, oid, fields)
    elseif oid == FULL_BUILDER_BOX_ID then
        destroy_builder_box(id, x, y, oid, fields)
    end
end

function scroll(direction, inverse)
    scroll_flower_box(direction, inverse)
    scroll_builder_box(direction, inverse)
end

function clock()
--     local machines = api_get_menu_objects()
--     api_log("Immortals", machines)
--     local count = 0
--     -- for i=1,#machines do
--     --  if api_gp(machines, "immortal") == true then count = count + 1 end
--     -- end
--   api_log("Immortals", ""..count)
end

