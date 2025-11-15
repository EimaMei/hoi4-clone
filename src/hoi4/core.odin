package hoi4

import "base:runtime"
import "core:mem"
import "core:log"



GlobalState :: struct {
	filepath: string,

	alloc_strings: runtime.Allocator,

	logger_backend: log.Logger,
	alloc_strings_backend: mem.Dynamic_Arena,

	m: Map,
	ideologies: Ideologies,
	gs: GraphicsContext,

	player: ^Country,
	selected_state: ^State,
}



globalState_init:: proc(g: ^GlobalState, root_path: string) {
	g.filepath = root_path

	mem.dynamic_arena_init(&g.alloc_strings_backend)
	g.alloc_strings = mem.dynamic_arena_allocator(&g.alloc_strings_backend)

	g.logger_backend = log.create_console_logger()
}

globalState_free:: proc(g: ^GlobalState) {
	mem.dynamic_arena_destroy(&g.alloc_strings_backend)
	log.destroy_console_logger(g.logger_backend)

	g^ = {}
}
