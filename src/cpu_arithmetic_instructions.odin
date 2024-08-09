package gameboy

import "core:encoding/endian"
import "core:math/bits"

// 8-bit START

cpu_add_8_bit :: proc(cpu: ^Cpu, opcode: u8, add_carry_flag: bool = false)  {
    src := extract_src_register(opcode)

    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte
    if src == OPCODE_REGISTER_HL_INDEX { 
        b = memory_mapper_read(cpu.memory_mapper^, u16(cpu.registers.HL))
    } else {
        b = get_register_value_from_opcode_index(cpu.registers, src)
    }

    sum: byte = a + b + byte(add_carry_flag)

    set_zero_flag(&cpu.registers, sum == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_8_bit_addition(cpu.registers, a, b, byte(add_carry_flag)))
    set_carry_flag(&cpu.registers, compute_carry_flag_by_8_bit_addition(cpu.registers, a, b, byte(add_carry_flag)))

    set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = OPCODE_REGISTER_A_INDEX,
        value = sum
    )
}

cpu_add_immediate :: proc(cpu: ^Cpu, opcode: u8, opcode_data: u8, add_carry_flag: bool = false)  {
    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte = opcode_data

    sum: byte = a + b + byte(add_carry_flag)

    set_zero_flag(&cpu.registers, sum == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_8_bit_addition(cpu.registers, a, b, byte(add_carry_flag)))
    set_carry_flag(&cpu.registers, compute_carry_flag_by_8_bit_addition(cpu.registers, a, b, byte(add_carry_flag)))

    set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = OPCODE_REGISTER_A_INDEX,
        value = sum
    )
}

cpu_sub_8_bit :: proc(cpu: ^Cpu, opcode: u8, sub_carry_flag: bool = false)  {
    src := extract_src_register(opcode)

    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte
    if src == OPCODE_REGISTER_HL_INDEX {
        b = memory_mapper_read(cpu.memory_mapper^, u16(cpu.registers.HL))
    } else {
        b = get_register_value_from_opcode_index(cpu.registers, src)
    }

    difference: byte = a - byte(sub_carry_flag) - b

    set_zero_flag(&cpu.registers, difference == 0)
    set_n_flag(&cpu.registers, true)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_8_bit_subtraction(cpu.registers, a, b, byte(sub_carry_flag)))
    set_carry_flag(&cpu.registers, compute_carry_flag_by_8_bit_subtraction(cpu.registers, a, b, byte(sub_carry_flag)))

    set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = OPCODE_REGISTER_A_INDEX,
        value = difference
    )
}

cpu_sub_immediate :: proc(cpu: ^Cpu, opcode: u8, opcode_data: u8, sub_carry_flag: bool = false)  {
    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte = opcode_data
    difference: byte = a - b - byte(sub_carry_flag)

    set_zero_flag(&cpu.registers, difference == 0)
    set_n_flag(&cpu.registers, true)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_8_bit_subtraction(cpu.registers, a, b, byte(sub_carry_flag)))
    set_carry_flag(&cpu.registers, compute_carry_flag_by_8_bit_subtraction(cpu.registers, a, b, byte(sub_carry_flag)))

    set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = OPCODE_REGISTER_A_INDEX,
        value = difference
    )
}

cpu_inc_register_8_bit :: proc(cpu: ^Cpu, opcode: u8)  {
    dst := extract_dst_register(opcode)

    a: byte
    b: byte = 1
    if dst == OPCODE_REGISTER_HL_INDEX {
        
        a = memory_mapper_read(cpu.memory_mapper^, u16(cpu.registers.HL))
    } else {
        a = get_register_value_from_opcode_index(cpu.registers, dst)
    }

    sum: byte = a + b

    set_zero_flag(&cpu.registers, sum == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_8_bit_addition(cpu.registers, a, b))

    if dst == OPCODE_REGISTER_HL_INDEX { 
        memory_mapper_write(cpu.memory_mapper, u16(cpu.registers.HL), sum)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = dst,
            value = sum
        )
    }
}

