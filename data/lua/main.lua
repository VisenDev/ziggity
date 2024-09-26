---@module "definitions.lua"
---@module "utils.lua"

---@type integer
TilemapResolution = 32

ZigLoadFile(ZigLuaStatePtr, "lua/utils.lua")

---@type Animation[]
Animations = {
      SubImage("player", "entities.png", 0, 0, 32, 32),
      SubImage("particle", "entities.png", 14, 14, 2, 2),

      --floor
      SubImage("cave_floor", "tilemap.png", 96, 0, 32, 32),

      --monsters
      SubImage("slime", "entities.png", 64, 0, 32, 32),
      SubImage("wendigo", "entities.png", 32, 0, 32, 32),
      SubImage("aged_goblin", "entities.png", 0, 0, 32, 32),
      SubImage("gumporg", "entities.png", 96, 0, 32, 32),

      --projectiles
      SlideShow("fireball", "fireball.png", 0, 0, 8, 8, 5, 100, false),

      --items
      SubImage("potion", "entities.png", 0, 32, 16, 16),

      table.unpack(DeriveWallAnimations("cave_wall", "tiles.png", 0, 0)),
      --table.unpack(DeriveWallAnimations("castle_wall", "tiles.png", 1, 0)),
      --table.unpack(DeriveWallAnimations("wood_wall", "tiles.png", 2, 0)),
}

PrintTable(Animations)


---@type KeyConfig[]
Keys = {
    {['name'] = 'player_right', ['key'] = 'D'},
    {['name'] = 'player_left',  ['key'] = 'A'},
    {['name'] = 'player_up',    ['key'] = 'W'},
    {['name'] = 'player_down',  ['key'] = 'S'},
    {['name'] = 'zoom_in',      ['key'] = '='},
    {['name'] = 'zoom_out',     ['key'] = '-'},
    {['name'] = 'debug_mode',   ['key'] = '/'},
    {['name'] = 'inventory',    ['key'] = 'I'},
}

---@type Tile[]
Tiles = {
      MakeTile("cave_floor", "floor"),
      MakeTile("cave_wall", "wall"),
      MakeTile("fort_floor", "floor"),
      MakeTile("fort_wall", "wall"),
   }

