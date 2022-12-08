-- TODO: 
-- test immortals are getting set/unset properly
-- try and match slot validation??
-- todo slot filtering
INSERTER_ID = "inserter"
FULL_INSERTER_ID = "storage_drawer_inserter"

INSERTER_TIMER = 2

INSERTER_CURRENT_MENU = nil
INSERTER_SELECT_MODE = nil

INSERTER_INPUTS = {}
INSERTER_OUTPUTS = {}

INSERTER_MENU_WIDTH = 97
INSERTER_MENU_HEIGHT = 40

INSERTER_RANGE = 20

INSERTER_PROGRESS_SIZE = 50
INSERTER_PROGRESS_OFFSET = 1
INSERTER_PROGRESS_HEIGHT = 22

INSERTER_SPECIAL_ITEMS = { -- list of important stats for different items
    bee = {'queen', 'species'},
    butterfly = {'species'},
    caterpillar = {'species'},
    eggs = {'species'},
    frame = {'filled', 'uncapped'},
    canister = {'type', 'amount'},
}

in_title_sprite = nil

function define_inserter()
    local define_obj = api_define_menu_object2({
        id = INSERTER_ID,
        name = "Inserter",
        category = "Machine",
        tooltip = "Move items from one object to another",
        layout = {
            {7, 17, "Output"}, -- input machine
            {42, 17, "Output"}, -- item filter
            {76, 17, "Output"} -- output machine
        },
        buttons = {"Help", "Target", "Close"},
        info = {
            {"1. Input Machine", "ORANGE"},
            {"2. Item Filter (Optional)", "RED"},
            {"3. Output Machine", "BLUE"}
        },
        tools = {"mouse1", "hammer1"},
        placeable = truese
    }, "sprites/inserter/item.png", "sprites/inserter/menu.png", {
        define = "on_inserter_define",
        tick = "inserter_tick",
        draw = "inserter_draw"
    })

    local recipe = {{item = "cog", amount = 5}, {item = "planks2", amount = 5}}
    local define_recipe = api_define_recipe("crafting", FULL_INSERTER_ID,
                                            recipe, 1)

    if define_obj == "Success" and define_recipe == "Success" then
        return "Success"
    end
    return nil
end

function on_inserter_define(menu_id)
    api_dp(menu_id, "working", 1)
    api_dp(menu_id, "p_start", 0)
    api_dp(menu_id, "p_end", INSERTER_TIMER)
    api_dp(menu_id, "input_zoid", "")
    api_dp(menu_id, "output_zoid", "")
    api_dp(menu_id, "filter", {"ANY"})
    api_dp(menu_id, "filter_stats", false)

    local slots = api_get_slots(menu_id) -- all slots are modded
    api_slot_set_modded(slots[1].id, true)
    api_slot_set_modded(slots[2].id, true)
    api_slot_set_modded(slots[3].id, true)

    api_define_gui(menu_id, "inserter_progress", 26, 14, "inserter_tooltip",
                   "sprites/inserter/progress_bar.png")
    api_dp(menu_id, "progress_bar",
           api_get_sprite("storage_drawer_inserter_progress"))

    local fields = {"input_zoid", "output_zoid", "filter", "filter_stats", "p_start", "p_end"}
    api_sp(menu_id, "_fields", fields)
end

function inserter_tooltip(menu_id)
    if api_gp(menu_id, "working") ~= 1 then return end
    local time_left = math.ceil(api_gp(menu_id, "p_end") -
                                    api_gp(menu_id, "p_start"))

    return {
        {"Transferring Item", "FONT_WHITE"},
        {time_left .. "s left", "FONT_BGREY"}
    }
end

function click_inserter(button, click_type)
    inserter_handle_selection(button, click_type)
    local menu_id = api_get_highlighted("menu")
    if menu_id ~= nil and api_gp(menu_id, "oid") == FULL_INSERTER_ID then
        local slot_id = api_get_highlighted("slot")
        if (slot_id ~= nil) then
            slot_inst = api_get_slot_inst(slot_id)
            if slot_inst.index == 2 then
                inserter_set_filter(menu_id, slot_id)
            elseif slot_inst.index == 1 then
                inserter_start_selection(button, menu_id, "INPUT_MENU", slot_id)
            elseif slot_inst.index == 3 then
                inserter_start_selection(button, menu_id, "OUTPUT_MENU", slot_id)
            end
        end
    end
