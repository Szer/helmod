local test_directory = arg[0]:match("^(.*)[/\\]") or "."
local Runner = dofile(test_directory .. "/orbit_test_runner.lua")
assert(#arg == 3, "Usage: lua test/run_fork_repros.lua GRAPHICAL_FACTORIO DATA AUDIT_REPROS")
local executable, data, saves = Runner.absolute(arg[1]), Runner.absolute(arg[2]), Runner.absolute(arg[3])
local root = Runner.absolute(test_directory .. "/..")
local work = Runner.create(root, data)
local mod = work .. "/mods/helmod-fork"
Runner.write(work .. "/mods/mod-list.json", [[{"mods":[{"name":"base","enabled":true},{"name":"space-age","enabled":true},{"name":"quality","enabled":true},{"name":"elevated-rails","enabled":true},{"name":"recycler","enabled":true},{"name":"helmod-fork","enabled":true}]}]])
Runner.copy(root .. "/test/test_fork_repros.lua", mod .. "/test_fork_repros.lua")
local control = Runner.read(mod .. "/control.lua")
for _, case in ipairs({"empty-explorer", "custom-recipe-quality", "custom-recipe-categories",
                       "blank-selector-rule", "truncated-import", "empty-blueprint-book", "quantity-after-reload", "quantity-confirm"}) do
    Runner.write(mod .. "/control.lua", control .. '\nrequire "test_fork_repros"("' .. case .. '")\n')
    local save = saves .. "/" .. case .. "/repro.zip"
    local log
    if case == "quantity-after-reload" then
        log = Runner.factorio(executable, work, {"--load-game", save, "--disable-audio"}, true)
    else
        if case == "quantity-confirm" then
            save = work .. "/write/saves/_autosave-fork-quantity.zip"
        end
        log = Runner.factorio(executable, work, {"--benchmark", save, "--benchmark-ticks", "5"})
    end
    assert(log:find("FORK REGRESSION PASS " .. case, 1, true), case .. ": see " .. work)
end
Runner.cleanup(work)
