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
import gl "vendor:OpenGL"
import im "../odin-imgui"

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
    memory_mapper_write(&gb_state.memory_mapper, LCDC, 0x91)
    memory_mapper_write(&gb_state.memory_mapper, STAT, 0x81)
    memory_mapper_write(&gb_state.memory_mapper, LCDC, 0x91)
    memory_mapper_write(&gb_state.memory_mapper, 0xFF46, 0xFF)
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
    timer_step(&gb_state.timer, m_cycles_delta)
}

gb_state_make :: proc() -> (self: Gb_State) {
    self.ppu = ppu_make()
    return
}

gb_state_delete :: proc(self: ^Gb_State) {
    ppu_destroy(&self.ppu)
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
    windowing_system_startup()
    defer windowing_system_clean_up()

    window := window_make(1280, 720, "yuki gb")
    defer window_destroy(&window)

    gb_state := gb_state_make()
    defer gb_state_delete(&gb_state)
    connect_devices(&gb_state)

    rom, rom_open_success := os.read_entire_file_from_filename("assets/Dr. Mario (World).gb")
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
           gameboy_step(&gb_state)
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