end

function inserter_tick(menu_id)
    if api_gp(menu_id, "working") ~= 1 then return end
    
    local input = get_input(menu_id)
  local output = get_output(menu_id)

    if input == nil or output == nil then
        api_sp(menu_id, "working", 0)
        api_sp(menu_id, "p_start", 0)
        return
    end

    api_sp(menu_id, "p_start", api_gp(menu_id, "p_start") + 0.1)
    if api_gp(menu_id, "p_start") >= api_gp(menu_id, "p_end") then
        api_sp(menu_id, "p_start", 0)

        local input_menu = api_gp(input, "menu")
        local output_menu = api_gp(output, "menu")
        
        if input_menu == nil or output_menu == nil then
          api_sp(menu_id, "working", 0)
          api_sp(menu_id, "p_start", 0)
          return
      end

        local filter = api_gp(menu_id, "filter")
        local filter_slot = api_get_slot(menu_id, 2)
        local slot = inserter_get_first_valid_slot(input_menu, filter, menu_id)

        if slot ~= nil then
            api_add_slot_to_menu(slot.id, output_menu)
            
            local input_script = api_gp(input_menu, "script_change")
            if input_script ~= nil and
                string.find(api_gp(input_menu, 'oid'), "storage_drawer") then
                api_mod_call("storage_drawer", script, {input_menu}) -- TODO: remove when patch has change event called automatically
            end

            local output_script = api_gp(output_menu, "script_change")
            if output_script ~= nil and
                string.find(api_gp(output_menu, 'oid'), "storage_drawer") then
                api_mod_call("storage_drawer", output_script, {output_menu}) -- TODO: remove when patch has change event called automatically
            end
        end
    end
end

function inserter_get_first_valid_slot(menu_id, filter, inserter_menu) -- filters out modded slots and match stats for certain items
    local slots = api_slot_match(menu_id, filter, false)
    local stats_key = api_gp(inserter_menu, "filter_stats")
    for i = 1, #slots do
        if api_gp(slots[i].id, "modded") == false then            
            if stats_key ~= false then
              local match = true
              for j=1,#INSERTER_SPECIAL_ITEMS[stats_key] do
                local key = INSERTER_SPECIAL_ITEMS[stats_key][j]
                local filter_stats = api_get_slot(inserter_menu, 2).stats
                local slot_stats = slots[i].stats
                if filter_stats[key] ~= slot_stats[key] then match = false end
              end
              if match == true then
                return slots[i]
              end
            else
              return slots[i]
            end
        end
    end
end

function inserter_draw(menu_id)
    local cam = api_get_cam()
    local gui = api_get_inst(api_gp(menu_id, "inserter_progress"))
    
    local input = get_input(menu_id)
  local output = get_output(menu_id)

    local cam = api_get_cam()
    local menu = api_get_inst(menu_id)
    local highlighted = api_get_highlighted("menu")
    if highlighted == menu_id then
        api_draw_sprite(in_title_sprite, 0, 2 + menu.x - cam.x,
                        2 + menu.y - cam.y)
    end

    local progress_sprite = api_gp(menu_id, "progress_bar")

    local gx = gui.x - cam.x
    local gy = gui.y - cam.y

    local progress = (api_gp(menu_id, "p_start") / api_gp(menu_id, "p_end") *
                         INSERTER_PROGRESS_SIZE)
    api_draw_sprite_part(progress_sprite, 2, 0, 0, progress,
                         INSERTER_PROGRESS_HEIGHT, gx, gy)
    api_draw_sprite(progress_sprite, 1, gx, gy)

    local highlighted_slot = api_get_highlighted('slot')
    if api_get_highlighted("ui") == gui.id and api_gp(menu_id, "working") == 1 and
        highlighted_slot == nil then
        -- api_draw_sprite(progress_sprite, 0, gx, gy)
    end

    local slots = api_get_slots(menu_id)
    api_slot_redraw(slots[2].id)
end

