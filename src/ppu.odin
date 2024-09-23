package gameboy

import rl "vendor:raylib"
import "core:fmt"

// Tile: 8x8 group of pixels.
// 1 Pixel = 2 bits.
// Object: Pieces of a sprite.

Pixel_Color :: [4]u8
GB_WHITE :: Pixel_Color {255, 255, 255, 255}
GB_LIGHT_GRAY :: Pixel_Color {200, 200, 200, 255}
GB_DARK_GRAY :: Pixel_Color {80, 80, 80, 255}
GB_BLACK :: Pixel_Color {0, 0, 0, 255}

Pixel_Color_Map := [4]Pixel_Color { GB_WHITE, GB_LIGHT_GRAY, GB_DARK_GRAY, GB_BLACK }

Ppu :: struct {
    framebuffer: []u8,
    cycles: uint,
    gb_state: ^Gb_State
}

ppu_step :: proc(ppu: ^Ppu) {
    gb_state := ppu.gb_state

    lcd_control := transmute(Lcd_Control_Register) memory_mapper_read(gb_state.memory_mapper, LCDC)

    if .LCD_Display_Enable not_in lcd_control {
        return
    }

    ly := memory_mapper_read(gb_state.memory_mapper, LY)
    lcd_status := transmute(Lcd_Status_Register)memory_mapper_read(gb_state.memory_mapper, STAT)
    interrupts_flag := transmute(Interrupt_Set)memory_mapper_read(gb_state.memory_mapper, INTERRUPTS_FLAG)

    if ppu.cycles >= 456 * 4 {
        // Line end.
        ppu.cycles = 0

        ly += 1
        if ly > 153 {
            // Go back to line 0.
            memory_mapper_write(&gb_state.memory_mapper, LY, 0)
            ly = 0
        } else {
            // Advance to the next line.
            memory_mapper_write(&gb_state.memory_mapper, LY, ly)
        }

        if ly == 144 {
            // Enter mode 1. V-Blank
            interrupts_flag += {.LCD}
            lcd_status.mode = .V_Blank
            lcd_status.v_blank_interrupt = true
            lcd_status.h_blank_interrupt = false
            lcd_status.oam_interrupt = false
        } else if ly < 144 {
            // Set mode 2. Searching objects.
            interrupts_flag += {.LCD}
            lcd_status.mode = .Searching_Oam
            lcd_status.oam_interrupt = true
            lcd_status.v_blank_interrupt = false
            lcd_status.h_blank_interrupt = false
        }
    } else if ppu.cycles >= 80 * 4 {
        // Enter mode 3. Drawing.
        lcd_status.mode = .Data_Transfer_To_Lcd
        lcd_status.oam_interrupt = false
        lcd_status.v_blank_interrupt = false
        lcd_status.h_blank_interrupt = false
    } else if ppu.cycles >= 369 * 4 {
        // Enter mode 0. HBlank.
        interrupts_flag += {.LCD}
        lcd_status.mode = .H_Blank
        lcd_status.h_blank_interrupt = true
        lcd_status.v_blank_interrupt = false
        lcd_status.oam_interrupt = false
    }

    if byte(ly) == memory_mapper_read(gb_state.memory_mapper, LYC) {
        lcd_status.lcy_ly_equality = true
        interrupts_flag += {.LCD}
    } else {
        lcd_status.lcy_ly_equality = false
    }
    lcd_status.lcy_ly_equality_read_only = lcd_status.lcy_ly_equality
    memory_mapper_write(&gb_state.memory_mapper, INTERRUPTS_FLAG, transmute(byte)interrupts_flag)
    memory_mapper_write(&gb_state.memory_mapper, STAT, transmute(byte)lcd_status)
}

ppu_get_tile_data :: proc(ppu: ^Ppu, tile_number: u16) -> (tile_data: [8 * 8 * 4]u8) {
    gb_state := ppu.gb_state
    tile_row: u16 = 0
    row_start: u16 = 0x8000 + 16 * tile_number

    for row: u16 = row_start; row < row_start + 16; row += 2 {

        // Get the row pixels.
        byte_1 := memory_mapper_read(gb_state.memory_mapper, row)
        byte_2 := memory_mapper_read(gb_state.memory_mapper, row + 1)

        for bit_pos in 0..=7 {
            // Extract the bit from each byte and resolve the color.
            mask: u8 = 0x01 << u8(bit_pos)
            bit_1 := (byte_1 & mask) >> u8(bit_pos)
            bit_2 := (byte_2 & mask) >> u8(bit_pos)
            pixel_val := (bit_2 << 1) | (bit_1)
            pixel_color := Pixel_Color_Map[pixel_val]

            // Set the pixel color in our framebuffer.
            pixel_x: u16 = u16(u16(7-bit_pos))
            pixel_y: u16 = tile_row

            pixel_offset := (8 * pixel_y + pixel_x) * 4

            tile_data[pixel_offset] = pixel_color.r
            tile_data[pixel_offset + 1] = pixel_color.g
            tile_data[pixel_offset + 2] = pixel_color.b
            tile_data[pixel_offset + 3] = pixel_color.a
        }

        tile_row += 1
    }

    return
}

ppu_decode_and_render_tile_data :: proc(gb_state: ^Gb_State, tile_framebuffer: []u8, tiles_per_row: u32) {

    tile_framebuffer_row := u32(0)
    tile_framebuffer_column := u32(0)
    for tile_num in 0..=255+0x7f {
        tile_data := ppu_get_tile_data(&gb_state.ppu, u16(tile_num))

        for tile_y in 0..=7 {
            for tile_x in 0..=7 {
                tile_framebuffer_x := u32(tile_framebuffer_column * 8 + u32(tile_x))
                tile_framebuffer_y := (tile_framebuffer_row * 8) + u32(tile_y)
                tile_framebuffer_xy := uint(((tiles_per_row * 8) * tile_framebuffer_y + tile_framebuffer_x) * 4)

                tile_xy: uint = (8 * uint(tile_y) + uint(tile_x)) * 4
                tile_framebuffer[tile_framebuffer_xy] = tile_data[tile_xy]
                tile_framebuffer[tile_framebuffer_xy + 1] = tile_data[tile_xy + 1]
                tile_framebuffer[tile_framebuffer_xy + 2] = tile_data[tile_xy + 2]
                tile_framebuffer[tile_framebuffer_xy + 3] = tile_data[tile_xy + 3]
            }
        }

        // Keep track of what column and row we are on.
        tile_framebuffer_column += 1
        if tile_framebuffer_column >= tiles_per_row {
            tile_framebuffer_column = 0
            tile_framebuffer_row += 1
        }
    }

}