package gameboy

import "core:math/bits"

cpu_rlca :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    // Rotate bit 7 into carry flag
    carry := u16(cpu.registers.AF.high) << 1 > 0xFF
    set_carry_flag(&cpu.registers, carry)

    // Circular Rotate
    cpu.registers.AF.high = bits.rotate_left8(cpu.registers.AF.high, 1)

    set_zero_flag(&cpu.registers, false)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}


cpu_rla :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    old_carry_flag := u8(is_carry_flag_set(cpu.registers))
    
    // Rotate bit 7 into carry flag
    carry := u16(cpu.registers.AF.high) << 1 > 0xFF
    set_carry_flag(&cpu.registers, carry)

    // Rotate left
    cpu.registers.AF.high = cpu.registers.AF.high << 1

    // Set bit 0 to be the old carry flag
    cpu.registers.AF.high = cpu.registers.AF.high | old_carry_flag

    set_zero_flag(&cpu.registers, false)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}


cpu_rrca :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    // Bit 0 -> Carry Flag
    new_carry_flag_from_bit_0 := cpu.registers.AF.high & 0x01
    set_carry_flag(&cpu.registers, bool(new_carry_flag_from_bit_0))

    // Circular Rotate to the right
    cpu.registers.AF.high = bits.rotate_left8(cpu.registers.AF.high, -1)

    set_zero_flag(&cpu.registers, false)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}


cpu_rra :: #force_inline proc(cpu: ^Cpu, opcode: u8)  {
    old_carry_flag := u8(is_carry_flag_set(cpu.registers)) << 7

    // Bit 0 -> Carry Flag
    new_carry_flag_from_bit_0 := cpu.registers.AF.high & 0x01
    set_carry_flag(&cpu.registers, bool(new_carry_flag_from_bit_0))

    // Rotate to the right
    cpu.registers.AF.high = cpu.registers.AF.high >> 1

    // Set bit 7 to be the old carry flag
    cpu.registers.AF.high = cpu.registers.AF.high | old_carry_flag

    set_zero_flag(&cpu.registers, false)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}


// Same as rlca, but for any 8-bit register.
cpu_rlc :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    src := extract_src_register(opcode_data)
    data: byte

    if src == OPCODE_REGISTER_HL_INDEX { 
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
        
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, src)
    }

    // Rotate bit 7 into carry flag
    carry := u16(data) << 1 > 0xFF
    set_carry_flag(&cpu.registers, carry)

    // Circular Rotate
    data = bits.rotate_left8(data, 1)

    
    if src == OPCODE_REGISTER_HL_INDEX { 
        bus_write(cpu.bus, u16(cpu.registers.HL), data)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = src,
            value = data
        )
    }

    set_zero_flag(&cpu.registers, data == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}


// Same as rla, but for any 8-bit register.
cpu_rl :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    src := extract_src_register(opcode_data)
    old_carry_flag := u8(is_carry_flag_set(cpu.registers))
    data: byte

    if src == OPCODE_REGISTER_HL_INDEX { 
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
        
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, src)
    }

    // Rotate bit 7 into carry flag
    carry := u16(data) << 1 > 0xFF
    set_carry_flag(&cpu.registers, carry)

    // Rotate left
    data = data << 1

    // Set bit 0 to be the old carry flag
    data = data | old_carry_flag
    
    if src == OPCODE_REGISTER_HL_INDEX { 
        bus_write(cpu.bus, u16(cpu.registers.HL), data)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = src,
            value = data
        )
    }

    set_zero_flag(&cpu.registers, data == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}


// Same as rrca, but for any 8-bit register.
cpu_rrc :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    src := extract_src_register(opcode_data)
    data: byte

    if src == OPCODE_REGISTER_HL_INDEX { 
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
        
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, src)
    }

    // Bit 0 -> Carry Flag
    new_carry_flag_from_bit_0 := data & 0x01
    set_carry_flag(&cpu.registers, bool(new_carry_flag_from_bit_0))

    // Circular Rotate to the right
    data = bits.rotate_left8(data, -1)
    
    if src == OPCODE_REGISTER_HL_INDEX { 
        bus_write(cpu.bus, u16(cpu.registers.HL), data)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = src,
            value = data
        )
    }

    set_zero_flag(&cpu.registers, data == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}


