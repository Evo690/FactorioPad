local loaded_base, library, skipped, wreck_created, cutscene_exited = false, nil, false, false, false
defines = {events = {on_tick = 1}, controllers = {cutscene = 2}}
storage = {}
local player = {
  controller_type = nil,
  exit_cutscene = function()
    assert(wreck_created, 'The wreck must exist before the cutscene ends')
    cutscene_exited = true
    storage.crash_site_cutscene_active = nil
  end
}
game = {get_player = function(index)
  assert(index == 1)
  return player
end}
package.preload['__base__/script/freeplay/control.lua'] = function()
  loaded_base = true
end
package.preload['event_handler'] = function()
  return {add_lib = function(value) library = value end}
end
remote = {call = function(interface, method, value)
  assert(interface == 'freeplay' and method == 'set_skip_intro' and value == true)
  skipped = true
end}

dofile('Tools/freeplay_control.lua')
assert(loaded_base and library and not skipped, 'Loading must preserve base freeplay and defer changes until initialization')
library.on_init()
assert(skipped, 'New freeplay games must skip the Tab-only intro message')
library.events[defines.events.on_tick]()
assert(not cutscene_exited, 'The script must wait for the crash site')
wreck_created = true
storage.crash_site_cutscene_active = true
player.controller_type = defines.controllers.cutscene
library.events[defines.events.on_tick]()
assert(wreck_created and cutscene_exited, 'New freeplay games must keep the wreck and skip the cutscene')
cutscene_exited = false
library.events[defines.events.on_tick]()
assert(not cutscene_exited, 'The cutscene must end only once')
print('Factorio freeplay intro tests passed.')
