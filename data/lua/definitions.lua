---@meta

--- This is an autogenerated file,
--- Do not modify

---@class (exact) Animation
---@field texture? struct_Texture | nil
---@field filepath string
---@field name string
---@field loop? boolean
---@field origin? struct_Vector2
---@field frames? AnimationFrame[]

---@class (exact) struct_Texture
---@field id? integer
---@field width? integer
---@field height? integer
---@field mipmaps? integer
---@field format? integer

---@class (exact) struct_Vector2
---@field x? number
---@field y? number

---@class (exact) AnimationFrame
---@field subrect struct_Rectangle
---@field milliseconds? number

---@class (exact) struct_Rectangle
---@field x? number
---@field y? number
---@field width? number
---@field height? number

---@class (exact) KeyConfig
---@field name string
---@field key string
---@field shift? boolean
---@field control? boolean
---@field mode? KeyMode

---@alias KeyMode
---|' "insert" '
---|' "normal" '

---@class (exact) Tile
---@field name? string
---@field animations? Tile__struct_3487
---@field category? Category

---@class (exact) Tile__struct_3487
---@field main? string | nil
---@field border? Tile__struct_3487__struct_3489

---@class (exact) Tile__struct_3487__struct_3489
---@field left? string | nil
---@field right? string | nil
---@field top? string | nil
---@field bottom? string | nil

---@alias Category
---|' "wall" '
---|' "floor" '
