ADVANCED_DRAWER_MAX_CAPACITY = 9999

ADVANCED_DRAWER_ID = "advanced_drawer"
FULL_ADVANCED_DRAWER_ID = "storage_drawer_advanced_drawer"

ADVANCED_DRAWER_ERROR_STACK = "Storage drawers can only hold stackable items"
ADVANCED_DRAWER_ERROR_MISMATCH = "Storage drawers can only store one type of item"
ADVANCED_DRAWER_ERROR_QUANTITY = "Storage drawers can only hold up to " ..
ADVANCED_DRAWER_MAX_CAPACITY .. " items"

advanced_drawer_sprite = nil
ad_tooltip_sprite = nil
ad_error_sprite = nil
ad_arrow_sprite = nil
ad_title_sprite = nil

-- define drawer and recipe w/ workbench
function define_advanced_drawer()
    local define_obj = api_define_menu_object2({
        id = ADVANCED_DRAWER_ID,
        name = "Advanced Drawer",
        category = "Storage",
        tooltip = "A drawer that can work with automation and crafting",
        layout = {{7, 17}, {33, 17, "Output"}, {-50, 17, "Output"}},
        buttons = {"Help", "Move", "Target", "Close"},
        info = {{"1. Input", "GREEN"}, {"2. Output", "RED"}},
        tools = {"mouse1", "hammer1"},
        placeable = true
    }, "sprites/advanced_drawer/item.png", "sprites/advanced_drawer/menu.png", {
        define = "on_advanced_drawer_define",
        change = "advanced_drawer_change",
        draw = "advanced_drawer_menu_draw",
    }, "draw_advanced_drawer")

    local recipe = {
      {item = FULL_DRAWER_ID, amount = 1}, {item = "cog", amount = 10},
    }
    local define_recipe = api_define_recipe("crafting", FULL_ADVANCED_DRAWER_ID, recipe,
                                            1)
    api_define_workbench("Storage Drawers", {t1 = "Storage Drawers"})

    if define_obj == "Success" and define_recipe == "Success" then
        return "Success"
    end
    return nil
end

function advanced_drawer_menu_draw(menu_id)
    local cam = api_get_cam()
    local menu = api_get_inst(menu_id)

    local highlighted = api_get_highlighted("menu")
    if highlighted == menu_id then
        api_draw_sprite(ad_title_sprite, 0, 2 + menu.x - cam.x,
                        2 + menu.y - cam.y)
    end
end
function on_advanced_drawer_define(menu_id)
    api_dp(menu_id, "item_sprite", nil) -- item_sprite contains the item to display on the front of the drawer
    api_dp(menu_id, "item_id", nil)
    api_dp(menu_id, "item_count", 0)

    local slot_id = api_get_slot(menu_id, 2).id
    api_slot_set_modded(slot_id, true) -- slot 2 needs to be modded so that click fns are handled properly (otherwise you would grab stacks of >99)

    --api_slot_set_inactive(api_get_slot(menu_id, 3).id, true) --TODO: enable

    local fields = {"item_sprite", "item_id", "item_count"}
    api_sp(menu_id, "_fields", fields)
end

function advanced_drawer_change(menu_id)
    -- attempt insert 
    local output_item = advanced_drawer_insert(menu_id)

    -- update item display
    if output_item ~= "" then
        local spr = api_get_sprite(output_item .. "_item")
        if spr == EMPTY_SPRITE then spr = api_get_sprite(output_item) end
        api_sp(menu_id, "item_sprite", spr)
    else
        api_sp(menu_id, "item_sprite", nil)
    end
end

function draw_advanced_drawer(obj_id)
    local obj_inst = api_get_inst(obj_id)
    local spr_item = api_gp(obj_inst.menu_id, "item_sprite")
    local boundary = api_get_boundary(obj_id)
    -- Draw drawer box and tooltip if highlighted
    if api_get_highlighted("obj") == obj_id then
        api_draw_sprite(advanced_drawer_sprite, 1, obj_inst.x, obj_inst.y)
        if spr_item ~= nil then
            api_draw_sprite(ad_tooltip_sprite, 0, obj_inst.x - 2, obj_inst.y - 24)
            api_draw_sprite(spr_item, 0, obj_inst.x, obj_inst.y - 22)
        else
            api_draw_sprite(ad_arrow_sprite, 0, obj_inst.x + 8, obj_inst.y - 4)
        end
    else
        api_draw_sprite(advanced_drawer_sprite, 0, obj_inst.x, obj_inst.y)
    end

    if spr_item ~= nil then
        api_draw_sprite_ext(spr_item, 0, obj_inst.x + 2, obj_inst.y + 2, 0.70,
                            0.70, 0, nil, 1)
    end

    -- need to handle error sprite here, because custom draw
    local slot = api_get_slot(obj_inst.menu_id, 1)
    if slot.item ~= "" then
        api_draw_sprite(ad_error_sprite, 0, boundary.right - 3, boundary.top - 9)
    end
end

function destroy_advanced_drawer(id, x, y, oid, fields)
    local menu_id = api_gp(id, "menu")
    if menu_id == nil then return end

    local item = fields.item_id or ""
    local count = (fields.item_count or 0) - 99 -- subtract 99 for advanced slot

    -- create item stacks of drawer contents
    while (count > 99) do
        api_create_item(item, 99, x, y)
        count = count - 99
    end
    if count > 0 then api_create_item(item, count, x, y) end
end

