package gameboy

import "core:encoding/endian"
import "core:fmt"

Register :: bit_field u16 {
    low:  u8 | 8,
    high: u8 | 8,
}

Registers :: struct {
    BC: Register,    
    DE: Register,    
    HL: Register,    
    AF: Register,
    // Program Counter
    PC: Register,
    // Stack Pointer
    SP: Register,
}

// 3 bit register opcode indices for 8 bit registers
OPCODE_REGISTER_B_INDEX  :: 0
OPCODE_REGISTER_C_INDEX  :: 1
OPCODE_REGISTER_D_INDEX  :: 2
OPCODE_REGISTER_E_INDEX  :: 3
OPCODE_REGISTER_H_INDEX  :: 4
OPCODE_REGISTER_L_INDEX  :: 5
OPCODE_REGISTER_HL_INDEX :: 6
OPCODE_REGISTER_A_INDEX  :: 7

// 2 bit register opcode indices for 16 bit registers
OPCODE_REGISTER_PAIR_BC_INDEX :: 0
OPCODE_REGISTER_PAIR_DE_INDEX :: 1
OPCODE_REGISTER_PAIR_HL_INDEX :: 2
OPCODE_REGISTER_PAIR_SP_INDEX :: 3

extract_src_register :: extract_rightmost_3_bits
extract_dst_register :: extract_bits_5_4_3
extract_dst_register_pair :: extract_bits_5_4

set_register_value_from_opcode_index :: proc(registers: ^Registers, opcode_index: u8, value: u8) {
    switch opcode_index {
        case OPCODE_REGISTER_B_INDEX: registers.BC.high = value
        case OPCODE_REGISTER_C_INDEX: registers.BC.low = value
        case OPCODE_REGISTER_D_INDEX: registers.DE.high = value
        case OPCODE_REGISTER_E_INDEX: registers.DE.low = value
        case OPCODE_REGISTER_H_INDEX: registers.HL.high = value
        case OPCODE_REGISTER_L_INDEX: registers.HL.low = value
        case OPCODE_REGISTER_A_INDEX: registers.AF.high = value
        case: {
            fmt.println(opcode_index)
            panic("Invalid register index provided!")
        }
   }
}

get_register_value_from_opcode_index :: proc(registers: Registers, opcode_index: u8) -> u8 {
    switch opcode_index {
        case OPCODE_REGISTER_B_INDEX: return registers.BC.high
        case OPCODE_REGISTER_C_INDEX: return registers.BC.low
        case OPCODE_REGISTER_D_INDEX: return registers.DE.high
        case OPCODE_REGISTER_E_INDEX: return registers.DE.low
        case OPCODE_REGISTER_H_INDEX: return registers.HL.high
        case OPCODE_REGISTER_L_INDEX: return registers.HL.low
        case OPCODE_REGISTER_A_INDEX: return registers.AF.high
        case: {
            panic("Invalid register index provided!")
        }
   }
}

get_register_pair_value_from_opcode_index :: proc(registers: Registers, register_pair_index: u8) -> u16 {
    switch register_pair_index {
        case OPCODE_REGISTER_PAIR_BC_INDEX: return u16(registers.BC)
        case OPCODE_REGISTER_PAIR_DE_INDEX: return u16(registers.DE)
        case OPCODE_REGISTER_PAIR_HL_INDEX: return u16(registers.HL)
        case OPCODE_REGISTER_PAIR_SP_INDEX: return u16(registers.SP)
        case: {
            panic("Invalid register pair index provided!")
        }
   }
}

set_register_pair_value_from_opcode_index :: proc(registers: ^Registers, register_pair_index: u8, value: u16) {
    switch register_pair_index {
        case OPCODE_REGISTER_PAIR_BC_INDEX: registers.BC = Register(value)
        case OPCODE_REGISTER_PAIR_DE_INDEX: registers.DE = Register(value)
        case OPCODE_REGISTER_PAIR_HL_INDEX: registers.HL = Register(value)
        case OPCODE_REGISTER_PAIR_SP_INDEX: registers.SP = Register(value)
        case: {
            panic("Invalid register pair index provided!")
        }
   }
}

// Flags
set_zero_flag :: proc(registers: ^Registers, is_set: bool) {
    if is_set {
        registers.AF.low = 0b10_00_0000 | registers.AF.low 
    } else {
        registers.AF.low = 0b01_11_1111 & registers.AF.low 
    }
}

set_half_carry_flag :: proc(registers: ^Registers, is_set: bool) {
    if is_set {
        registers.AF.low = 0b00_10_0000 | registers.AF.low 
    } else {
        registers.AF.low = 0b11_01_1111 & registers.AF.low
    }
}

set_carry_flag :: proc(registers: ^Registers, is_set: bool) {
    if is_set {
        registers.AF.low = 0b00_01_0000 | registers.AF.low
    } else {
        registers.AF.low = 0b11_10_1111 & registers.AF.low
    }
}

set_n_flag :: proc(registers: ^Registers, is_set: bool) {
    if is_set {
        registers.AF.low = 0b01_00_0000 | registers.AF.low
    } else {
        registers.AF.low = 0b10_11_1111 & registers.AF.low
    }
}

// Excellent overview on how the half carry flag works: https://gist.github.com/meganesu/9e228b6b587decc783aa9be34ae27841

compute_half_carry_flag_by_8_bit_addition :: proc(registers: Registers, a, b: byte, carry: byte = 0) -> bool {
    // Isolate the right nibble of each byte.
    masked_left: byte = a & 0xF
    masked_right: byte = b & 0xF

    return masked_left + masked_right + carry > 0xF
}

compute_half_carry_flag_by_16_bit_addition :: proc(registers: Registers, a, b: u16) -> bool {
    // Isolate the right nibble of each byte.
    masked_left: u16 = a & 0xFFF
    masked_right: u16 = b & 0xFFF

    return ((masked_left + masked_right) & 0x1000) == 0x1000
}

compute_half_carry_flag_by_8_bit_subtraction :: proc(registers: Registers, a, b: byte, carry: byte = 0) -> bool {
    // Isolate the right nibble of each byte.
    masked_left: byte = a & 0xF
    masked_right: byte = b & 0xF

    return masked_left - masked_right - carry > 0xF
}

compute_carry_flag_by_8_bit_addition :: proc(registers: Registers, a, b: byte, carry: byte = 0) -> bool {
    // We just need to check if the sum overflowed.
    return int(a) + int(b) + int(carry) > 0xFF
}

compute_carry_flag_by_16_bit_addition :: proc(registers: Registers, a, b: u16) -> bool {
    // We just need to check if the sum overflowed.
    return int(a) + int(b) > 0xFFFF
}

compute_carry_flag_by_8_bit_subtraction :: proc(registers: Registers, a, b: byte, carry: byte = 0) -> bool {
    // We just need to check if the sum underflowed.
    return int(a) - int(b) - int(carry) < 0
}

is_zero_flag_set :: proc(registers: Registers) -> bool {
    return (registers.AF.low & 0b10_00_0000) == 0b10_00_0000
}

is_n_flag_set :: proc(registers: Registers) -> bool {
    return (registers.AF.low & 0b01_00_0000) == 0b01_00_0000
}

is_half_carry_flag_set :: proc(registers: Registers) -> bool {
    return (registers.AF.low & 0b00_10_0000) == 0b00_10_0000
}

is_carry_flag_set :: proc(registers: Registers) -> bool {
    return (registers.AF.low & 0b00_01_0000) == 0b00_01_0000
}