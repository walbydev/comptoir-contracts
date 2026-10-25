-- Throwaway. Proves the control stage runs and that this machine lets a mod write a file.
-- Measured on 2.1.23, 2026-10-25: `game.write_file` NO LONGER EXISTS (the engine answers
-- "LuaGameScript doesn't contain key write_file"). `helpers.write_file` does, and writes to
-- <write-data>/script-output/. That single fact invalidated the first version of this file, which is
-- exactly why a smoke test is worth five minutes before a harness is built on top of it.

local function write(data, append)
  helpers.write_file("comptoir-smoke.txt", data .. "\n", append)
end

script.on_init(function()
  write("control stage OK, tick " .. game.tick)
end)

script.on_configuration_changed(function()
  write("configuration changed, tick " .. game.tick, true)
end)
