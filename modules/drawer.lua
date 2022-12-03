DRAWER_MAX_CAPACITY = 9999

DRAWER_ID = "drawer"
FULL_DRAWER_ID = "storage_drawer_drawer"

DRAWER_ERROR_STACK = "Storage drawers can only hold stackable items"
DRAWER_ERROR_MISMATCH = "Storage drawers can only store one type of item"
DRAWER_ERROR_QUANTITY = "Storage drawers can only hold up to " ..
                            DRAWER_MAX_CAPACITY .. " items"

drawer_sprite = nil
tooltip_sprite = nil
error_sprite = nil
arrow_sprite = nil

-- define drawer and recipe w/ workbench
function define_drawer()
    local define_obj = api_define_menu_object2({
        id = DRAWER_ID,
        name = "Drawer",
        category = "Storage",
        tooltip = "Stores a nearly infinite amount of one item",
        layout = {{7, 17}, {33, 17, "Output"}},
        buttons = {"Help", "Move", "Target", "Close"},
        info = {{"1. Input", "GREEN"}, {"2. Output", "RED"}},
        tools = {"mouse1", "hammer1"},
        placeable = true
    }, "sprites/drawer/item.png", "sprites/drawer/menu.png", {
        define = "on_drawer_define",
        change = "drawer_change"
    }, "draw_drawer")

    local recipe = {
        {item = "crate2", amount = 1}, {item = "sign", amount = 1},
        {item = "planks2", amount = 5}
    }
    local define_recipe = api_define_recipe("crafting", FULL_DRAWER_ID, recipe,
                                            1)
    api_define_workbench("Storage Drawers", {t1 = "Storage Drawers"})

    if define_obj == "Success" and define_recipe == "Success" then
        return "Success"
    end
    return nil
end

function on_drawer_define(menu_id)
    api_dp(menu_id, "item_sprite", nil) -- item_sprite contains the item to display on the front of the drawer
    api_dp(menu_id, "item_id", nil)
    api_dp(menu_id, "item_count", 0)

    local slot_id = api_get_slot(menu_id, 2).id
    api_slot_set_modded(slot_id, true) -- slot 2 needs to be modded so that click fns are handled properly (otherwise you would grab stacks of >99)

    local fields = {"item_sprite", "item_id", "item_count"}
    api_sp(menu_id, "_fields", fields)
end

function drawer_change(menu_id)
    -- attempt insert 
    local output_item = drawer_insert(menu_id)

    -- update item display
    if output_item ~= "" then
        local spr = api_get_sprite(output_item .. "_item")
        if spr == EMPTY_SPRITE then spr = api_get_sprite(output_item) end
        api_sp(menu_id, "item_sprite", spr)
    else
        api_sp(menu_id, "item_sprite", nil)
    end
end

function draw_drawer(obj_id)
    local obj_inst = api_get_inst(obj_id)
    local spr_item = api_gp(obj_inst.menu_id, "item_sprite")
    local boundary = api_get_boundary(obj_id)
    -- Draw drawer box and tooltip if highlighted
    if api_get_highlighted("obj") == obj_id then
        api_draw_sprite(drawer_sprite, 1, obj_inst.x, obj_inst.y)
        if spr_item ~= nil then
            api_draw_sprite(tooltip_sprite, 0, obj_inst.x - 2, obj_inst.y - 24)
            api_draw_sprite(spr_item, 0, obj_inst.x, obj_inst.y - 22)
        else
            api_draw_sprite(arrow_sprite, 0, obj_inst.x + 8, obj_inst.y - 4)
        end
    else
        api_draw_sprite(drawer_sprite, 0, obj_inst.x, obj_inst.y)
    end

    if spr_item ~= nil then
        api_draw_sprite_ext(spr_item, 0, obj_inst.x + 2, obj_inst.y + 2, 0.70,
                            0.70, 0, nil, 1)
    end

    -- need to handle error sprite here, because custom draw
    local slot = api_get_slot(obj_inst.menu_id, 1)
    if slot.item ~= "" then
        api_draw_sprite(error_sprite, 0, boundary.right - 3, boundary.top - 9)
    end
end

