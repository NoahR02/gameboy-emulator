package gameboy

import "core:fmt"
import "core:strings"
import "core:encoding/endian"

Gb_State :: struct {
    cpu: Cpu,
    ppu: Ppu,
    timer: Timer,
    memory_mapper: Memory_Mapper,
    current_cycle: int,
    is_halted: bool,
}

import "core:log"
import "core:os"
import "vendor:glfw"
import gl "vendor:OpenGL"
import im "../odin-imgui"
import "../odin-imgui/imgui_impl_glfw"
import "../odin-imgui/imgui_impl_opengl3"

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)
GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK :: 1_048_576
GAMEBOY_CPU_SPEED :: GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK * 4
GAMEBOY_SCREEN_WIDTH :: 128
GAMEBOY_SCREEN_HEIGHT :: 144 * 2

gameboy_configure_startup_values_after_the_boot_rom :: proc(gb_state: ^Gb_State) {
    // The state after executing the boot rom
    gb_state.cpu.registers.AF = Register(0x01b0)
    gb_state.cpu.registers.BC = Register(0x0013)
    gb_state.cpu.registers.DE = Register(0x00d8)
    gb_state.cpu.registers.HL = Register(0x014d)
    gb_state.cpu.registers.SP = Register(0xfffe)
    gb_state.cpu.registers.PC = Register(0x0100)
    memory_mapper_write(&gb_state.memory_mapper, 0xFF44, 0x90)
    gb_state.memory_mapper._io_ram[DIV-0xFF00] = 0x18
    memory_mapper_write(&gb_state.memory_mapper, TAC, 0xf8)
    memory_mapper_write(&gb_state.memory_mapper, INTERRUPTS_FLAG, 0xe1)
    memory_mapper_write(&gb_state.memory_mapper, INTERRUPTS_ENABLED, 0x00)

    // LCD
    memory_mapper_write(&gb_state.memory_mapper, LY, 0x91)
    memory_mapper_write(&gb_state.memory_mapper, STAT, 0x81)
    memory_mapper_write(&gb_state.memory_mapper, LCDC, 0x91 | 0x80)


    memory_mapper_write(&gb_state.memory_mapper, LY, 0x91)
}

gameboy_install_rom :: proc(gb_state: ^Gb_State, rom: []byte) {
    for address := 0; address < len(rom); address += 1 {
        memory_mapper_write(&gb_state.memory_mapper, u16(address), rom[address])
    }
}

gameboy_step :: proc(gb_state: ^Gb_State) {
    old_cycle_count := gb_state.current_cycle
    if !gb_state.is_halted {
        cpu_fetch_decode_execute(gb_state)
    } else {
        // HALT
        gb_state.current_cycle += 1
    }

    interrupt_controller_handle_interrupts(gb_state)

    m_cycles_delta := uint(gb_state.current_cycle - old_cycle_count)
    gb_state.ppu.cycles += uint(m_cycles_delta)
    ppu_step(&gb_state.ppu)

    timer_divider_step(&gb_state.timer, m_cycles_delta)
    timer_counter_step(&gb_state.timer, m_cycles_delta)
}

connect_devices :: proc(gb_state: ^Gb_State) {
    // This is a bit nasty because it will create circular references, but most of the time each device cannot operate in isolation.
    // TODO: Rework how the devices communicate.
    gb_state.cpu.memory_mapper = &gb_state.memory_mapper
    gb_state.ppu.gb_state = gb_state
    gb_state.memory_mapper.gb_state = gb_state
    gb_state.timer.gb_state = gb_state
}

main :: proc() {
     gb_state := Gb_State {}
     connect_devices(&gb_state)

     rom, rom_open_success := os.read_entire_file_from_filename("assets/Dr. Mario (World).gb")
     if !rom_open_success {
         panic("Failed to open the rom file!")
     }

     gameboy_install_rom(&gb_state, rom)
     gameboy_configure_startup_values_after_the_boot_rom(&gb_state)

     assert(cast(bool)glfw.Init())
     defer glfw.Terminate()

     glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
     glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
     glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

     window := glfw.CreateWindow(1280, 720, "yuki gb", nil, nil)
     assert(window != nil)
     defer glfw.DestroyWindow(window)

     glfw.MakeContextCurrent(window)
     glfw.SwapInterval(1) // vsync

     gl.load_up_to(3, 2, proc(p: rawptr, name: cstring) {
         (cast(^rawptr)p)^ = glfw.GetProcAddress(name)
     })

     im.CHECKVERSION()
     im.CreateContext()
     defer im.DestroyContext()
     io := im.GetIO()
     io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}
     when !DISABLE_DOCKING {
         io.ConfigFlags += {.DockingEnable}
         io.ConfigFlags += {.ViewportsEnable}

         style := im.GetStyle()
         style.WindowRounding = 0
         style.Colors[im.Col.WindowBg].w = 1
     }

     im.StyleColorsDark()

     imgui_impl_glfw.InitForOpenGL(window, true)
     defer imgui_impl_glfw.Shutdown()
     imgui_impl_opengl3.Init("#version 330 core")
     defer imgui_impl_opengl3.Shutdown()

     tile_data := make([]u8, GAMEBOY_SCREEN_WIDTH * GAMEBOY_SCREEN_HEIGHT * 4)
     defer delete(tile_data)

     offset := int(GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK / 60)

     tile_map_tab_open := true
     background_tab_open := true
     texture := texture_make()
     defer texture_destroy(&texture)

     for !glfw.WindowShouldClose(window) {
         glfw.PollEvents()

         for _ in 0..=offset {
             gameboy_step(&gb_state)
         }
         ppu_decode_and_render_tile_data(&gb_state.ppu, tile_data, 16)
         texture_update(&texture, tile_data, GAMEBOY_SCREEN_WIDTH, GAMEBOY_SCREEN_HEIGHT)

         imgui_impl_opengl3.NewFrame()
         imgui_impl_glfw.NewFrame()
         im.NewFrame()

         im.BeginTabBar(cstring("Debug Tab Container"), {})
         if im.BeginTabItem("Tile Map", &tile_map_tab_open, {}) {
             im.Image(rawptr(uintptr(texture.handle)), im.Vec2{GAMEBOY_SCREEN_WIDTH * 4, GAMEBOY_SCREEN_HEIGHT * 4})
             im.EndTabItem()
         }

         if im.BeginTabItem("Background Layer", &background_tab_open, {}) {
             im.Image(rawptr(uintptr(texture.handle)), im.Vec2{GAMEBOY_SCREEN_WIDTH * 2, GAMEBOY_SCREEN_HEIGHT * 2})
             im.EndTabItem()
         }
         im.EndTabBar()

         im.Render()
         window_width, window_height := glfw.GetFramebufferSize(window)
         gl.Viewport(0, 0, window_width, window_height)
         gl.ClearColor(0, 0, 0, 1)
         gl.Clear(gl.COLOR_BUFFER_BIT)
         imgui_impl_opengl3.RenderDrawData(im.GetDrawData())

         when !DISABLE_DOCKING {
             backup_current_window := glfw.GetCurrentContext()
             im.UpdatePlatformWindows()
             im.RenderPlatformWindowsDefault()
             glfw.MakeContextCurrent(backup_current_window)
         }

         glfw.SwapBuffers(window)
     }
}