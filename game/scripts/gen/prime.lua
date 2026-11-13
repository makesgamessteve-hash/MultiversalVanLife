-- Multiversal Van Life - the Prime universe (MIT).
--
-- Universe 0 is ours, and it is never generated: physics without magic or
-- psionics, the Milky Way, the Sun with its real planets and the Moon. Its
-- data is written here by hand. Earth's history, peoples, religions and
-- cultures are never generated or simulated; only the player's farm and its
-- rural surroundings exist below Earth (phase 8).
local prime = {}

prime.UNIVERSE = "u0"
prime.GALAXY = "u0.g0"
prime.NEIGHBOURHOOD = "u0.g0.c0"
prime.SOLAR_SYSTEM = "u0.g0.c0.s0"
prime.EARTH = "u0.g0.c0.s0.p2"
-- the only places generated below Earth: the farm (land 0) and the other
-- lands of its countryside
prime.FARM = "u0.g0.c0.s0.p2.k0.n0.l0"
prime.COUNTRYSIDE = "u0.g0.c0.s0.p2.k0.n0"

prime.universe = {
  name = "Prime",
  laws = { magic = "none", magic_strength = 0, psionics = 0, ftl = "none", gods = "silent" },
  age = 13.8, -- billions of years
}

prime.milky_way = {
  name = "Milky Way", morphology = "barred", arms = 4, radius = 15.0, bulge = 1.5, bar = 4.5,
  age = 13.6, sun_distance = 8.2, -- kiloparsecs
}

prime.neighbourhood = { name = "Solar neighbourhood", kind = "field", age = 4.6, metallicity = 0.0 }

prime.sun = { name = "Sun", class = "G", subclass = "G2V", mass = 1.0, luminosity = 1.0, age = 4.6,
              metallicity = 0.0, temperature = 5772 }

-- Semi-major axes in AU, sidereal periods in Earth years, masses in Earth
-- masses, mean radii in Earth radii.
prime.planets = {
  { name = "Mercury", kind = "rocky", a = 0.387, period = 0.2408, mass = 0.0553, radius = 0.383, moons = {} },
  { name = "Venus", kind = "rocky", a = 0.723, period = 0.6152, mass = 0.815, radius = 0.949, moons = {} },
  { name = "Earth", kind = "rocky", a = 1.000, period = 1.0000, mass = 1.0, radius = 1.0,
    moons = { { name = "Moon", a = 384400, period = 27.3217 } } },
  { name = "Mars", kind = "rocky", a = 1.524, period = 1.8808, mass = 0.107, radius = 0.532,
    moons = { { name = "Phobos", a = 9376, period = 0.3189 }, { name = "Deimos", a = 23463, period = 1.2624 } } },
  { name = "Jupiter", kind = "gas_giant", a = 5.203, period = 11.862, mass = 317.8, radius = 11.21,
    moons = { { name = "Io", a = 421700, period = 1.769 }, { name = "Europa", a = 671034, period = 3.551 },
              { name = "Ganymede", a = 1070412, period = 7.155 }, { name = "Callisto", a = 1882709, period = 16.689 } } },
  { name = "Saturn", kind = "gas_giant", a = 9.537, period = 29.457, mass = 95.16, radius = 9.45,
    moons = { { name = "Titan", a = 1221870, period = 15.945 }, { name = "Enceladus", a = 237948, period = 1.370 } } },
  { name = "Uranus", kind = "ice_giant", a = 19.19, period = 84.02, mass = 14.54, radius = 4.01,
    moons = { { name = "Titania", a = 435910, period = 8.706 }, { name = "Oberon", a = 583520, period = 13.463 } } },
  { name = "Neptune", kind = "ice_giant", a = 30.07, period = 164.8, mass = 17.15, radius = 3.88,
    moons = { { name = "Triton", a = 354759, period = -5.877 } } },
}
-- moon orbits: a in km, period in days (negative: retrograde)

prime.belts = {
  { name = "Asteroid belt", inner = 2.2, outer = 3.3 },
  { name = "Kuiper belt", inner = 30.0, outer = 50.0 },
}

-- True for the Prime universe and everything in it.
function prime.inside(addr) return addr == prime.UNIVERSE or addr:sub(1, 3) == "u0." end

-- May this place inside Prime exist? Only Prime's fixed places, the path to
-- the farm and the lands of its countryside do.
function prime.allowed(addr)
  return addr == prime.COUNTRYSIDE or prime.COUNTRYSIDE:sub(1, #addr + 1) == addr .. "." or
         addr:sub(1, #prime.COUNTRYSIDE + 2) == prime.COUNTRYSIDE .. ".l"
end

-- Prime has no generated lore: no eras, history, factions, religions,
-- species or cultures. Asking for it returns nothing.
function prime.lore() return {} end

return prime