function destroy_drawer(id, x, y, oid, fields)
    local menu_id = api_gp(id, "menu")
    if menu_id == nil then return end

    local item = fields.item_id or ""
    local count = fields.item_count or 0

    -- create item stacks of drawer contents
    while (count > 99) do
        api_create_item(item, 99, x, y)
        count = count - 99
    end
    if count > 0 then api_create_item(item, count, x, y) end
end

function click_drawer(button, click_type)
    -- filter clicks to only the ones that are on slot 2 of drawers
    local slot_id = api_get_highlighted("slot")
    if slot_id == nil then return end

    local slot = api_get_slot_inst(slot_id)
    if slot.item == "" then return end
    local slot_ct = slot.count
    local menu_id = api_gp(slot_id, "menu")
    if api_get_inst(menu_id).oid ~= FULL_DRAWER_ID or slot.index ~= 2 then
        return
    end

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
                    api_sp(menu_id, "item_sprite", nil)
                    -- set_drawer(key, nil)
                    api_sp(menu_id, "item_id", nil)
                    api_sp(menu_id, "item_count", nil)
                    api_slot_clear(slot_id)
                else
                    api_slot_set(slot_id, slot.item,
                                 slot_ct - amt + new_slot.count)
                    api_sp(menu_id, "item_id", slot.item)
                    api_sp(menu_id, "item_count", slot_ct - amt + new_slot.count)
                end
                return
            end
        end
        api_add_slot_to_menu(slot_id, api_get_player_instance())
        local new_slot = api_get_slot_inst(slot_id)
        if slot_ct - amt + new_slot.count <= 0 then
            api_sp(menu_id, "item_sprite", nil)
            -- set_drawer(key, nil)
            api_sp(menu_id, "item_id", nil)
            api_sp(menu_id, "item_count", nil)
            api_slot_clear(slot_id)
        else
            api_slot_set(slot_id, slot.item, slot_ct - amt + new_slot.count)
            api_sp(menu_id, "item_id", slot.item)
            api_sp(menu_id, "item_count", slot_ct - amt + new_slot.count)
        end
        return
    else
        -- mouse should be empty or holding the same item
        local mouse = api_get_mouse_inst()
        if mouse.item ~= "" and mouse.item ~= slot.item then return end

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
            api_sp(menu_id, "item_sprite", nil)
            -- set_drawer(key, nil)
            api_sp(menu_id, "item_id", nil)
            api_sp(menu_id, "item_count", nil)
        else
            api_sp(menu_id, "item_id", slot.item)
            api_sp(menu_id, "item_count", slot.count - amount)
        end
    end

end

function init_drawer()
    local define_check = define_drawer()

    drawer_sprite = api_get_sprite(FULL_DRAWER_ID)

    tooltip_sprite = api_get_sprite("slot_preview")
    error_sprite = api_get_sprite("button_emote2")
    arrow_sprite = api_get_sprite("highlight_arrow_h")

    return define_check
end

-- attempts to "insert" the item from input slot into the output slot
function drawer_insert(menu_id)

    local slots = api_get_slots(menu_id)
    local input_item = slots[1].item
    local output_item = slots[2].item

    -- if there's no input item, no error
    if input_item == "" then
        api_sp(menu_id, "error", "")
        return output_item
    end

    -- singular items aren't allowed
    if api_get_definition(input_item).singular then
        api_sp(menu_id, "error", DRAWER_ERROR_STACK)
        return output_item
    end

    local transfer_amount = math.min(DRAWER_MAX_CAPACITY - slots[2].count,
                                     slots[1].count) -- if input + output > 9999 there will be some leftover in input slot
    local new_total = slots[2].count + transfer_amount

    if output_item == "" or output_item == input_item then
        api_slot_set(slots[2].id, input_item, new_total) -- update output slot
        if slots[1].count > transfer_amount then
            api_sp(menu_id, "error", DRAWER_ERROR_QUANTITY) -- error if overflowed past max capacity
        end
        api_slot_decr(slots[1].id, transfer_amount)
        output_item = input_item

        api_sp(menu_id, "item_id", input_item)
        api_sp(menu_id, "item_count", new_total)
    else
        api_sp(menu_id, "error", DRAWER_ERROR_MISMATCH)
    end

    return output_item
end
