package gameboy

// 8-bit Load/Store/Move START
cpu_ld_8_bit :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    dst := extract_dst_register(opcode)
    src := extract_src_register(opcode)

    if dst == OPCODE_REGISTER_HL_INDEX {
        bus_write(cpu.bus, u16(cpu.registers.HL), get_register_value_from_opcode_index(cpu.registers, src))
    } else if src == OPCODE_REGISTER_HL_INDEX {
        set_register_value_from_opcode_index(&cpu.registers, dst, bus_read(cpu.bus^, u16(cpu.registers.HL)))
    } else {
        set_register_value_from_opcode_index(&cpu.registers, opcode_index = dst, value = get_register_value_from_opcode_index(cpu.registers, src))
    }
}

cpu_ld_immediate_into_register_8_bit :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    dst := extract_dst_register(opcode)
    immediate := opcode_data

    if dst == OPCODE_REGISTER_HL_INDEX {
        bus_write(cpu.bus, u16(cpu.registers.HL), immediate)
        
    } else {
        set_register_value_from_opcode_index(&cpu.registers, dst, immediate)
    }
}

cpu_ld_a_with_value_or_store_at_register_pair_address :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    // These instructions are a bit odd because they have to support HLI + HLD.
    //  We will always use A as the src or dest here.

    LD_BC_A  :: 0
    LD_DE_A  :: 2
    LD_HLI_A :: 4
    LD_HLD_A :: 6

    LD_A_BC  :: 1
    LD_A_DE  :: 3
    LD_A_HLI :: 5
    LD_A_HLD :: 7

    dst := extract_dst_register(opcode)
    a_register_value := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)

    switch dst {
        case LD_BC_A: {
            bus_write(cpu.bus, u16(cpu.registers.BC), a_register_value)
        }
        case LD_DE_A: {
            bus_write(cpu.bus, u16(cpu.registers.DE), a_register_value)
        }
        case LD_HLI_A: {
            bus_write(cpu.bus, u16(cpu.registers.HL), a_register_value)
            cpu.registers.HL = Register(u16(cpu.registers.HL) + 1)
        }
        case LD_HLD_A: {
            bus_write(cpu.bus, u16(cpu.registers.HL), a_register_value)
            cpu.registers.HL = Register(u16(cpu.registers.HL) - 1)
        }
        case LD_A_BC: {
            cpu.registers.AF.high = bus_read(cpu.bus^, u16(cpu.registers.BC))
        }
        case LD_A_DE: {
            cpu.registers.AF.high = bus_read(cpu.bus^, u16(cpu.registers.DE))
        }
        case LD_A_HLI: {
            cpu.registers.AF.high = bus_read(cpu.bus^, u16(cpu.registers.HL))
            cpu.registers.HL = Register(u16(cpu.registers.HL) + 1)
        }
        case LD_A_HLD: {
            cpu.registers.AF.high = bus_read(cpu.bus^, u16(cpu.registers.HL))
            cpu.registers.HL = Register(u16(cpu.registers.HL) - 1)
        }
    }
}

cpu_ld_a_at_address :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u16)  {
    bus_write(cpu.bus, opcode_data, cpu.registers.AF.high)
}

cpu_ld_data_at_address_to_a :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u16)  {
     cpu.registers.AF.high = bus_read(cpu.bus^, opcode_data)
}

// ldh = Load from high page
cpu_ldh_plus_c_register_from_a :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    address := u16(0xFF00) + u16(cpu.registers.BC.low)
    bus_write(cpu.bus, address, cpu.registers.AF.high)
}

cpu_ldh_plus_c_register_to_a :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    address := u16(0xFF00) + u16(cpu.registers.BC.low)
    cpu.registers.AF.high = bus_read(cpu.bus^, address)
}

// ldh = Load from high page
cpu_ldh_from_a :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    address := u16(0xFF00) + u16(opcode_data)
    bus_write(cpu.bus, address, cpu.registers.AF.high)
}


// ldh = Load from high page
cpu_ldh_to_a :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    address := u16(0xFF00) + u16(opcode_data)
    cpu.registers.AF.high = bus_read(cpu.bus^, address)
}

// 8-bit Load/Store/Move END

// 16-bit Load/Store/Move START

cpu_ld_hl_into_sp :: #force_inline proc(cpu: ^Cpu, opcode: u8) {
    cpu.registers.SP = cpu.registers.HL
}

cpu_ld_sp_at_address :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u16)  {
    bus_write(cpu.bus, opcode_data, cpu.registers.SP.low)
    bus_write(cpu.bus, opcode_data + 1, cpu.registers.SP.high)
}

cpu_ld_immediate_into_register_pair_16_bit :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u16)  {
    dst := extract_dst_register_pair(opcode)
    set_register_pair_value_from_opcode_index(
        &cpu.registers,
        register_pair_index = dst,
        value = opcode_data
    )
}

cpu_ld_sp_plus_immediate_into_hl :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8) {
    set_zero_flag(&cpu.registers, false)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_8_bit_addition(cpu.registers, cpu.registers.SP.low, opcode_data))
    set_carry_flag(&cpu.registers, compute_carry_flag_by_8_bit_addition(cpu.registers, cpu.registers.SP.low, opcode_data))

    cpu.registers.HL = Register(u16(cpu.registers.SP) + u16(i8(opcode_data)))
}

cpu_push :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    dst := extract_dst_register_pair(opcode)
    low: u8 = 0
    high: u8 = 0

    switch dst {
        case 0: { high = cpu.registers.BC.high; low = cpu.registers.BC.low; }
        case 1: { high = cpu.registers.DE.high; low = cpu.registers.DE.low; }
        case 2: { high = cpu.registers.HL.high; low = cpu.registers.HL.low; }
        case 3: { high = cpu.registers.AF.high; low = cpu.registers.AF.low; }
        case: {
            panic("Invalid register pair index provided!")
        }
   }

    bus_write(cpu.bus, u16(cpu.registers.SP) - 1, u8(high))
    bus_write(cpu.bus, u16(cpu.registers.SP) - 2, u8(low))
    
    cpu.registers.SP = Register(u16(cpu.registers.SP) - 2)
}

cpu_pop :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    dst := extract_dst_register_pair(opcode)
    low_sp := bus_read(cpu.bus^, u16(cpu.registers.SP))
    high_sp := bus_read(cpu.bus^, u16(cpu.registers.SP) + 1)

    switch dst {
        case 0: { cpu.registers.BC.high = high_sp; cpu.registers.BC.low = low_sp; }
        case 1: { cpu.registers.DE.high = high_sp; cpu.registers.DE.low = low_sp; }
        case 2: { cpu.registers.HL.high = high_sp; cpu.registers.HL.low = low_sp; }
        case 3: { 
            cpu.registers.AF.high = high_sp;
            cpu.registers.AF.low = low_sp & 0xf0;
         }
        case: {
            panic("Invalid register pair index provided!")
        }
   }
    
    cpu.registers.SP = Register(u16(cpu.registers.SP) + 2)
}

// 16-bit Load/Store/Move END