function click_advanced_drawer(button, click_type) --TODO manage slot 3
    -- filter clicks to only the ones that are on slot 2 of drawers
    local slot_id = api_get_highlighted("slot")
    if slot_id == nil then return end
    
    local slot = api_get_slot_inst(slot_id)
    if slot.item == "" then return end
    local slot_ct = slot.count
    local menu_id = api_gp(slot_id, "menu")
    if api_get_inst(menu_id).oid ~= FULL_ADVANCED_DRAWER_ID or slot.index ~= 2 then
        return
    end
    local advanced_slot_id = api_get_slot(menu_id, 3).id
    local shift_key_down = api_get_key_down("SHFT")
    if shift_key_down == 1 then
        local maxamt = 99
        if button == "RIGHT" then maxamt = 1 end
        local amt = math.min(slot_ct, maxamt)
        api_slot_set(slot_id, slot.item, amt)
        api_slot_set(advanced_slot_id, slot.item, math.min(99, amt))
        -- shift click procedure: if theres a target menu, go there, else player inventory
        local menus = api_get_menu_objects()
        local player = api_get_inst(api_get_player_instance())
        local filtered = {}
        for i = 1, #menus do
            if menus[i].menu_id ~= menu_id and api_gp(menus[i].id, "open") and
                api_gp(menus[i].menu_id, "target") then
                api_add_slot_to_menu(slot_id, menus[i].menu_id) --TODO change script
                local new_slot = api_get_slot_inst(slot_id)
                if slot_ct - amt + new_slot.count <= 0 then
                    api_sp(menu_id, "item_sprite", nil)
                    -- set_drawer(key, nil)
                    api_sp(menu_id, "item_id", nil)
                    api_sp(menu_id, "item_count", nil)
                    api_slot_clear(slot_id)
                    api_slot_clear(advanced_slot_id)
                else
                  api_slot_set(slot_id, slot.item,
                               slot_ct - amt + new_slot.count)
                  api_slot_set(advancedslot_id, slot.item,
                  math.min(99, slot_ct - amt + new_slot.count))
                  api_sp(menu_id, "item_id", slot.item)
                    api_sp(menu_id, "item_count", slot_ct - amt + new_slot.count)
                end
                return
            end
        end
        api_add_slot_to_menu(slot_id, api_get_player_instance()) --TODO: change script
        local new_slot = api_get_slot_inst(slot_id)
        if slot_ct - amt + new_slot.count <= 0 then
            api_sp(menu_id, "item_sprite", nil)
            -- set_drawer(key, nil)
            api_sp(menu_id, "item_id", nil)
            api_sp(menu_id, "item_count", nil)
            api_slot_clear(slot_id)
            api_slot_clear(advanced_slot_id)
        else
            api_slot_set(slot_id, slot.item, slot_ct - amt + new_slot.count)
            api_slot_set(advanced_slot_id, slot.item, math.min(99, slot_ct - amt + new_slot.count))
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
            api_slot_clear(advanced_slot_id)
        else
            api_sp(menu_id, "item_id", slot.item)
            api_sp(menu_id, "item_count", slot.count - amount)
            api_slot_set(advanced_slot_id, slot.item, math.min(99, slot.count - amount))
        end
    end

end

function init_advanced_drawer()
    local define_check = define_advanced_drawer()

    advanced_drawer_sprite = api_get_sprite(FULL_ADVANCED_DRAWER_ID)
    
    ad_title_sprite = api_define_sprite(MOD_NAME .. "_advanced_drawer_title",
                                        "sprites/advanced_drawer/title.png", 1)

    ad_tooltip_sprite = api_get_sprite("slot_preview")
    ad_error_sprite = api_get_sprite("button_emote2")
    ad_arrow_sprite = api_get_sprite("highlight_arrow_h")

    return define_check
end

-- attempts to "insert" the item from input slot into the output slot
function advanced_drawer_insert(menu_id)
    api_log("insert", "insert")
    local slots = api_get_slots(menu_id)
    local input_item = slots[1].item
    local output_item = slots[2].item
    
    --reconcile amounts
    local advanced_count = slots[3].count
    if advanced_count < 99 and advanced_count < slots[2].count then
      local missing = math.min(99, slots[2].count) - advanced_count;
      if missing > 0 then
        api_sp(menu_id, "item_count", slots[2].count - missing)
        api_slot_decr(slots[2].id, missing)
        if slots[2].count - missing == 0 then 
          output_item = ""
          api_sp(menu_id, "item_id", nil)
        end
      else
        api_slot_set(slots[3].id, output_item, math.min(99, slots[2].count)) -- update output slot
      end    
    end

    -- if there's no input item, no error
    if input_item == "" then
        api_sp(menu_id, "error", "")
        return output_item
    end

    -- singular items aren't allowed
    if api_get_definition(input_item).singular then
        api_sp(menu_id, "error", ADVANCED_DRAWER_ERROR_STACK)
        return output_item
    end

    local transfer_amount = math.min(ADVANCED_DRAWER_MAX_CAPACITY - slots[2].count,
                                     slots[1].count) -- if input + output > 9999 there will be some leftover in input slot
    local new_total = slots[2].count + transfer_amount

    if output_item == "" or output_item == input_item then
        api_slot_set(slots[2].id, input_item, new_total) -- update output slot
        api_slot_set(slots[3].id, input_item, math.min(99, new_total)) -- update output slot
        if slots[1].count > transfer_amount then
            api_sp(menu_id, "error", ADVANCED_DRAWER_ERROR_QUANTITY) -- error if overflowed past max capacity
        end
        api_slot_decr(slots[1].id, transfer_amount)
        output_item = input_item

        api_sp(menu_id, "item_id", input_item)
        api_sp(menu_id, "item_count", new_total)
    else
        api_sp(menu_id, "error", ADVANCED_DRAWER_ERROR_MISMATCH)
    end

    return output_item
end
