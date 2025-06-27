use crate::bus::bus::Bus;
use crate::cpu::cpu::Cpu;
use crate::cpu::registers::{compute_carry_flag_by_8_bit_addition, compute_half_carry_flag_by_8_bit_addition, get_register_value_from_opcode_index, set_carry_flag, set_half_carry_flag, set_n_flag, set_register_pair_value_from_opcode_index, set_register_value_from_opcode_index, set_zero_flag, Register, OPCODE_REGISTER_A_INDEX, OPCODE_REGISTER_HL_INDEX};
use crate::helpers::{extract_dst_register, extract_dst_register_pair, extract_src_register};

impl Cpu {
    // 8-bit Load/Store/Move START
    pub fn ld_8_bit(&mut self, bus: &mut Bus, opcode: u8)  {
        let dst = extract_dst_register(opcode);
        let src = extract_src_register(opcode);
    
        if dst == OPCODE_REGISTER_HL_INDEX {
            bus.write(self.registers.HL.as_u16(), get_register_value_from_opcode_index(&self.registers, src))
        } else if src == OPCODE_REGISTER_HL_INDEX {
            let val = bus.read(self.registers.HL.as_u16());
            set_register_value_from_opcode_index(&mut self.registers, dst, val);
        } else {
            let val = get_register_value_from_opcode_index(&self.registers, src);
            set_register_value_from_opcode_index(&mut self.registers, dst, val);
        }
    }
    
    pub fn ld_immediate_into_register_8_bit(&mut self, bus: &mut Bus, opcode: u8, opcode_data: u8)  {
        let dst = extract_dst_register(opcode);
        let immediate = opcode_data;
    
        if dst == OPCODE_REGISTER_HL_INDEX {
            bus.write(self.registers.HL.as_u16(), immediate)
            
        } else {
            set_register_value_from_opcode_index(&mut self.registers, dst, immediate)
        }
    }
    
    pub fn ld_a_with_value_or_store_at_register_pair_address(&mut self, bus: &mut Bus, opcode: u8)  {
        // These instructions are a bit odd because they have to support HLI + HLD.
        //  We will always use A as the src or dest here.
    
        const LD_BC_A: u8  = 0;
        const LD_DE_A: u8  = 2;
        const LD_HLI_A: u8 = 4;
        const LD_HLD_A: u8 = 6;
    
        const LD_A_BC: u8  = 1;
        const LD_A_DE: u8  = 3;
        const LD_A_HLI: u8 = 5;
        const LD_A_HLD: u8 = 7;
    
        let dst = extract_dst_register(opcode);
        let a_register_value = get_register_value_from_opcode_index(&self.registers, OPCODE_REGISTER_A_INDEX);
    
        match dst {
            LD_BC_A => {
                bus.write(self.registers.BC.as_u16(), a_register_value);
            }
            LD_DE_A => {
                bus.write(self.registers.DE.as_u16(), a_register_value);
            }
            LD_HLI_A => {
                bus.write(self.registers.HL.as_u16(), a_register_value);
                self.registers.HL = Register(self.registers.HL.as_u16().wrapping_add(1));
            }
            LD_HLD_A => {
                bus.write(self.registers.HL.as_u16(), a_register_value);
                self.registers.HL = Register(self.registers.HL.as_u16().wrapping_sub(1));
            }
            LD_A_BC => {
                self.registers.AF.set_high(bus.read(self.registers.BC.as_u16()));
            }
            LD_A_DE => {
                self.registers.AF.set_high(bus.read(self.registers.DE.as_u16()));
            }
            LD_A_HLI => {
                self.registers.AF.set_high(bus.read(self.registers.HL.as_u16()));
                self.registers.HL = Register(self.registers.HL.as_u16().wrapping_add(1));
            }
            LD_A_HLD => {
                self.registers.AF.set_high(bus.read(self.registers.HL.as_u16()));
                self.registers.HL = Register(self.registers.HL.as_u16().wrapping_sub(1));
            }
            _ => {
                unreachable!()
            }
        }
    }
    
    pub fn ld_a_at_address(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u16)  {
        bus.write(opcode_data, self.registers.AF.high())
    }
    
    pub fn ld_data_at_address_to_a(&mut self, bus: &Bus, _opcode: u8, opcode_data: u16)  {
         self.registers.AF.set_high(bus.read(opcode_data));
    }
    
