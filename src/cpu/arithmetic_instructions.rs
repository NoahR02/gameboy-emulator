// 8-bit START

use crate::bus::bus::Bus;
use crate::cpu::cpu::Cpu;
use crate::cpu::registers::{compute_carry_flag_by_16_bit_addition, compute_carry_flag_by_8_bit_addition, compute_carry_flag_by_8_bit_subtraction, compute_half_carry_flag_by_16_bit_addition, compute_half_carry_flag_by_8_bit_addition, compute_half_carry_flag_by_8_bit_subtraction, get_register_pair_value_from_opcode_index, get_register_value_from_opcode_index, is_carry_flag_set, is_half_carry_flag_set, is_n_flag_set, set_carry_flag, set_half_carry_flag, set_n_flag, set_register_pair_value_from_opcode_index, set_register_value_from_opcode_index, set_zero_flag, Register, OPCODE_REGISTER_A_INDEX, OPCODE_REGISTER_HL_INDEX};
use crate::helpers::{extract_dst_register, extract_dst_register_pair, extract_src_register};

impl Cpu {

    pub fn add_8_bit (&mut self, bus: &Bus, opcode: u8, add_carry_flag: bool /*= false*/)  {
        let src = extract_src_register(opcode);
    
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8;
        if src == OPCODE_REGISTER_HL_INDEX { 
            b = bus.read(self.registers.HL.as_u16());
        } else {
            b = get_register_value_from_opcode_index(&mut self.registers, src);
        }
    
        let sum: u8 = a.wrapping_add(b).wrapping_add(add_carry_flag as u8);
    
        set_zero_flag(&mut self.registers, sum == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, compute_half_carry_flag_by_8_bit_addition(a, b, add_carry_flag as u8));
        set_carry_flag(&mut self.registers, compute_carry_flag_by_8_bit_addition(a, b, add_carry_flag as u8));
    
        set_register_value_from_opcode_index (
            &mut self.registers,
            OPCODE_REGISTER_A_INDEX,
            sum
        );
    }
    
    pub fn add_immediate (&mut self, _opcode: u8, opcode_data: u8, add_carry_flag: bool /*= false*/)  {
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8 = opcode_data;
    
        let sum: u8 = a.wrapping_add(b).wrapping_add(add_carry_flag as u8);
    
        set_zero_flag(&mut self.registers, sum == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, compute_half_carry_flag_by_8_bit_addition(a, b, add_carry_flag as u8));
        set_carry_flag(&mut self.registers, compute_carry_flag_by_8_bit_addition(a, b, add_carry_flag as u8));
    
        set_register_value_from_opcode_index (
            &mut self.registers,
            OPCODE_REGISTER_A_INDEX,
            sum
        );
    }

    pub fn sub_8_bit (&mut self, bus: &Bus, opcode: u8, sub_carry_flag: bool /*= false*/)  {
        let src = extract_src_register(opcode);
    
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8;
        if src == OPCODE_REGISTER_HL_INDEX {
            b = bus.read(self.registers.HL.as_u16());
        } else {
            b = get_register_value_from_opcode_index(&mut self.registers, src);
        }
    
        let difference: u8 = a.wrapping_sub(sub_carry_flag as u8).wrapping_sub(b);
    
        set_zero_flag(&mut self.registers, difference == 0);
        set_n_flag(&mut self.registers, true);
        set_half_carry_flag(&mut self.registers, compute_half_carry_flag_by_8_bit_subtraction(a, b, sub_carry_flag as u8));
        set_carry_flag(&mut self.registers, compute_carry_flag_by_8_bit_subtraction(a, b, sub_carry_flag as u8));
    
        set_register_value_from_opcode_index (
            &mut self.registers,
            OPCODE_REGISTER_A_INDEX,
            difference
        );
    }

    pub fn sub_immediate (&mut self, _opcode: u8, opcode_data: u8, sub_carry_flag: bool /*= false*/)  {
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8 = opcode_data;
        let difference: u8 = a.wrapping_sub(b).wrapping_sub(sub_carry_flag as u8);
    
        set_zero_flag(&mut self.registers, difference == 0);
        set_n_flag(&mut self.registers, true);
        set_half_carry_flag(&mut self.registers, compute_half_carry_flag_by_8_bit_subtraction(a, b, sub_carry_flag as u8));
        set_carry_flag(&mut self.registers, compute_carry_flag_by_8_bit_subtraction(a, b, sub_carry_flag as u8));
    
        set_register_value_from_opcode_index (
            &mut self.registers,
            OPCODE_REGISTER_A_INDEX,
            difference
        );
    }

