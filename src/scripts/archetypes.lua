local api = api

function SpawnSlime()
   local id = api.lvl.newEntity()
   api.lvl.addComponent(id, "physics", [[{
   "pos": {"x": 3, "y": 3}
   }]])
   api.lvl.addComponent(id, "wanderer")
   api.lvl.addComponent(id, "health")
   api.lvl.addComponent(id, "hitbox")
   api.lvl.addComponent(id, "sprite", [[
      {"animation_player": {"animation_name": "slime"}}
   ]])
   api.lvl.addComponent(id, "metadata", [[{
      "archetype": "slime"
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



--self.setComponent(a, fireball, Component.sprite{
--                .animation_player = .{ .animation_name = "fireball", .tint = ray.ColorAlpha(ray.ORANGE, 0.5) },
--            }) catch return;
--            self.setComponent(a, fireball, Component.damage{
--                .type = "force",
--                .amount = 10,
--            }) catch return;
--            self.setComponent(a, fireball, Component.hitbox{ .top = 0.1, .bottom = 0.1, .left = 0.1, .right = 0.1 }) catch return;

