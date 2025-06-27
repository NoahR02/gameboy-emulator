#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Register(pub u16);

impl Register {
    pub fn set_from_u16(&mut self, value: u16) {
        self.0 = value;
    }

    pub const fn as_u16(&self) -> u16 {
        self.0
    }

    pub const fn low(&self) -> u8 {
        (self.0 & 0x00FF) as u8
    }

    pub const fn high(&self) -> u8 {
        (self.0 >> 8) as u8
    }

    pub fn set_low(&mut self, value: u8) {
        self.0 = (self.0 & 0xFF00) | value as u16;
    }

    pub fn set_high(&mut self, value: u8) {
        self.0 = (self.0 & 0x00FF) | ((value as u16) << 8);
    }
}

pub struct Registers {
    pub BC: Register,
    pub DE: Register,
    pub HL: Register,
    pub AF: Register,
    // Program Counter
    pub PC: Register,
    // Stack Pointer
    pub SP: Register,
}

// 3 bit register opcode indices for 8 bit registers
pub const OPCODE_REGISTER_B_INDEX:  u8 = 0;
pub const OPCODE_REGISTER_C_INDEX:  u8 = 1;
pub const OPCODE_REGISTER_D_INDEX:  u8 = 2;
pub const OPCODE_REGISTER_E_INDEX:  u8 = 3;
pub const OPCODE_REGISTER_H_INDEX:  u8 = 4;
pub const OPCODE_REGISTER_L_INDEX:  u8 = 5;
pub const OPCODE_REGISTER_HL_INDEX: u8 = 6;
pub const OPCODE_REGISTER_A_INDEX:  u8 = 7;

// 2 bit register opcode indices for 16 bit registers
pub const OPCODE_REGISTER_PAIR_BC_INDEX: u8 = 0;
pub const OPCODE_REGISTER_PAIR_DE_INDEX: u8 = 1;
pub const OPCODE_REGISTER_PAIR_HL_INDEX: u8 = 2;
pub const OPCODE_REGISTER_PAIR_SP_INDEX: u8 = 3;

pub fn set_register_value_from_opcode_index(registers: &mut Registers, opcode_index: u8, value: u8) {
    match opcode_index {
        OPCODE_REGISTER_B_INDEX => registers.BC.set_high(value),
        OPCODE_REGISTER_C_INDEX => registers.BC.set_low(value),
        OPCODE_REGISTER_D_INDEX => registers.DE.set_high(value),
        OPCODE_REGISTER_E_INDEX => registers.DE.set_low(value),
        OPCODE_REGISTER_H_INDEX => registers.HL.set_high(value),
        OPCODE_REGISTER_L_INDEX => registers.HL.set_low(value),
        OPCODE_REGISTER_A_INDEX => registers.AF.set_high(value),
        _ => {
            println!("{:?}", opcode_index);
            panic!("Invalid register index provided!")
        }
   }
}

pub fn get_register_value_from_opcode_index(registers: &Registers, opcode_index: u8) -> u8 {
    match opcode_index {
        OPCODE_REGISTER_B_INDEX => registers.BC.high(),
        OPCODE_REGISTER_C_INDEX => registers.BC.low(),
        OPCODE_REGISTER_D_INDEX => registers.DE.high(),
        OPCODE_REGISTER_E_INDEX => registers.DE.low(),
        OPCODE_REGISTER_H_INDEX => registers.HL.high(),
        OPCODE_REGISTER_L_INDEX => registers.HL.low(),
        OPCODE_REGISTER_A_INDEX => registers.AF.high(),
        _ => {
            panic!("Invalid register index provided!")
        }
   }
}

pub fn get_register_pair_value_from_opcode_index(registers: &Registers, register_pair_index: u8) -> u16 {
    match register_pair_index {
         OPCODE_REGISTER_PAIR_BC_INDEX => registers.BC.as_u16(),
         OPCODE_REGISTER_PAIR_DE_INDEX => registers.DE.as_u16(),
         OPCODE_REGISTER_PAIR_HL_INDEX => registers.HL.as_u16(),
         OPCODE_REGISTER_PAIR_SP_INDEX => registers.SP.as_u16(),
        _ => {
            panic!("Invalid register pair index provided!")
        }
   }
}

