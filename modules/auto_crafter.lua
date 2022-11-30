--TODO: 
-- -Error messages
-- -Honeycore?
-- - get colors from game files
CRAFTER_ID = "auto_crafter"
FULL_CRAFTER_ID = "storage_drawer_auto_crafter"

CRAFTER_TIMER = 3 --TODO: change
CRAFTER_SEARCH = {"ANY"}
CRAFTER_SLOTS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}

CRAFTER_PROGRESS_SIZE = 45
CRAFTER_PROGRESS_OFFSET = 1
CRAFTER_PROGRESS_HEIGHT = 10

CRAFTER_INPUT_SLOTS = {1,2,3,4,5,6}
CRAFTER_OUTPUT_SLOTS = {7,8,9,10,11,12}
CRAFTER_RECIPE_SLOT = 19

CRAFTER_RECIPES = {}

ac_title_sprite = nil
ac_recipe_tooltip_sprite = nil

function define_crafter()
    local define_obj = api_define_menu_object2({
        id = CRAFTER_ID,
        name = "Auto-Crafter",
        category = "Crafting",
        tooltip = "Craft your items automatically",
        layout = {
            {7, 17}, {7, 40}, {7, 63}, -- input ingredients
            {30, 17}, {30, 40}, {30, 63},
            {99, 17, "Output"}, {99, 40, "Output"}, {99, 63, "Output"}, -- output products
            {122, 17, "Output"}, {122, 40, "Output"}, {122, 63, "Output"},
            {7, 89}, {30, 89}, {53, 89}, {76, 89},{99, 89}, {122, 89}, -- extra space
            {65, 35, "Output"} -- recipe picker
        },
        buttons = {"Help", "Target", "Close"},
        info = {{"1. Items to Sell", "FONT_BGREY"}}, --TODO: change
        tools = {"mouse1", "hammer1"},
        placeable = true
    }, "sprites/auto_crafter/item.png", "sprites/auto_crafter/menu.png", {
        define = "on_crafter_define",
        change = "crafter_change",
        tick = "crafter_tick",
        draw = "crafter_draw"
    })

    local recipe = {
        {item = "workbench", amount = 1}, {item = "cog", amount = 5} --TODO change
    }
    local define_recipe = api_define_recipe("crafting", FULL_CRAFTER_ID, recipe, 1)

    if define_obj == "Success" and define_recipe == "Success" then
        return "Success"
    end
    return nil
end

function on_crafter_define(menu_id)
    api_dp(menu_id, "working", false)
    api_dp(menu_id, "p_start", 0)
    api_dp(menu_id, "p_end", CRAFTER_TIMER)

    api_define_gui(menu_id, "crafter_progress", 49, 20, "crafter_tooltip",
                   "sprites/auto_crafter/progress_bar.png")
    api_dp(menu_id, "progress_bar",
           api_get_sprite("storage_drawer_crafter_progress"))
    
    local slots = api_get_slots(menu_id)
    api_slot_set_modded(slots[CRAFTER_RECIPE_SLOT].id, true)
    
    api_dp(menu_id, "recipe", recipe)

    fields = {"p_start", "p_end", "recipe"}
    fields = api_sp(menu_id, "_fields", fields)
end

function crafter_tooltip(menu_id)
    if api_gp(menu_id, "working") ~= true then return end
    local time_left = math.ceil(api_gp(menu_id, "p_end") -
                                     api_gp(menu_id, "p_start"))

    return {{"Crafting Item", "FONT_WHITE"}, {time_left .. "s left", "FONT_BGREY"}}
end

function crafter_change(menu_id)
    local has_ingredients = crafter_has_ingredients(menu_id)
    --api_log('change_result', tostring(has_ingredients))
    if has_ingredients == true then
      api_sp(menu_id, "working", true)  
    else
      api_sp(menu_id, "working", false)
      api_sp(menu_id, "p_start", 0)
    end
end

function crafter_has_ingredients(menu_id)
  local recipe = api_gp(menu_id, "recipe")
  --api_log('recipe', recipe)
  if recipe == nil then return false end
  
  local slots = api_get_slots(menu_id)
  -- count items in input slots
  local items = {}
  for i=1,#CRAFTER_INPUT_SLOTS do
    local slot = slots[CRAFTER_INPUT_SLOTS[i]]
    --api_log('slot', slot)
    if slot.item ~= "" then
      if items[slot.item] ~= nil then
        items[slot.item] = items[slot.item] + slot.count
      else 
        items[slot.item] = slot.count
      end
    end
  end
  --api_log('items', items)
  --check if enough ingredients are all there for recipe
  local valid = true
  for i=1,#recipe.recipe do
    local input_amount = items[recipe.recipe[i].item]
    --api_log('input', {recipe_item = recipe.recipe[i].item, input_amount = items[recipe.recipe[i].item], recipe_amount = recipe.recipe[i].amount})
    if input_amount ~= nil and input_amount >= recipe.recipe[i].amount then
      items[recipe.recipe[i].item] = input_amount - recipe.recipe[i].amount
    else
      valid = false
    end
  end

  return valid
