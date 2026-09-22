-- loader.lua
-- Resolves hyprvim.* modules from this checkout, leaving the host config's package.path untouched.

--- @param path string
--- @return string
local function normalize(path)
  local out = {}
  for seg in path:gmatch("[^/]+") do
    if seg == ".." and #out > 0 and out[#out] ~= ".." then
      table.remove(out)
    elseif seg ~= "." then
      out[#out + 1] = seg
    end
  end
  local prefix = path:sub(1, 1) == "/" and "/" or ""
  if #out == 0 then return prefix == "/" and "/" or "./" end
  return prefix .. table.concat(out, "/") .. "/"
end

local root = normalize(debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./")
if package.loaded["hyprvim.loader"] then return package.loaded["hyprvim.loader"] end

local template = root .. "?.lua;" .. root .. "?/init.lua"

--- @param name string
local function search(name)
  local rest = name:match("^hyprvim%.(.+)$")
  if not rest then return nil end
  local file, err = package.searchpath(rest, template)
  if not file then return err end
  local chunk, load_err = loadfile(file)
  if not chunk then error(load_err, 2) end
  return chunk, file
end

table.insert(package.searchers or package.loaders, 2, search)
package.loaded["hyprvim.loader"] = root
return root
