BUILDER_BOX_ID = "builder_box"
FULL_BUILDER_BOX_ID = "storage_drawer_builder_box"

BUILDER_BOX_MAX_CAPACITY = 9999

BUILDER_BOX_ERROR_QUANTITY = "This box has a maximum capacity of " ..
                                 BUILDER_BOX_MAX_CAPACITY .. " per item"
BUILDER_BOX_ERROR_INVALID = "This box cannot hold this item"

bb_title_sprite = nil
bb_active_sprite = nil

function init_builder_box()
    bb_active_sprite = api_define_sprite(MOD_NAME .. "bb_active_slot",
                                         "sprites/active_slot.png", 1)
    bb_title_sprite = api_define_sprite(MOD_NAME .. "_builder_box_title",
                                        "sprites/builder_box/title.png", 2)
    return define_builder_box()
end

function define_builder_box()
    local define_obj = api_define_menu_object2({
        id = BUILDER_BOX_ID,
        name = "Builder's Box",
        category = "Storage",
        tooltip = "A drawer for storing all of your building materials",
        layout = {
            {
                7, 17, "Input", {
                    "customX:tile", "customX:wall",
                    "customX:carpet", "customX:window",
                    "customX:grass"
                }
            }, 

            {155, 17, "Output"}, -- storage slots
            {35, 19, "Output"}, {58, 19, "Output"}, {81, 19, "Output"},
            {104, 19, "Output"}, {127, 19, "Output"}, {35, 42, "Output"},
            {58, 42, "Output"}, {81, 42, "Output"}, {104, 42, "Output"},
            {127, 42, "Output"}, {35, 65, "Output"}, {58, 65, "Output"},
            {81, 65, "Output"}, {104, 65, "Output"}, {127, 65, "Output"},
            {35, 88, "Output"}, {58, 88, "Output"}, {81, 88, "Output"},
            {104, 88, "Output"}, {127, 88, "Output"}
        },
        buttons = {"Help", "Target", "Close"},
        info = {
            {"1. Deposit Slot", "GREEN"}, {"2. Stored Items", "YELLOW"},
            {"3. Withdrawal Slot", "RED"}, {"4. Scroll buttons", "BLUE"}
        },
        tools = {"mouse1", "hammer1"},
        placeable = false
    }, "sprites/builder_box/item.png", "sprites/builder_box/menu.png", {
        define = "on_builder_box_define",
        change = "builder_box_insert",
        draw = "builder_box_draw"
    })
    api_define_validation_icon("customX:tile",
                               "sprites/builder_box/icon_tile.png")
    api_define_validation_icon("customX:wall",
                               "sprites/builder_box/icon_wall.png")
    api_define_validation_icon("customX:carpet",
                               "sprites/builder_box/icon_carpet.png")
    api_define_validation_icon("customX:window",
                               "sprites/builder_box/icon_window.png")
    api_define_validation_icon("customX:grass",
                               "sprites/builder_box/icon_grass.png")
    local recipe = {
        {item = FULL_DRAWER_ID, amount = 3}, {item = "dye3", amount = 1},
        {item = "hammer2", amount = 1}
    }
    local define_recipe = api_define_recipe("crafting", FULL_BUILDER_BOX_ID,
                                            recipe, 1)

    if define_obj == "Success" and define_recipe == "Success" then
        return "Success"
    end
    return nil
end

function builder_box_insert(menu_id)
    api_sp(menu_id, "error", "")
    local slots = api_get_slots(menu_id)
    local input_item = slots[1].item

    if input_item ~= "" then
        local existing = api_gp(menu_id, input_item)
        if existing == nil then
            api_sp(menu_id, "error", BUILDER_BOX_ERROR_INVALID)
            return
        end
        local transfer_amount = math.min(BUILDER_BOX_MAX_CAPACITY - existing,
                                         slots[1].count)
        if slots[1].count > transfer_amount then
            api_sp(menu_id, "error", BUILDER_BOX_ERROR_QUANTITY) -- error if overflowed past max capacity
        end
        api_sp(menu_id, input_item, existing + transfer_amount)
        api_slot_decr(slots[1].id, transfer_amount)
        builder_box_set_active(menu_id, input_item, nil, true)
        builder_box_set_slots(menu_id)
    end
end

function builder_box_ready()
    local boxes = api_all_menu_objects(FULL_BUILDER_BOX_ID)
    for i = 1, #boxes do
        local menu_id = api_gp(boxes[i], "menu")
        if menu_id ~= nil then builder_box_set_slots(menu_id) end
    end

end