end

function click_crafter(button, click_type)
  -- api_log('click', {button=button,click_type=click_type})
  local menu_id = api_get_highlighted("menu")
  if (menu_id ~= nil and api_gp(menu_id, "oid") == FULL_CRAFTER_ID) then
    -- api_log('click', "match")
    local mouse = api_get_mouse_inst()
    local slot_id = api_get_highlighted("slot")
    -- api_log('slot', {slot=slot, slot_index = api_gp(slot, "index"), right_slot = CRAFTER_RECIPE_SLOT})
    if (slot_id ~= nil) then
      slot_inst = api_get_slot_inst(slot_id)
      if slot_inst.index == CRAFTER_RECIPE_SLOT then
      -- api_log('click', "right slot")
      local item_id = mouse.item
      -- api_log('click', {mouse = item_id})

      --api_log("click()", "Gather: " .. item_id)
      if (item_id == "") then
        api_sp(menu_id, "recipe", nil)
        api_sp(menu_id, "working", false)
        api_sp(menu_id, "p_start", 0)
        api_slot_clear(slot_id)
      else
        local recipe = CRAFTER_RECIPES[item_id]
        if recipe ~= nil then
          -- api_log('recipe', CRAFTER_RECIPES[item_id])
          api_sp(menu_id, "recipe", recipe)
          api_slot_set(slot_id, item_id, recipe.total or 1)
          api_sp(menu_id, "p_start", 0)
        end
      end
    end
    end
  end
end
function crafter_tick(menu_id)
    if api_gp(menu_id, "working") ~= true then return end

    local has_ingredients = crafter_has_ingredients(menu_id)
    if has_ingredients == false then
        api_sp(menu_id, "working", false)
        api_sp(menu_id, "p_start", 0)
    else
        api_sp(menu_id, "p_start", api_gp(menu_id, "p_start") + 0.1)
        if api_gp(menu_id, "p_start") >= api_gp(menu_id, "p_end") then
            api_sp(menu_id, "p_start", 0)

            -- craft item
            local result = crafter_use_items(menu_id)
            if result == false then
              api_sp(menu_id, "working", false)
              api_sp(menu_id, "p_start", 0)
            end
        end
    end
end

function crafter_draw(menu_id)
    local cam = api_get_cam()
    local gui = api_get_inst(api_gp(menu_id, "crafter_progress"))
    local menu = api_get_inst(menu_id)

    local highlighted = api_get_highlighted("menu")
    if highlighted == menu_id then
        api_draw_sprite(ac_title_sprite, 1, 2 + menu.x - cam.x,
                        2 + menu.y - cam.y)
    else
        api_draw_sprite(ac_title_sprite, 0, 2 + menu.x - cam.x,
                        2 + menu.y - cam.y)
    end

    local progress_sprite = api_gp(menu_id, "progress_bar")
    
    local mouse_pos = api_get_mouse_position()
    local gx = gui.x - cam.x
    local gy = gui.y - cam.y
    local progress = (api_gp(menu_id, "p_start") / api_gp(menu_id, "p_end") *
                         CRAFTER_PROGRESS_SIZE)
    api_draw_sprite_part(progress_sprite, 2, 0, 0, progress,
                          CRAFTER_PROGRESS_HEIGHT, gx, gy)
    api_draw_sprite(progress_sprite, 1, gx, gy) -- bar background

    if api_get_highlighted("ui") == gui.id and api_gp(menu_id, "working") ==
        true then
        api_draw_sprite(progress_sprite, 0, gx, gy) -- highlighted bar
    end
    
    local slot_id = api_get_highlighted("slot")
    -- api_log('slot', {slot=slot, slot_index = api_gp(slot, "index"), right_slot = CRAFTER_RECIPE_SLOT})
    if (slot_id ~= nil) then
      slot_inst = api_get_slot_inst(slot_id)
      --api_log("yeey", {index = slot_inst.index, craft = CRAFTER_RECIPE_SLOT, item = slot_inst.item})
      if slot_inst.index == CRAFTER_RECIPE_SLOT and slot_inst.item ~= "" then
        local recipe = api_gp(menu_id, "recipe")    
        api_draw_sprite(ac_recipe_tooltip_sprite, 0, mouse_pos.x + 8 - cam.x, mouse_pos.y + 8 - cam.y)
        local offset = 0
        for i=1,#recipe.recipe do
          local ingredient = recipe.recipe[i]
          if ingredient.item then
            local spr = api_get_sprite(ingredient.item .. "_item")
            if spr == EMPTY_SPRITE then spr = api_get_sprite(ingredient.item) end
            api_draw_sprite(spr, 0, mouse_pos.x + 15 - cam.x + offset, mouse_pos.y + 15 - cam.y)
            api_draw_number(mouse_pos.x + 34 - cam.x + offset, mouse_pos.y + 34 - cam.y, ingredient.amount)
            offset = offset + 31
          end
        end
      end
    end


