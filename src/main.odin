package main
import "hoi4"

import "core:log"
import glm "core:math/linalg/glsl"


main :: proc() {
	g: hoi4.GlobalState
	hoi4.globalState_init(&g, "game")
	defer hoi4.globalState_free(&g)
	context.logger = g.logger_backend

	m: hoi4.Map
	hoi4.map_make(&m, g)
	defer hoi4.map_delete(&m)

	ideologies: hoi4.Ideologies
	hoi4.ideologies_make(&ideologies, g)
	defer hoi4.ideologies_delete(&ideologies)

	win := hoi4.window_create(g, "name", {1280, 720}, {.VSync, .Debug})
	defer hoi4.window_close(win)

	gs: hoi4.GraphicsContext
	hoi4.graphics_make(&gs, {1280, 720})
	hoi4.graphics_stateInit(&gs, m)
	defer hoi4.graphics_free(&gs)

	hoi4.window_show(win)

	g.player = hoi4.map_findCountry(m, "LIT")

	for !hoi4.window_isClosed(win) {
		state := hoi4.window_pollEvents(win)

		c := [2]f32{f32(state.mouse_pos.x), f32(state.mouse_pos.y)}

		if (.MouseScroll in win.events) && state.mouse_scroll.y != 0 {
			zoom: f32 = (state.mouse_scroll.y > 0) ? 1.05 : (1.0/1.05)
			shift := glm.mat4Translate({c.x, c.y, 0})
			scale := glm.mat4Scale({zoom, zoom, 0})
			shift_back := glm.mat4Translate({-c.x, -c.y, 0})
			gs.u_transform *= shift * scale * shift_back
		}

		loop: if .MousePress in win.events {
			c_4x := gs.u_transform * [4]f32{c.x, 720 - c.y, 0, 1}
			c_4x.x = (c_4x.x * 0.5 + 0.5) * 1280.0
			c_4x.y = (c_4x.y * 0.5 + 0.5) * 720.0
			clr := hoi4.map_getPixel(m, {int(c_4x.x), int(c_4x.y)})

			s := g.selected_state
			if s != nil {
				hoi4.graphics_stateSetColor(&gs, g.selected_state^, s.owner.color)
			}

			g.selected_state = m.states_LUT[clr]
			if g.selected_state == nil { break loop }

			s = g.selected_state
			hoi4.graphics_stateSetColor(&gs, g.selected_state^, clr)

			log.infof("Clicked state: %v %v %s", s.id, s.namespace, s.owner.tag)
		}


		hoi4.graphics_render(&gs, {0.1, 0.2, 0.2, 1.0})
		hoi4.window_swapBuffers(win)
	}
}
