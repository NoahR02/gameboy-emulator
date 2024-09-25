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

Timer :: struct {
    gb_state: ^Gb_State,
    counter_delta: uint,
    divider_delta: uint
}

timer_divider_step :: proc(self: ^Timer, m_cycles_delta: uint) {
    self.divider_delta += m_cycles_delta

    // Increment the timer divider counter every 64 memory cycles.
    if self.divider_delta >= 64 {
        self.divider_delta = 0
        self.gb_state.memory_mapper._io_ram[DIV-0xFF00] += 1
    }
}

timer_counter_step :: proc(self: ^Timer, m_cycles_delta: uint) {
    if !timer_counter_is_running(self^) {
        self.counter_delta = 0
        return
    }

    self.counter_delta += m_cycles_delta
    gb_state := self.gb_state

    // Increment the timer divier counter every n memory cycles.
    // n is variable because the timer counter can increment at different frequencies.
    increment_on_n_m_cycles := uint(GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK / timer_get_clock_frequency(gb_state^))
    if self.counter_delta >= increment_on_n_m_cycles {
        self.counter_delta = 0

        timer_counter_data := memory_mapper_read(gb_state.memory_mapper, TIMA)
        if timer_counter_data == 0xFF {
            // When counter overflows, (TIMA) = (TMA).
            memory_mapper_write(&gb_state.memory_mapper, TIMA, memory_mapper_read(gb_state.memory_mapper, TMA))
            // Request timer interrupt.
            interrupts_flag := transmute(Interrupt_Set)memory_mapper_read(gb_state.memory_mapper, INTERRUPTS_FLAG)
            interrupts_flag += {.Timer}
            memory_mapper_write(&gb_state.memory_mapper, INTERRUPTS_FLAG, transmute(byte)interrupts_flag)
        } else {
            memory_mapper_write(&gb_state.memory_mapper, TIMA, timer_counter_data + 1)
        }

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

timer_counter_is_running :: proc(self: Timer) -> bool {
    timer_control_data := memory_mapper_read(self.gb_state.memory_mapper, TAC)
    is_running := bool((timer_control_data & 0x04) >> 2)
    return is_running
}
