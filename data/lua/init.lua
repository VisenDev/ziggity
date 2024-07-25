---@class Vector
---@field x integer
---@field y integer

---@class Rectangle
---@field x integer
---@field y integer
---@field width integer
---@field height integer

---@class Frame
---@field subrect Rectangle[]
---@field milliseconds integer|nil

---@class Animation
---@field name string
---@field filepath string
---@field rotation_speed integer|nil
---@field origin Vector|nil
---@field frames Frame[]|nil

---@fun(name: string, filepath: string, x: integer, y: integer, width: integer, height: integer): Animation
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

   local result = {
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
   }


      --wall
      result = TableConcat(result, DeriveWallAnimations("cave_wall", "tiles.png", 0, 0))
      result = TableConcat(result, DeriveWallAnimations("castle_wall", "tiles.png", 1, 0))
      result = TableConcat(result, DeriveWallAnimations("wood_wall", "tiles.png", 2, 0))

      return result
end

function TableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
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

---@param name string
---@param x integer
---@param y integer
---@return Animation[]
function DeriveWallAnimations(name, path, x, y)
    local size = TilemapResolution()
    return {
      SubImage(name, path, x * size + (size/2), y * size + (size/2), size, size),
      SubImage(name .. "_border_left", path, x * size, y * size, size/2, size * 1.5),
      SubImage(name .. "_border_right", path, x * size, y * size, size/2, size * 1.5),
      SubImage(name .. "_border_top", path, x * size + (size/2), y * size, size * 1.5, size/2),
    }
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
