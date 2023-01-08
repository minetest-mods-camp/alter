-- alter_messages: A library for message dialogues in Minetest
-- Copyright (C) 2021  Yaman Qalieh

-- TODO internationalization intlib (this line:
-- local S, NS = dofile(mymod_path .. "/intllib.lua")
-- )


alter_messages = {}

alter_messages.modname = minetest.get_current_modname()
alter_messages.modpath = minetest.get_modpath(alter_messages.modname)

-- Manage open dialogues by different players
alter_messages._dialogues = {}

-------------
-- Helpers --
-------------

local function to_formspec_style(t)
  local style = ""
  for k, v in pairs(t) do
    style = style .. ";" .. k .. "=" .. v
  end
  return style
end

local function get_dialogue_formspec(playername, dialogue)

  -- Generate Answer choices formspec
  -- TODO Alignment of button text
  -- TODO Tighter fit of button text to button
  local choices = {}
  if dialogue.successors then
    table.insert(choices, "container[0.05, 2.7]")
    for i, val in ipairs(dialogue.successors) do
      local id = "dialogue_choice_" .. i
      local text = minetest.formspec_escape(val.option_text)

      -- Add numbering to text
      if dialogue.number_successors then
        text = i .. ". " .. text
      end

      -- Create styles
      if dialogue.successors_style then
        table.insert(choices,
                     "style[" .. id .. to_formspec_style(dialogue.successors_style) .. "]")
      end
      if dialogue.successors_style_hovered then
        table.insert(choices,
                     "style[" .. id .. ":hovered" .. to_formspec_style(dialogue.successors_style_hovered) .. "]")
      end

      table.insert(choices, "button[0,"..(i*0.63)..";10,0.5;"..id..";"..text.."]")
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

---------------
-- Callbacks --
---------------

-- Clear dialogue if the user leaves
minetest.register_on_leaveplayer(function(player)
    alter_messages._dialogues[player:get_player_name()] = nil
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
    -- Exit if it's not the form for this mod
    if formname ~= alter_messages.modname .. ":dialogue" then
      return
    end

    local name = player:get_player_name()
    local dialogue = alter_messages._dialogues[name]
    if not dialogue then
      return true
    end

    if fields["quit"] then
        minetest.after(0.15, alter_messages.send_dialogue, name, dialogue)
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
        alter_messages.send_dialogue(name, pressed.dialogue)
      else
        minetest.close_formspec(name, alter_messages.modname .. ":dialogue")
      end
    end

    return true
end)

---------
-- API --
---------

-- Define the dialogue metatable
alter_messages.dialogue_defaults = {
  -- position
  -- background
  -- decorators
  -- text styling
  successors_style = {border = "false"},
  successors_style_hovered = {textcolor = "yellow"},
  number_successors = true
}
local dialogue = {}
dialogue.__index = alter_messages.dialogue_defaults


function alter_messages.set_default(dtable)
  for k, v in pairs(dtable) do
    alter_messages.dialogue_defaults[k] = v
  end
  dialogue.__index = alter_messages.dialogue_defaults
end

-- TODO Add "register_character" command to have a picture and voice associated.
-- For now, the registration is just the sound, but this can be expanded later to
-- contain various character states as well.
function alter_messages.register_character(name, registration)
  if not alter_messages.characters then
    alter_messages.characters = {}
  end
  alter_messages.characters[name] = registration
end

function alter_messages.send_dialogue(playername, dtable)
  setmetatable(dtable, dialogue)


  -- Expand the tree dynamically
  if dtable.update_self then
    dtable = dtable.update_self(minetest.get_player_by_name(playername), dtable)
  end

  alter_messages._dialogues[playername] = dtable

  minetest.show_formspec(playername, alter_messages.modname .. ":dialogue",
                         get_dialogue_formspec(playername, dtable))

  -- Sound
  -- TODO Add length control
  -- TODO Add other sound controls too (function for custom sound?)
  for k, reg in pairs(alter_messages.characters) do
    if dtable["speaker"] == k then
      minetest.sound_play({name = reg.sound}, {to_player = playername})
    end
  end
end

-- Returns a nested dialogue tree from a table of lines
-- This can be expanded on to add other dialogue properties
function alter_messages.linear_layout(speaker, sequence)
  local dialogue = nil
  for i = (#sequence - 1), 1, -2 do
    curr_dialogue = {
      speaker = speaker,
      successors = {}
    }
    -- Dialogue overrides
    if type(sequence[i]) == "table" then
      for k, v in pairs(sequence[i]) do
        curr_dialogue[k] = v
      end
    else
      curr_dialogue.text = sequence[i]
    end

    -- Option text overrides
    if type(sequence[i + 1]) == "table" then
      curr_dialogue.successors[1] = sequence[i + 1]
    else
      curr_dialogue.successors[1] = {option_text = sequence[i + 1]}
    end

    if dialogue then
      curr_dialogue.successors[1].dialogue = dialogue
    end
    dialogue = curr_dialogue
  end

  return dialogue
end
