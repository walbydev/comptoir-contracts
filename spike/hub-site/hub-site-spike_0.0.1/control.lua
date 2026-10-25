-- Throwaway spike: manual build check for both variants (container vs mining-drill).
script.on_init(function()
  local s = game.surfaces[1]
  local f = game.forces.player
  local p = { x = 0, y = 0 }
  local manual = defines.build_check_type.manual

  for _, who in ipairs({ "hub-anchor-a", "hub-anchor-b" }) do
    local req = { name = who, position = p, force = f, build_check_type = manual }
    local ok, res = pcall(function() return s.can_place_entity(req) end)
    log("SPIKE manual " .. who .. " call_ok=" .. tostring(ok) .. " can_place=" .. tostring(res))
  end
end)