    pub fn inc_register_8_bit (&mut self, bus: &mut Bus, opcode: u8)  {
        let dst = extract_dst_register(opcode);
    
        let mut a: u8;
        let b: u8 = 1;
        if dst == OPCODE_REGISTER_HL_INDEX {
            a = bus.read(self.registers.HL.as_u16());
        } else {
            a = get_register_value_from_opcode_index(&mut self.registers, dst);
        }
    
        let sum: u8 = a.wrapping_add(b);
    
        set_zero_flag(&mut self.registers, sum == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, compute_half_carry_flag_by_8_bit_addition(a, b, 0));
    
        if dst == OPCODE_REGISTER_HL_INDEX { 
            bus.write(self.registers.HL.as_u16(), sum);
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                dst,
                sum
            );
        }
    }

    pub fn dec_register_8_bit (&mut self, bus: &mut Bus, opcode: u8)  {
        let dst = extract_dst_register(opcode);
    
        let a: u8;
        let b: u8 = 1;
        if dst == OPCODE_REGISTER_HL_INDEX {
            a = bus.read(self.registers.HL.as_u16());
        } else {
            a = get_register_value_from_opcode_index(&mut self.registers, dst);
        }
        let difference: u8 = a.wrapping_sub(b);
    
        set_zero_flag(&mut self.registers, difference == 0);
        set_n_flag(&mut self.registers, true);
        set_half_carry_flag(&mut self.registers, compute_half_carry_flag_by_8_bit_subtraction(a, b, 0));
    
        if dst == OPCODE_REGISTER_HL_INDEX {
            bus.write(self.registers.HL.as_u16(), difference);
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                dst,
                difference
            );
        }
    }

    pub fn xor_8_bit (&mut self, bus: &Bus, opcode: u8)  {
        
        let src = extract_src_register(opcode);
    
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8;
        if src == OPCODE_REGISTER_HL_INDEX { 
            b = bus.read(self.registers.HL.as_u16());
            
        } else {
            b = get_register_value_from_opcode_index(&mut self.registers, src);
        }
    
        let xor_val: u8 = a ^ b;
    
        set_zero_flag(&mut self.registers, xor_val == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
        set_carry_flag(&mut self.registers, false);
    
        set_register_value_from_opcode_index (
            &mut self.registers,
            OPCODE_REGISTER_A_INDEX,
            xor_val
        );
    }

    pub fn xor_immediate (&mut self, _opcode: u8, opcode_data: u8)  {
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8 = opcode_data;

        let xor_val: u8 = a ^ b;
    
        set_zero_flag(&mut self.registers, xor_val == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
        set_carry_flag(&mut self.registers, false);
    
        set_register_value_from_opcode_index (
            &mut self.registers,
            OPCODE_REGISTER_A_INDEX,
            xor_val
        );
        return
    }

    pub fn cp_8_bit (&mut self, bus: &Bus, opcode: u8)  {
        let src = extract_src_register(opcode);
    
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8;
        if src == OPCODE_REGISTER_HL_INDEX {
            b = bus.read(self.registers.HL.as_u16());
            
        } else {
            b = get_register_value_from_opcode_index(&mut self.registers, src);
        }
    
        let difference: u8 = a.wrapping_sub(b);
    
        set_zero_flag(&mut self.registers, difference == 0);
        set_n_flag(&mut self.registers, true);
        set_half_carry_flag(&mut self.registers, compute_half_carry_flag_by_8_bit_subtraction(a, b, 0));
        set_carry_flag(&mut self.registers, compute_carry_flag_by_8_bit_subtraction(a, b, 0));
    }

    pub fn cp_immediate (&mut self, _opcode: u8, opcode_data: u8)  {
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8 = opcode_data;
    
        let difference: u8 = a.wrapping_sub(b);
    
        set_zero_flag(&mut self.registers, difference == 0);
        set_n_flag(&mut self.registers, true);
        set_half_carry_flag(&mut self.registers, compute_half_carry_flag_by_8_bit_subtraction(a, b, 0));
        set_carry_flag(&mut self.registers, compute_carry_flag_by_8_bit_subtraction(a, b, 0));
    }

    pub fn and_8_bit (&mut self, bus: &Bus, opcode: u8)  {
        let src = extract_src_register(opcode);
    
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8;
        if src == OPCODE_REGISTER_HL_INDEX { 
            b = bus.read(self.registers.HL.as_u16());
        } else {
            b = get_register_value_from_opcode_index(&mut self.registers, src);
        }
    
        let and_val: u8 = a & b;
    
        set_zero_flag(&mut self.registers, and_val == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, true);
        set_carry_flag(&mut self.registers, false);
    
        set_register_value_from_opcode_index (
            &mut self.registers,
            OPCODE_REGISTER_A_INDEX,
            and_val
        );
    }

    pub fn and_immediate_8_bit (&mut self, opcode: u8, opcode_data: u8)  {
        let src = extract_src_register(opcode);
    
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8 = opcode_data;
    
        let and_val: u8 = a & b;
    
        set_zero_flag(&mut self.registers, and_val == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, true);
        set_carry_flag(&mut self.registers, false);
    
        set_register_value_from_opcode_index (
            &mut self.registers,
            OPCODE_REGISTER_A_INDEX,
            and_val
        );
    }

    pub fn or_8_bit (&mut self, bus: &Bus, opcode: u8)  {
        let src = extract_src_register(opcode);
    
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8 = if src == OPCODE_REGISTER_HL_INDEX { 
            bus.read(self.registers.HL.as_u16())
        } else {
            get_register_value_from_opcode_index(&mut self.registers, src)
        };
    
        let or_val: u8 = a | b;
    
        set_zero_flag(&mut self.registers, or_val == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
        set_carry_flag(&mut self.registers, false);
    
        set_register_value_from_opcode_index (
            &mut self.registers,
            OPCODE_REGISTER_A_INDEX,
            or_val
        );
    }

    pub fn or_8_bit_immediate (&mut self, opcode: u8, opcode_data: u8)  {
        let src = extract_src_register(opcode);
    
        let a = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let b: u8 = opcode_data;
    
        let or_val: u8 = a | b;
    
        set_zero_flag(&mut self.registers, or_val == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
        set_carry_flag(&mut self.registers, false);
    
        set_register_value_from_opcode_index (
            &mut self.registers,
            OPCODE_REGISTER_A_INDEX,
            or_val
        );
    }

    pub fn daa(&mut self, _opcode: u8)  {
        let mut number = get_register_value_from_opcode_index(&mut self.registers, OPCODE_REGISTER_A_INDEX);
        let mut offset_value: u8 = 0;
    
        // Convert the binary number to a BCD (binary coded decimal).
    
        // For the first four bits (a digit in BCD), offset it by 6 if it overflows/is greater than 9.
        if is_half_carry_flag_set(&self.registers) || (!is_n_flag_set(&self.registers) && number & 0xf > 0x09) {
            offset_value |= 0x06;
        }
    
        // For the last four bits (a digit in BCD), offset it by 0x60 if it overflows/is greater than 0x99.
        if is_carry_flag_set(&self.registers) || (!is_n_flag_set(&self.registers) && number > 0x99) {
            offset_value |= 0x60;
            set_carry_flag(&mut self.registers, true);
        }
    
        // If we are adding then add the offset otherwise subtract it.
        if is_n_flag_set(&self.registers) {
            let (cpu_res, _) = number.overflowing_sub(offset_value);
            number = cpu_res;
        } else {
            let (res, _) = number.overflowing_add(offset_value);
            number = res;
            // The max value for each digit in a BCD is 9 and we can only have two digits, so the max value for a BCD is 0x99. 
        }
    
        set_half_carry_flag(&mut self.registers, false);
        self.registers.AF.set_high(number & 0xff);
        set_zero_flag(&mut self.registers, number == 0);
    }

    pub fn cpl(&mut self, _opcode: u8) {
        self.registers.AF.set_high(!self.registers.AF.high());
        set_n_flag(&mut self.registers, true);
        set_half_carry_flag(&mut self.registers, true);
    }

    pub fn ccf(&mut self, _opcode: u8) {
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
        let is_carry_flag_set = is_carry_flag_set(&self.registers);
        set_carry_flag(&mut self.registers, !is_carry_flag_set);
    }

    pub fn scf(&mut self, _opcode: u8) {
        set_carry_flag(&mut self.registers, true);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    // 8-bit END
    
    // 16-bit START

    pub fn add_immediate_into_sp(&mut self, _opcode: u8, opcode_data: u8)  {
        set_zero_flag(&mut self.registers, false);
        set_n_flag(&mut self.registers, false);
        
        
        let half_carry_flag_val = compute_half_carry_flag_by_8_bit_addition(self.registers.SP.low(), opcode_data, 0);
        let carry_flag_val = compute_carry_flag_by_8_bit_addition(self.registers.SP.low(), opcode_data, 0);
        set_half_carry_flag(&mut self.registers, half_carry_flag_val);
        set_carry_flag(&mut self.registers, carry_flag_val);
    
        self.registers.SP = Register(self.registers.SP.as_u16().wrapping_add((opcode_data as i8) as u16));
    }

    pub fn add_16_bit_register_pairs (&mut self, opcode: u8)  {
        let src = extract_dst_register_pair(opcode);
    
        let a = self.registers.HL.as_u16();
        let b: u16;
        match src {
            0 => b = self.registers.BC.as_u16(),
            1 => b = self.registers.DE.as_u16(),
            2 => b = self.registers.HL.as_u16(),
            3 => b = self.registers.SP.as_u16(),
            _ => unreachable!()
        }
        let sum: u16 = a.wrapping_add(b);
    
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, compute_half_carry_flag_by_16_bit_addition(a, b));
        set_carry_flag(&mut self.registers, compute_carry_flag_by_16_bit_addition(a, b));
    
        self.registers.HL = Register(sum);
    }

    pub fn inc_register_pair_16_bit (&mut self, opcode: u8)  {
        let dst = extract_dst_register_pair(opcode);
    
        let value = get_register_pair_value_from_opcode_index(&self.registers, dst).wrapping_add(1);
        set_register_pair_value_from_opcode_index(
            &mut self.registers,
            dst,
            value
        );
    }


    pub fn dec_register_pair_16_bit (&mut self, opcode: u8)  {
        let dst = extract_dst_register_pair(opcode);
    
        let value = get_register_pair_value_from_opcode_index(&self.registers, dst).wrapping_sub(1);
        set_register_pair_value_from_opcode_index(
            &mut self.registers,
            dst,
            value
        );
    }
    
    // 16-bit END
}