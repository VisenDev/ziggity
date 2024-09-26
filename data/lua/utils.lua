---@module "definitions.lua"

---@return Tile
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

---@return Animation
function SlideShow(name, filepath, x, y, width, height, frame_count, ms_per_frame, loop)
   local frames = {}
   for i = 1,frame_count + 1 do
      frames[i] = {
         ['subrect'] = {['x'] = x, ['y'] = y + (i - 1) * height, ['width'] = width, ['height'] = height},
         ['milliseconds'] = ms_per_frame,
      }
   end

   ---@type Animation
   return {
      ['name'] = name,
      ['filepath'] = filepath,
      ['frames'] = frames,
      ['loop'] = loop,
      ['origin'] = {['x'] = 0, ['y'] = 0},
    }
end

---@return Animation
function SubImage(name, filepath, x, y, width, height)

   ---@type Animation
   return {
      ['name'] = name,
      ['filepath'] = filepath,
      ['frames'] = {
         {['subrect'] = {['x'] = x, ['y'] = y, ['width'] = width, ['height'] = height},}
      },
   }
end


---@param name string
---@param x integer
---@param y integer
---@return Animation[]
function DeriveWallAnimations(name, path, x, y)
    local size = TilemapResolution
    return {
      SubImage(name, path, x * size + (size/2), y * size + (size/2), size, size),
      SubImage(name .. "_border_left", path, x * size, y * size, size/2, size * 1.5),
      SubImage(name .. "_border_right", path, x * size, y * size, size/2, size * 1.5),
      SubImage(name .. "_border_top", path, x * size + (size/2), y * size, size * 1.5, size/2),
    }
end


function TableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end