// Same as rra, but for any 8-bit register.
cpu_rr :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    src := extract_src_register(opcode_data)
    old_carry_flag := u8(is_carry_flag_set(cpu.registers)) << 7
    data: byte

    if src == OPCODE_REGISTER_HL_INDEX { 
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
        
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, src)
    }

    // Bit 0 -> Carry Flag
    new_carry_flag_from_bit_0 := data & 0x01
    set_carry_flag(&cpu.registers, bool(new_carry_flag_from_bit_0))

    // Rotate to the right
    data = data >> 1

    // Set bit 7 to be the old carry flag
    data = data | old_carry_flag
    
    if src == OPCODE_REGISTER_HL_INDEX { 
        bus_write(cpu.bus, u16(cpu.registers.HL), data)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = src,
            value = data
        )
    }

    set_zero_flag(&cpu.registers, data == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}


cpu_sla :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    src := extract_src_register(opcode_data)
    data: byte

    if src == OPCODE_REGISTER_HL_INDEX { 
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
        
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, src)
    }

    // Rotate bit 7 into carry flag
    carry := u16(data) << 1 > 0xFF
    set_carry_flag(&cpu.registers, carry)

    // Rotate left
    data = data << 1
    
    if src == OPCODE_REGISTER_HL_INDEX { 
        bus_write(cpu.bus, u16(cpu.registers.HL), data)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = src,
            value = data
        )
    }

    set_zero_flag(&cpu.registers, data == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}

cpu_sra :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    src := extract_src_register(opcode_data)
    data: byte

    if src == OPCODE_REGISTER_HL_INDEX {
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, src)
    }

    // Rotate bit 0 into the carry flag
    carry := u8(data) & 0x01
    set_carry_flag(&cpu.registers, bool(carry))

    // Leave bit 7 alone
    bit_7 := data & 0b1_000_0000

    // Rotate right
    data = data >> 1
    data = data | bit_7

    if src == OPCODE_REGISTER_HL_INDEX {
        bus_write(cpu.bus, u16(cpu.registers.HL), data)
    } else {
        set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = src,
        value = data
        )
    }

    set_zero_flag(&cpu.registers, data == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}

cpu_srl :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    src := extract_src_register(opcode_data)
    data: byte

    if src == OPCODE_REGISTER_HL_INDEX { 
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
        
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, src)
    }

    // Bit 0 -> Carry Flag
    new_carry_flag_from_bit_0 := data & 0x01
    set_carry_flag(&cpu.registers, bool(new_carry_flag_from_bit_0))

    // Rotate to the right
    data = data >> 1

    if src == OPCODE_REGISTER_HL_INDEX { 
        bus_write(cpu.bus, u16(cpu.registers.HL), data)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = src,
            value = data
        )
    }

    set_zero_flag(&cpu.registers, data == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}


cpu_swap :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    src := extract_src_register(opcode_data)
    data: byte

    if src == OPCODE_REGISTER_HL_INDEX { 
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
        
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, src)
    }

    // Swap bits 0-3 with bits 4-7
    data = data << 4 | data >> 4
    
    if src == OPCODE_REGISTER_HL_INDEX { 
        bus_write(cpu.bus, u16(cpu.registers.HL), data)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = src,
            value = data
        )
    }

    set_zero_flag(&cpu.registers, data == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
    set_carry_flag(&cpu.registers, false)
}


cpu_bit :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    bit := extract_dst_register(opcode_data)
    register_to_fetch_bit_from := extract_src_register(opcode_data)

    data: byte
    
    if register_to_fetch_bit_from == OPCODE_REGISTER_HL_INDEX { 
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
        
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, register_to_fetch_bit_from)
    }

    set_zero_flag(&cpu.registers, (data >> bit) & 0x01 == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, true)
}


cpu_set :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    bit := extract_dst_register(opcode_data)
    register := extract_src_register(opcode_data)

    data: byte
    
    if register == OPCODE_REGISTER_HL_INDEX { 
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
        
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, register)
    }

    // Turns the inputted bit on.
    data = (data | (0x01 << bit))

    if register == OPCODE_REGISTER_HL_INDEX { 
        bus_write(cpu.bus, u16(cpu.registers.HL), data)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = register,
            value = data
        )
    }
}


cpu_res :: #force_inline proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    bit := extract_dst_register(opcode_data)
    register := extract_src_register(opcode_data)

    data: byte
    
    if register == OPCODE_REGISTER_HL_INDEX { 
        data = bus_read(cpu.bus^, u16(cpu.registers.HL))
        
    } else {
        data = get_register_value_from_opcode_index(cpu.registers, register)
    }

    // Turns the inputted bit off.
    data = data & ~(byte(1) << byte(bit))

    if register == OPCODE_REGISTER_HL_INDEX { 
        bus_write(cpu.bus, u16(cpu.registers.HL), data)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = register,
            value = data
        )
    }
}