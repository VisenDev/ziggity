--require "definitions.lua"

---@type SubImage
function SubImage(name, filepath, x, y, width, height)
   return {
      ['name'] = name,
      ['filepath'] = filepath,
      ['frames'] = {
         {['subrect'] = {['x'] = x, ['y'] = y, ['width'] = width, ['height'] = height},}
      },
      --['origin'] = {['x'] = width / 2, ['y'] = height},
   }
end

---@return Animation
---@param name string
---@param filepath string
---@param x integer
---@param y integer
---@param width integer
---@param height integer
---@param frame_count integer
---@param ms_per_frame integer
---@param loop boolean
function SlideShow(name, filepath, x, y, width, height, frame_count, ms_per_frame, loop)
   local frames = {}
   for i = 1,frame_count + 1 do
      frames[i] = {
         ['subrect'] = {['x'] = x, ['y'] = y + (i - 1) * height, ['width'] = width, ['height'] = height},
         ['milliseconds'] = ms_per_frame,
      }
   end

   return {
      ['name'] = name,
      ['filepath'] = filepath,
      ['frames'] = frames,
      ['loop'] = loop,
   }
end

---@return Animation[]
function Animations()

   return {
      SubImage("player", "entities.png", 0, 0, 32, 32),
      SubImage("particle", "entities.png", 14, 14, 2, 2),

      --caves
      SubImage("cave_wall", "tilemap.png", 0, 0, 32, 32),
      SubImage("cave_floor", "tilemap.png", 32, 0, 32, 32),
      SubImage("cave_wall_border_left", "tilemap.png", 0, 64, 32, 32),
      SubImage("cave_wall_border_right", "tilemap.png", 0, 64, 32, 32),
      SubImage("cave_wall_border_top", "tilemap.png", 0, 32, 32, 32),

      --monsters
      SubImage("slime", "entities.png", 64, 0, 32, 32),
      SubImage("wendigo", "entities.png", 32, 0, 32, 32),
      SubImage("aged_goblin", "entities.png", 0, 0, 32, 32),
      SubImage("gumporg", "entities.png", 96, 0, 32, 32),

      --projectiles
      SlideShow("fireball", "fireball.png", 0, 0, 8, 8, 5, 100, false),

      --items
      SubImage("potion", "entities.png", 0, 32, 16, 16),
   }
end

function PrintTable(t)
   for key, value in pairs(t) do
      if type(value) == "table" then
         print("Key: " .. tostring(key))
         PrintTable(value)
      else
         print("Key: " .. tostring(key) .. ", Value: " .. tostring(value))
      end
   end
end
---@class KeyBinding
----@field name string
----@field mode string|nil
----@field key string


function KeyBindings()

   local bindings = {
      {['name'] = 'player_right', ['key'] = 'D'},
      {['name'] = 'player_left',  ['key'] = 'A'},
      {['name'] = 'player_up',    ['key'] = 'W'},
      {['name'] = 'player_down',  ['key'] = 'S'},
      {['name'] = 'zoom_in',      ['key'] = '='},
      {['name'] = 'zoom_out',     ['key'] = '-'},
      {['name'] = 'debug_mode',   ['key'] = '/'},
      {['name'] = 'inventory',   ['key'] = 'I'},
   }

   return bindings
end



function MakeTile(name, category)
   return
      {
         ['name'] = name,
         ['category'] = category,
         ['animations'] = {
            ['main'] = name,
            ['border'] = {
                ['top'] = name.."_border_top",
                ['left'] = name.."_border_left",
                ['right'] = name.."_border_right",
                ['bottom'] = name.."_border_bottom",
            },
         }
      }
end

function Tiles()
   return {
      MakeTile("cave_floor", "floor"),
      MakeTile("cave_wall", "wall"),
      MakeTile("fort_floor", "floor"),
      MakeTile("fort_wall", "wall"),
   }
end

function TilemapResolution()
   return 32
end
