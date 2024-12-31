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

Layer :: struct {
    texture: Texture,
    desired_tiles_per_row: u32,
    width, height: u32,
    data: []u8,
}

layer_make :: proc(width, height, desired_tiles_per_row: u32) -> (self: Layer) {
    self.width = width
    self.height = height
    self.data = make([]u8, width * height * 4)
    self.desired_tiles_per_row = desired_tiles_per_row
    self.texture = texture_make()
    return
}

layer_fill_texture :: proc(self: ^Layer) {
    texture_update(&self.texture, self.data, self.width, self.height)
}

layer_delete :: proc(self: ^Layer) {
    delete(self.data)
    if self.texture.handle > 0 {
        texture_destroy(&self.texture)
    }
}

Ppu :: struct {
    cycles: uint,
    bus: ^Bus,

    tiles: Layer,
    // Tile Map 1 $9800-$9BFF
    background_tile_map_1: Layer,
    // Tile Map 2 $9C00-$9FFF
    background_tile_map_2: Layer,
    oam_map: Layer,
    
    screen: Layer,
}

ppu_make :: proc() -> (self: Ppu) {
    
    tiles := layer_make(GAMEBOY_SCREEN_WIDTH - 32, GAMEBOY_SCREEN_HEIGHT * 2, 16)
    background_tile_map_1 := layer_make(256, 256, 32)
    background_tile_map_2 := layer_make(256, 256, 32)
    oam_map := layer_make(64, 64, 8)
    screen := layer_make(GAMEBOY_SCREEN_WIDTH, GAMEBOY_SCREEN_HEIGHT, GAMEBOY_SCREEN_WIDTH / 8)
    self.tiles = tiles
    self.background_tile_map_1 = background_tile_map_1
    self.background_tile_map_2 = background_tile_map_2
    self.oam_map = oam_map
    self.screen = screen
    return
}

ppu_destroy :: proc(self: ^Ppu) {
    layer_delete(&self.tiles)
    layer_delete(&self.background_tile_map_1)
    layer_delete(&self.background_tile_map_2)
    layer_delete(&self.oam_map)
    layer_delete(&self.screen)
}