pub fn set_register_pair_value_from_opcode_index(registers: &mut Registers, register_pair_index: u8, value: u16) {
    match register_pair_index {
        OPCODE_REGISTER_PAIR_BC_INDEX => registers.BC.set_from_u16(value),
        OPCODE_REGISTER_PAIR_DE_INDEX => registers.DE.set_from_u16(value),
        OPCODE_REGISTER_PAIR_HL_INDEX => registers.HL.set_from_u16(value),
        OPCODE_REGISTER_PAIR_SP_INDEX => registers.SP.set_from_u16(value),
        _ => {
            panic!("Invalid register pair index provided!")
        }
   }
}

// Flags
pub fn set_zero_flag(registers: &mut Registers, is_set: bool) {
    if is_set {
        registers.AF.set_low(0b10_00_0000 | registers.AF.low()); 
    } else {
        registers.AF.set_low(0b01_11_1111 & registers.AF.low()); 
    }
}

pub fn set_half_carry_flag(registers: &mut Registers, is_set: bool) {
    if is_set {
        registers.AF.set_low(0b00_10_0000 | registers.AF.low()); 
    } else {
        registers.AF.set_low(0b11_01_1111 & registers.AF.low());
    }
}

pub fn set_carry_flag(registers: &mut Registers, is_set: bool) {
    if is_set {
        registers.AF.set_low(0b00_01_0000 | registers.AF.low());
    } else {
        registers.AF.set_low(0b11_10_1111 & registers.AF.low());
    }
}

pub fn set_n_flag(registers: &mut Registers, is_set: bool) {
    if is_set {
        registers.AF.set_low(0b01_00_0000 | registers.AF.low());
    } else {
        registers.AF.set_low(0b10_11_1111 & registers.AF.low());
    }
}

// Excellent overview on how the half carry flag works: https://gist.github.com/meganesu/9e228b6b587decc783aa9be34ae27841

pub fn compute_half_carry_flag_by_8_bit_addition(a: u8, b: u8, carry: u8 /*= 0*/) -> bool {
    // Isolate the right nibble of each byte.
    let masked_left: u8 = a & 0xF;
    let masked_right: u8 = b & 0xF;

    masked_left + masked_right + carry > 0xF
}

pub fn compute_half_carry_flag_by_16_bit_addition(a: u16, b: u16) -> bool {
    // Isolate the right nibble of each byte.
    let masked_left: u16 = a & 0xFFF;
    let masked_right: u16 = b & 0xFFF;

    ((masked_left + masked_right) & 0x1000) == 0x1000
}

pub fn compute_half_carry_flag_by_8_bit_subtraction(a: u8, b: u8, carry: u8 /*= 0*/) -> bool {
    // Isolate the right nibble of each byte.
    let masked_left: u8 = a & 0xF;
    let masked_right: u8 = b & 0xF;

    masked_left.wrapping_sub(masked_right).wrapping_sub(carry) > 0xF
}

pub fn compute_carry_flag_by_8_bit_addition(a: u8, b: u8, carry: u8 /*= 0*/) -> bool {
    // We just need to check if the sum overflowed.
    a as i64 + b as i64 + carry as i64 > 0xFF
}

pub fn compute_carry_flag_by_16_bit_addition(a: u16, b: u16) -> bool {
    // We just need to check if the sum overflowed.
    a as i64 + b as i64 > 0xFFFF
}

pub fn compute_carry_flag_by_8_bit_subtraction(a: u8, b: u8, carry: u8 /*= 0*/) -> bool {
    // We just need to check if the sum underflowed.
    (a as i64 - b as i64 - carry as i64) < 0
}

pub fn is_zero_flag_set(registers: &Registers) -> bool {
    (registers.AF.low() & 0b10_00_0000) == 0b10_00_0000
}

pub fn is_n_flag_set(registers: &Registers) -> bool {
    (registers.AF.low() & 0b01_00_0000) == 0b01_00_0000
}

pub fn is_half_carry_flag_set(registers: &Registers) -> bool {
    (registers.AF.low() & 0b00_10_0000) == 0b00_10_0000
}

pub fn is_carry_flag_set(registers: &Registers) -> bool {
    (registers.AF.low() & 0b00_01_0000) == 0b00_01_0000
}