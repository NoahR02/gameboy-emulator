package gameboy

// Timer Registers
// DIV
DIV :: 0xFF04
// TIMA: Timer counter
TIMA :: 0xFF05
// TMA: Timer modulo
TMA :: 0xFF06
// TAC: Timer control
TAC :: 0xFF07

CLOCK_0 :: 4096
CLOCK_1 :: 262144
CLOCK_2 :: 65536
CLOCK_3 :: 16384

timer_increment_divider :: proc(gb_state: ^Gb_State) {
    gb_state.memory_mapper._io_ram[DIV-0xFF00] += 1
}

timer_increment_counter :: proc(gb_state: ^Gb_State) {
    timer_counter_data := memory_mapper_read(gb_state.memory_mapper, TIMA)
    if timer_counter_data == 0xFF {
        memory_mapper_write(&gb_state.memory_mapper, TIMA, memory_mapper_read(gb_state.memory_mapper, TMA))
        interrupts_flag := transmute(Interrupt_Set)memory_mapper_read(gb_state.memory_mapper, INTERRUPTS_FLAG)
        interrupts_flag += {.Timer}
        memory_mapper_write(&gb_state.memory_mapper, INTERRUPTS_FLAG, transmute(byte)interrupts_flag)
    } else {
        memory_mapper_write(&gb_state.memory_mapper, TIMA, timer_counter_data + 1)
    }
}

timer_get_clock_frequency :: proc(gb_state: Gb_State) -> int {
    clock_frequency := memory_mapper_read(gb_state.memory_mapper, TAC) & 0x03

    switch clock_frequency {
        case 0: return CLOCK_0
        case 1: return CLOCK_1
        case 2: return CLOCK_2
        case 3: return CLOCK_3
    }

    // Unreachable.
    return 0
}

timer_counter_is_running :: proc(gb_state: Gb_State) -> bool {
    timer_control_data := memory_mapper_read(gb_state.memory_mapper, TAC)
    is_running := bool((timer_control_data & 0x04) >> 2)
    return is_running
}