ppu_step :: proc(self: ^Ppu) {
    bus := self.bus

    lcd_control := transmute(Lcd_Control_Register) bus_read(bus^, LCDC)
    ly := bus_read(bus^, LY)
    lcd_status := transmute(Lcd_Status_Register)bus_read(bus^, STAT)
    interrupts_flag := transmute(Interrupt_Set)bus_read(bus^, INTERRUPTS_FLAG)

    if .LCD_Display_Enable not_in lcd_control {
        bus_write(bus, LY, 0)
        ly = 0

        if byte(ly) == bus_read(bus^, LYC) {
            lcd_status.lcy_ly_equality = true
            interrupts_flag += {.LCD}
        } else {
            lcd_status.lcy_ly_equality = false
        }
        lcd_status.lcy_ly_equality_read_only = lcd_status.lcy_ly_equality

        interrupts_flag += {.LCD}
        lcd_status.mode = .H_Blank
        lcd_status.h_blank_interrupt = true
        lcd_status.v_blank_interrupt = false
        lcd_status.oam_interrupt = false

        bus_write(bus, INTERRUPTS_FLAG, transmute(byte)interrupts_flag)
        bus_write(bus, STAT, transmute(byte)lcd_status)
        return
    }

    // TODO: Move some of this code into lcd.odin once we know how these devices interact better.
    if self.cycles >= 456 * 4 {
    // Line end.
        self.cycles = 0

        ly += 1
        if ly > 153 {
            // Go back to line 0.
            bus_write(bus, LY, 0)
            ly = 0
        } else {
            // Advance to the next line.
            bus_write(bus, LY, ly)
        }

        if ly > 144 {
            // Enter mode 1. V-Blank
            interrupts_flag += {.LCD, .VBlank}
            lcd_status.mode = .V_Blank
            lcd_status.v_blank_interrupt = true
            lcd_status.h_blank_interrupt = false
            lcd_status.oam_interrupt = false

            // 10 extra scan lines
            self.cycles += 456 * 10 / 4
        } else if ly < 144 {
            // Set mode 2. OAM Scan, searching for objects.
            interrupts_flag += {.LCD}
            lcd_status.mode = .Searching_Oam
            lcd_status.oam_interrupt = true
            lcd_status.v_blank_interrupt = false
            lcd_status.h_blank_interrupt = false
            
            // Blit the current line onto our screen buffer.
            // [x] Background Layer
            // [ ] Screen Layer
            // [ ] Sprite Layer

            tile_framebuffer_row := u32(uint(ly) / TILE_SIZE)
            for x in 0..<GAMEBOY_SCREEN_WIDTH {
                tile_framebuffer_column := u32(x / TILE_SIZE)

                bg_tile_map_address := (32 * tile_framebuffer_row) + tile_framebuffer_column
                tile_map_index := bus_read(self.bus^, u16(0x9800 + bg_tile_map_address))
                tile_data := ppu_get_tile_data(self, u8(u32(tile_map_index)), .Default_Behavior)

                tile_framebuffer_xy := uint((uint(ly) * GAMEBOY_SCREEN_WIDTH) + uint(x)) * 4

                tile_y := ly % TILE_SIZE
                tile_x := x % TILE_SIZE
                tile_xy: uint = (TILE_SIZE * uint(tile_y) + uint(tile_x)) * 4
        
                self.screen.data[tile_framebuffer_xy] = tile_data[tile_xy]
                self.screen.data[tile_framebuffer_xy + 1] = tile_data[tile_xy + 1]
                self.screen.data[tile_framebuffer_xy + 2] = tile_data[tile_xy + 2]
                self.screen.data[tile_framebuffer_xy + 3] = tile_data[tile_xy + 3]
            }

            // 80 T-cycles
            self.cycles += 80 / 4
        }
    } else if self.cycles >= 369 * 4 {
        // Enter mode 0. HBlank.
        interrupts_flag += {.LCD}
        lcd_status.mode = .H_Blank
        lcd_status.h_blank_interrupt = true
        lcd_status.v_blank_interrupt = false
        lcd_status.oam_interrupt = false

        // 87 - 204 T cycles
        self.cycles += 204 / 4
    } else if self.cycles >= 80 * 4 {
        
        // Enter mode 3. Drawing.
        lcd_status.mode = .Data_Transfer_To_Lcd
        lcd_status.oam_interrupt = false
        lcd_status.v_blank_interrupt = false
        lcd_status.h_blank_interrupt = false

        // 172 - 289 T cycles
        self.cycles += 289 / 4
    }

    if byte(ly) == bus_read(bus^, LYC) {
        lcd_status.lcy_ly_equality = true
        interrupts_flag += {.LCD}
    } else {
        lcd_status.lcy_ly_equality = false
    }
    lcd_status.lcy_ly_equality_read_only = lcd_status.lcy_ly_equality
    bus_write(bus, INTERRUPTS_FLAG, transmute(byte)interrupts_flag)
    bus_write(bus, STAT, transmute(byte)lcd_status)
}

Tile_Fetch_Mode :: enum {
    Default_Behavior,
    _8000_Only,
    _8800_Only,
}

