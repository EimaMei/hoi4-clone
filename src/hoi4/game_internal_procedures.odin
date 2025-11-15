#+private
package hoi4

import "core:strings"
import "core:encoding/json"
import "core:log"
import os "core:os/os2"


createFullPath :: proc(g: GlobalState, path: string) -> string {
	b := strings.builder_make(0, len(g.filepath) + 1 + len(path), context.temp_allocator)
	strings.write_string(&b, g.filepath)
	strings.write_byte(&b, '/')
	strings.write_string(&b, path)
	return strings.to_string(b)
}

createFullPath_cstr :: proc(g: GlobalState, path: string) -> string {
	b := strings.builder_make(0, len(g.filepath) + 1 + len(path) + 1, context.temp_allocator)
	strings.write_string(&b, g.filepath)
	strings.write_byte(&b, '/')
	strings.write_string(&b, path)
	strings.write_byte(&b, 0)
	return strings.to_string(b)
}


jsonGetField :: proc(root: json.Object, path: string, $field: string, $T: typeid) -> (res: T, is_successful: bool) {
	if root[field] == nil {
		log.errorf("Field '%s' does not exist for '%s'", field, path)
		is_successful = false
		return
	}

	value, is_type := root[field].(T)
	if !is_type {
		log.errorf("Field '%s' is not a valid type (%v) for '%s': %v", field, typeid_of(T), path, value)
		is_successful = false
		return
	}

	res = value
	is_successful = true
	return
}

jsonParseFile :: proc(w: ^os.Walker, info: os.File_Info, out_path: ^string) -> (root: json.Object, res: bool) {
	data: []u8 = ---

	path, err := os.walker_error(w)
	if err != nil {
		log.errorf("Failed to walk '%s': %s", path, err)
		res = false
		return
	}

	if !strings.has_suffix(info.fullpath, ".json") {
		res = false
		return
	}

	data, err = os.read_entire_file_from_path(info.fullpath, context.temp_allocator)
	if err != nil {
		log.errorf("Failed to read '%s': %s", path, err)
		res = false
		return
	}

	json_data, json_error := json.parse(data, allocator = context.temp_allocator)
	if err != nil {
		log.errorf("Failed to parse '%s': %s", path, json_error)
		res = false
		return
	}

	root = json_data.(json.Object)
	res = true
	out_path^ = path
	return
}

jsonFindColor :: proc(path: string, root_color: json.Value) -> (res: Color, is_successful: bool) {
	if root_color == nil {
		log.errorf("Field 'color' doesn't exist for '%s': %v", path, root_color)
		is_successful = false
		return
	}

	color_array, is_an_array := root_color.(json.Array)
	if !is_an_array || len(color_array) != 3 {
		log.errorf("Field 'color' isn't an array of 3 for '%s': %v", path, color_array)
		is_successful = false
		return
	}

	for i in 0..<3 {
		value, is_f64 := color_array[i].(f64)
		if !is_f64 {
			log.errorf("Field 'color' has an invalid value '%v' for '%s': %v", color_array[i], path, color_array)
			is_successful = false
			return
		}

		res[i] = u8(value)
		if res[i] < 0 || res[i] > 255 {
			log.warnf("Field 'color' has an integer not in the 0-255 interval for '%s': %v", color_array[i], path, color_array)
		}
	}

	is_successful = true
	return
}

jsonFindColor_vec4 :: #force_inline proc(path: string, root_color: json.Value) -> (res: [4]f32, ok: bool) {
	c, is_successful := jsonFindColor(path, root_color)
	res = {f32(c.r), f32(c.g), f32(c.b), 255}
	res /= 255
	ok = is_successful
	return
}