    // ldh = Load from high page
    pub fn ldh_plus_c_register_from_a(&mut self, bus: &mut Bus, _opcode: u8)  {
        let address = 0xFF00 + self.registers.BC.low() as u16;
        bus.write(address, self.registers.AF.high());
    }
    
    pub fn ldh_plus_c_register_to_a(&mut self, bus: &mut Bus, _opcode: u8)  {
        let address = 0xFF00 + self.registers.BC.low() as u16;
        self.registers.AF.set_high(bus.read(address));
    }
    
    // ldh = Load from high page
    pub fn ldh_from_a(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u8)  {
        let address = 0xFF00 + opcode_data as u16;
        bus.write(address, self.registers.AF.high());
    }
    
    
    // ldh = Load from high page
    pub fn ldh_to_a(&mut self, bus: &Bus, _opcode: u8, opcode_data: u8)  {
        let address = 0xFF00 + opcode_data as u16;
        self.registers.AF.set_high(bus.read(address));
    }
    
    // 8-bit Load/Store/Move END
    
    // 16-bit Load/Store/Move START
    
    pub fn ld_hl_into_sp(&mut self, _opcode: u8) {
        self.registers.SP = self.registers.HL
    }
    
    pub fn ld_sp_at_address(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u16)  {
        bus.write(opcode_data, self.registers.SP.low());
        bus.write(opcode_data + 1, self.registers.SP.high());
    }
    
    pub fn ld_immediate_into_register_pair_16_bit(&mut self, opcode: u8, opcode_data: u16)  {
        let dst = extract_dst_register_pair(opcode);
        set_register_pair_value_from_opcode_index(
            &mut self.registers,
            dst,
            opcode_data
        );
    }
    
    pub fn ld_sp_plus_immediate_into_hl(&mut self, _opcode: u8, opcode_data: u8) {
        set_zero_flag(&mut self.registers, false);
        set_n_flag(&mut self.registers, false);
        
        let half_carry_flag = compute_half_carry_flag_by_8_bit_addition(self.registers.SP.low(), opcode_data, 0);
        let carry_flag = compute_carry_flag_by_8_bit_addition(self.registers.SP.low(), opcode_data, 0);
        set_half_carry_flag(&mut self.registers, half_carry_flag);
        set_carry_flag(&mut self.registers, carry_flag);
    
        self.registers.HL = Register(self.registers.SP.as_u16().wrapping_add((opcode_data as i8) as u16))
    }
    
    pub fn push(&mut self, bus: &mut Bus, opcode: u8)  {
        let dst = extract_dst_register_pair(opcode);
        let low: u8;
        let high: u8;
    
        match dst {
            0 => { high = self.registers.BC.high(); low = self.registers.BC.low(); }
            1 => { high = self.registers.DE.high(); low = self.registers.DE.low(); }
            2 => { high = self.registers.HL.high(); low = self.registers.HL.low(); }
            3 => { high = self.registers.AF.high(); low = self.registers.AF.low(); }
            _ => {
                panic!("Invalid register pair index provided!")
            }
       }
    
        bus.write(self.registers.SP.as_u16() - 1, high);
        bus.write(self.registers.SP.as_u16() - 2, low);
        
        self.registers.SP = Register(self.registers.SP.as_u16() - 2);
    }
    
    pub fn pop(&mut self,  bus: &Bus, opcode: u8)  {
        let dst = extract_dst_register_pair(opcode);
        let low_sp = bus.read(self.registers.SP.as_u16());
        let high_sp = bus.read(self.registers.SP.as_u16() + 1);
    
        match dst {
            0 => { self.registers.BC.set_high(high_sp); self.registers.BC.set_low(low_sp); }
            1 => { self.registers.DE.set_high(high_sp); self.registers.DE.set_low(low_sp); }
            2 => { self.registers.HL.set_high(high_sp); self.registers.HL.set_low(low_sp); }
            3 => { 
                self.registers.AF.set_high(high_sp);
                self.registers.AF.set_low(low_sp & 0xf0);
             }
            _ => {
                panic!("Invalid register pair index provided!")
            }
       }
        
        self.registers.SP = Register(self.registers.SP.as_u16() + 2);
    }
    
    // 16-bit Load/Store/Move END
}