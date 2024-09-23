package gameboy

import "core:fmt"
import "core:strings"
import "core:encoding/endian"

Gb_State :: struct {
    cpu: Cpu,
    ppu: Ppu,
    memory_mapper: Memory_Mapper,
    current_cycle: int,
    is_halted: bool,
    timer_counter_delta: int,
    timer_divider_delta: int,
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

    cycle_count_delta := gb_state.current_cycle - old_cycle_count
    gb_state.ppu.cycles += uint(cycle_count_delta)
    ppu_step(&gb_state.ppu)

    gb_state.timer_divider_delta += cycle_count_delta
    gb_state.timer_counter_delta += cycle_count_delta

    // Increment the timer divier counter every 64 memory cycles.
    if gb_state.timer_divider_delta >= 64 {
        timer_increment_divider(gb_state)
        gb_state.timer_divider_delta = 0
    }

    if timer_counter_is_running(gb_state^) {
        // Increment the timer divier counter every n memory cycles.
        // n is variable because the timer counter can increment at different frequencies.
        increment_on_n_m_cycles := int(GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK / timer_get_clock_frequency(gb_state^))
        if gb_state.timer_counter_delta >= increment_on_n_m_cycles {
            timer_increment_counter(gb_state)
            gb_state.timer_counter_delta = 0
        }
    } else {
        gb_state.timer_counter_delta = 0
    }
}

main :: proc() {
     gb_state := Gb_State {}
     gb_state.cpu.memory_mapper = &gb_state.memory_mapper
     gb_state.ppu.gb_state = &gb_state
     gb_state.memory_mapper.gb_state = &gb_state

     // rom := #load("../tests/cpu_instrs/02-interrupts.gb")
     rom, rom_open_success := os.read_entire_file_from_filename("assets/Dr. Mario (World).gb")
     if !rom_open_success {
         panic("Failed to open the rom file!")
     }

     gameboy_install_rom(&gb_state, rom)
     gameboy_configure_startup_values_after_the_boot_rom(&gb_state)

     assert(cast(bool)glfw.Init())
     defer glfw.Terminate()

     glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
     glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 2)
     glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
     glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, 1) // i32(true)

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
     imgui_impl_opengl3.Init("#version 150")
     defer imgui_impl_opengl3.Shutdown()

     tile_data := make([]u8, GAMEBOY_SCREEN_WIDTH * GAMEBOY_SCREEN_HEIGHT * 4)
     defer delete(tile_data)

     offset := int(GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK / 60)

     tile_map_tab_open := true
     background_tab_open := true
     texture := load_texture_from_memory(tile_data, GAMEBOY_SCREEN_WIDTH, GAMEBOY_SCREEN_HEIGHT)

     for !glfw.WindowShouldClose(window) {
         glfw.PollEvents()

         for _ in 0..=offset {
             gameboy_step(&gb_state)
         }
         ppu_decode_and_render_tile_data(&gb_state, tile_data, 16)
         update_texture(texture, tile_data, GAMEBOY_SCREEN_WIDTH, GAMEBOY_SCREEN_HEIGHT)

         imgui_impl_opengl3.NewFrame()
         imgui_impl_glfw.NewFrame()
         im.NewFrame()

         im.BeginTabBar(cstring("tab_bar"), {})
         if im.BeginTabItem("tile_map", &tile_map_tab_open, {}) {
             im.Image(rawptr(uintptr(texture)), im.Vec2{GAMEBOY_SCREEN_WIDTH * 4, GAMEBOY_SCREEN_HEIGHT * 4})
             im.EndTabItem()
         }

         if im.BeginTabItem("background", &background_tab_open, {}) {
             im.Image(rawptr(uintptr(texture)), im.Vec2{GAMEBOY_SCREEN_WIDTH * 4, GAMEBOY_SCREEN_HEIGHT * 4})
             im.EndTabItem()
         }
         im.EndTabBar()

         im.Render()
         display_w, display_h := glfw.GetFramebufferSize(window)
         gl.Viewport(0, 0, display_w, display_h)
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