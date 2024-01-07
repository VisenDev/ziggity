---@source ~/zig/dev/src/api.zig

---@param ecs userdata
---@param allocator userdata
---@return integer
function SpawnPlayer(ecs, allocator)
   local a = allocator
   local id = api.lvl.newEntity(ecs, a)
   api.lvl.addComponent(ecs, a, id, "physics", [[{
   "pos": {"x": 5, "y": 5}
   }]])
   api.lvl.addComponent(ecs, a, id, "is_player", nil)
   api.lvl.addComponent(ecs, a, id, "sprite", [[
      {"animation_player": {"animation_name": "player"}}
   ]])
   api.lvl.addComponent(ecs, a, id, "inventory", nil)
   api.lvl.addComponent(ecs, a, id, "hitbox", nil)
   api.lvl.addComponent(ecs, a, id, "wall_collisions", nil)
   return id
end

---@param ecs userdata
---@param allocator userdata
---@return integer
function SpawnSlime(ecs, allocator)
   local a = allocator
   local id = api.lvl.newEntity(ecs, a)
   api.lvl.addComponent(ecs, a, id, "physics", [[{
   "pos": {"x": 3, "y": 3}
   }]])
   api.lvl.addComponent(ecs, a, id, "wanderer", nil)
   api.lvl.addComponent(ecs, a, id, "health", nil)
   api.lvl.addComponent(ecs, a, id, "hitbox", nil)
   api.lvl.addComponent(ecs, a, id, "death_particles", nil)
   api.lvl.addComponent(ecs, a, id, "sprite", [[
      {"animation_player": {"animation_name": "slime"}}
   ]])
   api.lvl.addComponent(ecs, a, id, "metadata", [[{
      "archetype": "slime"
   }]])
   api.lvl.addComponent(ecs, a, id, "loot", [[{
      "items": ["SpawnCoin"]
   }]])
   api.lvl.addComponent(ecs, a, id, "wall_collisions", nil)
   return id
end

---@param ecs userdata
---@param allocator userdata
---@return integer
function SpawnMovementParticle(ecs, allocator)
   local a = allocator
   local id = api.lvl.newEntity(ecs, a)
   api.lvl.addComponent(ecs, a, id, "health", nil)
   api.lvl.addComponent(ecs, a, id, "sprite", [[{
      "animation_player": {
         "animation_name": "particle",
         "tint": {"r": 100, "g": 100, "b": 100, "a": 50}
      },
      "z_level": "foreground"
   }]])
   api.lvl.addComponent(ecs, a, id, "health_trickle", nil)
   api.lvl.addComponent(ecs, a, id, "metadata", [[{
      "archetype": "particle"
   }]])
   return id
end

---@param ecs userdata
---@param allocator userdata
---@return integer
function SpawnFireball(ecs, allocator)
      local a = allocator
      local id = api.lvl.newEntity(ecs, a)
      api.lvl.addComponent(ecs, a, id, "sprite", [[{
         "animation_player": {
            "animation_name": "fireball",
            "tint": {"r": 200, "g": 100, "b": 100, "a": 150}
         }
      }]])
      api.lvl.addComponent(ecs, a, id, "hitbox", [[{
         "top": 0.1, "bottom": 0.1, "left": 0.1, "right": 0.1
      }]])
      api.lvl.addComponent(ecs, a, id, "damage", [[{
         "type": "force", "amount": 10
      }]])
      api.lvl.addComponent(ecs, a, id, "health", nil)
      api.lvl.addComponent(ecs, a, id, "health_trickle", nil)
      api.lvl.addComponent(ecs, a, id, "invulnerable", nil)
      api.lvl.addComponent(ecs, a, id, "metadata", [[{
         "archetype": "fireball"
      }]])
      api.lvl.addComponent(ecs, a, id, "death_animation", [[
         {"animation_name": "fireball_explosion"}
      ]])
      return id
end

---@param ecs userdata
---@param allocator userdata
---@return integer
function SpawnCoin(ecs, allocator)

   local a = allocator
   local id = api.lvl.newEntity(ecs, a)
   api.lvl.addComponent(ecs, a, id, "sprite", [[{
      "animation_player": {
         "animation_name": "coin",
         "tint": {"r": 143, "g": 201, "b": 218, "a": 250}
      },
      "z_level": "background"
   }]])
   api.lvl.addComponent(ecs, a, id, "hitbox", [[{
      "top": 0.1, "bottom": 0.1, "left": 0.1, "right": 0.1
   }]])
   api.lvl.addComponent(ecs, a, id, "physics", nil)
   api.lvl.addComponent(ecs, a, id, "item", [[{
   "type": "coin"
   }]])
   api.lvl.addComponent(ecs, a, id, "invulnerable", nil)
   api.lvl.addComponent(ecs, a, id, "metadata", [[{
      "archetype": "item"
   }]])
   return id;
end


---@param ecs userdata
---@param allocator userdata
---@return integer
function SpawnBloodParticle(ecs, allocator)
   local a = allocator
   local id = api.lvl.newEntity(ecs, a)
   api.lvl.addComponent(ecs, a, id, "health", nil)
   api.lvl.addComponent(ecs, a, id, "sprite", [[{
      "animation_player": {
         "animation_name": "particle",
         "tint": {"r": 143, "g": 0, "b": 0, "a": 50}
      },
      "z_level": "background"
   }]])
   api.lvl.addComponent(ecs, a, id, "health_trickle", nil)
   api.lvl.addComponent(ecs, a, id, "metadata", [[{
      "archetype": "particle"
   }]])
   return id
end

---@param ecs userdata
---@param allocator userdata
---@return integer
function SpawnAnimation (ecs, allocator)
   local a = allocator
   local id = api.lvl.newEntity(ecs, a)
   api.lvl.addComponent(ecs, a, id, "metadata", [[{
      "archetype": "animation"
   }]])
   api.lvl.addComponent(ecs, a, id, "is_animation", nil)
   return id
end
