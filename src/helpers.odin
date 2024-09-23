package gameboy

import "core:fmt"
import "core:os"
import "core:log"
import "core:strings"
import gl "vendor:OpenGL"

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

extract_bits_5_4_3 :: proc(opcode: u8) -> u8 {
    dst_mask := byte(0b00111000)

    dst_register := (opcode & dst_mask) >> 3
    return dst_register
}

extract_bits_5_4 :: proc(opcode: u8) -> u8 {
    dst_mask := byte(0b00110000)

    dst_register := (opcode & dst_mask) >> 4
    return dst_register
}

load_texture_from_memory :: proc(data: []u8, width, height: u32) -> (texture: u32) {
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)

    // Setup filtering parameters for display
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

    // Upload pixels into texture
    gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(width), i32(height), 0, gl.RGBA, gl.UNSIGNED_BYTE, &data[0])

    return
}

update_texture :: proc(texture: u32, data: []u8, width, height: u32) {
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(width), i32(height), 0, gl.RGBA, gl.UNSIGNED_BYTE, &data[0])
}