function on_builder_box_define(menu_id)
    api_define_button(menu_id, "builder_box_up", 17, 96, "",
                      "builder_box_click_up", "sprites/builder_box/up.png")
    api_define_button(menu_id, "builder_box_down", 4, 96, "",
                      "builder_box_click_down", "sprites/builder_box/down.png")
    local oids = api_describe_oids(false)
    local mod_oids = api_describe_oids(true)
    api_dp(menu_id, "button_count", 0)
    api_dp(menu_id, "active_item", nil)
    api_dp(menu_id, "active_slot", nil)
    api_dp(menu_id, "scroll", 0)
    -- local fields = {"button_count", "active_item", "active_slot", "scroll"}
    local fields = {"button_count", "active_item", "active_slot", "scroll"}
    local slots = api_get_slots(menu_id)
    -- output slots
    api_slot_set_modded(slots[2].id, true)
    -- selection slots
    for i = 3, 22 do
        api_slot_set_modded(slots[i].id, true)
        api_slot_set_inactive(slots[i].id, true)
    end

    for i = 1, #oids do
        local oid = oids[i]
        if oid:find("wall", 1, true) == 1 or oid:find("tile", 1, true) == 1 or
            oid:find("window", 1, true) == 1 or oid:find("carpet", 1, true) == 1 or
            oid:find("grass", 1, true) == 1 then
            api_dp(menu_id, oids[i], 0)
            table.insert(fields, oids[i])
        end
    end
    for i = 1, #mod_oids do
        local oid = mod_oids[i]
        if oid:find("wall", 1, true) == 1 or oid:find("tile", 1, true) == 1 or
            oid:find("window", 1, true) == 1 or oid:find("carpet", 1, true) == 1 or
            oid:find("grass", 1, true) == 1 then
            api_dp(menu_id, mod_oids[i], 0)
            table.insert(fields, mod_oids[i])
        end
    end
    api_sp(menu_id, "_fields", fields)
end

function destroy_builder_box(id, x, y, oid, fields)
    for item, count in pairs(fields) do
        if item:find("wall", 1, true) == 1 or item:find("tile", 1, true) == 1 or
            item:find("window", 1, true) == 1 or item:find("carpet", 1, true) ==
            1 or item:find("grass", 1, true) == 1 then
            while (count > 99) do
                api_create_item(item, 99, x, y)
                count = count - 99
            end
            if count > 0 then api_create_item(item, count, x, y) end
        end
    end
end

function builder_box_draw(menu_id)
    local active = api_gp(menu_id, "active_slot")
    local cam = api_get_cam()
    local menu = api_get_inst(menu_id)
    if active ~= nil then
        active = active - 3
        local row = math.floor(active / 5)
        local col = active % 5
        local x = 32 + 23 * col + menu.x - cam.x
        local y = 16 + 23 * row + menu.y - cam.y
        api_draw_sprite(bb_active_sprite, 0, x, y)
    end

    local buttons = api_gp(menu_id, "button_count")
    local scroll = api_gp(menu_id, "scroll")
    if buttons > 20 then
        if scroll ~= 0 then
            api_draw_button(api_gp(menu_id, "builder_box_up"), false)
        end
        if 20 + 5 * scroll < buttons then
            api_draw_button(api_gp(menu_id, "builder_box_down"), false)
        end
    end

    local highlighted = api_get_highlighted("menu")
    if highlighted == menu_id then
        api_draw_sprite(bb_title_sprite, 1, 2 + menu.x - cam.x,
                        2 + menu.y - cam.y)
    else
        api_draw_sprite(bb_title_sprite, 0, 2 + menu.x - cam.x,
                        2 + menu.y - cam.y)
    end
end

function click_builder_box(button, click_type)
    -- filter clicks to only the ones that are on slot 2 of drawers
    local slot_id = api_get_highlighted("slot")
    if slot_id == nil then return end

    local slot = api_get_slot_inst(slot_id)
    if slot.item == "" then return end

    local menu_id = api_gp(slot_id, "menu")
    if api_get_inst(menu_id).oid ~= FULL_BUILDER_BOX_ID then return end

    if slot.index >= 3 and slot.item ~= "" then
        builder_box_set_active(menu_id, slot.item, slot.index)
    end

    if slot.index == 2 then
        local slot_ct = slot.count
        local shift_key_down = api_get_key_down("SHFT")
        if shift_key_down == 1 then
            local maxamt = 99
            if button == "RIGHT" then maxamt = 1 end
            local amt = math.min(slot_ct, maxamt)
            api_slot_set(slot_id, slot.item, amt)
            -- shift click procedure: if theres a target menu, go there, else player inventory
            local menus = api_get_menu_objects()
            local player = api_get_inst(api_get_player_instance())
            local filtered = {}
            for i = 1, #menus do
                if menus[i].menu_id ~= menu_id and api_gp(menus[i].id, "open") and
                    api_gp(menus[i].menu_id, "target") then
                    api_add_slot_to_menu(slot_id, menus[i].menu_id)
                    local new_slot = api_get_slot_inst(slot_id)
                    if slot_ct - amt + new_slot.count <= 0 then
                        api_sp(menu_id, slot.item, 0)
                        api_slot_clear(slot_id)
                        if api_get_slot(menu_id, 2).item == "" then
                            builder_box_set_slots(menu_id)
                        end
                    else
                        api_slot_set(slot_id, slot.item,
                                     slot_ct - amt + new_slot.count)
                        api_sp(menu_id, slot.item,
                               slot_ct - amt + new_slot.count)
                    end
                    return
                end
            end
            api_add_slot_to_menu(slot_id, api_get_player_instance())
            local new_slot = api_get_slot_inst(slot_id)
            if slot_ct - amt + new_slot.count <= 0 then
                api_sp(menu_id, slot.item, 0)
                api_slot_clear(slot_id)
                if api_get_slot(menu_id, 2).item == "" then
                    builder_box_set_slots(menu_id)
                end
            else
                api_slot_set(slot_id, slot.item, slot_ct - amt + new_slot.count)
                api_sp(menu_id, slot.item, slot_ct - amt + new_slot.count)
            end
            return
        else
            -- mouse should be empty or holding the same item
            local mouse = api_get_mouse_inst()
            if mouse.item ~= "" and mouse.item ~= slot.item then
                return
            end

            -- get the correct amount, r_click grabs 1 item, l_click grabs up to 99 (but may be less if mouse already had item, or drawer has less than 99)
            local mouse_amt = mouse.count or 0
            local max_amt = 99 - mouse_amt
            if max_amt == 0 then return end
            local amount = (slot.count < max_amt) and slot.count or max_amt

            if button == "RIGHT" then amount = 1 end
            api_slot_set(mouse.id, slot.item, amount + mouse_amt)
            api_slot_decr(slot_id, amount)

            -- either clear drawer if empty, or decrease its count
            if slot.count - amount <= 0 then
                api_sp(menu_id, slot.item, 0)
                api_slot_clear(slot_id)
                if api_get_slot(menu_id, 2).item == "" then
                    builder_box_set_slots(menu_id)
                end
            else
                api_sp(menu_id, slot.item, slot.count - amount)
            end
        end
    end
