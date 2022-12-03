-- TODO: 
-- test immortals are getting set/unset properly
-- try and match slot validation??
INSERTER_ID = "inserter"
FULL_INSERTER_ID = "storage_drawer_inserter"

INSERTER_TIMER = 3 --TODO: change

INSERTER_CURRENT_MENU = nil
INSERTER_SELECT_MODE = nil

INSERTER_INPUTS = {}
INSERTER_OUTPUTS = {}

INSERTER_MENU_WIDTH = 97
INSERTER_MENU_HEIGHT = 40

INSERTER_RANGE = 20
-- CRAFTER_SEARCH = {"ANY"}
-- CRAFTER_SLOTS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}

-- CRAFTER_PROGRESS_SIZE = 45
-- CRAFTER_PROGRESS_OFFSET = 1
-- CRAFTER_PROGRESS_HEIGHT = 10

-- CRAFTER_INPUT_SLOTS = {1,2,3,4,5,6}
-- CRAFTER_OUTPUT_SLOTS = {7,8,9,10,11,12}
-- CRAFTER_RECIPE_SLOT = 19

-- CRAFTER_RECIPES = {}

-- ac_title_sprite = nil
-- ac_recipe_tooltip_sprite = nil

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
        info = {{"1. Items to Sell", "FONT_BGREY"}}, -- TODO: change
        tools = {"mouse1", "hammer1"},
        placeable = true
    }, "sprites/inserter/item.png", "sprites/inserter/menu.png", {
        define = "on_inserter_define",
        tick = "inserter_tick",
        draw = "inserter_draw"
    })

    local recipe = {
        {item = "crate2", amount = 1}, {item = "cog", amount = 5} -- TODO: change
    }
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

    local slots = api_get_slots(menu_id) -- all slots are modded
    api_slot_set_modded(slots[1].id, true)
    api_slot_set_modded(slots[2].id, true)
    api_slot_set_modded(slots[3].id, true)

    api_dp(menu_id, "input_zoid", "")
    api_dp(menu_id, "output_zoid", "")
    -- api_dp(menu_id, "input_id", "")
    -- api_dp(menu_id, "output_id", "")
    api_dp(menu_id, "filter", "ANY")

    local fields = {"input_zoid", "output_zoid", "filter", "p_start", "p_end"}
    api_sp(menu_id, "_fields", fields)
end

function click_inserter(button, click_type)
    inserter_handle_selection(button, click_type)
    -- api_log('click', {button=button,click_type=click_type})
    local menu_id = api_get_highlighted("menu")
    if (menu_id ~= nil and api_gp(menu_id, "oid") == FULL_INSERTER_ID) then
        -- api_log('click', "match")
        local mouse = api_get_mouse_inst()
        local slot_id = api_get_highlighted("slot")
        -- api_log('slot', {slot=slot, slot_index = api_gp(slot, "index"), right_slot = CRAFTER_RECIPE_SLOT})
        if (slot_id ~= nil) then
            slot_inst = api_get_slot_inst(slot_id)
            if slot_inst.index == 2 then
                -- api_log('click', "right slot")
                local item_id = mouse.item
                -- api_log('click', {mouse = item_id})

                -- api_log("click()", "Gather: " .. item_id)
                if (item_id == "") then
                  api_sp(menu_id, "filter", "ANY")
                  api_sp(menu_id, "working", 1)
                  api_sp(menu_id, "p_start", 0)
                  api_slot_clear(slot_id)
                else
                  api_sp(menu_id, "filter", item_id)
                  api_slot_set(slot_id, item_id, 0) --TODO: fix
                  api_sp(menu_id, "working", 1)
                end
              elseif slot_inst.index == 1 then
                if button == "LEFT" then
                  INSERTER_CURRENT_MENU = menu_id
                  INSERTER_SELECT_MODE = "INPUT"
                else
                  INSERTER_CURRENT_MENU = nil
                  INSERTER_SELECT_MODE = nil
                  api_slot_clear(slot_id)
                  -- api_log("y","1")
                  local old_menu = INSERTER_INPUTS['id'..menu_id]
                  if old_menu ~= nil then api_set_immortal(old_menu, false) end
                  -- api_log("y","2")
                  INSERTER_INPUTS['id'..menu_id] = nil
                  api_sp(menu_id, "input_zoid", "")
                  --TODO: clear slot and data, set menu not immortal etc
                end
              elseif slot_inst.index == 3 then
                if button == "LEFT" then
                    INSERTER_CURRENT_MENU = menu_id
                    INSERTER_SELECT_MODE = "OUTPUT"
                  else
                    INSERTER_CURRENT_MENU = nil
                    INSERTER_SELECT_MODE = nil
                    api_slot_clear(slot_id)
                    -- api_log("y","3")
                    local old_menu = INSERTER_OUTPUTS['id'..menu_id]
                    if old_menu ~= nil then api_set_immortal(old_menu, false) end
                    -- api_log("y","4")
                    INSERTER_OUTPUTS['id'..menu_id] = nil
                    api_sp(menu_id, "output_zoid", "")
                    --TODO: clear slot and data, set menu not immortal etc
                  end
            end
        end
    end
