local api = api

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
   return id
end

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
   return id
end


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

function SpawnCoin(ecs, allocator)

   local a = allocator
   local id = api.lvl.newEntity(ecs, a)
   api.lvl.addComponent(ecs, a, id, "sprite", [[
      {"animation_player": {"animation_name": "coin"}, "z_level": "background"}
   ]])
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
   api.lvl.addComponent(ecs, a, id, "hitbox", [[{
      "top": 0.1, "bottom": 0.1, "left": 0.1, "right": 0.1
   }]])
   return id;
end


function SpawnBloodParticle(ecs, allocator)
   local a = allocator
   local id = api.lvl.newEntity(ecs, a)
   api.lvl.addComponent(ecs, a, id, "health", nil)
   api.lvl.addComponent(ecs, a, id, "sprite", [[{
      "animation_player": {
         "animation_name": "particle",
         "tint": {"r": 143, "g": 201, "b": 218, "a": 0}
      },
      "z_level": "background"
   }]])
   api.lvl.addComponent(ecs, a, id, "health_trickle", nil)
   api.lvl.addComponent(ecs, a, id, "metadata", [[{
      "archetype": "particle"
   }]])
   return id
end

function SpawnAnimation (ecs, allocator)
   local a = allocator
   local id = api.lvl.newEntity(ecs, a)
   api.lvl.addComponent(ecs, a, id, "metadata", [[{
      "archetype": "animation"
   }]])
   api.lvl.addComponent(ecs, a, id, "is_animation", nil)
   return id
end
