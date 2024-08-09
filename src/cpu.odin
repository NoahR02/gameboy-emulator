package gameboy

import "core:fmt"
import "core:encoding/endian"

Cpu :: struct {
    memory_mapper: ^Memory_Mapper,
    registers: Registers,
    // An on/off switch that when off will ignore interrupts and permit interrupts when on.
    ime: bool,
}

cpu_fetch_decode_execute :: proc(gb_state: ^Gb_State) {

    m_cycles: u8 = 0
    opcode := memory_mapper_read(gb_state.memory_mapper, u16(gb_state.cpu.registers.PC))
    //fmt.printf("RUNNING OPCODE: %s at %s \n", format_8_bit_number(opcode), format_address([]byte{gb_state.cpu.registers.PC.low, gb_state.cpu.registers.PC.high}))
    gb_state.cpu.registers.PC = Register(u16(gb_state.cpu.registers.PC) + 1)

    opcode_length := OPCODE_LENGTH_TABLE[opcode]
    if opcode_length == 0 {
        opcode_length = 1
    }
    opcode_data_u8: u8 = 0
    opcode_data_u16: u16 = 0

    if opcode_length == 3 {
        byte1 := memory_mapper_read(gb_state.memory_mapper, u16(gb_state.cpu.registers.PC))
        byte2 := memory_mapper_read(gb_state.memory_mapper, u16(gb_state.cpu.registers.PC) + 1)
        data, __ := endian.get_u16({byte1, byte2}, .Little)
        opcode_data_u16 = data
        gb_state.cpu.registers.PC = Register(u16(gb_state.cpu.registers.PC) + 2)
    } else if opcode_length == 2 {
        opcode_data_u8 = memory_mapper_read(gb_state.memory_mapper, u16(gb_state.cpu.registers.PC))
        gb_state.cpu.registers.PC = Register(u16(gb_state.cpu.registers.PC) + 1)
    }

    pc_before_execution := gb_state.cpu.registers.PC

    if opcode == 0xcb {
            opcode_data_u8 = memory_mapper_read(gb_state.memory_mapper, u16(gb_state.cpu.registers.PC))
            gb_state.cpu.registers.PC = Register(u16(gb_state.cpu.registers.PC) + 1)

            switch opcode_data_u8 {
                case 0x00..=0x07: cpu_rlc(&gb_state.cpu, opcode, opcode_data_u8)
                case 0x08..=0x0f: cpu_rrc(&gb_state.cpu, opcode, opcode_data_u8)
                case 0x10..=0x17: cpu_rl(&gb_state.cpu, opcode, opcode_data_u8)
                case 0x18..=0x1f: cpu_rr(&gb_state.cpu, opcode, opcode_data_u8)
                case 0x20..=0x27: cpu_sla(&gb_state.cpu, opcode, opcode_data_u8)
                case 0x28..=0x2f: cpu_sra(&gb_state.cpu, opcode, opcode_data_u8)
                case 0x30..=0x37: cpu_swap(&gb_state.cpu, opcode, opcode_data_u8)
                case 0x38..=0x3f: cpu_srl(&gb_state.cpu, opcode, opcode_data_u8)
                case 0x40..=0x7f: cpu_bit(&gb_state.cpu, opcode, opcode_data_u8)
                case 0x80..=0xbf: cpu_res(&gb_state.cpu, opcode, opcode_data_u8)
                case 0xc0..=0xff: cpu_set(&gb_state.cpu, opcode, opcode_data_u8)
            }
    } else {
        switch opcode {
            // No operation.
            case 0x00: {}

            // EI (Enable Interrupts)
            case 0xfb: { gb_state.cpu.ime = true } // See below. EI is called at the very end of this function.

            // DI (Disable Interrupts)
            case 0xf3: gb_state.cpu.ime = false

            case
            // LD one of {BC, DE, HLI, HLD}, A
            0x02, 0x12, 0x22, 0x32,
            // LD A, one of {BC, DE, HLI, HLD}
            0x0a, 0x1a, 0x2a, 0x3a:  {
                cpu_ld_a_with_value_or_store_at_register_pair_address(&gb_state.cpu, opcode)
            }

            // ld rp, u16
            case 0x01, 0x11, 0x21, 0x31: {
                cpu_ld_immediate_into_register_pair_16_bit(&gb_state.cpu, opcode, opcode_data_u16)
            }

            // LD r8, u8
            case 0x0e, 0x1e, 0x2e, 0x3e, 0x26, 0x06, 0x36, 0x16: cpu_ld_immediate_into_register_8_bit(&gb_state.cpu, opcode, opcode_data_u8)

            // INC r8
            case
            0x0c, 0x1c, 0x2c, 0x3c,
            0x04, 0x14, 0x24, 0x34: {
                cpu_inc_register_8_bit(&gb_state.cpu, opcode)
            }

            // INC r16
            case 0x03, 0x13, 0x23, 0x33: cpu_inc_register_pair_16_bit(&gb_state.cpu, opcode)

            // DEC r8
            case
            0x0d, 0x1d, 0x2d, 0x3d,
            0x05, 0x15, 0x25, 0x35: {
                cpu_dec_register_8_bit(&gb_state.cpu, opcode)
            }

            case 0x0b, 0x1b, 0x2b, 0x3b: cpu_dec_register_pair_16_bit(&gb_state.cpu, opcode)


            // case 0x29: add_


            // LD r8, r8
            case 0x40..=0x75: cpu_ld_8_bit(&gb_state.cpu, opcode)
            // LD r8, r8
            case 0x77..=0x7F: cpu_ld_8_bit(&gb_state.cpu, opcode)

            // RET CONDITION_CODE
            case 0xc0, 0xd0: cpu_ret_on_condition(&gb_state.cpu, opcode)

            // ADD, u8
            case 0xc6: cpu_add_immediate(&gb_state.cpu, opcode, opcode_data_u8)
            // SUB, u8
            case 0xd6: cpu_sub_immediate(&gb_state.cpu, opcode, opcode_data_u8)

            // RET Z
            case 0xc8, 0xd8: cpu_ret_on_condition(&gb_state.cpu, opcode)

            // JR i8
            case 0x18: cpu_jr_to_relative_u8_address(&gb_state.cpu, opcode, opcode_data_u8)

            // RET
            case 0xc9: cpu_ret(&gb_state.cpu, opcode)

            // RETI
            case 0xd9: cpu_reti(&gb_state.cpu, opcode)

            case 0x07: cpu_rlca(&gb_state.cpu, opcode)
            case 0x0f: cpu_rrca(&gb_state.cpu, opcode)
            case 0x17: cpu_rla(&gb_state.cpu, opcode)

            // ADD r, r and ADDC r,r
            case 0x80..=0x87: cpu_add_8_bit(&gb_state.cpu, opcode)
            case 0x88..=0x8f: cpu_add_8_bit(&gb_state.cpu, opcode, add_carry_flag = is_carry_flag_set(gb_state.cpu.registers))

            // ADD Register Pairs
            case 0x09, 0x19, 0x29, 0x39: cpu_add_16_bit_register_pairs(&gb_state.cpu, opcode)

            // ADC A,u8
            case 0xce: cpu_add_immediate(&gb_state.cpu, opcode, opcode_data_u8, add_carry_flag = is_carry_flag_set(gb_state.cpu.registers))
            // SBC A,u8
            case 0xde: cpu_sub_immediate(&gb_state.cpu, opcode, opcode_data_u8, sub_carry_flag = is_carry_flag_set(gb_state.cpu.registers))
            // XOR A,u8
            case 0xee: cpu_xor_immediate(&gb_state.cpu, opcode, opcode_data_u8)
            // CP A,u8
            case 0xfe: cpu_cp_immediate(&gb_state.cpu, opcode, opcode_data_u8)

            case 0xe2: cpu_ldh_plus_c_register_from_a(&gb_state.cpu, opcode)
            case 0xf2: cpu_ldh_plus_c_register_to_a(&gb_state.cpu, opcode)

            case 0x27: cpu_daa(&gb_state.cpu, opcode)
            case 0x2f: cpu_cpl(&gb_state.cpu, opcode)
            case 0x3f: cpu_ccf(&gb_state.cpu, opcode)

            // SUB r, r and SBC r, r
            case 0x90..=0x97: cpu_sub_8_bit(&gb_state.cpu, opcode)
            case 0x98..=0x9f: cpu_sub_8_bit(&gb_state.cpu, opcode, sub_carry_flag = is_carry_flag_set(gb_state.cpu.registers))

            case 0xe9: cpu_jp_to_hl(&gb_state.cpu, opcode)

            // AND r, r
            case 0xa0..=0xa7: cpu_and_8_bit(&gb_state.cpu, opcode)
            // XOR r, r
            case 0xa8..=0xaf: cpu_xor_8_bit(&gb_state.cpu, opcode)
            // OR r, r
            case 0xb0..=0xb7: cpu_or_8_bit(&gb_state.cpu, opcode)
            // CP r, r
            case 0xb8..=0xbf: cpu_cp_8_bit(&gb_state.cpu, opcode)

            // JP u16
            case 0xc3: cpu_jp_to_address(&gb_state.cpu, opcode, opcode_data_u16)

            // JP CONDITION, u16
            case 0xc2, 0xca, 0xd2, 0xda: cpu_jp_to_address_conditionally(&gb_state.cpu, opcode, opcode_data_u16)

            // RST
            case 0xc7, 0xd7, 0xe7, 0xf7, 0xcf, 0xdf, 0xef, 0xff: cpu_rst(&gb_state.cpu, opcode)

            // RRA
            case 0x1f: cpu_rra(&gb_state.cpu, opcode)

            // JR CONDITION_CODE, i8
            case 0x20, 0x28, 0x30, 0x38: cpu_jr_to_relative_u8_address_on_condition(&gb_state.cpu, opcode, opcode_data_u8)

            case 0x37: cpu_scf(&gb_state.cpu, opcode)

            case 0xea: cpu_ld_a_at_address(&gb_state.cpu, opcode, opcode_data_u16)
            case 0xfa: cpu_ld_data_at_address_to_a(&gb_state.cpu, opcode, opcode_data_u16)

            case 0x08: cpu_ld_sp_at_address(&gb_state.cpu, opcode, opcode_data_u16)
            case 0xf8: cpu_ld_sp_plus_immediate_into_hl(&gb_state.cpu, opcode, opcode_data_u8)
            case 0xf9: cpu_ld_hl_into_sp(&gb_state.cpu, opcode)
            case 0xe8: cpu_add_immediate_into_sp(&gb_state.cpu, opcode, opcode_data_u8)

            // ldh (FF00 + u8), a
            case 0xe0: cpu_ldh_from_a(&gb_state.cpu, opcode, opcode_data_u8)
            // ldh a, (FF00 + u8)
            case 0xf0: cpu_ldh_to_a(&gb_state.cpu, opcode, opcode_data_u8)

            case 0xe5, 0xc5, 0xd5, 0xf5: cpu_push(&gb_state.cpu, opcode)
            case 0xe1, 0xc1, 0xd1, 0xf1: cpu_pop(&gb_state.cpu, opcode)
            case 0xcd: cpu_call_address(&gb_state.cpu, opcode, opcode_data_u16)
            case 0xc4, 0xd4, 0xcc, 0xdc: cpu_call_address_on_condition(&gb_state.cpu, opcode, opcode_data_u16)

            case 0xe6: cpu_and_immediate_8_bit(&gb_state.cpu, opcode, opcode_data_u8)

            case 0xf6: cpu_or_8_bit_immediate(&gb_state.cpu, opcode, opcode_data_u8)

            // Empty Instructions:
            case 0xe3, 0xe4, 0xf4, 0xfc, 0xfd, 0xd3, 0xdb, 0xdd, 0xeb, 0xec, 0xed: {}

            // HALT
            case 0x76: {
                gb_state.is_halted = true
            }

            case: panic(fmt.aprintfln("%s not implemented", format_8_bit_number(opcode), allocator = context.temp_allocator))
            }
    }
    if opcode == 0xcb {
        m_cycles = 2
    } else if pc_before_execution == gb_state.cpu.registers.PC {
        m_cycles = OPCODE_M_CYCLES_NO_BRANCH_TABLE[opcode]
    } else {
        m_cycles = OPCODE_M_CYCLES_TABLE[opcode]
    }

    gb_state.current_cycle += int(m_cycles)
}