package gameboy

import "core:fmt"
import "core:strings"
import "core:encoding/endian"

Gb_State :: struct {
    cpu: Cpu,
    memory_mapper: Memory_Mapper,
    current_cycle: int,
    is_halted: bool,
    timer_counter_delta: int,
    timer_divider_delta: int,
}

import "core:log"
import "core:os"

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
        increment_on_n_m_cycles := int(1048576 / timer_get_clock_frequency(gb_state^))
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
     gb_state.memory_mapper.cpu = &gb_state.cpu

     rom := #load("../tests/cpu_instrs/02-interrupts.gb")

     gameboy_install_rom(&gb_state, rom)
     gameboy_configure_startup_values_after_the_boot_rom(&gb_state)

     for int(gb_state.cpu.registers.PC) < 0xFFFF {
         gameboy_step(&gb_state)
     }
}