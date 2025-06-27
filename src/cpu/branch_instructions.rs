use crate::bus::bus::Bus;
use crate::cpu::cpu::Cpu;
use crate::cpu::registers::{is_carry_flag_set, is_zero_flag_set, Register, Registers};
use crate::helpers::extract_bits_5_4_3;

enum Condition_Code {
    NZ = 0x00,
    Z  = 0x01,
    NC = 0x02,
    C  = 0x03,
}

pub fn is_condition_true(registers: &Registers, condition: Condition_Code) -> bool {
    match condition {
        Condition_Code::NZ => !is_zero_flag_set(registers),
        Condition_Code::Z  => is_zero_flag_set(registers),
        Condition_Code::NC => !is_carry_flag_set(registers),
        Condition_Code::C  => is_carry_flag_set(registers),
    }
}

pub fn extract_condition(opcode: u8) -> Condition_Code {
    let dst_mask = 0b00011000;
    let dst_register = (opcode & dst_mask) >> 3;

    debug_assert!(dst_register <= 3, "Invalid Condition_Code value: {}", dst_register);
    unsafe {
        std::mem::transmute(dst_register)
    }
}

impl Cpu {

    pub fn jp_to_hl(&mut self, opcode: u8)  {
        self.registers.PC = self.registers.HL
    }

    pub fn jp_to_address(&mut self, opcode: u8, opcode_data: u16)  {
        let address = opcode_data;
        self.registers.PC = Register(address);
    }

    pub fn jp_to_address_conditionally(&mut self, opcode: u8, opcode_data: u16)  {
        let condition = extract_condition(opcode);
        let address = opcode_data;

        if is_condition_true(&self.registers, condition) {
            self.registers.PC = Register(address);
        }
    }

    pub fn jp_to_address_at_hl(&mut self)  {
        self.registers.PC = self.registers.HL
    }

    // Jump relative to the current program counter address.
    pub fn jr_to_relative_u8_address(&mut self, opcode: u8, opcode_data: u8)  {
        let n = opcode_data as i8;

        let address = self.registers.PC.as_u16() as i32 + n as i32;
        self.registers.PC = Register(address as u16)
    }

    // Jump relative to the current program counter address if a condition is true.
    pub fn jr_to_relative_u8_address_on_condition(&mut self, opcode: u8, opcode_data: u8)  {
        let condition = extract_condition(opcode);
        let n = opcode_data as i8;

        if is_condition_true(&self.registers, condition) {
            let address = self.registers.PC.as_u16() as i32 + n as i32;
            self.registers.PC = Register(address as u16);
        }
    }


    pub fn call_address(&mut self, bus: &mut Bus, _opcode: u8, opcode_data: u16)  {
        bus.write(self.registers.SP.as_u16() - 1, self.registers.PC.high());
        bus.write(self.registers.SP.as_u16() - 2, self.registers.PC.low());
        self.registers.SP = Register(self.registers.SP.as_u16() - 2);
        let address = opcode_data;
        self.registers.PC = Register(address);
    }


    pub fn call_address_on_condition(&mut self, bus: &mut Bus, opcode: u8, opcode_data: u16)  {
        let condition = extract_condition(opcode);

        if is_condition_true(&self.registers, condition) {
            bus.write(self.registers.SP.as_u16() - 1, self.registers.PC.high());
            bus.write(self.registers.SP.as_u16() - 2, self.registers.PC.low());
            self.registers.SP = Register(self.registers.SP.as_u16() - 2);
            let address = opcode_data;
            self.registers.PC = Register(address);
        }
    }

    pub fn ret(&mut self, bus: &Bus, _opcode: u8)  {
        self.registers.PC.set_low(bus.read(self.registers.SP.as_u16()));
        self.registers.PC.set_high(bus.read(self.registers.SP.as_u16() + 1));
        self.registers.SP = Register(self.registers.SP.as_u16() + 2);
    }

    pub fn reti(&mut self, bus: &Bus, _opcode: u8)  {
        self.registers.PC.set_low(bus.read(self.registers.SP.as_u16()));
        self.registers.PC.set_high(bus.read(self.registers.SP.as_u16() + 1));
        self.registers.SP = Register(self.registers.SP.as_u16() + 2);
        self.ime = true;
    }

    pub fn ret_on_condition(&mut self, bus: &Bus, opcode: u8)  {
        let condition = extract_condition(opcode);
        if is_condition_true(&self.registers, condition) {
            self.registers.PC.set_low(bus.read(self.registers.SP.as_u16()));
            self.registers.PC.set_high(bus.read(self.registers.SP.as_u16() + 1));
            self.registers.SP = Register(self.registers.SP.as_u16() + 2);
        }
    }

    pub fn rst(&mut self, bus: &mut Bus, opcode: u8)  {
        // Map t to 1 of 8 addresses
        let t = extract_bits_5_4_3(opcode);
        let p = t * 8;
        let pc = Register(self.registers.PC.as_u16());
        bus.write(self.registers.SP.as_u16() - 1, pc.high());
        bus.write(self.registers.SP.as_u16() - 2, pc.low());
        self.registers.SP = Register(self.registers.SP.as_u16() - 2);
        self.registers.PC.set_high(0);
        self.registers.PC.set_low(p);
    }
}