-- Alter mirror mod: Creates nodes and items needed for the game.
-- Copyright (C) 2021  Yaman Qalieh

alter = {}

local modname = minetest.get_current_modname()
local tau = 2 * math.pi

minetest.register_item(":", {
                         type="none",
                         wield_image = "wieldhand.png",
                         tool_capabilities = {
                           max_drop_level = 0,
                           groupcaps = {
                             crumbly = {uses=0, maxlevel=1, times={[1]=1, [2]=0.75, [3]=0.5}}
                           }
                         }
})

function alter.register_node(name, extra)
  local definition = {
    tiles = {"alter_" .. name .. ".png"},
    stack_max = 1000,
    groups = {instant_break=1}
  }

  if extra then
    for k,v in pairs(extra) do
      definition[k] = v
    end
  end

  minetest.register_node(modname .. ":" .. name, definition)
end

function alter.register_mirror_node(name, extra)
  local definition = {
    node_placement_prediction = "air",
    on_drop = function(itemstack, dropper, pos)
      return itemstack
    end,
    after_place_node = function(pos, placer, itemstack, pointed_thing)
      minetest.remove_node(pos)
      pos.x = -1 * pos.x
      local other = minetest.get_node_or_nil(pos)
      if not other or other.name ~= "air" then
        minetest.sound_play({name="error"},
          {to_player=placer:get_player_name(),
           pitch = 1.3},
          true)
        return true
      else
        minetest.sound_play({name="mirror_place"},
          {gain=3, pitch=1.5}, true)
        minetest.set_node(pos, {name = modname .. ":" .. name})
      end
    end,
  }

  if extra then
    for k,v in pairs(extra) do
      definition[k] = v
    end
  end

  alter.register_node(name, definition)
end

minetest.register_node(modname .. ":door", {
                         tiles = {"alter_door.png"},
                         on_punch = function(pos, node, puncher, pointed_thing)
                           if puncher:get_pos().z - pos.z > -1 then
                             -- Remove barrier
                             minetest.set_node(pos, {name = "air"})
                             pos.y = pos.y - 1
                             minetest.set_node(pos, {name = "air"})
                             puncher:set_pos(pos)

                             -- Close behind
                             pos.z = pos.z - 1
                             minetest.set_node(pos, {name = modname .. ":unbreakable"})
                             pos.y = pos.y + 1
                             minetest.set_node(pos, {name = modname .. ":unbreakable"})

                             -- Only teleporters go to the next part
                             local inv = puncher:get_inventory()
                             local stack = ItemStack(modname .. ":teleporter " .. 99)
                             stack = inv:remove_item("main", stack)
                             inv:set_list("main", {})
                             inv:add_item("main", stack)

                             minetest.sound_play({name="success"},
                               {to_player=puncher:get_player_name()},
                               true)

                             -- TODO This is a dependency issue
                             -- TODO Bug: If player restarts immediately after completing level, things break.
                             minetest.after(1.5, show_level_end_dialogue, puncher)
                           else
                             minetest.sound_play({name="error"},
                               {to_player=puncher:get_player_name(),
                                pitch = 1.3},
                               true)

                             -- TODO This is a dependency issue
                             local pmeta = puncher:get_meta()
                             if pmeta:get_int("alter_mirror:button_distance") == 0 then
                               pmeta:set_int("alter_mirror:button_distance", 1)
                               show_incomplete_level_dialogue(puncher)
                             end
                           end

                         end
})

minetest.register_craftitem(modname .. ":teleporter", {
                              inventory_image = "alter_teleporter.png",
                              stack_max = 1000,
                              on_drop = function(itemstack, dropper, pos)
                                  return itemstack
                              end,
                              on_use = function(itemstack, player, pointed_thing)
                                -- Position calculation
                                local tpos = player:get_pos()
                                tpos.x = -1 * tpos.x

                                -- Check that it's valid (head area)
                                tpos.y = tpos.y + 1
                                local target_head = minetest.get_node_or_nil(tpos)
                                if not target_head or target_head.name ~= "air" then
                                  minetest.sound_play({name="error"},
                                    {to_player=player:get_player_name(),
                                     pitch = 1.3},
                                    true)
                                  return nil
                                end
                                tpos.y = tpos.y - 1

                                itemstack:take_item(1)

                                -- If empty, restart game
                                -- TODO This is a dependency issue
                                if itemstack:is_empty() then
                                  show_death_dialogue(player)
                                  return itemstack
                                end


                                local pitch = 1.5
                                if tpos.x < 0 then
                                  pitch = 1.3
                                end

                                minetest.sound_play({name="teleport"},
                                  {to_player=player:get_player_name(),
                                  pitch=pitch},
                                  true)

                                -- Angle calculation
                                local angle = player:get_look_horizontal()
                                local angle = tau - angle

                                -- Teleport
                                player:set_look_horizontal(angle)
                                player:move_to(tpos, true)

                                -- Velocity calculation
                                local vel = player:get_velocity()
                                local change = {x = -2 * vel.x, y = 0, z = 0}
                                player:add_velocity(change)

                                return itemstack
                              end
})

alter.register_node("unbreakable")
alter.register_node("unbreakable_interior")
alter.register_node("unbreakable_glass", {
                      use_texture_alpha = "blend",
                      drawtype="glasslike_framed",
                      sunlight_propagates=true,
                      paramtype = "light"
})
alter.register_node("light", {
                      light_source = minetest.LIGHT_MAX,
                      sunlight_propagates=true
})
alter.register_mirror_node("blue", {
                       groups = {crumbly=2,
                                 instant_break = 1}
})
