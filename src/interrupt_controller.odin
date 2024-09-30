package gameboy

Interrupt_Type :: enum u8 {
    VBlank = 0,
    LCD = 1,
    Timer = 2,
    Serial = 3,
    Joypad = 4
}

Interrupt_Set ::  bit_set[Interrupt_Type; u8]

// IF
INTERRUPTS_FLAG :: 0xFF0F
// IE
INTERRUPTS_ENABLED :: 0xFFFF

interrupt_controller_handle_interrupts :: proc(cpu: ^Cpu) -> (m_cycles: uint) {
    interrupts_enabled := transmute(Interrupt_Set)bus_read(cpu.bus^, INTERRUPTS_ENABLED)
    interrupts_flag := transmute(Interrupt_Set)bus_read(cpu.bus^, INTERRUPTS_FLAG)
    did_interrupt_occur := false

    if
    .VBlank in interrupts_enabled && .VBlank in interrupts_flag ||
    .LCD in interrupts_enabled && .LCD in interrupts_flag ||
    .Timer in interrupts_enabled && .Timer in interrupts_flag ||
    .Serial in interrupts_enabled && .Serial in interrupts_flag ||
    .Joypad in interrupts_enabled && .Joypad in interrupts_flag {
        did_interrupt_occur = true
    }

    // If any interrupts happen, wake up the CPU.
    if did_interrupt_occur {
        cpu.is_halted = false
    }

    if cpu.ime {

        push_pc :: proc(cpu: ^Cpu) {
            bus_write(cpu.bus, u16(cpu.registers.SP) - 1, cpu.registers.PC.high)
            bus_write(cpu.bus, u16(cpu.registers.SP) - 2, cpu.registers.PC.low)
            cpu.registers.SP = Register(u16(cpu.registers.SP) - 2)
        }

        // In order from the highest priority to the lowest priority.
        if .VBlank in interrupts_enabled && .VBlank in interrupts_flag {
            push_pc(cpu)
            cpu.registers.PC = Register(0x40)
            interrupts_flag -= {.VBlank}
        } else if .LCD in interrupts_enabled && .LCD in interrupts_flag {
            push_pc(cpu)
            cpu.registers.PC = Register(0x48)
            interrupts_flag -= {.LCD}
        } else if .Timer in interrupts_enabled && .Timer in interrupts_flag {
            push_pc(cpu)
            cpu.registers.PC = Register(0x50)
            interrupts_flag -= {.Timer}
        } else if .Serial in interrupts_enabled && .Serial in interrupts_flag {
            push_pc(cpu)
            cpu.registers.PC = Register(0x58)
            interrupts_flag -= {.Serial}
        } else if .Joypad in interrupts_enabled && .Joypad in interrupts_flag {
            push_pc(cpu)
            cpu.registers.PC = Register(0x60)
            interrupts_flag -= {.Joypad}
        }

        if did_interrupt_occur {
            m_cycles += 5
            bus_write(cpu.bus, INTERRUPTS_FLAG, transmute(byte)interrupts_flag)
        }
    }

    return
}

