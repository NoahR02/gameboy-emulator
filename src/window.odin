package gameboy

import "vendor:glfw"
import gl "vendor:OpenGL"
import "core:strings"

Window :: struct {
    handle: glfw.WindowHandle,
    width: u32,
    height: u32,
    title: string,
}


@(private)
// For now we will setup the windowing system when we create the window.
// In the future we should consider decoupling them, so that we can have multiple windows.
windowing_system_startup :: proc() {
    assert(cast(bool)glfw.Init())

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
}

@(private)
windowing_system_clean_up:: proc() {
    glfw.Terminate()
}

window_make :: proc(width, height: u32, title: string) -> (self: Window) {
    windowing_system_startup()
    title_cstring := strings.clone_to_cstring(title, context.temp_allocator)
    self.handle = glfw.CreateWindow(i32(width), i32(height), title_cstring, nil, nil)
    self.width = width
    self.height = height
    self.title = strings.clone_from(title)
    assert(self.handle != nil)
    window_hook_in_to_graphics_library(&self)
    return
}

@(private)
window_hook_in_to_graphics_library :: proc(self: ^Window) {
    glfw.MakeContextCurrent(self.handle)
    gl.load_up_to(3, 3, glfw.gl_set_proc_address)
}

window_get_size :: proc(self: Window) -> (u32, u32) {
    window_width, window_height := glfw.GetWindowSize(self.handle)
    return u32(window_width), u32(window_height)
}

window_should_close :: proc(self: Window) -> bool {
    return bool(glfw.WindowShouldClose(self.handle))
}

window_destroy :: proc(self: ^Window) {
    delete(self.title)
    glfw.DestroyWindow(self.handle)
    windowing_system_clean_up()
}