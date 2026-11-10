## What the fork adds to Helmod

- **Plan shipments to orbit.** Pick a delivery rate, such as 60 science packs per second, and see the rocket ingredients and silos you need. The plan uses each item’s rocket capacity, your modules and productivity research, and the launch cycle at the silo’s quality. If a modded silo offers several rocket-part recipes, you can choose which one to use.
- **Size power plants from factory demand.** Link a power block to your machines and beacons. Boiler and fuel counts reflect the inlet temperature. For fusion, two normal reactors producing 8 plasma/s can feed four generators in isolation or eight as a connected pair. The planner accounts for hotter plasma, generator limits and returned coolant.
- **Balance recycling and quality loops.** Ctrl-click materials in the main Input row to let Matrix Solver draw those materials at the selected quality from outside the block. Linked blocks carry intermediates across nested production lines and account for fluid temperatures, including make-up coolant in recycling loops.
- **Edit large and shared plans.** Keep your scroll position as you edit rows, switch a sub-block’s mode from its icon, and clear constraints even at zero throughput. For multiplayer, an experimental solver spreads recalculation across ticks to reduce stalls during edits. It’s off by default under **Settings → Mod settings → Map**.
- **Plan modded recipes more accurately.** The fork handles repeated outputs with different productivity rules, spent fuel that matches a recipe output, pumps with a fixed fluid, and machines locked to a recipe. Custom recipes keep their item qualities and crafting categories, and saved quantities survive a reload.

Works with or without Space Age. Orbital shipping requires space travel and a compatible silo. See the [full changelog](https://mods.factorio.com/mod/helmod-fork/changelog) for individual fixes.

## Switching from Helmod on Factorio 2.1

- Back up your save.
- In the Mods menu, disable Helmod and enable **Helmod: Szer’s Fork** in the same restart.
- Load your save to bring over your plans, custom recipes, and rules. Saving with both mods disabled can discard that data.
- Check mods that depend on the original Helmod ID. They may need an update to work with the fork.

[Source](https://github.com/Szer/helmod/tree/fork) · [Report an issue](https://github.com/Szer/helmod/issues)

## Credits

Original mod and project lead: Helfima. Other credited names in the upstream Git history: KiwiHawk, Shadow_Man, Notarin Steele, aegeeik, jodli, Mape6, KirillNaumkin, luaotix, Arumba, LUISDASARTIMANHAS, Maarten Bezemer, x2605, JP Sugarbroad, KoharaKazuya, ichbestimmtnicht, nboulic, Alexander Karatarakis, Astorin, Benjamin Mann, Branden Maleki, Cliff Frey, Duchesko, Ehren Kret, ImgBotApp, Jakub Higersberger, John Arbash Meinel, Jordan Dominion, LUIS_DAS_ARTIMANHAS, NEstoll, Nick Peterson, NoPrint, PenguinEncounter, RastGame, Sandro Jäckel, Sébastien Lavoie, Walter Mundt, alexkar598, i2um1, jakob, sotn56. See the [original repository](https://github.com/Helfima/helmod), [contribution history](https://github.com/Helfima/helmod/graphs/contributors) and [Helmod changelog](https://mods.factorio.com/mod/helmod/changelog) for individual code and translation credits. Original authorship and MIT licensing are preserved. Fork maintenance and releases: Szer.
