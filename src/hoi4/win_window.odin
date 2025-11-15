package hoi4

import "base:runtime"

import "core:log"
import "core:fmt"
import "core:strings"

import "vendor:glfw"
import gl "vendor:OpenGL"


WindowFlag :: enum {
	Fullscreen, Debug, VSync, Resizable, Visible,
}
WindowFlags :: bit_set[WindowFlag]


WindowEvent :: enum {
	WindowResize,

	MouseMove,
	MousePress,
	MouseScroll
}
WindowEvents :: bit_set[WindowEvent]


WindowState :: struct {
	window_area: [2]int,

	mouse_pos: [2]int,
	mouse_scroll: [2]f32
}


Window :: struct {
	handle: glfw.WindowHandle,

	events: WindowEvents,
	state: WindowState,
}


Keycode :: int
MouseButton :: enum {
	MouseButton_Left = 0,
}

window_create :: proc(g: GlobalState, name: string, res: [2]int, flags := WindowFlags{.VSync}) -> (win: ^Window) {
	{
		assert(res.x > 0 && res.x <= int(max(i32)))
		assert(res.y > 0 && res.y <= int(max(i32)))
		error_callback :: proc "c" (code: i32, desc: cstring) {
			context = runtime.default_context()
			fmt.println(desc, code)
		}
		glfw.SetErrorCallback(error_callback)
	}

	if !glfw.Init() { panic("EXIT_FAILURE") }

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_VERSION_MAJOR)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_VERSION_MINOR)
	glfw.WindowHint(glfw.RESIZABLE, i32(.Resizable in flags))
	glfw.WindowHint(glfw.VISIBLE, i32(.Visible in flags))

	win = new(Window)
	win.handle = glfw.CreateWindow(
		i32(res.x), i32(res.y),
		strings.clone_to_cstring(name, context.temp_allocator), nil, nil
	)
	if win.handle == nil { panic("EXIT_FAILURE") }

	{
		window_resize_callback :: proc "c" (glfw_window: glfw.WindowHandle, width, height: i32) {
			win := cast(^Window)glfw.GetWindowUserPointer(glfw_window)
			win.events |= {WindowEvent.WindowResize}
			win.state.window_area = {int(width), int(height)}
		}


		mouse_move_callback :: proc "c" (glfw_window: glfw.WindowHandle, xoffset: f64, yoffset: f64) {
			win := cast(^Window)glfw.GetWindowUserPointer(glfw_window)
			win.events |= {WindowEvent.MouseMove}
			win.state.mouse_pos = {int(xoffset), int(yoffset)}
		}
		mouse_press_callback :: proc "c" (glfw_window: glfw.WindowHandle, button, action, mods: i32) {
			win := cast(^Window)glfw.GetWindowUserPointer(glfw_window)
			if (action == glfw.PRESS) {
				win.events |= {WindowEvent.MousePress}
			}
		}
		mouse_scroll_callback :: proc "c" (glfw_window: glfw.WindowHandle, xoffset: f64, yoffset: f64) {
			win := cast(^Window)glfw.GetWindowUserPointer(glfw_window)
			win.events |= {WindowEvent.MouseScroll}
			win.state.mouse_scroll = {f32(xoffset), f32(yoffset)}
		}


		glfw.SetWindowUserPointer(win.handle, win)

		glfw.SetWindowSizeCallback(win.handle, window_resize_callback)

		glfw.SetCursorPosCallback(win.handle, mouse_move_callback)
		glfw.SetMouseButtonCallback(win.handle, mouse_press_callback)
		glfw.SetScrollCallback(win.handle, mouse_scroll_callback)
	}

	glfw.MakeContextCurrent(win.handle)
	glfw.SwapInterval(i32(.VSync in flags))


	gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, glfw.gl_set_proc_address)
	if .Debug in flags {
		gl.Enable(gl.DEBUG_OUTPUT)
		default_logger_backend = context.logger

		DebugCallback :: proc "c" (source: u32, type: u32, id: u32, severity: u32,
				length: i32, message: cstring, userParam: rawptr) {
			if severity == gl.DEBUG_SEVERITY_NOTIFICATION { return }
			context = runtime.default_context()
			context.logger = default_logger_backend
			log.infof("GL DEBUG: %s %s %i %s: %s", gl.GL_Enum(source), gl.GL_Enum(type), gl.GL_Enum(id), gl.GL_Enum(severity), message)
		}
		gl.DebugMessageCallback(DebugCallback, nil)
	}

	return
}

window_close :: proc(win: ^Window) {
	glfw.DestroyWindow(win.handle)
	free(win)

	glfw.Terminate()
}


window_pollEvents :: proc(win: ^Window) -> ^WindowState {
	win.events = {}
	glfw.PollEvents()

	return &win.state
}


window_swapBuffers :: proc(win: ^Window) {
	glfw.SwapBuffers(win.handle)
}


window_show :: proc(win: ^Window) {
	glfw.ShowWindow(win.handle)
}

window_isClosed :: proc(win: ^Window) -> bool {
	return bool(glfw.WindowShouldClose(win.handle))
}


window_keyGetOS :: proc(win: ^Window, keycode: Keycode) -> int {
	return keycode
}

window_isKeyPressed :: proc(win: ^Window, keycode: Keycode) -> bool {
	return bool(glfw.GetKey(win.handle, cast(i32)window_keyGetOS(win, keycode)) == glfw.PRESS)
}


window_mouseButtonGetOS :: proc(win: ^Window, mousebutton: MouseButton) -> int {
	return int(mousebutton)
}

window_isMouseButtonPressed :: proc(win: ^Window, mouse: MouseButton) -> bool {
	return bool(
		glfw.GetMouseButton(
			win.handle, cast(i32)window_mouseButtonGetOS(win, mouse)
		) == glfw.PRESS
	)
}


@(private)
default_logger_backend: log.Logger
