local selector = RecipeSelector("HMRecipeSelector")
if Cache.hasData(selector.classname, "list_products") then
    Cache.reset(selector.classname)
    selector:prepare()
    for _, player in pairs(game.players) do
        Player.set(player)
        User.resetCache(selector.classname)
        User.resetTranslate()
    end
end
