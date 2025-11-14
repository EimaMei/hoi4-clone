package hoi4

import "base:runtime"

import "core:mem"
import "core:strings"
import "core:fmt"
import "core:encoding/json"
import "core:log"
import "vendor:stb/image"

import os "core:os/os2"



Color :: [3]u8

Map :: struct {
	width, height: int,
	data: [^]Color,

	countries: [dynamic]Country,
	countries_LUT: map[[3]u8]^Country,

	states: [dynamic]State,
	states_LUT: map[Color]^State,
}

City :: struct {
	population: int
}

State :: struct {
	id: int,
	vertex_id: int,

	namespace: string,
	color: Color,
	owner: ^Country,

	cities: []^City,
}

Country :: struct {
	tag: [3]u8,
	id: int,

	color: [4]f32,

	states: []^State,
}



map_make :: proc(m: ^Map, g: GlobalState) {
	res := map_initImage(m, g)
	map_initCountries(m, g)
	map_initStates(m, g)

	free_all(context.temp_allocator)
	return
}


map_delete :: proc(m: ^Map) {
	map_destroyImage(m)
	map_destroyCountry(m)
	map_destroyStates(m)
}



map_initImage :: proc(m: ^Map, g: GlobalState) -> bool {
	filepath := createFullPath_cstr(g, "map/provinces.bmp")

	width, height: i32
	data := image.load(strings.unsafe_string_to_cstring(filepath), &width, &height, nil, 3)
	if data == nil {
		log.errorf("Failed to load '%s' image (%ix%i)", filepath, m.width, m.height)
		return false
	}

	m.data = transmute([^]Color)data
	m.width = int(width)
	m.height = int(height)

	log.infof("Loaded '%s' image (%ix%i)", filepath, m.width, m.height)
	return true
}

map_destroyImage :: proc(m: ^Map) {
	if m.data != nil {
		image.image_free(m.data)
		m.data = nil
		m.width = 0
		m.height = 0
	}

	log.infof("Destroyed image")
}


map_initCountries :: proc(m: ^Map, g: GlobalState) {
	m.countries = make(type_of(m.countries))

	w := os.walker_create(createFullPath(g, "map/countries"))
	defer os.walker_destroy(&w)

	for info in os.walker_walk(&w) {
		path: string = ---
		root, is_parsed := jsonParseFile(&w, info, &path)
		if (!is_parsed) { continue }

		tag, is_string := root["tag"].(string)
		if !is_string {
			log.errorf("Field 'tag' is not a string for '%s': %v", path, tag)
		}

		color, res := jsonFindColor_vec4(path, root["color"])
		if !res {
			continue
		}

		c: Country
		c.tag = {tag[0], tag[1], tag[2]}
		c.color = color
		append(&m.countries, c)

		free_all(context.temp_allocator)
	}

	if path, err := os.walker_error(&w); err != nil {
		log.errorf("Failed to walk '%s': %v", path, err)
	}

	m.countries_LUT = make(type_of(m.countries_LUT))
	reserve(&m.countries_LUT, len(m.countries))

	for &c, i in m.countries {
		if c.tag in m.countries_LUT {
			log.errorf("Tag '%s' already exists", c.tag)
			continue
		}
		m.countries_LUT[c.tag] = &c
	}

	log.infof("Loaded '%i' countries", len(m.countries))
}

map_destroyCountry :: proc(m: ^Map) {
	if (m.countries != nil) { delete(m.countries) }
	if (m.countries_LUT != nil) { delete(m.countries_LUT) }

	log.infof("Destroyed countries")
}


map_initStates :: proc(m: ^Map, g: GlobalState) {
	m.states = make(type_of(m.states))

	w := os.walker_create(createFullPath(g, "map/states"))
	defer os.walker_destroy(&w)

	for info in os.walker_walk(&w) {
		path: string = ---
		root, is_parsed := jsonParseFile(&w, info, &path)
		if (!is_parsed) { continue }

		owner, is_string := root["owner"].(string)
		if !is_string {
			log.errorf("Field 'owner' is not a string for '%s': %v", path, owner)
			continue
		}

		id, is_f64 := root["id"].(f64)
		if !is_string {
			log.errorf("Field 'id' is not a valid integer for '%s': %v", path, id)
			continue
		}

		namespace: string = ---
		namespace, is_string = root["name"].(string)
		if !is_string {
			log.errorf("Field 'owner' is not a string for '%s': %v", path, owner)
			continue
		}

		color, res := jsonFindColor(path, root["color"])
		if (!res) { continue }

		s: State
		s.id = int(id)
		s.namespace = strings.clone(namespace, g.alloc_strings)
		s.color = color
		s.owner = map_findCountry(m^, {owner[0], owner[1], owner[2]})

		append(&m.states, s)
		free_all(context.temp_allocator)
	}

	if path, err := os.walker_error(&w); err != nil {
		log.errorf("Failed to walk '%s': %v", path, err)
	}

	m.states_LUT = make(type_of(m.states_LUT))
	reserve(&m.states_LUT, len(m.states))

	for &s, i in m.states {
		s.vertex_id = i
		m.states_LUT[s.color] = &s
	}

	log.infof("Created '%i' states", len(m.states))
}


map_destroyStates :: proc(m: ^Map) {
	if (m.states != nil) { delete(m.states) }
	if (m.states_LUT != nil) { delete(m.states_LUT) }

	log.infof("Destroyed states")
}




map_stateGetPoints :: proc(target: Color, m: Map, start: [2]int) -> ([2][2]int, bool) {
	start := start
	points := [2][2]int{{m.width, m.height}, {m.width - 1, m.height - 1}}
	found := false

	loop: for y in start.y..< m.height {
		for x in start.x..< m.width {
			a := target
			b := map_getPixel(m, {x, y})
			if !(a.r == b.r && a.g == b.g && a.b == b.b) {
				continue
			}
			points[0] = {x, y}
			found = true
			break loop
		}

		start.x = 0
	}

	for x in points[0].x + 1..< m.width {
		a := target
		b := map_getPixel(m, {x, points[0].y})
		if (a.r == b.r && a.g == b.g && a.b == b.b) {
			continue
		}
		points[1] = {x, points[0].y}
		found = false
		return points, true
	}

	if found {
		return {points[0], {m.width - 1, start.y}}, true
	}

	return {{1, 0}, {-1, 0}}, false
}


map_findCountry :: #force_inline proc(m: Map, tag: [3]u8) -> ^Country {
	return m.countries_LUT[tag]
}

map_getPixel :: proc(m: Map, pos: [2]int) -> Color {
	return m.data[pos.y * m.width + pos.x]
}
