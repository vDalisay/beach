class_name UiPalette
extends RefCounted
## Brand colours and fonts, taken from the wordmark (marketing/steam/build_capsule.py). Every UI
## script reads colours from here; nothing else hard-codes a brand colour. Presentation only.

const NAVY := Color("0b2a44")
const NAVY_DEEP := Color("071a2c")
const WHITE := Color("ffffff")
const INK_SOFT := Color("3d5a73")

const GOLD_TOP := Color("fff6cf")
const GOLD := Color("ffd257")
const GOLD_BOTTOM := Color("ff9f1c")
const GOLD_SHADE := Color("c9570f")

const AQUA_TOP := Color("ffffff")
const AQUA := Color("bff6ff")
const AQUA_BOTTOM := Color("3fc6e6")
const AQUA_SHADE := Color("16799c")

const SAND := Color("fff3dc")
const SAND_DEEP := Color("f2dfbb")
const CORAL := Color("f25c54")
const CORAL_TOP := Color("ffb3a8")
const MINT := Color("7ff5c8")
const AMBER := Color("e8b45a")
const MONEY := Color("ffd85a")
const MUTED := Color("9fb3c4")

const FONT_DISPLAY := preload("res://art/fonts/Bungee-Regular.ttf")
const FONT_BODY_BOLD := preload("res://art/fonts/BarlowCondensed-Bold.ttf")
const FONT_BODY := preload("res://art/fonts/BarlowCondensed-Medium.ttf")

## Outline thickness for text drawn straight on the world, at the 1280×720 base.
const WORLD_OUTLINE := 8
const WORLD_OUTLINE_SMALL := 6
