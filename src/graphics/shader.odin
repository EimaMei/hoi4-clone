package hoi4

import "core:log"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"


Shader :: struct {
	program: u32,
	uniforms: map[string]gl.Uniform_Info
}


shader_make :: proc(vertex_shader, fragment_shader: string) -> (s: Shader, res: bool) {
	s.program, res = gl.load_shaders_source(vertex_shader, fragment_shader)
	if !res {
		log.error("Failed to load shaders")
		res = false
		return
	}

	s.uniforms = gl.get_uniforms_from_program(s.program)
	res = true
	return
}

shader_destroy :: proc(s: ^Shader) {
	gl.destroy_uniforms(s.uniforms)
	gl.DeleteProgram(s.program)

	s^ = {}
}


shader_use :: proc(s: Shader) {
	gl.UseProgram(s.program)
}


shader_uniformSet :: proc {
	shader_uniformSet_matrix,
	//shader_uniformSet_matrix_arr,
	shader_uniformSet_vec4,
	shader_uniformSet_vec4_arr,
}


shader_uniformSet_matrix :: #force_inline proc(s: Shader, $uniform_name: string, m: matrix[4, 4]f32) {
	f := transmute([16]f32)(m)
	gl.UniformMatrix4fv(s.uniforms[uniform_name].location, 1, false, raw_data(f[:]))
}

shader_uniformSet_vec4 :: #force_inline proc(s: Shader, $uniform_name: string,
		v: [4]f32) {
	shader_uniformSet_index(s, uniform_name, 0, v)
}

shader_uniformSet_vec4_arr :: #force_inline proc(s: Shader, $uniform_name: string,
		v: [][4]f32) {
	shader_uniformSet_index(s, uniform_name, 0, v)
}


shader_uniformSet_index :: proc {
	shader_uniformSet_index_vec4,
	shader_uniformSet_index_vec4_arr,
}

shader_uniformSet_index_vec4 :: #force_inline proc(s: Shader, $uniform_name: string,
		i: int, v: [4]f32) {
	v := v
	gl.Uniform4fv(s.uniforms[uniform_name].location + i32(i), 1, raw_data(&v))
}

shader_uniformSet_index_vec4_arr :: #force_inline proc(s: Shader, $uniform_name: string,
		i: int, v: [][4]f32) {
	gl.Uniform4fv(s.uniforms[uniform_name].location + i32(i), i32(len(v)), raw_data(&v[0]))
}
