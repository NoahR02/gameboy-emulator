package gameboy

import "core:fmt"
import "core:os"
import "core:log"
import "core:strings"

KILOBYTE :: 1024

format_16_bit_number :: proc(address: []byte, allocator := context.temp_allocator) -> string {
    return fmt.aprintf("#%02x%02x", address[1], address[0], allocator = allocator)
}

format_8_bit_number :: proc(address: byte, allocator := context.temp_allocator) -> string {
    return fmt.aprintf("#%02x", address, allocator = allocator)
}

format_address :: proc(address: []byte, allocator := context.temp_allocator) -> string {
    return fmt.aprintf("$%02x%02x", address[1], address[0], allocator = allocator)
}

extract_rightmost_3_bits :: proc(opcode: u8) -> u8 {
    src_mask := byte(0b00000111)
    src_register := (opcode & src_mask)
    return src_register
}

extract_middle_bits :: proc(opcode: u8) -> u8 {
    dst_mask := byte(0b00111000)

    dst_register := (opcode & dst_mask) >> 3
    return dst_register
}

extract_middle_2_bits :: proc(opcode: u8) -> u8 {
    dst_mask := byte(0b00110000)

    dst_register := (opcode & dst_mask) >> 4
    return dst_register
}