cpu_dec_register_8_bit :: proc(cpu: ^Cpu, opcode: u8)  {
    dst := extract_dst_register(opcode)

    a: byte
    b: byte = 1
    if dst == OPCODE_REGISTER_HL_INDEX { 
        
        a = memory_mapper_read(cpu.memory_mapper^, u16(cpu.registers.HL))
    } else {
        a = get_register_value_from_opcode_index(cpu.registers, dst)
    }

    difference: byte = a - b

    set_zero_flag(&cpu.registers, difference == 0)
    set_n_flag(&cpu.registers, true)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_8_bit_subtraction(cpu.registers, a, b))

    if dst == OPCODE_REGISTER_HL_INDEX {
        memory_mapper_write(cpu.memory_mapper, u16(cpu.registers.HL), difference)
    } else {
        set_register_value_from_opcode_index (
            &cpu.registers,
            opcode_index = dst,
            value = difference
        )
    }
}

cpu_xor_8_bit :: proc(cpu: ^Cpu, opcode: u8)  {
    
    src := extract_src_register(opcode)

    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte
    if src == OPCODE_REGISTER_HL_INDEX { 
        b = memory_mapper_read(cpu.memory_mapper^, u16(cpu.registers.HL))
        
    } else {
        b = get_register_value_from_opcode_index(cpu.registers, src)
    }

    xor_val: byte = a ~ b

    set_zero_flag(&cpu.registers, xor_val == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
    set_carry_flag(&cpu.registers, false)

    set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = OPCODE_REGISTER_A_INDEX,
        value = xor_val
    )
}

cpu_xor_immediate:: proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte = opcode_data

    xor_val: byte = a ~ b

    set_zero_flag(&cpu.registers, xor_val == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
    set_carry_flag(&cpu.registers, false)

    set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = OPCODE_REGISTER_A_INDEX,
        value = xor_val
    )
    return
}

cpu_cp_8_bit :: proc(cpu: ^Cpu, opcode: u8)  {
    src := extract_src_register(opcode)

    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte
    if src == OPCODE_REGISTER_HL_INDEX {
        b = memory_mapper_read(cpu.memory_mapper^, u16(cpu.registers.HL))
        
    } else {
        b = get_register_value_from_opcode_index(cpu.registers, src)
    }

    difference: byte = a - b

    set_zero_flag(&cpu.registers, difference == 0)
    set_n_flag(&cpu.registers, true)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_8_bit_subtraction(cpu.registers, a, b))
    set_carry_flag(&cpu.registers, compute_carry_flag_by_8_bit_subtraction(cpu.registers, a, b))
}

cpu_cp_immediate :: proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte = opcode_data

    difference: byte = a - b

    set_zero_flag(&cpu.registers, difference == 0)
    set_n_flag(&cpu.registers, true)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_8_bit_subtraction(cpu.registers, a, b))
    set_carry_flag(&cpu.registers, compute_carry_flag_by_8_bit_subtraction(cpu.registers, a, b))
}

cpu_and_8_bit :: proc(cpu: ^Cpu, opcode: u8)  {
    src := extract_src_register(opcode)

    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte
    if src == OPCODE_REGISTER_HL_INDEX { 
        b = memory_mapper_read(cpu.memory_mapper^, u16(cpu.registers.HL))
    } else {
        b = get_register_value_from_opcode_index(cpu.registers, src)
    }

    and_val: byte = a & b

    set_zero_flag(&cpu.registers, and_val == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, true)
    set_carry_flag(&cpu.registers, false)

    set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = OPCODE_REGISTER_A_INDEX,
        value = and_val
    )
}

cpu_and_immediate_8_bit :: proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    src := extract_src_register(opcode)

    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte = opcode_data

    and_val: byte = a & b

    set_zero_flag(&cpu.registers, and_val == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, true)
    set_carry_flag(&cpu.registers, false)

    set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = OPCODE_REGISTER_A_INDEX,
        value = and_val
    )
}

cpu_or_8_bit :: proc(cpu: ^Cpu, opcode: u8)  {
    src := extract_src_register(opcode)

    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte
    if src == OPCODE_REGISTER_HL_INDEX { 
        b = memory_mapper_read(cpu.memory_mapper^, u16(cpu.registers.HL))
    } else {
        b = get_register_value_from_opcode_index(cpu.registers, src)
    }

    or_val: byte = a | b

    set_zero_flag(&cpu.registers, or_val == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
    set_carry_flag(&cpu.registers, false)

    set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = OPCODE_REGISTER_A_INDEX,
        value = or_val
    )
}