function init_inserter()
    in_title_sprite = api_define_sprite(MOD_NAME .. "_inserter_title",
                                        "sprites/inserter/title.png", 1)
    api_define_color("PURPLE", {r = 101, g = 66, b = 178})

    return define_inserter()
end

function inserter_handle_selection(button, click_type)
    if INSERTER_CURRENT_MENU == nil then return end
    if api_gp(INSERTER_CURRENT_MENU, "open") == false then
        INSERTER_CURRENT_MENU = nil
        INSERTER_SELECT_MODE = nil
        return
    end

    local highlight = api_get_highlighted("menu_obj");
    if highlight == nil then return end

    local inserter_id = api_get_menus_obj(INSERTER_CURRENT_MENU)
    local inserter = api_get_inst(inserter_id)
    local nearby_machines = api_get_inst_in_circle("menu_obj", inserter.x + 7,
                                                   inserter.y + 7,
                                                   INSERTER_RANGE - 2)

    local in_range = false
    for i = 1, #nearby_machines do
        if nearby_machines[i].id == highlight then in_range = true end
    end

    if in_range == false then return end

    if INSERTER_SELECT_MODE == "INPUT_MENU" then
        local old_menu = get_input(menu_id)
        if old_menu ~= nil then api_set_immortal(old_menu, false) end
        INSERTER_INPUTS['id' .. INSERTER_CURRENT_MENU] = highlight
        api_sp(INSERTER_CURRENT_MENU, "input_zoid", inserter_get_zoid(highlight))
        api_slot_set(api_get_slot(INSERTER_CURRENT_MENU, 1).id,
                     api_gp(highlight, "oid"), 0)
        api_set_immortal(highlight, true)
        api_toggle_menu(api_gp(highlight, "menu"), "close")
    elseif INSERTER_SELECT_MODE == "OUTPUT_MENU" then
        local old_menu = get_output(INSERTER_CURRENT_MENU)
        if old_menu ~= nil then api_set_immortal(old_menu, false) end
        INSERTER_OUTPUTS['id' .. INSERTER_CURRENT_MENU] = highlight
        api_sp(INSERTER_CURRENT_MENU, "output_zoid",
               inserter_get_zoid(highlight))
        api_slot_set(api_get_slot(INSERTER_CURRENT_MENU, 3).id,
                     api_gp(highlight, "oid"), 0)
        api_set_immortal(highlight, true)
        api_toggle_menu(api_gp(highlight, "menu"), "close")
    end
    api_sp(INSERTER_CURRENT_MENU, "working", 1)
    INSERTER_CURRENT_MENU = nil
    INSERTER_SELECT_MODE = nil
end

function inserter_ready()
    local inserters = api_all_menu_objects(FULL_INSERTER_ID)
    for i = 1, #inserters do
        local menu_id = api_gp(inserters[i], "menu")
        local input_zoid = api_gp(menu_id, "input_zoid")
        if input_zoid ~= "" then
            local zoid = inserter_split(input_zoid, "-")
            local input_inst = api_get_menu_objects(5, zoid[1], {
                x = math.floor(zoid[2]),
                y = math.floor(zoid[3])
            })
            if #input_inst ~= 1 then
                INSERTER_INPUTS['id' .. menu_id] = nil
                api_sp(menu_id, "input_zoid", "")
                api_slot_clear(menu_id, 1)
            else
                INSERTER_INPUTS['id' .. menu_id] = input_inst[1].id
            end
        end
        local output_zoid = api_gp(menu_id, "output_zoid")
        if output_zoid ~= "" then
            local zoid = inserter_split(output_zoid, "-")
            local output_inst = api_get_menu_objects(5, zoid[1], {
                x = math.floor(zoid[2]),
                y = math.floor(zoid[3])
            })
            if #output_inst ~= 1 then
                api_log("ready", "Did not find match")
                INSERTER_OUTPUTS['id' .. menu_id] = nil
                api_sp(menu_id, "output_zoid", "")
                api_slot_clear(menu_id, 3)
            else
                INSERTER_OUTPUTS['id' .. menu_id] = output_inst[1].id
            end
        end
        if get_input(menu_id) ~= nil and get_output(menu_id) ~= nil then
            api_sp(inserters[i], "working", 1)
        end

    end
