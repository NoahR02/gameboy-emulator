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

windowing_system_startup :: proc() {
    assert(cast(bool)glfw.Init())

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
}

windowing_system_clean_up:: proc() {
    glfw.Terminate()
}

window_make :: proc(width, height: u32, title: string) -> (self: Window) {
    title_cstring := strings.clone_to_cstring(title, context.temp_allocator)
    self.handle = glfw.CreateWindow(i32(width), i32(height), title_cstring, nil, nil)
    self.width = width
    self.height = height
    self.title = strings.clone_from(title)
    assert(self.handle != nil)
    window_hook_in_to_graphics_library(&self)
    return
}

window_poll_for_events :: proc() {
    glfw.PollEvents()
}

window_swap_buffers :: proc(window: Window) {
    glfw.SwapBuffers(window.handle)
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
}