end

function init_crafter()
    ac_title_sprite = api_define_sprite(MOD_NAME .. "_auto_crafter_title",
                                        "sprites/auto_crafter/title.png", 2)
    ac_recipe_tooltip_sprite = api_define_sprite(MOD_NAME .. "_auto_crafter_tooltip", "sprites/auto_crafter/tooltip.png", 1)
    return define_crafter()
end

function crafter_use_items(menu_id)
  local recipe = api_gp(menu_id, "recipe")
  --api_log('recipe', recipe)
  if recipe == nil then return false end
  
  local decr_amts = {}
  for i=1,#CRAFTER_INPUT_SLOTS do
    decr_amts[i] = 0
  end
  local slots = api_get_slots(menu_id)
  
  -- check input slots for recipe ingredients, and also calculate amounts to subtract from each slot
  local valid = true
  for i=1,#recipe.recipe do
    local recipe_ingredient = recipe.recipe[i].item
    local recipe_amount = recipe.recipe[i].amount
    local slot_index = 1
    while recipe_amount > 0 do
      if slot_index > #CRAFTER_INPUT_SLOTS then return false end
      local slot = slots[CRAFTER_INPUT_SLOTS[slot_index]]
      if slot.item == recipe_ingredient then
        local amount = math.min(recipe_amount, slot.count)
        decr_amts[slot_index] = decr_amts[slot_index] + amount
        recipe_amount = recipe_amount - amount
      end
      slot_index = slot_index + 1
    end
  end
  
  
  local search = {recipe.item, ""}
  if api_get_definition(recipe.item).singular then
    search = {""}
  end

  local matched_slots = api_slot_match_range(menu_id, search, CRAFTER_OUTPUT_SLOTS)
  local incr_amts = {}
  for i=1,#matched_slots do
    incr_amts[i] = 0
  end
  -- find output slot
  local total = 1
  local slot_index = 1
  if recipe.total ~= nil then
    total = recipe.total
  end
  
  while total > 0 do
    if slot_index > #matched_slots then return false end
    local slot = matched_slots[slot_index]
    if slot.count < 99 then
      local amount = math.min(total, 99 - slot.count)
      incr_amts[slot_index] = incr_amts[slot_index] + amount
      total = total - amount
    end
    slot_index = slot_index + 1
  end 
  
  for i=1,#CRAFTER_INPUT_SLOTS do
    if decr_amts[i] > 0 then
      api_slot_decr(slots[CRAFTER_INPUT_SLOTS[i]].id, decr_amts[i])
    end
  end

  for i=1,#matched_slots do
    if incr_amts[i] > 0 then
    if matched_slots[i].item == "" then
     api_slot_set(matched_slots[i].id, recipe.item, incr_amts[i])
    else
      api_slot_incr(matched_slots[i].id, incr_amts[i])
    end
  end
  end

  return true
end

function crafter_load_recipes()
  local base_recipes = api_describe_recipes(false)
  local mod_recipes = api_describe_recipes(true)
  
  for tab,recipes in pairs(base_recipes) do
    for i=1,#recipes do
        if type(recipes[i]) == "table" then
          local item = recipes[i]["item"]
          CRAFTER_RECIPES[item] = recipes[i]
        end
    end
  end
  for mod,recipe_groups in pairs(mod_recipes) do
    for tab,recipes in pairs(recipe_groups) do
      for i=1,#recipes do
          if type(recipes[i]) == "table" then
            local item = recipes[i]["item"]
            CRAFTER_RECIPES[item] = recipes[i]
          end
      end
    end
  end
end

function crafter_ready()
  crafter_load_recipes()
end
