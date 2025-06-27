use crate::bus::bus::Bus;
use crate::cpu::cpu::Cpu;
use crate::cpu::registers::{get_register_value_from_opcode_index, is_carry_flag_set, set_carry_flag, set_half_carry_flag, set_n_flag, set_register_value_from_opcode_index, set_zero_flag, OPCODE_REGISTER_HL_INDEX};
use crate::helpers::{extract_dst_register, extract_src_register};

impl Cpu {
    pub fn rlca(&mut self, _opcode: u8) {
        // Rotate bit 7 into carry flag
        let carry = (self.registers.AF.high() as u16) << 1 > 0xFF;
        set_carry_flag(&mut self.registers, carry);
    
        // Circular Rotate
        self.registers.AF.set_high(self.registers.AF.high().rotate_left(1));
    
        set_zero_flag(&mut self.registers, false);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    
    pub fn rla(&mut self, _opcode: u8) {
        let old_carry_flag = is_carry_flag_set(&self.registers) as u8;
        
        // Rotate bit 7 into carry flag
        let carry = (self.registers.AF.high() as u16) << 1 > 0xFF;
        set_carry_flag(&mut self.registers, carry);
    
        // Rotate left
        self.registers.AF.set_high(self.registers.AF.high() << 1);
    
        // Set bit 0 to be the old carry flag
        self.registers.AF.set_high(self.registers.AF.high() | old_carry_flag);
    
        set_zero_flag(&mut self.registers, false);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    
    pub fn rrca(&mut self, opcode: u8) {
        // Bit 0 -> Carry Flag
        let new_carry_flag_from_bit_0 = self.registers.AF.high() & 0x01;
        set_carry_flag(&mut self.registers, new_carry_flag_from_bit_0 != 0);
    
        // Circular Rotate to the right
        self.registers.AF.set_high(self.registers.AF.high().rotate_right(1));
    
        set_zero_flag(&mut self.registers, false);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    
    pub fn rra(&mut self, _opcode: u8) {
        let old_carry_flag = (is_carry_flag_set(&self.registers) as u8) << 7;
    
        // Bit 0 -> Carry Flag
        let new_carry_flag_from_bit_0 = self.registers.AF.high() & 0x01;
        set_carry_flag(&mut self.registers, new_carry_flag_from_bit_0 != 0);
    
        // Rotate to the right
        self.registers.AF.set_high(self.registers.AF.high() >> 1);
    
        // Set bit 7 to be the old carry flag
        self.registers.AF.set_high(self.registers.AF.high() | old_carry_flag);
    
        set_zero_flag(&mut self.registers, false);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    
    // Same as rlca, but for any 8-bit register.
    pub fn rlc(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8) {
        let src = extract_src_register(opcode_data);
        let mut data: u8;
    
        if src == OPCODE_REGISTER_HL_INDEX { 
            data = bus.read(self.registers.HL.as_u16());
            
        } else {
            data = get_register_value_from_opcode_index(&self.registers, src);
        }
    
        // Rotate bit 7 into carry flag
        let carry = (data as u16) << 1 > 0xFF;
        set_carry_flag(&mut self.registers, carry);
    
        // Circular Rotate
        data = data.rotate_left(1);
    
        
        if src == OPCODE_REGISTER_HL_INDEX { 
            bus.write(self.registers.HL.as_u16(), data);
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                src,
                data
            );
        }
    
        set_zero_flag(&mut self.registers, data == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    
    // Same as rla, but for any 8-bit register.
    pub fn rl(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8) {
        let src = extract_src_register(opcode_data);
        let old_carry_flag = is_carry_flag_set(&self.registers) as u8;
        let mut data: u8;
    
        if src == OPCODE_REGISTER_HL_INDEX { 
            data = bus.read(self.registers.HL.as_u16());
            
        } else {
            data = get_register_value_from_opcode_index(&self.registers, src);
        }
    
        // Rotate bit 7 into carry flag
        let carry = (data as u16) << 1 > 0xFF;
        set_carry_flag(&mut self.registers, carry);
    
        // Rotate left
        data = data << 1;
    
        // Set bit 0 to be the old carry flag
        data = data | old_carry_flag;
        
        if src == OPCODE_REGISTER_HL_INDEX { 
            bus.write(self.registers.HL.as_u16(), data);
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                src,
                data
            );
        }
    
        set_zero_flag(&mut self.registers, data == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    
    // Same as rrca, but for any 8-bit register.
    pub fn rrc(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8) {
        let src = extract_src_register(opcode_data);
        let mut data: u8;
    
        if src == OPCODE_REGISTER_HL_INDEX { 
            data = bus.read(self.registers.HL.as_u16());
        } else {
            data = get_register_value_from_opcode_index(&self.registers, src);
        }
    
        // Bit 0 -> Carry Flag
        let new_carry_flag_from_bit_0 = data & 0x01;
        set_carry_flag(&mut self.registers, new_carry_flag_from_bit_0 != 0);
    
        // Circular Rotate to the right
        data = data.rotate_right(1);
        
        if src == OPCODE_REGISTER_HL_INDEX { 
            bus.write(self.registers.HL.as_u16(), data)
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                src,
                data
            )
        }
    
        set_zero_flag(&mut self.registers, data == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    
    // Same as rra, but for any 8-bit register.
    pub fn rr(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8) {
        let src = extract_src_register(opcode_data);
        let old_carry_flag = (is_carry_flag_set(&self.registers) as u8) << 7;
        let mut data: u8;
    
        if src == OPCODE_REGISTER_HL_INDEX { 
            data = bus.read(self.registers.HL.as_u16())
            
        } else {
            data = get_register_value_from_opcode_index(&self.registers, src)
        }
    
        // Bit 0 -> Carry Flag
        let new_carry_flag_from_bit_0 = data & 0x01;
        set_carry_flag(&mut self.registers, new_carry_flag_from_bit_0 != 0);
    
        // Rotate to the right
        data = data >> 1;
    
        // Set bit 7 to be the old carry flag
        data = data | old_carry_flag;
        
        if src == OPCODE_REGISTER_HL_INDEX { 
            bus.write(self.registers.HL.as_u16(), data)
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                src,
                data
            )
        }
    
        set_zero_flag(&mut self.registers, data == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    
    pub fn sla(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8) {
        let src = extract_src_register(opcode_data);
        let mut data: u8;
    
        if src == OPCODE_REGISTER_HL_INDEX { 
            data = bus.read(self.registers.HL.as_u16());
            
        } else {
            data = get_register_value_from_opcode_index(&self.registers, src);
        }
    
        // Rotate bit 7 into carry flag
        let carry = (data as u16) << 1 > 0xFF;
        set_carry_flag(&mut self.registers, carry);
    
        // Rotate left
        data = data << 1;
        
        if src == OPCODE_REGISTER_HL_INDEX { 
            bus.write(self.registers.HL.as_u16(), data)
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                src,
                data
            )
        }
    
        set_zero_flag(&mut self.registers, data == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    pub fn sra(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8) {
        let src = extract_src_register(opcode_data);
        let mut data: u8;
    
        if src == OPCODE_REGISTER_HL_INDEX {
            data = bus.read(self.registers.HL.as_u16())
        } else {
            data = get_register_value_from_opcode_index(&self.registers, src)
        }
    
        // Rotate bit 0 into the carry flag
        let carry = (data as u8) & 0x01;
        set_carry_flag(&mut self.registers, carry != 0);
    
        // Leave bit 7 alone
        let bit_7 = data & 0b1_000_0000;
    
        // Rotate right
        data = data >> 1;
        data = data | bit_7;
    
        if src == OPCODE_REGISTER_HL_INDEX {
            bus.write(self.registers.HL.as_u16(), data)
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                src,
                data
            )
        }
    
        set_zero_flag(&mut self.registers, data == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    pub fn srl(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8) {
        let src = extract_src_register(opcode_data);
        let mut data: u8;
    
        if src == OPCODE_REGISTER_HL_INDEX { 
            data = bus.read(self.registers.HL.as_u16());
            
        } else {
            data = get_register_value_from_opcode_index(&self.registers, src);
        }
    
        // Bit 0 -> Carry Flag
        let new_carry_flag_from_bit_0 = data & 0x01;
        set_carry_flag(&mut self.registers, new_carry_flag_from_bit_0 != 0);
    
        // Rotate to the right
        data = data >> 1;
    
        if src == OPCODE_REGISTER_HL_INDEX { 
            bus.write(self.registers.HL.as_u16(), data);
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                src,
                data
            );
        }
    
        set_zero_flag(&mut self.registers, data == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
    }
    
    
    pub fn swap(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8) {
        let src = extract_src_register(opcode_data);
        let mut data: u8;
    
        if src == OPCODE_REGISTER_HL_INDEX { 
            data = bus.read(self.registers.HL.as_u16())
            
        } else {
            data = get_register_value_from_opcode_index(&self.registers, src)
        }
    
        // Swap bits 0-3 with bits 4-7
        data = data << 4 | data >> 4;
        
        if src == OPCODE_REGISTER_HL_INDEX { 
            bus.write(self.registers.HL.as_u16(), data)
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                src,
                data
            )
        }
    
        set_zero_flag(&mut self.registers, data == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, false);
        set_carry_flag(&mut self.registers, false);
    }
    
    
    pub fn bit(&mut self, bus: &Bus, _opcode: u8, opcode_data: u8) {
        let bit = extract_dst_register(opcode_data);
        let register_to_fetch_bit_from = extract_src_register(opcode_data);
    
        let mut data: u8;
        
        if register_to_fetch_bit_from == OPCODE_REGISTER_HL_INDEX { 
            data = bus.read(self.registers.HL.as_u16());
            
        } else {
            data = get_register_value_from_opcode_index(&self.registers, register_to_fetch_bit_from);
        }
    
        set_zero_flag(&mut self.registers, (data >> bit) & 0x01 == 0);
        set_n_flag(&mut self.registers, false);
        set_half_carry_flag(&mut self.registers, true);
    }
    
    
    pub fn set(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8) {
        let bit = extract_dst_register(opcode_data);
        let register = extract_src_register(opcode_data);
    
        let mut data: u8;
        
        if register == OPCODE_REGISTER_HL_INDEX { 
            data = bus.read(self.registers.HL.as_u16());
            
        } else {
            data = get_register_value_from_opcode_index(&self.registers, register);
        }
    
        // Turns the inputted bit on.
        data = data | (0x01 << bit);
    
        if register == OPCODE_REGISTER_HL_INDEX { 
            bus.write(self.registers.HL.as_u16(), data)
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                register,
                data
            );
        }
    }
    
    
    pub fn res(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8) {
        let bit = extract_dst_register(opcode_data);
        let register = extract_src_register(opcode_data);
    
        let mut data: u8;
        
        if register == OPCODE_REGISTER_HL_INDEX { 
            data = bus.read(self.registers.HL.as_u16());
            
        } else {
            data = get_register_value_from_opcode_index(&self.registers, register);
        }
    
        // Turns the inputted bit off.
        data = data & !((1 as u8) << (bit));
    
        if register == OPCODE_REGISTER_HL_INDEX { 
            bus.write(self.registers.HL.as_u16(), data);
        } else {
            set_register_value_from_opcode_index (
                &mut self.registers,
                register,
                data
            );
        }
    }
}