end

function inserter_tick(menu_id)
  -- api_log('inserter tick', {
  --   menu_id = menu_id, 
  --   p_start = api_gp(menu_id, "p_start"), 
  --   p_end = api_gp(menu_id, "p_end"), 
  --   working = api_gp(menu_id, "working"),
  --   input = INSERTER_INPUTS[menu_id],
  --   output = INSERTER_OUTPUTS[menu_id],
  -- })
  if api_gp(menu_id, "working") ~= 1 then return end
  
  local input = INSERTER_INPUTS['id'..menu_id]

  local output = INSERTER_OUTPUTS['id'..menu_id]
  
  -- api_log('tick', INSERTER_INPUTS)
  -- api_log('tick', INSERTER_OUTPUTS)
  if input == nil or output == nil then return end
  local input_menu = api_gp(input, "menu")
  local output_menu = api_gp(output, "menu")
  api_sp(menu_id, "p_start", api_gp(menu_id, "p_start") + 0.1)
  
  if api_gp(menu_id, "p_start") >= api_gp(menu_id, "p_end") then
    -- api_log('process inserter', {menu_id = menu_id, output_menu = output_menu, input_menu = input_menu})
    api_sp(menu_id, "p_start", 0)
    local filter = api_gp(menu_id, "filter")
    -- craft item
   
   local search = {(filter or "ANY")}
   local slots = api_slot_match(input_menu, search, false)
   local slot = get_first_valid_slot(slots)

   if slot ~= nil then
    api_add_slot_to_menu(slot.id, output_menu)
    --if api_gp(output, "oid") == FULL_FLOWER_BOX_ID then
        local script = api_gp(output_menu, "script_change")
        if script ~= nil then
        api_mod_call("storage_drawer", script, {output_menu}) --TODO: all mods
    --local change_script = api_gp(output_menu, "script_change")
    --script_change
    end
   end
    end
end

function get_first_valid_slot(slots) --basically filters out modded slots
  for i=1,#slots do
    if api_gp(slots[i].id, "modded") == false then return slots[i] end
  end
end

function inserter_draw(menu_id)
    local cam = api_get_cam()
    -- local gui = api_get_inst(api_gp(menu_id, "crafter_progress"))
    -- local menu = api_get_inst(menu_id)

    -- local highlighted = api_get_highlighted("menu")
    -- if highlighted == menu_id then
    --     api_draw_sprite(ac_title_sprite, 1, 2 + menu.x - cam.x,
    --                     2 + menu.y - cam.y)
    -- else
    --     api_draw_sprite(ac_title_sprite, 0, 2 + menu.x - cam.x,
    --                     2 + menu.y - cam.y)
    -- end

    -- local mouse_pos = api_get_mouse_position()
    
    local input_zoid = INSERTER_INPUTS['id'..menu_id]
    if input_zoid ~= nil then
        local spr = api_get_sprite(api_gp(input_zoid, "oid"))
        api_draw_sprite_ext(spr, 0, api_gp(input_zoid, "x") - cam.x, api_gp(input_zoid, "y") - cam.y, 1, 1, 0, "FONT_BLUE", 1)
    end

    local output_zoid = INSERTER_OUTPUTS['id'..menu_id]
    if output_zoid ~= nil then
        color = "FONT_ORANGE"
        if input_zoid == output_zoid then color = "PURPLE" end --purple if same input and output
        local spr = api_get_sprite(api_gp(output_zoid, "oid"))
        api_draw_sprite_ext(spr, 0, api_gp(output_zoid, "x") - cam.x, api_gp(output_zoid, "y") - cam.y, 1, 1, 0, color, 1)
    end
    --TODO: draw underneath menu?? TODO: add message tooltip for clicking on menu
    if INSERTER_CURRENT_MENU == menu_id then
        local menu = api_get_inst(menu_id)
        local color = "FONT_BLUE"
        local message = "Click an object to input from..."
        if INSERTER_SELECT_MODE == "OUTPUT" then color = "FONT_ORANGE" message = "Click an object to output into..." end
        local obj_id = api_get_menus_obj(menu_id)
        local obj = api_get_inst(obj_id)
        api_draw_text(menu.x - cam.x + 5, menu.y + INSERTER_MENU_HEIGHT + 5 - cam.y, message, true, color, INSERTER_MENU_WIDTH)
        api_draw_circle(obj.x - cam.x + 7, obj.y - cam.y + 7, INSERTER_RANGE, color, true)
        local machines = api_get_inst_in_circle("menu_obj", obj.x + 7, obj.y + 7, INSERTER_RANGE - 2)
        --api_log('machines', machines)
        for i=1,#machines do
        if machines[i].id ~= obj_id then
            local spr = api_get_sprite(machines[i].oid)
            api_draw_sprite_ext(spr, 0, machines[i].x - cam.x, machines[i].y - cam.y, 1, 1, 0, color, 1)
        end
        end
    end
