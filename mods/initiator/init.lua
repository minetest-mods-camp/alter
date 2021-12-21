local storage = minetest.get_mod_storage()

num_teleporters = 25
if storage:get_int("num_human") == 0 then
  storage:set_int("num_human", 31476)
end

-- TODO Add helper functions to messagelib: (linear_layout, branch, etc)
local tutorial_successor = {
  option_text = "Continue",
  dialogue = {
    speaker = "Metallic Voice",
    text = "Your body has been surgically modified into a permanent state of quantum entanglement across the alter dimension.",
    successors = {
      {
        option_text = "I don't understand",
        dialogue = {
          speaker = "Metallic Voice",
          text = "Apologies. My calculations for your intelligence were inflated. This explanation should be adequate: 'Placing blocks on this side makes them appear on the other side'",
          successors = {
            {
              option_text = "Oh I see",
              dialogue = {
                speaker = "Metallic Voice",
                update_self = function(player, dialogue)
                  dialogue.text = "You will also need these to reverse the quantum alt— This information is wasted on you. Drinking this will move you to the other side. If you use all of them, trials will proceed with Human #" .. (storage:get_int("num_human") + 1) .. ". Now go push that button on the other side."
                  return dialogue
                end,
                successors = {
                  {
                    option_text = "Ok.",
                    on_choose = function(player)
                      local number = num_teleporters + storage:get_int("handicap")
                      if number <= 0 then
                        return
                      end
                      local stack = ItemStack("mirror:teleporter " .. number)
                      player:get_inventory():add_item("main", stack)
                    end
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

local first_dialogue = {
  speaker = "Metallic Voice",
  update_self = function(player, dialogue)
    dialogue.text = "Congratulations Human #"..storage:get_int("num_human")..", you have been selected for the biotechnology trial division. We will begin your training shortly."
    return dialogue
  end,
  successors = {
    {
      option_text = "I never asked for this...",
      dialogue = {
        update_self = function(player, dialogue)
          dialogue.successors = {tutorial_successor}
          return dialogue
        end,
        speaker = "Metallic Voice",
        text = "Ha. Ha. Ha. Ha. You humans always act the same. Let us get started."
      }
    },
    {
      option_text = "Alright! Let's get started!",
      on_choose = function(player)
        num_teleporters = num_teleporters - 3
      end,
      dialogue = {
        update_self = function(player, dialogue)
          dialogue.successors = {tutorial_successor}
          return dialogue
        end,
        speaker = "Metallic Voice",
        text = "Your enthusiasm is disturbing. I will increase the difficulty of your training to return it to normal levels."
      }
    }
  }
}

local level_texts = {
  [0] = {
    text = "You have already surpassed my expectations for humans...",
    teleporter = 10
  },
  [1] = {
    text = "Did you expect me to congratulate you? Continue with the next trial.",
    teleporter = 10
  },
  [2] = {
    text = "Previous trials suggest that human memory is fragile: You must not consume all the entanglement samples.",
    teleporter = 10
  },
  [3] = {
    text = "Human-led studies claim that their young develop object-permanence as early as 5 months, though these data show otherwise.",
    teleporter = 10
  },
  [4] = {
    text = "Proceed with the next trial.",
    teleporter = 15
  },
  [5] = {
    text = "You humans always talk about 'thinking outside the box,' but what about inside the box?",
    teleporter = 15
  },
  [6] = {
    text = "Hum— Objects in motion remain in motion.",
    teleporter = 15
  },
  [7] = {
    text = "Your agility must also be tested.",
    teleporter = 15
  },
  [8] = {
    text = "Well done. Results from this test room indicate that humans do not have significant spatial memory capacity. Perhaps you consider yourself special in that regard?",
    teleporter = 15
  },
  [9] = {
    text = "Congratulations. You have passed all the trials and are free to continue to the next stage. It is now time for me to fine-tune these trials for future candidates.", -- TODO
  }
}

function show_level_end_dialogue(player)
  local level = storage:get_int("level")
  local dialogue = {
    speaker = "Metallic Voice",
    text = level_texts[level].text,
    successors = {
      {
        option_text = "Continue",
        on_choose = function(player)
          if level_texts[level].teleporter then
            local count = level_texts[level].teleporter + storage:get_int("handicap")
            if count <= 0 then
              return
            end
            local stack = ItemStack("mirror:teleporter " .. count)
            player:get_inventory():add_item("main", stack)
          end
        end
      }
    }
  }
  if level == 9 then -- Last level
    -- TODO Adjust difficulty
    dialogue.successors[1].dialogue = first_dialogue
    dialogue.successors[1].on_choose = function(player)
      local handicap = storage:get_int("handicap")
      storage:set_int("handicap", handicap - 10)

      restart_game(player)
    end
  end
  send_dialogue(player:get_player_name(), dialogue)
  storage:set_int("level", level + 1)
end


function show_incomplete_level_dialogue(player)
  local dialogue = {
    speaker = "",
    text = "You cannot reach the button. Try getting closer.",
    successors = {
      {
        option_text = "Ok"
      }
    }
  }
  send_dialogue(player:get_player_name(), dialogue)
end

-- TODO Death screen is not very good because escape exits automatically
function show_death_dialogue(player)
  local dialogue = {
    speaker = "Metallic Voice",
    text = "Your performance is unsatisfactory. Proceeding with Human #" .. (storage:get_int("num_human") + 1) .. ". Potion rations will be adjusted accordingly.",
    update_self = function(player, dialogue)
      local handicap = storage:get_int("handicap")
      storage:set_int("handicap", handicap + 2)
      return dialogue
    end,
    successors = {
      {
        option_text = "No! I can still make it!",
        dialogue = {
          speaker = "Metallic Voice",
          text = "Very well. I will leave you here until you give up and open your inventory.",
          successors = {
            {
              option_text = "Ok",
            }
          }
        }
      },
      {
        option_text = "Game over...",
        on_choose = restart_game,
        dialogue = first_dialogue
      },
    }
  }
  send_dialogue(player:get_player_name(), dialogue)
end

local function get_inventory_formspec()
  local formspec = {
    "size[3,1.3]",
    "button[0,0;3,0.5;restart_game;Restart Game]",
    "button[0,1;3,0.5;continue_game;Continue]"
  }
  return table.concat(formspec, "")
end

local function place_levels()
  local schem_pos = {x=-10, y=5, z=0}
  minetest.place_schematic(schem_pos, minetest.get_modpath("initiator").."/schems/levels.mts", "0", nil, true)
end

function restart_game(player)
  num_teleporters = 25
  -- Deal with num_human and level
  local num_human = storage:get_int("num_human")
  storage:set_int("num_human", num_human + 1)
  storage:set_int("level", 0)
  -- place schematic
  place_levels()
  -- Always day
  player:override_day_night_ratio(1)
  minetest.settings:set("time_speed", 0)
  -- teleport
  local pos = {x=5, y=6.5, z=1}
  player:set_pos(pos)
  -- set yaw (0)
  player:set_look_horizontal(0)
  player:set_look_vertical(0)
  -- Clear inventory
  player:get_inventory():set_list("main", {})
  -- Send starter dialogue
  send_dialogue(player:get_player_name(), first_dialogue)
end

minetest.register_on_joinplayer(function(player, last_login)
    -- Don't allow user to modify their inventory layout
    player:set_inventory_formspec(get_inventory_formspec())
    player:hud_set_hotbar_itemcount(3)

    if player:get_inventory():is_empty("main") then
      restart_game(player)
    end
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "" then
      if fields.restart_game then
        restart_game(player)
        return true
      elseif fields.continue_game then
        minetest.close_formspec(player:get_player_name(), "")
        return true
      end
    end
end)
