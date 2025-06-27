use crate::bus::bus::Bus;
use crate::cpu::opcode_tables::{OPCODE_LENGTH_TABLE, OPCODE_M_CYCLES_NO_BRANCH_TABLE, OPCODE_M_CYCLES_TABLE};
use crate::cpu::registers::{is_carry_flag_set, Register, Registers};

pub struct Cpu {
    pub registers: Registers,
    // An on/off switch that when off will ignore interrupts and permit interrupts when on.
    pub ime: bool,
    pub is_halted: bool,
}

impl Cpu {
    pub(crate) fn step(&mut self, bus: &mut Bus) -> usize {
        let mut m_cycles: usize = 0;

        if self.is_halted {
            m_cycles = 1;
            return m_cycles;
        }

        let opcode = bus.read(self.registers.PC.as_u16());
        
        //println!("RUNNING OPCODE: {} at {:x}", opcode, self.registers.PC.as_u16());
        // fmt.printf("RUNNING OPCODE: %s at %s \n", format_8_bit_number(opcode), format_address([]byte{gb_state.cpu.registers.PC.low, gb_state.cpu.registers.PC.high}))
        self.registers.PC.set_from_u16(self.registers.PC.as_u16() + 1);

        let mut opcode_length = OPCODE_LENGTH_TABLE[opcode as usize];
        if opcode_length == 0 {
            opcode_length = 1;
        }
        let mut opcode_data_u8: u8 = 0;
        let mut opcode_data_u16: u16 = 0;

        if opcode_length == 3 {
            let byte1 = bus.read(self.registers.PC.as_u16());
            let byte2 = bus.read(self.registers.PC.as_u16() + 1);

            let mut data = Register(0);
            data.set_low(byte1);
            data.set_high(byte2);

            opcode_data_u16 = data.as_u16();
            self.registers.PC = Register(self.registers.PC.as_u16() + 2);
        } else if opcode_length == 2 {
            opcode_data_u8 = bus.read(self.registers.PC.as_u16());
            self.registers.PC = Register(self.registers.PC.as_u16() + 1);
        }

        let pc_before_execution = self.registers.PC;

        // 0xCB prefixed instructions:
        if opcode == 0xcb {
            opcode_data_u8 = bus.read(self.registers.PC.as_u16());
            self.registers.PC = Register(self.registers.PC.as_u16() + 1);
            match opcode_data_u8 {
                0x00..=0x07 => self.rlc(bus, opcode, opcode_data_u8),
                0x08..=0x0f => self.rrc(bus, opcode, opcode_data_u8),
                0x10..=0x17 => self.rl(bus, opcode, opcode_data_u8),
                0x18..=0x1f => self.rr(bus, opcode, opcode_data_u8),
                0x20..=0x27 => self.sla(bus, opcode, opcode_data_u8),
                0x28..=0x2f => self.sra(bus, opcode, opcode_data_u8),
                0x30..=0x37 => self.swap(bus, opcode, opcode_data_u8),
                0x38..=0x3f => self.srl(bus, opcode, opcode_data_u8),
                0x40..=0x7f => self.bit(bus, opcode, opcode_data_u8),
                0x80..=0xbf => self.res(bus, opcode, opcode_data_u8),
                0xc0..=0xff => self.set(bus, opcode, opcode_data_u8),
                _ => {
                    unreachable!();
                }
            }
        } else {
            match opcode {
                // No operation.
                0x00 => {}

                // EI (Enable Interrupts)
                0xfb => self.ime = true, // See below. EI is called at the very end of this function.

                // DI (Disable Interrupts)
                0xf3 => self.ime = false,

                //  --- Load Instructions START ---
                0x02 | 0x12 | 0x22 | 0x32 |
                0x0a | 0x1a | 0x2a | 0x3a =>  self.ld_a_with_value_or_store_at_register_pair_address(bus, opcode),
                0x01 | 0x11 | 0x21 | 0x31 => self.ld_immediate_into_register_pair_16_bit(opcode, opcode_data_u16),
                0x0e | 0x1e | 0x2e | 0x3e | 0x26 | 0x06 | 0x36 | 0x16 => self.ld_immediate_into_register_8_bit(bus, opcode, opcode_data_u8),
                0x40..=0x75 | 0x77..=0x7F => self.ld_8_bit(bus, opcode),
                0xe2 => self.ldh_plus_c_register_from_a(bus, opcode),
                0xf2 => self.ldh_plus_c_register_to_a(bus, opcode),
                0xea => self.ld_a_at_address(bus, opcode, opcode_data_u16),
                0xfa => self.ld_data_at_address_to_a(bus, opcode, opcode_data_u16),
                0x08 => self.ld_sp_at_address(bus, opcode, opcode_data_u16),
                0xf8 => self.ld_sp_plus_immediate_into_hl(opcode, opcode_data_u8),
                0xf9 => self.ld_hl_into_sp(opcode),
                0xe0 => self.ldh_from_a(bus, opcode, opcode_data_u8),
                0xf0 => self.ldh_to_a(bus, opcode, opcode_data_u8),
                0xe5 | 0xc5 | 0xd5 | 0xf5 => self.push(bus, opcode),
                0xe1 | 0xc1 | 0xd1 | 0xf1 => self.pop(bus, opcode),
                //  --- Load Instructions END ---

                //  --- Arithmetic Instructions START ---
                0x0c | 0x1c | 0x2c | 0x3c | 0x04 | 0x14 | 0x24 | 0x34 => self.inc_register_8_bit(bus, opcode),
                0x03 | 0x13 | 0x23 | 0x33 => self.inc_register_pair_16_bit(opcode),
                0x0d | 0x1d | 0x2d | 0x3d | 0x05 | 0x15 | 0x25 | 0x35 => self.dec_register_8_bit(bus, opcode),
                0x0b | 0x1b | 0x2b | 0x3b => self.dec_register_pair_16_bit(opcode),
                0xc6 => self.add_immediate(opcode, opcode_data_u8, false),
                0xd6 => self.sub_immediate(opcode, opcode_data_u8, false),
                0x80..=0x87 => self.add_8_bit(bus, opcode, false),
                0x88..=0x8f => self.add_8_bit(bus, opcode, is_carry_flag_set(&self.registers)),
                0x09 | 0x19 | 0x29 | 0x39 => self.add_16_bit_register_pairs(opcode),
                0xce => self.add_immediate(opcode, opcode_data_u8, is_carry_flag_set(&self.registers)),
                0xde => self.sub_immediate(opcode, opcode_data_u8, is_carry_flag_set(&self.registers)),
                0xee => self.xor_immediate(opcode, opcode_data_u8),
                0xfe => self.cp_immediate(opcode, opcode_data_u8),
                0x90..=0x97 => self.sub_8_bit(bus, opcode, false),
                0x98..=0x9f => self.sub_8_bit(bus, opcode, is_carry_flag_set(&self.registers)),
                0xa0..=0xa7 => self.and_8_bit(bus, opcode),
                0xa8..=0xaf => self.xor_8_bit(bus, opcode),
                0xb0..=0xb7 => self.or_8_bit(bus, opcode),
                0xb8..=0xbf => self.cp_8_bit(bus, opcode),
                0x37 => self.scf(opcode),
                0xe8 => self.add_immediate_into_sp(opcode, opcode_data_u8),
                0xe6 => self.and_immediate_8_bit(opcode, opcode_data_u8),
                0xf6 => self.or_8_bit_immediate(opcode, opcode_data_u8),
                //  --- Arithmetic Instructions END ---

                //  --- Branch Instructions START ---
                0xc0 | 0xd0 | 0xc8 | 0xd8 => self.ret_on_condition(bus, opcode),
                0x18 => self.jr_to_relative_u8_address(opcode, opcode_data_u8),
                0xc9 => self.ret(bus, opcode),
                0xd9 => self.reti(bus, opcode),
                0xc2 | 0xca | 0xd2 | 0xda => self.jp_to_address_conditionally(opcode, opcode_data_u16),
                0x20 | 0x28 | 0x30 | 0x38 => self.jr_to_relative_u8_address_on_condition(opcode, opcode_data_u8),
                0xcd => self.call_address(bus, opcode, opcode_data_u16),
                0xc4 | 0xd4 | 0xcc | 0xdc => self.call_address_on_condition(bus, opcode, opcode_data_u16),
                0xc7 | 0xd7 | 0xe7 | 0xf7 | 0xcf | 0xdf | 0xef | 0xff => self.rst(bus, opcode),
                0xe9 => self.jp_to_hl(opcode),
                0xc3 => self.jp_to_address(opcode, opcode_data_u16),
                //  --- Branch Instructions END ---

                //  --- Rotate / Shift Instructions START ---
                0x07 => self.rlca(opcode),
                0x0f => self.rrca(opcode),
                0x17 => self.rla(opcode),
                0x27 => self.daa(opcode),
                0x2f => self.cpl(opcode),
                0x3f => self.ccf(opcode),
                0x1f => self.rra(opcode),
                //  --- Rotate / Shift Instructions END ---

                // Empty Instructions:
                0xe3 | 0xe4 | 0xf4 | 0xfc | 0xfd | 0xd3 | 0xdb | 0xdd | 0xeb | 0xec | 0xed => {}

                // HALT
                0x76 => {
                    self.is_halted = true
                }

                _ => panic!("{:?} not implemented", opcode)
            }
        }

        if opcode == 0xcb {
            m_cycles = 2
        } else if pc_before_execution == self.registers.PC {
            m_cycles = OPCODE_M_CYCLES_NO_BRANCH_TABLE[opcode as usize] as usize;
        } else {
            m_cycles = OPCODE_M_CYCLES_TABLE[opcode as usize] as usize;
        }

        m_cycles
    }
}