end

function builder_box_set_active(menu_id, item, index, force_update)
    local old_item = api_gp(menu_id, "active_item")
    api_sp(menu_id, "active_item", item)
    api_sp(menu_id, "active_slot", index)
    if old_item == item and force_update ~= true then return end
    if item == nil then
        api_slot_clear(api_get_slot(menu_id, 2).id)
    else

        local item_count = api_gp(menu_id, item)

        if item_count > 0 then
            api_slot_set(api_get_slot(menu_id, 2).id, item, item_count)
        else
            api_slot_clear(api_get_slot(menu_id, 2).id)
        end
    end

end

function builder_box_click_up(menu_id)
    local curr_scroll = api_gp(menu_id, "scroll")
    if curr_scroll - 1 >= 0 then
        api_sp(menu_id, "scroll", curr_scroll - 1)
        builder_box_set_slots(menu_id)
    end
end

function builder_box_click_down(menu_id)
    local buttons = api_gp(menu_id, "button_count")
    local scroll = api_gp(menu_id, "scroll")
    if 20 + 5 * scroll < buttons then
        api_sp(menu_id, "scroll", scroll + 1)
        builder_box_set_slots(menu_id)
    end
end

function scroll_builder_box(direction, inverse)
    local menu_id = api_get_highlighted("menu")
    if menu_id == nil then return end

    if api_gp(menu_id, "oid") ~= FULL_BUILDER_BOX_ID then return end

    if direction == "UP" then
        if inverse == true then
            builder_box_click_down(menu_id)
        else
            builder_box_click_up(menu_id)
        end
    else
        if inverse == true then
            builder_box_click_up(menu_id)
        else
            builder_box_click_down(menu_id)
        end
    end
end

function builder_box_set_slots(menu_id)
    local new_active_index = nil
    local curr_active_item = api_gp(menu_id, "active_item")
    local slots = api_get_slots(menu_id)
    local fields = api_gp(menu_id, "_fields")
    local items = {} -- list ie {"flower1", "flower2", "flower3"}
    local values_inserted = {} -- lookup table ie {flower1: true, flower2: true}
    for _, key in pairs(fields) do
        local val = api_gp(menu_id, key)

        if key:find("wall", 1, true) == 1 or key:find("tile", 1, true) == 1 or
            key:find("window", 1, true) == 1 or key:find("carpet", 1, true) == 1 or
            key:find("grass", 1, true) == 1 then
            if val > 0 then
                if values_inserted[key] == nil then
                    table.insert(items, key)
                    values_inserted[key] = true
                end
            end
        end
    end

    table.sort(items)
    api_sp(menu_id, "button_count", #items)
    local scroll = api_gp(menu_id, "scroll")
    local offset = 5 * scroll
    for i = 1, 20 do
        if slots[i + 2] ~= nil and slots[i + 2].id ~= nil then
            if items[i + offset] ~= nil then
                api_slot_set(slots[i + 2].id, items[i + offset], 0)
                api_slot_set_inactive(slots[i + 2].id, false)
                api_sp(slots[i + 2].id, "changed", false)
                if curr_active_item ~= nil and curr_active_item ==
                    items[i + offset] then
                    new_active_index = i + 2
                end
            else
                api_slot_clear(slots[i + 2].id)
                api_slot_set_inactive(slots[i + 2].id, true)
                api_sp(slots[i + 2].id, "changed", false)
            end
        end
    end
    builder_box_set_active(menu_id, curr_active_item, new_active_index)
end
