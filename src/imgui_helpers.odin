package gameboy

import "vendor:glfw"
import gl "vendor:OpenGL"
import im "../odin-imgui"
import "../odin-imgui/imgui_impl_glfw"
import "../odin-imgui/imgui_impl_opengl3"

p_open_default := true

imgui_startup :: proc(window: Window) {
    im.CHECKVERSION()
    im.CreateContext()
    io := im.GetIO()
    io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}
    io.ConfigFlags += {.DockingEnable}
    io.ConfigFlags += {.ViewportsEnable}
    style := im.GetStyle()
    style.WindowRounding = 0
    style.Colors[im.Col.WindowBg].w = 1
    im.StyleColorsDark()
    imgui_impl_glfw.InitForOpenGL(window.handle, true)
    imgui_impl_opengl3.Init("#version 330 core")
}

imgui_preprare_frame :: proc() {
    imgui_impl_opengl3.NewFrame()
    imgui_impl_glfw.NewFrame()
    im.NewFrame()
}

imgui_assemble_and_render_frame :: proc(window: Window) {
    im.Render()

    window_width, window_height := window_get_size(window)
    gl.Viewport(0, 0, i32(window_width), i32(window_height))
    gl.ClearColor(0, 0, 0, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    imgui_impl_opengl3.RenderDrawData(im.GetDrawData())
    backup_current_window := glfw.GetCurrentContext()
    im.UpdatePlatformWindows()
    im.RenderPlatformWindowsDefault()
    glfw.MakeContextCurrent(backup_current_window)
}

imgui_clean_up :: proc() {
    imgui_impl_opengl3.Shutdown()
    imgui_impl_glfw.Shutdown()
    im.DestroyContext()
}