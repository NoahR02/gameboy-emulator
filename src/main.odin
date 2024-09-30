package gameboy

import "core:fmt"
import "core:strings"
import "core:encoding/endian"

Gb_State :: struct {
    cpu: Cpu,
    ppu: Ppu,
    timer: Timer,
    bus: Bus,
    current_cycle: uint,
}

import "core:log"
import "core:os"
import gl "vendor:OpenGL"
import im "../odin-imgui"
import "vendor:glfw"

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
    bus_write(&gb_state.bus, 0xFF44, 0x90)
    gb_state.bus._io_ram[DIV-0xFF00] = 0x18
    bus_write(&gb_state.bus, TAC, 0xf8)
    bus_write(&gb_state.bus, INTERRUPTS_FLAG, 0xe1)
    bus_write(&gb_state.bus, INTERRUPTS_ENABLED, 0x00)

    // LCD
    bus_write(&gb_state.bus, LY, 0x91)
    bus_write(&gb_state.bus, LCDC, 0x91)
    bus_write(&gb_state.bus, STAT, 0x81)
    bus_write(&gb_state.bus, LCDC, 0x91)
    bus_write(&gb_state.bus, 0xFF46, 0xFF)
    bus_write(&gb_state.bus, P1_JOYPAD, 0xCF)
}

gameboy_install_rom :: proc(gb_state: ^Gb_State, rom: []byte) {
    for address := 0; address < len(rom); address += 1 {
        bus_write(&gb_state.bus, u16(address), rom[address])
    }
}

gameboy_step :: proc(gb_state: ^Gb_State, window: ^Window) {
    old_cycle_count := gb_state.current_cycle
    gb_state.current_cycle += cpu_step(&gb_state.cpu)

    // Account for how long a DMA transfer takes.
    if gb_state.bus.dma_transfer_requested {
        gb_state.bus.dma_transfer_requested = false
        gb_state.current_cycle += 160
    }

    // Remove this. Just for testing.
    // ----
    w_key_state := glfw.GetKey(window.handle, glfw.KEY_W)
    a_key_state := glfw.GetKey(window.handle, glfw.KEY_A)
    s_key_state := glfw.GetKey(window.handle, glfw.KEY_S)
    d_key_state := glfw.GetKey(window.handle, glfw.KEY_D)

    p1_joypad := gb_state.bus._io_ram[P1_JOYPAD-0xFF00]
    select_buttons_enabled := (p1_joypad & 0b00_10_0000) == 0
    dpad_buttons_enabled := (p1_joypad & 0b00_01_0000) == 0

    if (w_key_state == glfw.PRESS)
    {
        if select_buttons_enabled {
            select_buttons = select_buttons & 0b1111_0111
        } else if dpad_buttons_enabled {
            dpad_buttons = dpad_buttons & 0b1111_0111
        }
    } else if(w_key_state == glfw.RELEASE) {
        if select_buttons_enabled {
            select_buttons = select_buttons | 0b0000_1000
        } else if dpad_buttons_enabled {
            dpad_buttons = dpad_buttons  | 0b0000_1000
        }
    }
    // ----

    gb_state.current_cycle += interrupt_controller_handle_interrupts(&gb_state.cpu)

    m_cycles_delta := uint(gb_state.current_cycle - old_cycle_count)

    gb_state.ppu.cycles += uint(m_cycles_delta)
    ppu_step(&gb_state.ppu)
    timer_step(&gb_state.timer, m_cycles_delta)
}

gb_state_make :: proc() -> (self: Gb_State) {
    self.ppu = ppu_make()
    return
}

gb_state_delete :: proc(self: ^Gb_State) {
    ppu_destroy(&self.ppu)
}

main :: proc() {
    windowing_system_startup()
    defer windowing_system_clean_up()

    window := window_make(1280, 720, "yuki gb")
    defer window_destroy(&window)

    gb_state := gb_state_make()
    defer gb_state_delete(&gb_state)
    bus_connect_devices(&gb_state.bus, &gb_state.cpu, &gb_state.ppu, &gb_state.timer)

    rom, rom_open_success := os.read_entire_file_from_filename("assets/Dr. Mario (World).gb")
    // rom, rom_open_success := os.read_entire_file_from_filename("assets/Tetris.gb")
    if !rom_open_success {
        panic("Failed to open the rom file!")
    }

   gameboy_install_rom(&gb_state, rom)
   gameboy_configure_startup_values_after_the_boot_rom(&gb_state)
   imgui_startup(window)
   defer imgui_clean_up()

   offset := int(GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK / 60)

   for !window_should_close(window) {
       window_poll_for_events()

       for _ in 0..=offset {
           gameboy_step(&gb_state, &window)
       }

       ppu_fill_tiles(&gb_state.ppu)
       ppu_fill_tile_map_1(&gb_state.ppu)
       ppu_fill_tile_map_2(&gb_state.ppu)
       ppu_fill_oam_map(&gb_state.ppu)

       layer_fill_texture(&gb_state.ppu.tiles)
       layer_fill_texture(&gb_state.ppu.tile_map_1)
       layer_fill_texture(&gb_state.ppu.tile_map_2)
       layer_fill_texture(&gb_state.ppu.oam_map)

       imgui_preprare_frame()

       im.Begin("Game", &p_open_default)
       im.Image(rawptr(uintptr(gb_state.ppu.tile_map_1.texture.handle)), im.Vec2{f32(gb_state.ppu.tile_map_1.width) * 2, f32(gb_state.ppu.tile_map_1.height) * 2})
       im.End()

       im.BeginTabBar(cstring("Debug Tab Container"))
       if im.BeginTabItem("Tile Map", &p_open_default) {
           im.Image(rawptr(uintptr(gb_state.ppu.tiles.texture.handle)), im.Vec2{f32(gb_state.ppu.tiles.width) * 4, f32(gb_state.ppu.tiles.height) * 4})
           im.EndTabItem()
       }

       if im.BeginTabItem("Background Layer", &p_open_default) {
           im.Image(rawptr(uintptr(gb_state.ppu.tile_map_1.texture.handle)), im.Vec2{f32(gb_state.ppu.tile_map_1.width) * 2, f32(gb_state.ppu.tile_map_1.height) * 2})
           im.Image(rawptr(uintptr(gb_state.ppu.tile_map_2.texture.handle)), im.Vec2{f32(gb_state.ppu.tile_map_2.width) * 2, f32(gb_state.ppu.tile_map_2.height) * 2})
           im.EndTabItem()
       }

       if im.BeginTabItem("OAM / Sprites Layer", &p_open_default) {
           im.Image(rawptr(uintptr(gb_state.ppu.oam_map.texture.handle)), im.Vec2{f32(gb_state.ppu.oam_map.width) * 8, f32(gb_state.ppu.oam_map.height) * 8})
           im.EndTabItem()
       }
       im.EndTabBar()

       imgui_assemble_and_render_frame(window)
       window_swap_buffers(window)
   }
}