end

function inserter_split(inputstr, sep)
    if sep == nil then sep = "%s" end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function inserter_get_zoid(inst_id)
    if inst_id == nil or inst_id == "" then return "" end
    return api_gp(inst_id, 'oid') .. '-' .. math.floor(api_gp(inst_id, 'x')) ..
               '-' .. math.floor(api_gp(inst_id, 'y'))
end

function inserter_draw_world()
    if INSERTER_CURRENT_MENU ~= nil then
        local cam = api_get_camera_position()
        local menu_id = INSERTER_CURRENT_MENU
        local menu = api_get_inst(menu_id)
        local color = ""
        local message = ""
        if INSERTER_SELECT_MODE == "INPUT_MENU" then
            color = "FONT_BLUE"
            message = "Click an object to input from..."
        elseif INSERTER_SELECT_MODE == "OUTPUT_MENU" then
            color = "FONT_ORANGE"
            message = "Click an object to output into..."
        end
        local obj_id = api_get_menus_obj(menu_id)
        local obj = api_get_inst(obj_id)
        if message ~= "" and color ~= "" then
            api_draw_text(menu.x - cam.x + 5,
                        menu.y + INSERTER_MENU_HEIGHT + 5 - cam.y, message, true,
                        color, INSERTER_MENU_WIDTH)
        end
        api_draw_circle(obj.x - cam.x + 7, obj.y - cam.y + 7, INSERTER_RANGE,
                        color, true)
        local machines = api_get_inst_in_circle("menu_obj", obj.x + 7,
                                                obj.y + 7, INSERTER_RANGE - 2)
        -- api_log('machines', machines)
        for i = 1, #machines do
            if machines[i].id ~= obj_id then
                local spr = api_get_sprite(machines[i].oid)
                api_draw_sprite_ext(spr, 0, machines[i].x - cam.x,
                                    machines[i].y - cam.y, 1, 1, 0, color, 1)
            end
        end

    else
        local highlight = api_get_highlighted("menu_obj")
        if highlight ~= nil then

            local oid = api_gp(highlight, 'oid')
            if oid ~= FULL_INSERTER_ID then return end
            local menu_id = api_gp(highlight, 'menu')
            local cam = api_get_camera_position()
            local input_zoid = get_input(menu_id)
            if input_zoid ~= nil then
                local oid = api_gp(input_zoid, "oid")
                if oid ~= nil then
                    local spr = api_get_sprite(oid)
                    -- api_log('sprite4', spr)
                    if spr >= 0 then
                        api_draw_sprite_ext(spr, 0,
                                            api_gp(input_zoid, "x") - cam.x,
                                            api_gp(input_zoid, "y") - cam.y, 1,
                                            1, 0, "FONT_BLUE", 1)
                    end
                end
            end

            local output_zoid = get_output(menu_id)
            if output_zoid ~= nil then
                color = "FONT_ORANGE"
                if input_zoid == output_zoid then
                    color = "PURPLE"
                end -- purple if same input and output
                local oid = api_gp(output_zoid, "oid")
                if oid ~= nil then
                    local spr = api_get_sprite(oid)
                    -- api_log('sprite3', spr)
                    if spr >= 0 then
                        api_draw_sprite_ext(spr, 0,
                                            api_gp(output_zoid, "x") - cam.x,
                                            api_gp(output_zoid, "y") - cam.y, 1,
                                            1, 0, color, 1)
                    end
                end
            end
        else
            highlight = api_get_highlighted("slot")
            if highlight == nil then return end

            local menu_id = api_gp(highlight, 'menu')
            local oid = api_gp(menu_id, 'oid')
            if oid ~= FULL_INSERTER_ID then return end

            local index = api_gp(highlight, 'index')
            local cam = api_get_camera_position()
            if index == 0 then
                -- local input_zoid = get_input(menu_id)
                -- if input_zoid ~= nil then
                --     local oid = api_gp(input_zoid, "oid")
                --     if oid ~= nil then
                --         local spr = api_get_sprite(oid)
                --         api_log('sprite2', spr)
                --         if spr >= 0 then
                --             api_draw_sprite_ext(spr, 0,
                --                                 api_gp(input_zoid, "x") - cam.x,
                --                                 api_gp(input_zoid, "y") - cam.y,
                --                                 1, 1, 0, "FONT_BLUE", 1)
                --         end
                --     end
                -- end
            elseif index == 2 then
                -- local output_zoid = get_output(menu_id)
                -- if output_zoid ~= nil then
                --     color = "FONT_ORANGE"
                --     local oid = api_gp(output_zoid, "oid")
                --     if oid ~= nil then
                --         local spr = api_get_sprite(oid)
                --         api_log('sprite1', spr)
                --         if spr >= 0 then
                --             api_draw_sprite_ext(spr, 0,
                --                                 api_gp(output_zoid, "x") - cam.x,
                --                                 api_gp(output_zoid, "y") - cam.y,
                --                                 1, 1, 0, color, 1)
                --         end
                --     end
                -- end
            end
        end
    end
