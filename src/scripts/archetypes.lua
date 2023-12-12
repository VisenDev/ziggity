local api = api

function SpawnPlayer()
   local id = api.lvl.newEntity()
   api.lvl.addComponent(id, "physics", [[{
   "pos": {"x": 5, "y": 5}
   }]])
   api.lvl.addComponent(id, "is_player")
   api.lvl.addComponent(id, "sprite", [[
      {"animation_player": {"animation_name": "player"}}
   ]])
   api.lvl.addComponent(id, "inventory")
   return id
end

function SpawnSlime()
   local id = api.lvl.newEntity()
   api.lvl.addComponent(id, "physics", [[{
   "pos": {"x": 3, "y": 3}
   }]])
   api.lvl.addComponent(id, "wanderer")
   api.lvl.addComponent(id, "health")
   api.lvl.addComponent(id, "hitbox")
   api.lvl.addComponent(id, "death_particles")
   api.lvl.addComponent(id, "sprite", [[
      {"animation_player": {"animation_name": "slime"}}
   ]])
   api.lvl.addComponent(id, "metadata", [[{
      "archetype": "slime"
   }]])
   api.lvl.addComponent(id, "loot", [[{
      "items": ["SpawnCoin"]
   }]])
   return id
end


function SpawnMovementParticle()
   local id = api.lvl.newEntity()
   api.lvl.addComponent(id, "health")
   api.lvl.addComponent(id, "sprite", [[{
      "animation_player": {
         "animation_name": "particle",
         "tint": {"r": 100, "g": 100, "b": 100, "a": 50}
      }
   }]])
   api.lvl.addComponent(id, "health_trickle")
   api.lvl.addComponent(id, "metadata", [[{
      "archetype": "particle"
   }]])
   return id
end

function SpawnFireball()
   local id = api.lvl.newEntity()
   api.lvl.addComponent(id, "sprite", [[{
      "animation_player": {
         "animation_name": "fireball",
         "tint": {"r": 200, "g": 100, "b": 100, "a": 150}
      }
   }]])
   api.lvl.addComponent(id, "hitbox", [[{
      "top": 0.1, "bottom": 0.1, "left": 0.1, "right": 0.1
   }]])
   api.lvl.addComponent(id, "damage", [[{
      "type": "force", "amount": 10
   }]])
   api.lvl.addComponent(id, "health")
   api.lvl.addComponent(id, "health_trickle")
   api.lvl.addComponent(id, "invulnerable")
   api.lvl.addComponent(id, "metadata", [[{
      "archetype": "fireball"
   }]])
   return id
end

function SpawnCoin()

   local id = api.lvl.newEntity()
   api.lvl.addComponent(id, "sprite", [[
      {"animation_player": {"animation_name": "coin"}}
   ]])
   api.lvl.addComponent(id, "hitbox", [[{
      "top": 0.1, "bottom": 0.1, "left": 0.1, "right": 0.1
   }]])
   api.lvl.addComponent(id, "physics")
   api.lvl.addComponent(id, "item", [[{
   "type": "coin"
   }]])
   api.lvl.addComponent(id, "invulnerable")
   api.lvl.addComponent(id, "metadata", [[{
      "archetype": "item"
   }]])
   api.lvl.addComponent(id, "hitbox", [[{
      "top": 0.1, "bottom": 0.1, "left": 0.1, "right": 0.1
   }]])
   return id;
end


function SpawnBloodParticle()
--   print("spawning blood particle")
   local id = api.lvl.newEntity()
   api.lvl.addComponent(id, "health")
   api.lvl.addComponent(id, "sprite", [[{
      "animation_player": {
         "animation_name": "particle",
         "tint": {"r": 50, "g": 250, "b": 20, "a": 200}
      }
   }]])
   api.lvl.addComponent(id, "health_trickle")
   api.lvl.addComponent(id, "metadata", [[{
      "archetype": "particle"
   }]])
   return id
end
