local test_directory = arg[0]:match("^(.*)[/\\]") or "."
local Runner = dofile(test_directory .. "/orbit_test_runner.lua")
local headless = arg[4] == "--headless"
assert(#arg == 3 or (headless and #arg == 4), "Usage: lua test/run_fork_repros.lua FACTORIO DATA AUDIT_REPROS [--headless]")
local executable, data, saves = Runner.absolute(arg[1]), Runner.absolute(arg[2]), Runner.absolute(arg[3])
local root = Runner.absolute(test_directory .. "/..")
local work = Runner.create(root, data)
local mod = work .. "/mods/helmod-fork"
Runner.write(work .. "/mods/mod-list.json", [[{"mods":[{"name":"base","enabled":true},{"name":"space-age","enabled":true},{"name":"quality","enabled":true},{"name":"elevated-rails","enabled":true},{"name":"recycler","enabled":true},{"name":"helmod-fork","enabled":true}]}]])
Runner.copy(root .. "/test/test_fork_repros.lua", mod .. "/test_fork_repros.lua")
Runner.copy(root .. "/test/test_consumer_controls.lua", mod .. "/test_consumer_controls.lua")
local control = Runner.read(mod .. "/control.lua")
for _, case in ipairs({"row-removal-scroll", "consumer-controls", "empty-explorer", "custom-recipe-quality", "custom-recipe-categories",
                       "blank-selector-rule", "truncated-import", "empty-blueprint-book", "quantity-after-reload", "quantity-confirm"}) do
    Runner.write(mod .. "/control.lua", control .. '\nrequire "test_fork_repros"("' .. case .. '")\n')
    local save = saves .. "/" .. case .. "/repro.zip"
    if case == "consumer-controls" or case == "row-removal-scroll" then save = saves .. "/empty-explorer/repro.zip" end
    local log
    if case == "quantity-after-reload" then
        if headless then
            local settings = work .. "/server-settings.json"
            local template = Runner.read(data .. "/server-settings.example.json")
            for _, setting in ipairs({"public", "lan", "require_user_verification", "auto_pause"}) do
                template = template:gsub('("' .. setting .. '"%s*:%s*)true', '%1false')
            end
            Runner.write(settings, template)
            Runner.directory(work .. "/write/saves")
            Runner.copy(save, work .. "/source.zip")
            log = Runner.factorio(executable, work, {"--start-server", work .. "/source.zip", "--bind", "127.0.0.1",
                "--port", "0", "--server-settings", settings}, true)
        else
            log = Runner.factorio(executable, work, {"--load-game", save, "--disable-audio"}, true)
        end
    else
        if case == "quantity-confirm" then
            save = work .. "/write/saves/_autosave-fork-quantity.zip"
            if headless then save = work .. "/write/saves/fork-quantity.zip" end
        end
        log = Runner.factorio(executable, work, {"--benchmark", save, "--benchmark-ticks", "5"})
    end
    assert(log:find("FORK REGRESSION PASS " .. case, 1, true), case .. ": see " .. work)
end
Runner.cleanup(work)
