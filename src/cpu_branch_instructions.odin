package gameboy

Condition_Code :: enum {
    NZ = 0x00,
    Z  = 0x01,
    NC = 0x02,
    C  = 0x03,
}

is_condition_true :: proc(registers: Registers, condition: Condition_Code) -> bool {
    is_condition_true: bool
    switch condition {
    case .NZ: is_condition_true = !is_zero_flag_set(registers)
    case .Z:  is_condition_true = is_zero_flag_set(registers)
    case .NC: is_condition_true = !is_carry_flag_set(registers)
    case .C:  is_condition_true = is_carry_flag_set(registers)
    case: panic("Invalid condition inputted!")
    }
    return is_condition_true
}

extract_condition :: proc(opcode: u8) -> Condition_Code {
    dst_mask := byte(0b00011000)
    dst_register := (opcode & dst_mask) >> 3
    return Condition_Code(dst_register)
}

cpu_jp_to_hl :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    cpu.registers.PC = cpu.registers.HL
}

cpu_jp_to_address :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u16)  {
    address := opcode_data
    cpu.registers.PC = Register(address)
}

cpu_jp_to_address_conditionally :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u16)  {
    condition := extract_condition(opcode)
    address := opcode_data

    if is_condition_true(cpu.registers, condition) {
        cpu.registers.PC = Register(address)
    }
}

cpu_jp_to_address_at_hl :: #force_inline proc(cpu: ^Cpu)  {
    cpu.registers.PC = cpu.registers.HL
}

// Jump relative to the current program counter address.
cpu_jr_to_relative_u8_address :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    n := i8(opcode_data)

    address := i32(cpu.registers.PC) + i32(i8(n))
    cpu.registers.PC = Register(u16(address))
}


// Jump relative to the current program counter address if a condition is true.
cpu_jr_to_relative_u8_address_on_condition :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    condition := extract_condition(opcode)
    n := i8(opcode_data)

    if is_condition_true(cpu.registers, condition) {
        address := i32(cpu.registers.PC) + i32(i8(n))
        cpu.registers.PC = Register(u16(address))
    }
}


cpu_call_address :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u16)  {
    bus_write(cpu.bus, u16(cpu.registers.SP) - 1, cpu.registers.PC.high)
    bus_write(cpu.bus, u16(cpu.registers.SP) - 2, cpu.registers.PC.low)
    cpu.registers.SP = Register(u16(cpu.registers.SP) - 2)
    address := opcode_data
    cpu.registers.PC = Register(address)
}


cpu_call_address_on_condition :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u16)  {
    condition := extract_condition(opcode)

    if is_condition_true(cpu.registers, condition) {
        bus_write(cpu.bus, u16(cpu.registers.SP) - 1, cpu.registers.PC.high)
        bus_write(cpu.bus, u16(cpu.registers.SP) - 2, cpu.registers.PC.low)
        cpu.registers.SP = Register(u16(cpu.registers.SP) - 2)
        address := opcode_data
        cpu.registers.PC = Register(address)
    }
}

cpu_ret :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    cpu.registers.PC.low = bus_read(cpu.bus^, u16(cpu.registers.SP))
    cpu.registers.PC.high = bus_read(cpu.bus^, u16(cpu.registers.SP) + 1)
    cpu.registers.SP = Register(u16(cpu.registers.SP) + 2)
}

cpu_reti :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    cpu.registers.PC.low = bus_read(cpu.bus^, u16(cpu.registers.SP))
    cpu.registers.PC.high = bus_read(cpu.bus^, u16(cpu.registers.SP) + 1)
    cpu.registers.SP = Register(u16(cpu.registers.SP) + 2)
    cpu.ime = true
}


cpu_ret_on_condition :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    condition := extract_condition(opcode)
    if is_condition_true(cpu.registers, condition) {
        cpu.registers.PC.low = bus_read(cpu.bus^, u16(cpu.registers.SP))
        cpu.registers.PC.high = bus_read(cpu.bus^, u16(cpu.registers.SP) + 1)
        cpu.registers.SP = Register(u16(cpu.registers.SP) + 2)
    }
}

cpu_rst :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    // Map t to 1 of 8 addresses
    t := extract_bits_5_4_3(opcode)
    P := t * 8
    pc := Register(u16(cpu.registers.PC))
    bus_write(cpu.bus, u16(cpu.registers.SP) - 1, pc.high)
    bus_write(cpu.bus, u16(cpu.registers.SP) - 2, pc.low)
    cpu.registers.SP = Register(u16(cpu.registers.SP) - 2)
    cpu.registers.PC.high = 0
    cpu.registers.PC.low = P
}