end

function init_inserter()
    -- ac_title_sprite = api_define_sprite(MOD_NAME .. "_auto_crafter_title",
    --                                     "sprites/auto_crafter/title.png", 2)
    -- ac_recipe_tooltip_sprite = api_define_sprite(MOD_NAME ..
    --                                                  "_auto_crafter_tooltip",
    --                                              "sprites/auto_crafter/tooltip.png",
    --                                              1)
    api_define_color("PURPLE", {r=101,g=66,b=178})
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
--   zoid = api_get_zoid_from_inst(highlight)
--   api_log('clicked zoid is: ', zoid)
  local inserter_id = api_get_menus_obj(INSERTER_CURRENT_MENU)
  local inserter = api_get_inst(inserter_id)
  local nearby_machines = api_get_inst_in_circle("menu_obj", inserter.x + 7, inserter.y + 7, INSERTER_RANGE - 2)

  local in_range = false
  for i=1,#nearby_machines do
    if nearby_machines[i].id == highlight then
        in_range = true
    end
  end

  if in_range == false then return end
  
  if INSERTER_SELECT_MODE == "INPUT" then
    local old_menu = INSERTER_INPUTS['id'..INSERTER_CURRENT_MENU]
    if old_menu ~= nil then api_set_immortal(old_menu, false) end
    INSERTER_INPUTS['id'..INSERTER_CURRENT_MENU] = highlight
    api_sp(INSERTER_CURRENT_MENU, "input_zoid", inserter_get_zoid(highlight))
    api_slot_set(api_get_slot(INSERTER_CURRENT_MENU, 1).id, api_gp(highlight, "oid"), 0) --TODO: fix
    api_set_immortal(highlight, true)
    api_toggle_menu(api_gp(highlight, "menu"), "close")
  elseif INSERTER_SELECT_MODE == "OUTPUT" then
    local old_menu = INSERTER_OUTPUTS['id'..INSERTER_CURRENT_MENU]
    if old_menu ~= nil then api_set_immortal(old_menu, false) end
    INSERTER_OUTPUTS['id'..INSERTER_CURRENT_MENU] = highlight
    api_sp(INSERTER_CURRENT_MENU, "output_zoid", inserter_get_zoid(highlight))
    api_slot_set(api_get_slot(INSERTER_CURRENT_MENU, 3).id, api_gp(highlight, "oid"), 0) --TODO: fix
    api_set_immortal(highlight, true)
    api_toggle_menu(api_gp(highlight, "menu"), "close")
  end
  INSERTER_CURRENT_MENU = nil
  INSERTER_SELECT_MODE = nil
end

function inserter_ready()
    -- api_log('ready', 'ready')
  local inserters = api_all_menu_objects(FULL_INSERTER_ID)
  -- api_log('ready', {inserters = inserters})
  for i=1,#inserters do
    local menu_id = api_gp(inserters[i], "menu")
    local input_zoid = api_gp(menu_id, "input_zoid")
    -- api_log('ready', {input_zoid = input_zoid})
    if input_zoid ~= "" then
      local zoid = inserter_split(input_zoid, "-")
      local input_inst = api_get_menu_objects(5, zoid[1], {x = math.floor(zoid[2]), y = math.floor(zoid[3])})
      -- api_log('ready', {input_inst = input_inst})
      if #input_inst ~= 1 then
        INSERTER_INPUTS['id'..menu_id] = nil
        -- api_log("ready", "Did not find match")
        api_sp(menu_id, "input_zoid", "")
        api_slot_clear(menu_id, 1)
      else
        -- api_log("ready", "Found match")
        INSERTER_INPUTS['id'..menu_id] = input_inst[1].id
      end
    end
    local output_zoid = api_gp(menu_id, "output_zoid")
    -- api_log('ready', {output_zoid = output_zoid})
    if output_zoid ~= "" then
        local zoid = inserter_split(output_zoid, "-")
        local output_inst = api_get_menu_objects(5, zoid[1], {x = math.floor(zoid[2]), y = math.floor(zoid[3])})
        -- api_log('ready', {output_inst = output_inst})
        if #output_inst ~= 1 then
          api_log("ready", "Did not find match")
          INSERTER_OUTPUTS['id'..menu_id] = nil
          api_sp(menu_id, "output_zoid", "")
          api_slot_clear(menu_id, 3)
        else
          -- api_log("ready", "Found match")
          INSERTER_OUTPUTS['id'..menu_id] = output_inst[1].id
        end
      end
    if INSERTER_INPUTS['id'..menu_id] ~= nil and INSERTER_OUTPUTS['id'..menu_id] ~= nil then
      api_sp(inserters[i], "working", 1)
    end
  
    end
end

function inserter_split(inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

function inserter_get_zoid(inst_id)
  if inst_id == nil or inst_id == "" then return "" end
  return api_gp(inst_id, 'oid')..'-'..math.floor(api_gp(inst_id, 'x'))..'-'..math.floor(api_gp(inst_id, 'y'))
end