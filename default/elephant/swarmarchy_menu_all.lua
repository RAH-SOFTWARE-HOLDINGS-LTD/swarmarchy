--
-- Swarmarchy Menu, deeper entries, for the walker set "swarmarchymenu"
-- (see config/walker/config.toml). Entries come from swarmarchy-menu's own
-- index; picking one replays its path through the normal menus.
--
Name = "swarmarchymenuall"
NamePretty = "Swarmarchy Menu Search"
HideFromProviderlist = true
Cache = false

local function shell_escape(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

function GetEntries()
  local entries = {}
  local handle = io.popen("swarmarchy-menu --index 2>/dev/null")
  if not handle then
    return entries
  end

  for line in handle:lines() do
    if line ~= "" then
      table.insert(entries, {
        Text = line,
        Actions = {
          activate = "swarmarchy-menu --pick " .. shell_escape(line),
        },
      })
    end
  end

  handle:close()
  return entries
end
