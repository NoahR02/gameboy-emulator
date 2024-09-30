package gameboy

import "core:fmt"
import "core:encoding/endian"

Cpu :: struct {
    bus: ^Bus,
    registers: Registers,
    // An on/off switch that when off will ignore interrupts and permit interrupts when on.
    ime: bool,
    is_halted: bool,
}

cpu_step :: proc(cpu: ^Cpu) -> (m_cycles: uint) {

    if cpu.is_halted {
        m_cycles = 1
        return
    }

    opcode := bus_read(cpu.bus^, u16(cpu.registers.PC))
    // fmt.printf("RUNNING OPCODE: %s at %s \n", format_8_bit_number(opcode), format_address([]byte{gb_state.cpu.registers.PC.low, gb_state.cpu.registers.PC.high}))
    cpu.registers.PC = Register(u16(cpu.registers.PC) + 1)

    opcode_length := OPCODE_LENGTH_TABLE[opcode]
    if opcode_length == 0 {
        opcode_length = 1
    }
    opcode_data_u8: u8 = 0
    opcode_data_u16: u16 = 0

    if opcode_length == 3 {
        byte1 := bus_read(cpu.bus^, u16(cpu.registers.PC))
        byte2 := bus_read(cpu.bus^, u16(cpu.registers.PC) + 1)
        data, __ := endian.get_u16({byte1, byte2}, .Little)
        opcode_data_u16 = data
        cpu.registers.PC = Register(u16(cpu.registers.PC) + 2)
    } else if opcode_length == 2 {
        opcode_data_u8 = bus_read(cpu.bus^, u16(cpu.registers.PC))
        cpu.registers.PC = Register(u16(cpu.registers.PC) + 1)
    }

    pc_before_execution := cpu.registers.PC

    // 0xCB prefixed instructions:
    if opcode == 0xcb {
            opcode_data_u8 = bus_read(cpu.bus^, u16(cpu.registers.PC))
            cpu.registers.PC = Register(u16(cpu.registers.PC) + 1)
            switch opcode_data_u8 {
                case 0x00..=0x07: cpu_rlc(cpu, opcode, opcode_data_u8)
                case 0x08..=0x0f: cpu_rrc(cpu, opcode, opcode_data_u8)
                case 0x10..=0x17: cpu_rl(cpu, opcode, opcode_data_u8)
                case 0x18..=0x1f: cpu_rr(cpu, opcode, opcode_data_u8)
                case 0x20..=0x27: cpu_sla(cpu, opcode, opcode_data_u8)
                case 0x28..=0x2f: cpu_sra(cpu, opcode, opcode_data_u8)
                case 0x30..=0x37: cpu_swap(cpu, opcode, opcode_data_u8)
                case 0x38..=0x3f: cpu_srl(cpu, opcode, opcode_data_u8)
                case 0x40..=0x7f: cpu_bit(cpu, opcode, opcode_data_u8)
                case 0x80..=0xbf: cpu_res(cpu, opcode, opcode_data_u8)
                case 0xc0..=0xff: cpu_set(cpu, opcode, opcode_data_u8)
            }
    } else {
        switch opcode {
            // No operation.
            case 0x00: {}

            // EI (Enable Interrupts)
            case 0xfb: cpu.ime = true // See below. EI is called at the very end of this function.

            // DI (Disable Interrupts)
            case 0xf3: cpu.ime = false

            //  --- Load Instructions START ---
            case
            0x02, 0x12, 0x22, 0x32,
            0x0a, 0x1a, 0x2a, 0x3a:  cpu_ld_a_with_value_or_store_at_register_pair_address(cpu, opcode)
            case 0x01, 0x11, 0x21, 0x31: cpu_ld_immediate_into_register_pair_16_bit(cpu, opcode, opcode_data_u16)
            case 0x0e, 0x1e, 0x2e, 0x3e, 0x26, 0x06, 0x36, 0x16: cpu_ld_immediate_into_register_8_bit(cpu, opcode, opcode_data_u8)
            case 0x40..=0x75, 0x77..=0x7F: cpu_ld_8_bit(cpu, opcode)
            case 0xe2: cpu_ldh_plus_c_register_from_a(cpu, opcode)
            case 0xf2: cpu_ldh_plus_c_register_to_a(cpu, opcode)
            case 0xea: cpu_ld_a_at_address(cpu, opcode, opcode_data_u16)
            case 0xfa: cpu_ld_data_at_address_to_a(cpu, opcode, opcode_data_u16)
            case 0x08: cpu_ld_sp_at_address(cpu, opcode, opcode_data_u16)
            case 0xf8: cpu_ld_sp_plus_immediate_into_hl(cpu, opcode, opcode_data_u8)
            case 0xf9: cpu_ld_hl_into_sp(cpu, opcode)
            case 0xe0: cpu_ldh_from_a(cpu, opcode, opcode_data_u8)
            case 0xf0: cpu_ldh_to_a(cpu, opcode, opcode_data_u8)
            case 0xe5, 0xc5, 0xd5, 0xf5: cpu_push(cpu, opcode)
            case 0xe1, 0xc1, 0xd1, 0xf1: cpu_pop(cpu, opcode)
            //  --- Load Instructions END ---

            //  --- Arithmetic Instructions START ---
            case
            0x0c, 0x1c, 0x2c, 0x3c,
            0x04, 0x14, 0x24, 0x34: cpu_inc_register_8_bit(cpu, opcode)
            case 0x03, 0x13, 0x23, 0x33: cpu_inc_register_pair_16_bit(cpu, opcode)
            case
            0x0d, 0x1d, 0x2d, 0x3d,
            0x05, 0x15, 0x25, 0x35: cpu_dec_register_8_bit(cpu, opcode)
            case 0x0b, 0x1b, 0x2b, 0x3b: cpu_dec_register_pair_16_bit(cpu, opcode)
            case 0xc6: cpu_add_immediate(cpu, opcode, opcode_data_u8)
            case 0xd6: cpu_sub_immediate(cpu, opcode, opcode_data_u8)
            case 0x80..=0x87: cpu_add_8_bit(cpu, opcode)
            case 0x88..=0x8f: cpu_add_8_bit(cpu, opcode, add_carry_flag = is_carry_flag_set(cpu.registers))
            case 0x09, 0x19, 0x29, 0x39: cpu_add_16_bit_register_pairs(cpu, opcode)
            case 0xce: cpu_add_immediate(cpu, opcode, opcode_data_u8, add_carry_flag = is_carry_flag_set(cpu.registers))
            case 0xde: cpu_sub_immediate(cpu, opcode, opcode_data_u8, sub_carry_flag = is_carry_flag_set(cpu.registers))
            case 0xee: cpu_xor_immediate(cpu, opcode, opcode_data_u8)
            case 0xfe: cpu_cp_immediate(cpu, opcode, opcode_data_u8)
            case 0x90..=0x97: cpu_sub_8_bit(cpu, opcode)
            case 0x98..=0x9f: cpu_sub_8_bit(cpu, opcode, sub_carry_flag = is_carry_flag_set(cpu.registers))
            case 0xa0..=0xa7: cpu_and_8_bit(cpu, opcode)
            case 0xa8..=0xaf: cpu_xor_8_bit(cpu, opcode)
            case 0xb0..=0xb7: cpu_or_8_bit(cpu, opcode)
            case 0xb8..=0xbf: cpu_cp_8_bit(cpu, opcode)
            case 0x37: cpu_scf(cpu, opcode)
            case 0xe8: cpu_add_immediate_into_sp(cpu, opcode, opcode_data_u8)
            case 0xe6: cpu_and_immediate_8_bit(cpu, opcode, opcode_data_u8)
            case 0xf6: cpu_or_8_bit_immediate(cpu, opcode, opcode_data_u8)
            //  --- Arithmetic Instructions END ---

            //  --- Branch Instructions START ---
            case 0xc0, 0xd0, 0xc8, 0xd8: cpu_ret_on_condition(cpu, opcode)
            case 0x18: cpu_jr_to_relative_u8_address(cpu, opcode, opcode_data_u8)
            case 0xc9: cpu_ret(cpu, opcode)
            case 0xd9: cpu_reti(cpu, opcode)
            case 0xc2, 0xca, 0xd2, 0xda: cpu_jp_to_address_conditionally(cpu, opcode, opcode_data_u16)
            case 0x20, 0x28, 0x30, 0x38: cpu_jr_to_relative_u8_address_on_condition(cpu, opcode, opcode_data_u8)
            case 0xcd: cpu_call_address(cpu, opcode, opcode_data_u16)
            case 0xc4, 0xd4, 0xcc, 0xdc: cpu_call_address_on_condition(cpu, opcode, opcode_data_u16)
            case 0xc7, 0xd7, 0xe7, 0xf7, 0xcf, 0xdf, 0xef, 0xff: cpu_rst(cpu, opcode)
            case 0xe9: cpu_jp_to_hl(cpu, opcode)
            case 0xc3: cpu_jp_to_address(cpu, opcode, opcode_data_u16)
            //  --- Branch Instructions END ---

            //  --- Rotate / Shift Instructions START ---
            case 0x07: cpu_rlca(cpu, opcode)
            case 0x0f: cpu_rrca(cpu, opcode)
            case 0x17: cpu_rla(cpu, opcode)
            case 0x27: cpu_daa(cpu, opcode)
            case 0x2f: cpu_cpl(cpu, opcode)
            case 0x3f: cpu_ccf(cpu, opcode)
            case 0x1f: cpu_rra(cpu, opcode)
            //  --- Rotate / Shift Instructions END ---

            // Empty Instructions:
            case 0xe3, 0xe4, 0xf4, 0xfc, 0xfd, 0xd3, 0xdb, 0xdd, 0xeb, 0xec, 0xed: {}

            // HALT
            case 0x76: {
                cpu.is_halted = true
            }

            case: panic(fmt.aprintfln("%s not implemented", format_8_bit_number(opcode), allocator = context.temp_allocator))
        }
    }

    if opcode == 0xcb {
        m_cycles = 2
    } else if pc_before_execution == cpu.registers.PC {
        m_cycles = uint(OPCODE_M_CYCLES_NO_BRANCH_TABLE[opcode])
    } else {
        m_cycles = uint(OPCODE_M_CYCLES_TABLE[opcode])
    }

    return
}