end

function get_input(menu_id)
    -- api_log('get input', menu_id)
    if menu_id == nil then return end
    local input_id = INSERTER_INPUTS['id' .. menu_id]
    if input_id == nil then return nil end
    if api_inst_exists(input_id) == 1 then
        return input_id
    else
        INSERTER_INPUTS['id' .. menu_id] = nil
        api_slot_clear(api_get_slot(menu_id, 1).id)
        api_sp(menu_id, 'input_zoid', "")
        return nil
    end
end

function get_output(menu_id)
    local output_id = INSERTER_OUTPUTS['id' .. menu_id]
    if output_id == nil then return nil end
    -- api_log('output', {output_id = output_id, exists = api_inst_exists(output_id)})
    if api_inst_exists(output_id) == 1 then
        return output_id
    else
        INSERTER_OUTPUTS['id' .. menu_id] = nil
        api_slot_clear(api_get_slot(menu_id, 3).id)
        api_sp(menu_id, 'output_zoid', "")
        return nil
    end
end

function inserter_start_selection(button, menu_id, mode, slot_id)
    if button == "LEFT" then
        INSERTER_CURRENT_MENU = menu_id
        INSERTER_SELECT_MODE = mode
    else
        INSERTER_CURRENT_MENU = nil
        INSERTER_SELECT_MODE = nil
        api_slot_clear(slot_id)
        if mode == "INPUT_MENU" then
            local old_menu = get_input(menu_id)
            if old_menu ~= nil then api_set_immortal(old_menu, false) end

            INSERTER_INPUTS['id' .. menu_id] = nil
            api_sp(menu_id, "input_zoid", "")
        elseif mode == "OUTPUT_MENU" then
            local old_menu = get_output(menu_id)
            if old_menu ~= nil then api_set_immortal(old_menu, false) end

            INSERTER_OUTPUTS['id' .. menu_id] = nil
            api_sp(menu_id, "output_zoid", "")
        end
    end
end

function inserter_set_filter(menu_id, slot_id)
    local mouse = api_get_mouse_inst()
    local item_id = mouse.item

    if string.find(item_id, "bee") then return end -- TODO: bee, frame, canister support

    if (item_id == "") then
        api_sp(menu_id, "filter", {"ANY"})
        api_sp(menu_id, "filter_stats", false)
        api_sp(menu_id, "working", 1)
        api_sp(menu_id, "p_start", 0)
        api_slot_clear(slot_id)
    else
        api_sp(menu_id, "filter", {item_id})
        api_slot_set(slot_id, item_id, 0, mouse.stats)
        api_sp(menu_id, "working", 1)
        -- some items have stats that are important
        if string.find(item_id, "bee") then api_sp(menu_id, "filter_stats", "bee")
        elseif string.find(item_id, "butterfly") then api_sp(menu_id, "filter_stats", "butterfly")
        elseif string.find(item_id, "caterpillar") then api_sp(menu_id, "filter_stats", "caterpillar")
        elseif string.find(item_id, "eggs") then api_sp(menu_id, "filter_stats", "eggs")
        elseif string.find(item_id, "frame") then api_sp(menu_id, "filter_stats", "frame")
        elseif string.find(item_id, "canister") then api_sp(menu_id, "filter_stats", "canister")
        else api_sp(menu_id, "filter_stats", false)
        end
    end
end