ppu_get_tile_data :: proc(self: ^Ppu, tile_number: u8, force_tile_fetch_method: Tile_Fetch_Mode = .Default_Behavior) -> (tile_data: [8 * 8 * 4]u8) {
    bus := self.bus
    tile_row: u16 = 0

    row_start: u16

    switch force_tile_fetch_method {
        case .Default_Behavior: {
            lcd_control := transmute(Lcd_Control_Register) bus_read(bus^, LCDC)
            // If bit 4 in LCDC is set, use the 8000 method, otherwise use the 8800 method.
            if .BG_Window_Tile_Data_Select in lcd_control {
                row_start = 0x8000 + 16 * u16(tile_number)
            } else {
                row_start = u16(0x9000 + 16 * i32(i8(tile_number)))
            }
        }
        case ._8000_Only: {
            row_start = 0x8000 + 16 * u16(tile_number)
        }
        case ._8800_Only: {
            row_start = u16(0x9000 + 16 * i32(i8(tile_number)))
        }
    }

    for row: u16 = row_start; row < row_start + 16; row += 2 {

        // Get the row pixels.
        byte_1 := bus_read(bus^, row)
        byte_2 := bus_read(bus^, row + 1)

        for bit_pos in 0..=7 {
            // 2 bits per pixel.
            // Extract the bit from each byte and resolve the color.
            mask: u8 = 0x01 << u8(bit_pos)
            bit_1 := (byte_1 & mask) >> u8(bit_pos)
            bit_2 := (byte_2 & mask) >> u8(bit_pos)
            pixel_val := (bit_2 << 1) | (bit_1)
            pixel_color := Pixel_Color_Map[pixel_val]

            // Set the pixel color in our framebuffer.
            pixel_x: u16 = u16(7-bit_pos)
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

ppu_blit_tile_on_to_layer :: proc(self: ^Ppu, layer: ^Layer, tile_num: u32, tile_framebuffer_current_tile_row, tile_framebuffer_current_tile_column: u32, force_tile_fetch_method: Tile_Fetch_Mode = .Default_Behavior) -> (next_row, next_column: u32) {

    tile_data := ppu_get_tile_data(self, u8(tile_num), force_tile_fetch_method)

    tile_framebuffer_current_tile_column := tile_framebuffer_current_tile_column
    tile_framebuffer_current_tile_row := tile_framebuffer_current_tile_row

    for tile_y in 0..=7 {
        for tile_x in 0..=7 {
            tile_framebuffer_x := u32(tile_framebuffer_current_tile_column * 8 + u32(tile_x))
            tile_framebuffer_y := (tile_framebuffer_current_tile_row * 8) + u32(tile_y)
            tile_framebuffer_xy := uint(((layer.desired_tiles_per_row * 8) * tile_framebuffer_y + tile_framebuffer_x) * 4)

            tile_xy: uint = (8 * uint(tile_y) + uint(tile_x)) * 4
            layer.data[tile_framebuffer_xy] = tile_data[tile_xy]
            layer.data[tile_framebuffer_xy + 1] = tile_data[tile_xy + 1]
            layer.data[tile_framebuffer_xy + 2] = tile_data[tile_xy + 2]
            layer.data[tile_framebuffer_xy + 3] = tile_data[tile_xy + 3]
        }
    }

    // Keep track of what column and row we are on.
    tile_framebuffer_current_tile_column += 1
    if tile_framebuffer_current_tile_column >= layer.desired_tiles_per_row {
        tile_framebuffer_current_tile_column = 0
        tile_framebuffer_current_tile_row += 1
    }

    return tile_framebuffer_current_tile_row, tile_framebuffer_current_tile_column

}

ppu_fill_tiles :: proc(self: ^Ppu) {
    tile_framebuffer_row := u32(0)
    tile_framebuffer_column := u32(0)
    for tile_num in 0..=255 {
        // Get the first 256 tiles with the 8000 tile retrieval method.
        next_row, next_column := ppu_blit_tile_on_to_layer(self, &self.tiles, u32(tile_num), tile_framebuffer_row, tile_framebuffer_column, ._8000_Only)
        tile_framebuffer_row = next_row
        tile_framebuffer_column = next_column
    }
    for tile_num in 0..=127 {
        // Get the last 128 tiles with the 8800 tile retrieval method.
        next_row, next_column := ppu_blit_tile_on_to_layer(self, &self.tiles, u32(tile_num), tile_framebuffer_row, tile_framebuffer_column, ._8800_Only)
        tile_framebuffer_row = next_row
        tile_framebuffer_column = next_column
    }
}

ppu_fill_background_tile_map_1 :: proc(self: ^Ppu) {
    tile_framebuffer_row := u32(0)
    tile_framebuffer_column := u32(0)

    // Tile Map 1 $9800-$9BFF
    for tile_map_index_address in 0x9800..=0x9BFF {
        tile_map_index := bus_read(self.bus^, u16(tile_map_index_address))
        next_row, next_column := ppu_blit_tile_on_to_layer(self, &self.background_tile_map_1, u32(tile_map_index), tile_framebuffer_row, tile_framebuffer_column)
        tile_framebuffer_row = next_row
        tile_framebuffer_column = next_column
    }
}

ppu_fill_background_tile_map_2 :: proc(self: ^Ppu) {
    tile_framebuffer_row := u32(0)
    tile_framebuffer_column := u32(0)

    // Tile Map 1 $9C00-$9FFF
    for tile_map_index_address in 0x9C00..=0x9FFF {
        tile_map_index := bus_read(self.bus^, u16(tile_map_index_address))
        next_row, next_column := ppu_blit_tile_on_to_layer(self, &self.background_tile_map_2, u32(tile_map_index), tile_framebuffer_row, tile_framebuffer_column)
        tile_framebuffer_row = next_row
        tile_framebuffer_column = next_column
    }
}

ppu_fill_oam_map :: proc(self: ^Ppu) {
    tile_framebuffer_row := u32(0)
    tile_framebuffer_column := u32(0)

    for sprite_index := 0; sprite_index < 159; sprite_index += 4 {
        tile_map_index := bus_read(self.bus^, u16(0xFE00 + sprite_index + 2))
        // Sprites always use the 8000 method.
        next_row, next_column := ppu_blit_tile_on_to_layer(self, &self.oam_map, u32(tile_map_index), tile_framebuffer_row, tile_framebuffer_column, ._8000_Only)
        tile_framebuffer_row = next_row
        tile_framebuffer_column = next_column
    }

}