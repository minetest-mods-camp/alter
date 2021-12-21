-- TODO License
--
-- TODO internationalization intlib (this line:
-- local S, NS = dofile(mymod_path .. "/intllib.lua")
-- )

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)


-- Manage open dialogues by different players
local _dialogues = {}
local function get_dialogue(user)
  return _dialogues[user] or {}
end

-- Clear dialogue if the user leaves
minetest.register_on_leaveplayer(function(player)
    _dialogues[player:get_player_name()] = nil
end)

-- Define the dialogue metatable
dialogue_defaults = {
  -- position
  -- background
  -- decorators
  -- text styling
  -- size
}

dialogue = {}
dialogue.__index = dialogue_defaults

function get_dialogue_formspec(playername, dialogue)

  -- Generate Answer choices formspec
  -- TODO Alignment of button text
  -- TODO Tighter fit of button text to button
  local choices = {}
  if dialogue.successors then
    table.insert(choices, "container[0.05, 2.7]")
    for i, val in ipairs(dialogue.successors) do
      local id = "dialogue_choice_" .. i
      local choice_formspec = {
          "style[" .. id .. ";border=false]",
          "style[" .. id ..":hovered;textcolor=yellow]",
          "button[0,"..(i*0.63)..";10,0.5;" .. id .. ";" .. minetest.formspec_escape(val.option_text) .. "]"
      }
      table.insert(choices, table.concat(choice_formspec, ""))
    end
    table.insert(choices, "container_end[]")
  end

  -- Main formspec
  local formspec = {
    "formspec_version[4]",
    "size[10,5]",
    "position[0.01, 0.9]",
    "anchor[0, 1]",
    "no_prepend[]",
    -- "background9[0,0;0,0;weird_cloud.png;true;400]"
    -- Name and picture
    "label[0.1,0.3;" .. minetest.colorize("white", dialogue.speaker) .."]",
    "textarea[0.1,0.5;10,4;;;" .. minetest.formspec_escape(dialogue.text) .. "]",
    table.concat(choices, ""),
  }

  return table.concat(formspec, "")
end

function send_dialogue(playername, dtable)
  setmetatable(dtable, dialogue)


  -- Expand the tree dynamically
  if dtable.update_self then
    dtable = dtable.update_self(minetest.get_player_by_name(playername), dtable)
  end

  _dialogues[playername] = dtable

  minetest.show_formspec(playername, modname .. ":dialogue",
                         get_dialogue_formspec(playername, dtable))

  -- TODO Add "register_character" command to have a picture and voice associated
  if dtable["speaker"] == "Metallic Voice" then
    -- TODO Add length control
    -- local length = #dtable["text"] / 250

    sound = minetest.sound_play(
      {name = "metallic_voice"},
      {to_player = playername,
       -- loop=true
      },
      false
    )
    -- minetest.after(length, minetest.sound_stop, sound)
    -- FIXME play sound
  end
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
    -- Exit if it's not the form for this mod
    if formname ~= modname .. ":dialogue" then
      return
    end

    local name = player:get_player_name()
    local dialogue = _dialogues[name]
    if not dialogue then
      return true
    end

    -- TODO This doesn't work very well right now
    if fields["quit"] then
      send_dialogue(name, dialogue)
      return true
    end

    local pressed = nil
    for i, val in ipairs(dialogue.successors) do
      local id = "dialogue_choice_" .. i
      if fields[id] then
        pressed = val
        break
      end
    end

    if pressed then
      if pressed.on_choose then
        pressed.on_choose(player)
      end

      if pressed.dialogue then
        send_dialogue(name, pressed.dialogue)
      else
        minetest.close_formspec(name, modname .. ":dialogue")
      end
    end

    return true
end)
