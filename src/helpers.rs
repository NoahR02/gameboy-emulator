pub fn extract_rightmost_3_bits(opcode: u8) -> u8 {
    let src_mask = 0b00000111;
    let src_register = opcode & src_mask;
    src_register
}

pub fn extract_bits_5_4_3(opcode: u8) -> u8 {
    let dst_mask = 0b00111000;
    let dst_register = (opcode & dst_mask) >> 3;
    dst_register
}

pub fn extract_bits_5_4(opcode: u8) -> u8 {
    let dst_mask = 0b00110000;

    let dst_register = (opcode & dst_mask) >> 4;
    dst_register
}

#[inline(always)]
pub fn extract_src_register(opcode: u8) -> u8 {
    extract_rightmost_3_bits(opcode)
}

#[inline(always)]
pub fn extract_dst_register(opcode: u8) -> u8 {
    extract_bits_5_4_3(opcode)
}

#[inline(always)]
pub fn extract_dst_register_pair(opcode: u8) -> u8 {
    extract_bits_5_4(opcode)
}