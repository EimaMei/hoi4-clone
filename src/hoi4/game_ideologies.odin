package hoi4

import "core:strings"
import "core:log"
import "core:encoding/json"
import os "core:os/os2"


Ideologies :: struct {
	parent_ideologies: [dynamic]ParentIdeology,
	ideologies: [dynamic]Ideology
}

ParentIdeology :: struct {
	namespace: string,
	color: [4]f32
}

Ideology :: struct {
	namespace: string,
	parent: ^ParentIdeology,
	color: [4]f32,
}


ideologies_make :: proc(i: ^Ideologies, g: GlobalState) -> bool {
	i.parent_ideologies = make(type_of(i.parent_ideologies))
	i.ideologies = make(type_of(i.ideologies))
	filepath := createFullPath(g, "history/ideologies.json")

	data, err := os.read_entire_file_from_path(filepath, context.temp_allocator)
	if err != nil {
		log.errorf("Failed to read '%s': %s", filepath, err)
		return false
	}

	json_data, json_error := json.parse(data, allocator = context.temp_allocator)
	if err != nil {
		log.errorf("Failed to parse '%s': %s", filepath, err)
		return false
	}

	parent_ideologies_LUT := make(map[string]^ParentIdeology)
	reserve(&parent_ideologies_LUT, 32)
	defer delete(parent_ideologies_LUT)

	root := json_data.(json.Object)

	for namespace, value in root["parents"].(json.Object) {
		parent: ParentIdeology
		parent.namespace = strings.clone(namespace, g.alloc_strings)

		color, is_successful := jsonFindColor_vec4(filepath, value.(json.Object)["color"])
		if (!is_successful) { continue }

		append(&i.parent_ideologies, parent)
		parent_ideologies_LUT[parent.namespace] = &i.parent_ideologies[len(i.parent_ideologies) - 1]
	}
	log.infof("Created '%i' parent ideologies", len(i.parent_ideologies))

	for namespace, value in root["ideologies"].(json.Object) {
		ideology: Ideology
		ideology.namespace = strings.clone(namespace, g.alloc_strings)

		color, is_successful := jsonFindColor_vec4(filepath, value.(json.Object)["color"])
		if (!is_successful) { continue }

		parent_string, is_string := jsonGetField(value.(json.Object), filepath, "parent", string)
		if (!is_string) { continue }

		ideology.parent = parent_ideologies_LUT[parent_string]
		append(&i.ideologies, ideology)
	}
	log.infof("Created '%i' regular ideologies", len(i.ideologies))

	free_all(context.temp_allocator)
	return true
}

ideologies_delete :: proc(i: ^Ideologies) {
	if i.parent_ideologies != nil {
		delete(i.parent_ideologies)
	}
	if i.ideologies != nil {
		delete(i.ideologies)
	}

	i^ = {}
	log.info("Destroyed all ideologies")
}
