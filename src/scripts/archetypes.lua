function SpawnSlime()
   local id = api.lvl.newEntity()
   api.lvl.addComponent(id, "physics")
   api.lvl.addComponent(id, "wanderer")
   api.lvl.addComponent(id, "health")
   api.lvl.addComponent(id, "movement_particles")
   api.lvl.addComponent(id, "hitbox")
   api.lvl.addComponent(id, "sprite", [[
      {"animation_player": {"animation_name": "slime"}}
   ]])
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
   return id
end
