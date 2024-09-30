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
    bus: ^Bus,
    counter_delta: uint,
    divider_delta: uint
}

timer_step :: proc(self: ^Timer, m_cycles_delta: uint) {
    timer_divider_step(self, m_cycles_delta)
    timer_counter_step(self, m_cycles_delta)
}

timer_divider_step :: proc(self: ^Timer, m_cycles_delta: uint) {
    self.divider_delta += m_cycles_delta

    // Increment the timer divider counter every 64 memory cycles.
    if self.divider_delta >= 64 {
        self.divider_delta = 0
        self.bus._io_ram[DIV-0xFF00] += 1
    }
}

timer_counter_step :: proc(self: ^Timer, m_cycles_delta: uint) {
    if !timer_counter_is_running(self^) {
        self.counter_delta = 0
        return
    }

    self.counter_delta += m_cycles_delta

    // Increment the timer divier counter every n memory cycles.
    // n is variable because the timer counter can increment at different frequencies.
    increment_on_n_m_cycles := uint(GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK / timer_get_clock_frequency(self^))
    if self.counter_delta >= increment_on_n_m_cycles {
        self.counter_delta = 0

        timer_counter_data := bus_read(self.bus^, TIMA)
        if timer_counter_data == 0xFF {
            // When counter overflows, (TIMA) = (TMA).
            bus_write(self.bus, TIMA, bus_read(self.bus^, TMA))
            // Request timer interrupt.
            interrupts_flag := transmute(Interrupt_Set)bus_read(self.bus^, INTERRUPTS_FLAG)
            interrupts_flag += {.Timer}
            bus_write(self.bus, INTERRUPTS_FLAG, transmute(byte)interrupts_flag)
        } else {
            bus_write(self.bus, TIMA, timer_counter_data + 1)
        }

    }

}

timer_get_clock_frequency :: proc(self: Timer) -> int {
    clock_frequency := bus_read(self.bus^, TAC) & 0x03

    switch clock_frequency {
        case 0: return CLOCK_0
        case 1: return CLOCK_1
        case 2: return CLOCK_2
        case 3: return CLOCK_3
    }

    unreachable()
}

timer_counter_is_running :: proc(self: Timer) -> bool {
    timer_control_data := bus_read(self.bus^, TAC)
    is_running := bool((timer_control_data & 0x04) >> 2)
    return is_running
}
