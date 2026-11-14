-- Multiversal Van Life - calendars and holidays (MIT).
--
-- A culture counts days by its world's turning (on a tidally locked world,
-- by sleeps of one standard day), years by its orbit, and months by its
-- most prominent moon: lunar where there are moons and mild seasons,
-- lunisolar where moons and strong seasons meet, solar without moons.
-- Months are named in its language. Holidays fall on astronomical dates
-- worked out from the same orbits the sky shows (gen/visuals/sky.lua):
-- solstices and equinoxes, full moons of every moon (and the nights when
-- two moons are full together), eclipse seasons; history adds
-- commemorations of its events (traditions.commemorate).
--
-- Dates: `t` is days from the start of the culture's year (its northern
-- spring equinox, or the first full moon on worlds without seasons), in
-- standard days; `day` is the day of the year in local days (from 1).
local dm = require("gen.dmath")
local language = require("gen.culture.language")

local CAL = {}
local TAU = 2 * dm.pi

local SEASON_WORDS = {
  { "seed", "rain", "flower", "dawn" }, { "sun", "fruit", "fire", "honey" },
  { "leaf", "ash", "mist", "wind" }, { "frost", "snow", "ice", "night" },
}

local function wrap(x) return x - TAU * math.floor(x / TAU) end

-- Synodic period (days) of a moon with sidereal period p on a year y.
function CAL.synodic(p, y)
  if p >= y then return p end
  return 1 / (1 / p - 1 / y)
end

-- Days (from absolute time 0) of the first time after t0 that the
-- elongation of moon m from the star equals `target` (pi: full, 0: new).
local function next_phase(S, m, year, target, t0)
  local delta0 = m.longitude0 - (S.longitude0 + dm.pi)
  local syn = CAL.synodic(m.period, year)
  local rate = TAU / syn
  local now = wrap(delta0 + rate * t0)
  local need = wrap(target - now)
  return t0 + need / rate, syn
end

-- The time (absolute days) of the first moment after t0 the star's
-- ecliptic longitude is `l`.
local function sun_at(S, year, l, t0)
  local now = wrap(S.longitude0 + dm.pi + TAU * t0 / year)
  return t0 + wrap(l - now) / TAU * year
end

