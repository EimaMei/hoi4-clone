package hoi4

import "core:log"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"



GL_VERSION_MAJOR :: 4
GL_VERSION_MINOR :: 3


Vertex :: struct {
	pos: glm.vec2,
}

GraphicsContext :: struct {
	shader_state: Shader,
	shader_stencil: Shader,

	state_VAO: u32,

	state_VBO: u32,
	state_vertices: [dynamic]Vertex,

	state_IBO: u32,
	state_indirect_cmds: [dynamic]gl.DrawArraysIndirectCommand,

	u_transform: matrix[4, 4]f32,
}


graphics_make :: proc(gs: ^GraphicsContext, window_res: [2]int) -> bool {
	res: bool = ---

	gs.shader_state, res = shader_make(#load("../../res/shaders/state_v.glsl"), #load("../../res/shaders/state_f.glsl"))
	if (!res) { return false }

	gs.shader_stencil, res = shader_make(#load("../../res/shaders/stencil_v.glsl"), #load("../../res/shaders/stencil_f.glsl"))
	if (!res) { return false }

	shader_use(gs.shader_state)

	gl.GenVertexArrays(1, &gs.state_VAO)
	gl.BindVertexArray(gs.state_VAO)

	buffers: [2]u32
	gl.GenBuffers(len(buffers), raw_data(buffers[:]))
	gs.state_VBO = buffers[0]
	gs.state_IBO = buffers[1]

	gl.Viewport(0, 0, i32(window_res.x), i32(window_res.y))
	gs.u_transform = {
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1
	}

	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LESS)
	gl.Enable(gl.STENCIL_TEST)
	gl.StencilFunc(gl.NOTEQUAL, 1, 0xFF)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.REPLACE)

	return true
}

graphics_free :: proc(gs: ^GraphicsContext) {
	shader_destroy(&gs.shader_state)
	shader_destroy(&gs.shader_stencil)
	gl.DeleteVertexArrays(1, &gs.state_VAO)

	buffers := [2]u32{gs.state_VBO, gs.state_IBO}
	gl.DeleteBuffers(len(buffers), raw_data(buffers[:]))

	if (gs.state_indirect_cmds != nil) { delete(gs.state_indirect_cmds) }
	if (gs.state_vertices != nil) { delete(gs.state_vertices) }

	gs^ = {}
	log.infof("Freed graphics")
}


graphics_render :: proc(gs: ^GraphicsContext, m: Map, bg: [4]f32) {
	gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)


	ortho := glm.mat4Ortho3d(0, f32(1280.0), f32(720.0), 0, 0, 1)

	shader_use(gs.shader_state)
	shader_uniformSet(gs.shader_state, "u_transform", ortho * gs.u_transform)

	gl.StencilFunc(gl.ALWAYS, 1, 0xFF)
	gl.StencilMask(0xFF)

	gl.BindVertexArray(gs.state_VAO)
	gl.MultiDrawArraysIndirect(gl.LINES, nil, i32(len(gs.state_indirect_cmds)), 0)

	//gl.StencilFunc(gl.NOTEQUAL, 1, 0xFF)
	//gl.StencilMask(0x00)
	//gl.Disable(gl.DEPTH_TEST)
	//shader_use(gs.shader_stencil)

	//shader_uniformSet(gs.shader_stencil, "u_transform", ortho * gs.u_transform * glm.mat4Translate({-50, 0, 0}) * glm.mat4Scale({1.05, 1.05, 0}))
	//gl.BindVertexArray(gs.state_VAO)
	//gl.MultiDrawArraysIndirect(gl.LINES, nil, i32(len(gs.state_indirect_cmds)), 0)

	//gl.StencilMask(0xFF)
	//gl.StencilFunc(gl.ALWAYS, 0, 0xFF)
	//gl.Enable(gl.DEPTH_TEST)
}

graphics_stateInit :: proc(gs: ^GraphicsContext, m: Map) {
	gs.state_indirect_cmds = make(type_of(gs.state_indirect_cmds), len(m.states))
	gs.state_vertices = make(type_of(gs.state_vertices), 0, len(m.states) * 2 * 32)

	points: [2][2]int = {{0, 0}, {-1, 0}}
	res: bool = ---
	u_color: [256][4]f32 = ---

	for s, i in m.states {
		vertex_start := len(gs.state_vertices)
		for true {
			points[1].x += 1
			points, res = map_stateGetPoints(s.color, m, points[1])
			if !res { break }

			append(
				&gs.state_vertices,
				Vertex{ {f32(points[0][0]), f32(points[0][1])} },
				Vertex{ {f32(points[1][0]), f32(points[1][1])} }
			)
		}

		gs.state_indirect_cmds[i] = {
			count = u32(len(gs.state_vertices) - vertex_start),
			instanceCount = 1,
			first = u32(vertex_start),
			baseInstance = u32(i)
		}
		u_color[i] = s.owner.color
	}


	gl.BindBuffer(gl.ARRAY_BUFFER, gs.state_VBO)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(gs.state_vertices) * size_of(gs.state_vertices[0]),
		raw_data(gs.state_vertices),
		gl.STATIC_DRAW
	)

	gl.BindBuffer(gl.DRAW_INDIRECT_BUFFER, gs.state_IBO)
	gl.BufferData(
		gl.DRAW_INDIRECT_BUFFER,
		len(gs.state_indirect_cmds) * size_of(gs.state_indirect_cmds[0]),
		raw_data(gs.state_indirect_cmds),
		gl.STATIC_DRAW
	)

	// TODO(EimaMei): Make this autogen, check GB's code from discord
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
	gl.EnableVertexAttribArray(0)
	shader_uniformSet(gs.shader_state, "u_color[0]", u_color[:])

	log.infof("Initialized map graphics")
}






graphics_stateSetColor :: proc {
	graphics_stateSetColor_vec4,
	graphics_stateSetColor_color
}

graphics_stateSetColor_vec4 :: #force_inline proc(gs: ^GraphicsContext, s: State, color: [4]f32) {
	shader_uniformSet_index(gs.shader_state, "u_color[0]", s.vertex_id, color)
}

graphics_stateSetColor_color :: #force_inline proc(gs: ^GraphicsContext, s: State, color: Color) {
	clr := [4]f32{f32(color.r), f32(color.g), f32(color.b), 255}
	clr /= 255
	graphics_stateSetColor_vec4(gs, s, clr)
}


texture_make :: proc(data: ^u8, width, height, channels: int) -> (tex: u32) {
	@(static) internal_format_LUT := []i32{gl.R8, gl.RG8, gl.RGB8, gl.RGBA8}
	@(static) format_LUT := []u32{gl.RED, gl.RG, gl.RGB, gl.RGBA}

	gl.GenTextures(1, &tex)
	gl.BindTexture(gl.TEXTURE_2D, tex)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S,     gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T,     gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
	gl.PixelStorei(gl.UNPACK_ROW_LENGTH, i32(width))

	gl.TexImage2D(
		gl.TEXTURE_2D, 0, internal_format_LUT[channels - 1],
		i32(width), i32(height), 0, format_LUT[channels - 1],
		gl.UNSIGNED_BYTE, data
	)

	return
}
