local Hotkey = require "gui.controls.Hotkey"
data:extend(
  {
    {
      type = "custom-input",
      name = Hotkey.close,
      key_sequence = "ESCAPE",
      consuming = "none"

    },
    {
      type = "custom-input",
      name = Hotkey.openClose,
      key_sequence = "U",
      consuming = "none"

    },
    {
      type = "custom-input",
      name = Hotkey.productionLine,
      key_sequence = "I",
      consuming = "none"

    },
    {
      type = "custom-input",
      name = Hotkey.recipeSelector,
      key_sequence = "SHIFT + O",
      consuming = "none"

    },
    {
      type = "custom-input",
      name = Hotkey.recipeExplorer,
      key_sequence = "Y",
      consuming = "none"

    },
    {
      type = "custom-input",
      name = Hotkey.richText,
      key_sequence = "CONTROL + T",
      consuming = "none"

    },
    {
      type = "custom-input",
      name = Hotkey.createOrWhereUsed,
      key_sequence = "CONTROL + U",
      consuming = "none"

    }
  }
)
