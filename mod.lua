MOD_NAME = "storage_drawer"
EMPTY_SPRITE = nil
MAX_STACK = 999

function register()
    return {
        name = MOD_NAME,
        hooks = {"destroy", "click"},
        modules = {"drawer"}
    }
end

function init()
    EMPTY_SPRITE = api_get_sprite("zzzzz_zzzzz")
    drawer_check = init_drawer()

    -- TODO: REMOVE
    api_set_devmode(true)

    if drawer_check == "Success" then
        return "Success"
    end
end

function destroy(id, x, y, oid, fields)
    api_log("destroy", { id=id, x=x, y=y, oid=oid, fields=fields, FULL_DRAWER_ID=FULL_DRAWER_ID })
    state = api_game_state()
    if state.game_loading then return end

    if oid == FULL_DRAWER_ID then
        destroy_drawer(id, x, y, oid, fields)
    end
end

function click(button, click_type)
    if click_type ~= "PRESSED" then return end
    click_drawer(button, click_type)
end
