DRAWER_MAX_CAPACITY = 99999

DRAWER_ID = "drawer"
FULL_DRAWER_ID = MOD_NAME.."_"..DRAWER_ID

DRAWER_ERROR_STACK = "Storage drawers can only hold stackable items"
DRAWER_ERROR_MISMATCH = "Storage drawers can only store one type of item"
DRAWER_ERROR_QUANTITY = "Storage drawers can only hold up to "..DRAWER_MAX_CAPACITY.." items"

DRAWER_MENU_DEFINITION = {
    id = DRAWER_ID,
    name = "Drawer",
    category = "Storage",
    tooltip = "Stores a nearly infinite amount of one item",
    layout = {{7, 17}, {33, 17, "Output"}},
    buttons = {"Help", "Move", "Target", "Close"},
    info = {{"1. Input", "GREEN"}, {"2. Output", "RED"}},
    tools = {"mouse1", "hammer1"},
    placeable = true
}

function init_drawer()
    local define_obj = api_define_menu_object2(
        DRAWER_MENU_DEFINITION, 
        "sprites/drawer/item.png",
        "sprites/drawer/menu.png", 
        {
            define = "drawer_define",
            change = "drawer_change"
        }
    )

    local recipe = {
        {item = "crate2", amount = 1}, 
        {item = "sign", amount = 1},
        {item = "planks2", amount = 5}
    }
    local define_recipe = api_define_recipe("crafting", FULL_DRAWER_ID, recipe, 1)
    api_define_workbench("Storage Drawers", {t1 = "Storage Drawers"})

    if define_obj == "Success" and define_recipe == "Success" then
        return "Success"
    end

    return nil
end

function drawer_define(menu_id)
    api_dp(menu_id, "display_id", nil)
    api_dp(menu_id, "item_id", nil)
    api_dp(menu_id, "item_count", 0)

    local slot_id = api_get_slot(menu_id, 2).id
    api_slot_set_modded(slot_id, true)

    local fields = {"item_id", "item_count"}
    api_sp(menu_id, "_fields", fields)

    drawer_update_display(menu_id)
end

function drawer_change(menu_id)
    -- attempt insert 
    drawer_insert(menu_id)
    drawer_update_display(menu_id)
    drawer_update_fields(menu_id)
end

function destroy_drawer(id, x, y, oid, fields)
    local item = fields.item_id or ""
    local count = fields.item_count or 0

    if item == "" then
        return
    end

    while (count > 0) do
        local amt = math.min(count, MAX_STACK)
        api_create_item(item, amt, x, y)
        count = count - amt
    end
end

function click_drawer(button, click_type)
    -- filter clicks to only the ones that are on slot 2 of drawers
    local slot_id = api_get_highlighted("slot")
    if slot_id == nil then return end -- not a slot

    local slot = api_get_slot_inst(slot_id)
    if slot.item == "" then return end -- empty slot
    local slot_ct = slot.count
    local menu_id = api_gp(slot_id, "menu")
    if api_get_inst(menu_id).oid ~= FULL_DRAWER_ID or slot.index ~= 2 then
        return -- not storage drawer output
    end

    local shift_key_down = api_get_key_down("SHFT")
    if shift_key_down == 1 then
        local maxamt = MAX_STACK
        if button == "RIGHT" then maxamt = 1 end
        local amt = math.min(slot_ct, maxamt)
        api_slot_set(slot_id, slot.item, amt)
        -- shift click procedure: if theres a target menu, go there, else player inventory
        local menus = api_get_menu_objects()
        local filtered = {}
        for i = 1, #menus do
            if menus[i].menu_id ~= menu_id and api_gp(menus[i].id, "open") and
                api_gp(menus[i].menu_id, "target") then
                api_add_slot_to_menu(slot_id, menus[i].menu_id)
                local new_slot = api_get_slot_inst(slot_id)
                if slot_ct - amt + new_slot.count <= 0 then
                    api_slot_clear(slot_id)
                else
                    api_slot_set(slot_id, slot.item,
                                 slot_ct - amt + new_slot.count)
                end
                return
            end
        end
        api_add_slot_to_menu(slot_id, api_get_player_instance())
        local new_slot = api_get_slot_inst(slot_id)
        if slot_ct - amt + new_slot.count <= 0 then
            api_slot_clear(slot_id)
        else
            api_slot_set(slot_id, slot.item, slot_ct - amt + new_slot.count)
        end
        return
    else
        -- mouse should be empty or holding the same item
        local mouse = api_get_mouse_inst()
        if mouse.item ~= "" and mouse.item ~= slot.item then return end

        -- get the correct amount, r_click grabs 1 item, l_click grabs up to MAX_STACK (but may be less if mouse already had item, or drawer has less than MAX_STACK)
        local mouse_amt = mouse.count or 0
        local max_amt = MAX_STACK - mouse_amt
        if max_amt == 0 then return end
        local amount = (slot.count < max_amt) and slot.count or max_amt

        if button == "RIGHT" then amount = 1 end
        api_slot_set(mouse.id, slot.item, amount + mouse_amt)
        api_slot_decr(slot_id, amount)
    end

end

-- attempts to insert the input item into the output slot
function drawer_insert(menu_id)

    local slots = api_get_slots(menu_id)
    local input = slots[1]
    local output = slots[2]

    -- remove any errors
    if input.item == "" then
        api_sp(menu_id, "error", "")
        return
    end

    -- singular items aren't allowed
    if api_get_definition(input.item).singular then
        api_sp(menu_id, "error", DRAWER_ERROR_STACK)
        return
    end

    -- items must match
    if output.item ~= "" and output.item ~= input.item then
        api_sp(menu_id, "error", DRAWER_ERROR_MISMATCH)
        return
    end

    local remaining_space = DRAWER_MAX_CAPACITY - output.count
    local transfer_amount = math.min(remaining_space, input.count)

    if transfer_amount > 0 then
        api_slot_decr(input.id, transfer_amount)
        api_slot_set(output.id, input.item, output.count + transfer_amount)
    end

    -- max capacity reached
    if input.count > 0 then
        api_sp(menu_id, "error", DRAWER_ERROR_QUANTITY) 
    end
end

-- manages the lightweight that displays the current drawer item
function drawer_update_display(menu_id)
    -- update item display
    local existing_id = api_gp(menu_id, "display_id")
    if existing_id ~= nil then
        api_destroy_inst(existing_id)
    end

    local slots = api_get_slots(menu_id)
    local output = slots[2]

    if output.item == "" then
        api_sp(menu_id, "display_id", nil)
        return
    end

    local spr = api_get_sprite(output.item .. "_item")
    if spr == EMPTY_SPRITE then 
        spr = api_get_sprite(output.item) 
    end

    local lightweight_id = api_create_lightweight(
        "obj", 
        spr, 
        1,
        api_gp(menu_id, "obj_x"),
        api_gp(menu_id, "obj_y")
    )

    api_sp(menu_id, "display_id", lightweight_id)
end

-- keep fields up to date
function drawer_update_fields(menu_id)
    local slots = api_get_slots(menu_id)
    local output = slots[2]

    api_sp(menu_id, "item_id", output.item)
    api_sp(menu_id, "item_count", output.count)
end