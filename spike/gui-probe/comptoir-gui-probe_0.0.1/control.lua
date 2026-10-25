-- control.lua — the whole probe: a container is opened, we take the GUI away, we put our frame up.
--
-- Description: throwaway instrument for criterion R1 (ADR 0050). It implements nothing the mod
--              needs; it answers one question that no headless run can answer: on a graphical
--              client, when `player.opened = nil` runs inside on_gui_opened for a `container`, does
--              the vanilla inventory frame disappear, and is our frame the only thing left on screen?
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: on_gui_opened / on_gui_click / on_gui_closed, no data stage
-- Usages:      loaded beside comptoir-contracts on the requester's machine, and nowhere else
-- Notes:       NO DATA STAGE. The probe declares no prototype, so `data.lua` is absent on purpose:
--              the counter it looks at is `comptoir-counter`, owned by comptoir-contracts, which
--              this mod depends on (a required dependency, no `?`).
--              The frame is drawn in `player.gui.screen`, the only surface a mod can add to without
--              an entity. Whether that surface renders above the vanilla container frame is exactly
--              what the probe measures — and it cannot force that layer, hence the wording the
--              requester reads on the label.
--              The close the probe causes itself (`player.opened = nil`) can come back as an
--              on_gui_closed in the same tick. That one is ignored: otherwise the frame just added
--              would be destroyed by the probe's own reflection and the requester would see nothing.
--              A later close is the requester pressing E, and that one destroys the frame.
--              No state, no tick handler: `storage` is never touched, the frame is the only thing
--              this mod creates in the world.
-- Licence:     MIT (see LICENSE)

local FRAME = "comptoir-gui-probe"
local CLOSE_BUTTON = "comptoir-gui-probe-close"

-- The tick at which we closed a GUI ourselves, per player index. A plain table, not `storage`: a
-- probe that remembers nothing after a save reload is a feature, not a gap.
local self_closed_tick = {}

local function destroy_frame(player)
  local frame = player.gui.screen[FRAME]
  if frame and frame.valid then
    frame.destroy()
  end
end

local function build_frame(player)
  local frame = player.gui.screen.add {
    type = "frame",
    name = FRAME,
    caption = "comptoir-gui-probe",
  }
  frame.add {
    type = "label",
    caption = "PROBE: our frame is on screen",
  }
  frame.add {
    type = "label",
    caption = "vanilla frame visible? look behind this one",
  }
  frame.add {
    type = "button",
    name = CLOSE_BUTTON,
    caption = "close",
  }
end

-- Opening anything that is a container (the counter is one) is the measured event.
script.on_event(defines.events.on_gui_opened, function(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end
  if entity.type ~= "container" then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  game.print('[comptoir-gui-probe] opened entity: "' .. entity.name .. '"')

  destroy_frame(player)
  -- Ask the engine to close the vanilla inventory frame it has just opened for this container.
  player.opened = nil
  self_closed_tick[event.player_index] = game.tick
  build_frame(player)
end)

-- Our own `player.opened = nil` may bounce back here in the same tick: keep the frame in that case.
script.on_event(defines.events.on_gui_closed, function(event)
  if self_closed_tick[event.player_index] == game.tick then
    self_closed_tick[event.player_index] = nil
    return
  end

  local player = game.get_player(event.player_index)
  if player then
    destroy_frame(player)
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end
  if element.name ~= CLOSE_BUTTON then
    return
  end

  local player = game.get_player(event.player_index)
  if player then
    destroy_frame(player)
  end
end)
