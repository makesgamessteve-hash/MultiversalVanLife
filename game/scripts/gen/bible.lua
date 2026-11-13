-- Multiversal Van Life - world bible: a readable Markdown account of a
-- generated place and everything on its path, for review and tuning (MIT).
--   mvl_headless --data game --bible u1.g2 --out bible.md [--seed N]
local address = require("gen.address")
local facts = require("gen.facts")
local util = require("gen.util")

local bible = {}

local function scalar(v)
  if type(v) == "number" then
    if math.type(v) == "integer" then return tostring(v) end
    return string.format("%.4g", v)
  end
  if type(v) == "string" then return v end
  return tostring(v)
end

-- Renders a value as Markdown bullet lines.
local function render(v, indent, out, depth)
  if type(v) ~= "table" then
    out[#out + 1] = indent .. "- " .. scalar(v)
    return
  end
  for _, k in ipairs(util.sorted_keys(v)) do
    local x = v[k]
    if type(x) == "table" and #x > 32 then
      -- per-cell fields and other long lists: summarised, not listed
      local lo, hi, num = math.huge, -math.huge, true
      for i = 1, #x do
        if type(x[i]) ~= "number" then num = false break end
        lo, hi = math.min(lo, x[i]), math.max(hi, x[i])
      end
      out[#out + 1] = indent .. "- **" .. scalar(k) .. "**: " .. #x .. " values" ..
                      (num and (" from " .. scalar(lo) .. " to " .. scalar(hi)) or "")
    elseif type(x) == "table" and depth < 4 and next(x) ~= nil then
      out[#out + 1] = indent .. "- **" .. scalar(k) .. "**"
      render(x, indent .. "  ", out, depth + 1)
    elseif type(x) == "table" then
      out[#out + 1] = indent .. "- **" .. scalar(k) .. "**: " .. (next(x) and "…" or "(empty)")
    else
      out[#out + 1] = indent .. "- **" .. scalar(k) .. "**: " .. scalar(x)
    end
  end
end

local function anchor(id) return (id:gsub("[^%w]+", "-")) end

local function fact_line(f)
  local line = "- <a id=\"" .. anchor(f.id) .. "\"></a>**" .. f.id .. "** — " .. f.kind
  local d = f.data
  if f.kind == "commitment" then
    line = line .. ": " .. tostring(d.kind) .. " promised to `" .. tostring(d.target) .. "`"
  elseif d.name or d.title then
    line = line .. ": " .. tostring(d.name or d.title)
  end
  if #f.because > 0 then
    local links = {}
    for i, id in ipairs(f.because) do links[i] = "[" .. id .. "](#" .. anchor(id) .. ")" end
    line = line .. " — because " .. table.concat(links, ", ")
  end
  return line
end

-- The bible of `addr` (generated first if needed) as Markdown text.
function bible.export(G, addr)
  G:generate(addr)
  local out = {
    "# World bible: " .. address.describe(G.scheme, addr), "",
    string.format("Root seed %d · generator version %d · mods: %s", G.seed, G.version,
                  #G.mods > 0 and table.concat(G.mods, ", ") or "none"), "",
  }
  for _, a in ipairs(address.path(addr)) do
    local node = G.nodes[a]
    out[#out + 1] = "## " .. address.describe(G.scheme, a)
    out[#out + 1] = ""
    out[#out + 1] = string.format("Seed %d · version %d", node.seed, node.version)
    out[#out + 1] = ""
    local describe = G.registry.levels[node.level].describe
    if describe then
      out[#out + 1] = describe(node)
      out[#out + 1] = ""
    end
    if next(node.summary) then
      out[#out + 1] = "### Summary"
      render(node.summary, "", out, 0)
      out[#out + 1] = ""
    end
    if next(node.data) then
      out[#out + 1] = "### Generated"
      render(node.data, "", out, 0)
      out[#out + 1] = ""
    end
    if next(node.children) then
      local n = 0
      for _ in pairs(node.children) do n = n + 1 end
      out[#out + 1] = string.format("### Places inside (%d)", n)
      for _, i in ipairs(util.sorted_keys(node.children)) do
        local s = node.children[i]
        out[#out + 1] = "- `" .. address.child(G.scheme, a, i) .. "`" .. (s.name and (" " .. tostring(s.name)) or "")
      end
      out[#out + 1] = ""
    end
    if #node.fact_order > 0 then
      out[#out + 1] = "### Facts"
      for _, id in ipairs(node.fact_order) do
        local f = node.facts[id]
        out[#out + 1] = fact_line(f)
        if next(f.data) and f.kind ~= "commitment" then render(f.data, "  ", out, 1) end
        if f.members then out[#out + 1] = "  - shared by: " .. table.concat(f.members, ", ") end
      end
      out[#out + 1] = ""
    end
    local honoured = util.sorted_keys(node.honoured)
    if #honoured > 0 then
      out[#out + 1] = "### Promises kept"
      for _, cid in ipairs(honoured) do
        out[#out + 1] = string.format("- [%s](#%s) by [%s](#%s)", cid, anchor(cid), node.honoured[cid],
                                      anchor(node.honoured[cid]))
      end
      out[#out + 1] = ""
    end
  end
  return table.concat(out, "\n")
end

-- Command line: --bible ADDRESS --out FILE [--seed N]
function bible.cli(registry, run)
  local addr = mvl.option("bible")
  local seed = tonumber(mvl.option("seed") or "") or 1
  local G = run.new(registry, { seed = math.floor(seed) })
  local ok, text = pcall(bible.export, G, addr)
  if not ok then
    mvl.log("bible: " .. tostring(text))
    error(text, 0)
  end
  if mvl.option("out") then
    assert(mvl.write_option_file("out", text), "could not write " .. mvl.option("out"))
    mvl.log("bible of " .. (addr == "" and "the multiverse" or addr) .. " written to " .. mvl.option("out"))
  else
    print(text)
  end
  mvl.quit()
  return text
end

bible.facts = facts
return bible