cpu_or_8_bit_immediate :: proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    src := extract_src_register(opcode)

    a := get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX)
    b: byte = opcode_data

    or_val: byte = a | b

    set_zero_flag(&cpu.registers, or_val == 0)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
    set_carry_flag(&cpu.registers, false)

    set_register_value_from_opcode_index (
        &cpu.registers,
        opcode_index = OPCODE_REGISTER_A_INDEX,
        value = or_val
    )
}

cpu_daa :: proc(cpu: ^Cpu, opcode: u8)  {
    number := u8(get_register_value_from_opcode_index(cpu.registers, OPCODE_REGISTER_A_INDEX))
    offset_value: byte = 0

    // Convert the binary number to a BCD (binary coded decimal).

    // For the first four bits (a digit in BCD), offset it by 6 if it overflows/is greater than 9.
    if is_half_carry_flag_set(cpu.registers) || (!is_n_flag_set(cpu.registers) && number & 0xf > 0x09) {
        offset_value |= 0x06
    }

    // For the last four bits (a digit in BCD), offset it by 0x60 if it overflows/is greater than 0x99.
    if is_carry_flag_set(cpu.registers) || (!is_n_flag_set(cpu.registers) && number > 0x99) {
        offset_value |= 0x60
        set_carry_flag(&cpu.registers, true)
    }

    // If we are adding then add the offset otherwise subtract it.
    if is_n_flag_set(cpu.registers) {
        cpu_res, _ := bits.overflowing_sub(number, offset_value)
        number = cpu_res
    } else {
        res, _ := bits.overflowing_add(number, offset_value)
        number = res
        // The max value for each digit in a BCD is 9 and we can only have two digits, so the max value for a BCD is 0x99. 
    }

    set_half_carry_flag(&cpu.registers, false)
    cpu.registers.AF.high = u8(number & 0xff)
    set_zero_flag(&cpu.registers, number == 0)
}

cpu_cpl :: proc(cpu: ^Cpu, opcode: u8) {
    cpu.registers.AF.high = ~cpu.registers.AF.high
    set_n_flag(&cpu.registers, true)
    set_half_carry_flag(&cpu.registers, true)
}

cpu_ccf :: proc(cpu: ^Cpu, opcode: u8) {
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
    set_carry_flag(&cpu.registers, !is_carry_flag_set(cpu.registers))
}

cpu_scf :: proc(cpu: ^Cpu, opcode: u8) {
    set_carry_flag(&cpu.registers, true)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, false)
}

// 8-bit END

// 16-bit START

cpu_add_immediate_into_sp :: proc(cpu: ^Cpu, opcode: u8, opcode_data: u8)  {
    set_zero_flag(&cpu.registers, false)
    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_8_bit_addition(cpu.registers, cpu.registers.SP.low, opcode_data))
    set_carry_flag(&cpu.registers, compute_carry_flag_by_8_bit_addition(cpu.registers, cpu.registers.SP.low, opcode_data))

    cpu.registers.SP = Register(u16(cpu.registers.SP) + u16(i8(opcode_data)))
}

cpu_add_16_bit_register_pairs :: proc(cpu: ^Cpu, opcode: u8)  {
    src := extract_dst_register_pair(opcode)

    a := u16(cpu.registers.HL)
    b: u16
    switch src {
        case 0: b = u16(cpu.registers.BC)
        case 1: b = u16(cpu.registers.DE)
        case 2: b = u16(cpu.registers.HL)
        case 3: b = u16(cpu.registers.SP)
    }
    sum: u16 = a + b

    set_n_flag(&cpu.registers, false)
    set_half_carry_flag(&cpu.registers, compute_half_carry_flag_by_16_bit_addition(cpu.registers, a, b))
    set_carry_flag(&cpu.registers, compute_carry_flag_by_16_bit_addition(cpu.registers, a, b))

    cpu.registers.HL = Register(sum)
}

cpu_inc_register_pair_16_bit :: proc(cpu: ^Cpu, opcode: u8)  {
    dst := extract_dst_register_pair(opcode)

    set_register_pair_value_from_opcode_index(
        &cpu.registers,
        register_pair_index = dst,
        value = get_register_pair_value_from_opcode_index(cpu.registers, dst) + 1
    )
}


cpu_dec_register_pair_16_bit :: proc(cpu: ^Cpu, opcode: u8)  {
    dst := extract_dst_register_pair(opcode)

    set_register_pair_value_from_opcode_index(
        &cpu.registers,
        register_pair_index = dst,
        value = get_register_pair_value_from_opcode_index(cpu.registers, dst) - 1
    )
}

// 16-bit END