-- The calendar of a culture: heavens H (gen.visuals.sky.heavens) and
-- language lang; `epoch` is an absolute time (days) inside the year to
-- describe.
function CAL.generate(H, lang, rng, epoch)
  local S = H.sky
  local year = H.year or 365.25
  -- days long against the year: count sleeps of one standard day instead
  local slow = H.locked or (H.day or 1) > year / 20
  local day = slow and 1 or (H.day or 1)
  local seasons = (H.tilt or 0) > 8
  local moons = S.moons or {}
  local main
  for i, m in ipairs(moons) do if not main or m.size > moons[main].size then main = i end end
  -- the start of the year
  local start
  if seasons then start = sun_at(S, year, 0, epoch - year)
  elseif main then start = next_phase(S, moons[main], year, dm.pi, epoch - year)
  else start = epoch - (epoch % year) end
  while start + year <= epoch do start = start + year end
  local cal = { day_length = day, year = dm.round(year, 4), days = math.max(1, math.floor(year / day + 0.5)),
                unit = slow and "sleep" or "day", start = dm.round(start, 4), holidays = {} }
  local function local_day(t) return math.floor(t / day) + 1 end
  -- months
  local months, kind
  if main then
    local syn = CAL.synodic(moons[main].period, year)
    local n = math.floor(year / syn + 0.5)
    if n >= 2 and n <= 30 then
      months, kind = n, seasons and "lunisolar" or "lunar"
      cal.month = dm.round(syn, 4)
    end
  end
  if not months then months, kind = seasons and 12 or 10, "solar" end
  months = math.min(months, math.floor(cal.days / 3))
  cal.kind = months >= 2 and kind or "single-season"
  cal.months = {}
  local used = {}
  for i = 1, math.min(months, 30) do
    local season = SEASON_WORDS[math.floor((i - 1) / math.max(1, months / 4)) % 4 + 1]
    local word = season[rng:int(1, #season)]
    for _ = 1, #season do
      if not used[word] then break end
      word = season[(rng:int(1, #season))]
    end
    used[word] = true
    local n = language.name(lang, rng, "place", { word, kind == "solar" and "season" or "moon", format = "%s %s" })
    cal.months[i] = { name = n.name, meaning = n.meaning }
  end
  if kind == "lunisolar" then cal.leap = "a thirteenth month every few years keeps the moons with the seasons" end
  local function add(name, meaning, t, kind2, extra)
    local h = { name = name, meaning = meaning, t = dm.round(t, 3), day = local_day(t), kind = kind2 }
    for k, v in pairs(extra or {}) do h[k] = v end
    cal.holidays[#cal.holidays + 1] = h
    return h
  end
  -- solstices and equinoxes
  if seasons then
    for _, e in ipairs({ { 0, { "seed", "day" }, "spring" }, { dm.pi / 2, { "sun", "day" }, "midsummer" },
                         { dm.pi, { "leaf", "day" }, "autumn" }, { 3 * dm.pi / 2, { "night", "day" }, "midwinter" } }) do
      local t = sun_at(S, year, e[1], start) - start
      local n = language.name(lang, rng, "place", { e[2][1], e[2][2], format = "%s %s" })
      add(n.name, n.meaning, t, e[3])
    end
  end
  -- full moons: a feast of every moon, and the nights two moons are full
  local fulls = {}
  for i, m in ipairs(moons) do
    local t, syn = next_phase(S, m, year, dm.pi, start)
    local list = {}
    local step = math.max(1, math.ceil((year / syn) / 13))
    local k = 0
    while t < start + year do
      k = k + 1
      if (k - 1) % step == 0 then list[#list + 1] = t - start end
      t = t + syn
    end
    fulls[i] = list
    local n = language.name(lang, rng, "god", { "moon", ({ "song", "dance", "blessing", "oath" })[math.min(i, 4)],
                                                 format = "%s %s" })
    for _, ft in ipairs(list) do add(n.name, n.meaning, ft, "full moon", { moon = i }) end
  end
  if #moons >= 2 then
    for _, a in ipairs(fulls[1]) do
      for _, b in ipairs(fulls[2]) do
        if math.abs(a - b) < 1 then
          local n = language.name(lang, rng, "place", { "twin", "light", format = "Night of the %s %s" })
          add(n.name, n.meaning, (a + b) / 2, "two full moons")
        end
      end
    end
  end
  -- eclipse seasons: new moons near the moon's nodes
  if main and moons[main].size >= S.star.size * 0.8 then
    local m = moons[main]
    local t, syn = next_phase(S, m, year, 0, start)
    while t < start + year do
      local lm = m.longitude0 + TAU * t / m.period
      if math.abs(dm.sin(lm)) < 0.25 then
        local n = language.name(lang, rng, "place", { "dark", "sun", format = "the %s %s" })
        add(n.name, n.meaning, t - start, "eclipse")
        break
      end
      t = t + syn
    end
  end
  table.sort(cal.holidays, function(a, b) return a.t < b.t end)
  return cal
end

-- The absolute time (days) of a holiday in the calendar's described year.
function CAL.when(cal, h) return cal.start + h.t end

-- A line for the bible.
function CAL.describe(cal)
  local names = {}
  for i = 1, math.min(#cal.months, 4) do names[i] = cal.months[i].name .. " (" .. cal.months[i].meaning .. ")" end
  local hs = {}
  local seen = {}
  for _, h in ipairs(cal.holidays) do
    if not seen[h.name] then
      seen[h.name] = true
      hs[#hs + 1] = string.format("%s \"%s\" (%s, %s %d)", h.name, h.meaning, h.kind, cal.unit, h.day)
    end
  end
  local months = #cal.months >= 2 and string.format(" in %d months (%s%s)", #cal.months, table.concat(names, ", "),
                                                     #cal.months > 4 and ", …" or "") or ""
  return string.format("a %s calendar of %d %ss%s; holidays: %s", cal.kind, cal.days, cal.unit, months,
                       #hs > 0 and table.concat(hs, "; ") or "none")
end

return CAL
