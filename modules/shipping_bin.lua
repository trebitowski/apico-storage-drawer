BIN_ID = "shipping_bin"
FULL_BIN_ID = MOD_NAME.."_"..BIN_ID

BIN_TIMER = 30
BIN_SEARCH = {"ANY"}
BIN_SLOTS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}

BIN_PROGRESS_SIZE = 87
BIN_PROGRESS_OFFSET = 2
BIN_PROGRESS_HEIGHT = 6

sb_title_sprite = nil

function define_shipping()
    local define_obj = api_define_menu_object2({
        id = BIN_ID,
        name = "Shipping Bin",
        category = "Misc",
        tooltip = "Sell your items automatically",
        layout = {
            {7, 25}, {30, 25}, {53, 25}, {76, 25}, {7, 48}, {30, 48}, {53, 48},
            {76, 48}, {7, 71}, {30, 71}, {53, 71}, {76, 71}
        },
        buttons = {"Help", "Target", "Close"},
        info = {{"1. Items to Sell", "FONT_BGREY"}},
        tools = {"mouse1", "hammer1"},
        placeable = true
    }, "sprites/shipping_bin/item.png", "sprites/shipping_bin/menu.png", {
        define = "on_shipping_define",
        change = "shipping_change",
        tick = "shipping_tick",
        draw = "shipping_draw"
    })

    local recipe = {
        {item = "crate2", amount = 1}, {item = "dye3", amount = 1},
        {item = "planks2", amount = 5}
    }
    local define_recipe = api_define_recipe("crafting", FULL_BIN_ID, recipe, 1)

    if define_obj == "Success" and define_recipe == "Success" then
        return "Success"
    end
    return nil
end

function on_shipping_define(menu_id)
    api_dp(menu_id, "working", false)
    api_dp(menu_id, "p_start", 0)
    api_dp(menu_id, "p_end", BIN_TIMER)

    api_define_gui(menu_id, "shipping_progress", 4, 15, "shipping_tooltip",
                   "sprites/shipping_bin/progress_bar.png")
    api_dp(menu_id, "progress_bar",
           api_get_sprite("storage_drawer_shipping_progress"))

    fields = {"p_start", "p_end"}
    fields = api_sp(menu_id, "_fields", fields)
end

function shipping_tooltip(menu_id)
    if api_gp(menu_id, "working") ~= true then return end
    local time_left = math.ceil(api_gp(menu_id, "p_end") -
                                     api_gp(menu_id, "p_start"))

    return {{"Selling Item", "FONT_WHITE"}, {time_left .. "s left", "FONT_BGREY"}}
end

function shipping_change(menu_id)
    local sell_item = find_sellable_slot(menu_id)
    if sell_item == nil then
        api_sp(menu_id, "working", false)
        api_sp(menu_id, "p_start", 0)
    else
        api_sp(menu_id, "working", true)
    end
end

function find_sellable_slot(menu_id)
    local items = api_slot_match_range(menu_id, BIN_SEARCH, BIN_SLOTS)
    for i = 1, #items do
        local item_def = api_get_definition(items[i].item)
        if item_def.cost ~= nil and item_def.cost.key ~= 1 then
            return items[i]
        end
    end
    return nil
end

function shipping_tick(menu_id)
    if api_gp(menu_id, "working") ~= true then return end

    local sell_item = find_sellable_slot(menu_id)
    if sell_item == nil then
        api_sp(menu_id, "working", false)
        api_sp(menu_id, "p_start", 0)
    else
        api_sp(menu_id, "p_start", api_gp(menu_id, "p_start") + 0.1)
        if api_gp(menu_id, "p_start") >= api_gp(menu_id, "p_end") then
            api_sp(menu_id, "p_start", 0)

            -- sell item
            local count = sell_item.count
            local item_def = api_get_definition(sell_item.item)
            api_slot_clear(sell_item.id)
            if item_def.honeycore == 1 then
                api_give_honeycore(count * item_def.cost.sell)
            else
                api_give_money(count * item_def.cost.sell)
            end
            api_play_sound("jingle")
        end
    end
end

function shipping_draw(menu_id)
    local cam = api_get_cam()
    local gui = api_get_inst(api_gp(menu_id, "shipping_progress"))
    local progress_sprite = api_gp(menu_id, "progress_bar")
    local menu = api_get_inst(menu_id)

    local gx = gui.x - cam.x
    local gy = gui.y - cam.y
    local progress = (api_gp(menu_id, "p_start") / api_gp(menu_id, "p_end") *
                         BIN_PROGRESS_SIZE)
    api_draw_sprite_part(progress_sprite, 2, 0, 0, progress,
                         BIN_PROGRESS_HEIGHT, gx, gy)
    api_draw_sprite(progress_sprite, 1, gx, gy) -- bar background

    if api_get_highlighted("ui") == gui.id and api_gp(menu_id, "working") ==
        true then
        api_draw_sprite(progress_sprite, 0, gx, gy) -- highlighted bar
    end

    local highlighted = api_get_highlighted("menu")
    if highlighted == menu_id then
        api_draw_sprite(sb_title_sprite, 1, 2 + menu.x - cam.x,
                        2 + menu.y - cam.y)
    else
        api_draw_sprite(sb_title_sprite, 0, 2 + menu.x - cam.x,
                        2 + menu.y - cam.y)
    end
end

function init_shipping()
    sb_title_sprite = api_define_sprite(MOD_NAME .. "_shipping_bin_title",
                                        "sprites/shipping_bin/title.png", 2)
    return define_shipping()
end
