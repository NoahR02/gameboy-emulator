// Tile: 8x8 group of pixels.
// 1 Pixel = 2 bits.
// Object: Pieces of a sprite.

// Tile: 8x8 group of pixels.
// 1 Pixel = 2 bits.
// Object: Pieces of a sprite.

use crate::bus::bus::{Bus, INTERRUPTS_FLAG};
use crate::interrupt_controller::InterruptType;
use crate::lcd::{LcdControlOption, LcdStatusRegister, Mode, LCDC, LY, LYC, STAT};
use crate::{GAMEBOY_SCREEN_HEIGHT, GAMEBOY_SCREEN_WIDTH, TILE_SIZE};
use bit_field::BitField;
use enumset::EnumSet;

pub type PixelColor = [u8; 4];
pub const GB_WHITE:      PixelColor = [255, 255, 255, 255];
pub const GB_LIGHT_GRAY: PixelColor = [200, 200, 200, 255];
pub const GB_DARK_GRAY:  PixelColor = [80, 80, 80, 255];
pub const GB_BLACK:      PixelColor = [0, 0, 0, 255];

#[derive(Default, Copy, Clone)]
pub struct ColorIds {
    backing: u8,
}

impl ColorIds {
    pub const fn new(backing: u8) -> Self {
        Self {
            backing,
        }
    }
    
    pub fn id_0(&self) -> u8 {
        self.backing.get_bits(0..=1)
    }

    pub fn id_1(&self) -> u8 {
        self.backing.get_bits(2..=3)
    }

    pub fn id_2(&self) -> u8 {
        self.backing.get_bits(4..=5)
    }

    pub fn id_3(&self) -> u8 {
        self.backing.get_bits(6..=7)
    }
}

#[derive(Default, Copy, Clone)]
pub struct SpriteAttributeFlag(pub u8);

impl SpriteAttributeFlag {
    
    pub fn _gbc(&self) -> u8 {
        self.0.get_bits(0..=3)
    }

    pub fn dmg_palette(&self) -> bool {
        self.0.get_bit(4)
    }

    pub fn x_flip(&self) -> bool {
        self.0.get_bit(5)
    }

    pub fn y_flip(&self) -> bool {
        self.0.get_bit(6)
    }

    pub fn priority(&self) -> bool {
        self.0.get_bit(7)
    }
}

pub struct Layer {
    pub desired_tiles_per_row: u32,
    pub width: u32,
    pub height: u32,
    pub data: Vec<u8>,
}

impl Layer {
    pub fn new(width: u32, height: u32, desired_tiles_per_row: u32) -> Self {
        Self {
            width,
            height,
            data: vec![0; (width * height * 4) as usize],
            desired_tiles_per_row
        }
    }
}

enum TileFetchMode {
    DefaultBehavior,
    _8000_Only,
    _8800_Only,
}

enum Palette {
    Bgp,
    Obp0,
    Obp1,
}

pub const PIXEL_COLOR_MAP: [PixelColor; 4] = [GB_WHITE, GB_LIGHT_GRAY, GB_DARK_GRAY, GB_BLACK];

pub struct Ppu {
    pub(crate) cycles: usize,

    pub tiles: Layer,
    // Tile Map 1 $9800-$9BFF
    pub background_tile_map_1: Layer,
    // Tile Map 2 $9C00-$9FFF
    pub background_tile_map_2: Layer,
    pub oam_map: Layer,

    pub screen: Layer,
}

impl Ppu {
    pub fn new() -> Self {
        let tiles = Layer::new(GAMEBOY_SCREEN_WIDTH - 32, GAMEBOY_SCREEN_HEIGHT * 2, 16);
        let background_tile_map_1 = Layer::new(256, 256, 32);
        let background_tile_map_2 = Layer::new(256, 256, 32);
        let oam_map = Layer::new(64, 64, 8);
        let screen = Layer::new(GAMEBOY_SCREEN_WIDTH, GAMEBOY_SCREEN_HEIGHT, GAMEBOY_SCREEN_WIDTH / 8);

        Self {
            cycles: 0,
            tiles,
            background_tile_map_1,
            background_tile_map_2,
            oam_map,
            screen,
        }
    }

    #[inline(always)]
    pub fn step(&mut self, bus: &mut Bus) {
        let lcd_control = EnumSet::<LcdControlOption>::from_u8(bus.read(LCDC as u16));
        let mut ly = bus.read(LY as u16);
        let mut lcd_status = LcdStatusRegister(bus.read(STAT as u16));
        let mut interrupts_flag = EnumSet::<InterruptType>::from_u8(bus.read(INTERRUPTS_FLAG as u16));

        if !lcd_control.contains(LcdControlOption::LcdDisplayEnable) {
            bus.write(LY as u16, 0);
            ly = 0;

            if ly == bus.read(LYC as u16) {
                lcd_status.set_lcy_ly_equality(true);
                interrupts_flag.insert(InterruptType::LCD);
            } else {
                lcd_status.set_lcy_ly_equality(false);
            }

            lcd_status.set_lcy_ly_equality_read_only(lcd_status.lcy_ly_equality());

            interrupts_flag.insert(InterruptType::LCD);
            lcd_status.set_mode(Mode::HBlank);
            lcd_status.set_h_blank_interrupt(true);
            lcd_status.set_v_blank_interrupt(false);
            lcd_status.set_oam_interrupt(false);

            bus.write(INTERRUPTS_FLAG as u16, interrupts_flag.as_u8());
            bus.write(STAT as u16, lcd_status.0);
            return
        }

        // TODO: Move some of this code into lcd.odin once we know how these devices interact better.
        if self.cycles >= 456 * 4 {
            // Line end.
            self.cycles = 0;

            ly += 1;
            if ly > 153 {
                // Go back to line 0.
                bus.write(LY as u16, 0);
                ly = 0
            } else {
                // Advance to the next line.
                bus.write(LY as u16, ly);
            }

            if ly > 144 {
                // Enter mode 1. V-Blank

                interrupts_flag.insert(InterruptType::LCD);
                interrupts_flag.insert(InterruptType::VBlank);

                lcd_status.set_mode(Mode::VBlank);
                lcd_status.set_v_blank_interrupt(true);
                lcd_status.set_h_blank_interrupt(false);
                lcd_status.set_oam_interrupt(false);

                // 10 extra scan lines
                self.cycles += 456 * 10 / 4;
            } else if ly < 144 {
                // Set mode 2. OAM Scan, searching for objects.
                interrupts_flag.insert(InterruptType::LCD);

                lcd_status.set_mode(Mode::SearchingOam);
                lcd_status.set_oam_interrupt(true);
                lcd_status.set_v_blank_interrupt(false);
                lcd_status.set_h_blank_interrupt(false);

                // Blit the current line onto our screen buffer.
                // [x] Background Layer
                // [ ] Screen Layer
                // [ ] Sprite

                let tile_framebuffer_row = (ly as usize / TILE_SIZE) as u32;

                for x in (0u8..GAMEBOY_SCREEN_WIDTH as u8).step_by(TILE_SIZE) {
                    let tile_framebuffer_column = (x / TILE_SIZE as u8) as u32;

                    let bg_tile_map_address = (32 * tile_framebuffer_row) + tile_framebuffer_column;
                    let tile_map_index = bus.read((0x9800 + bg_tile_map_address) as u16);
                    let tile_data = get_tile_data(bus, (tile_map_index as u32) as u8, TileFetchMode::DefaultBehavior, Palette::Bgp);

                    let tile_framebuffer_xy = ((ly as usize * GAMEBOY_SCREEN_WIDTH as usize) + x as usize) * 4;

                    let tile_y = ly % TILE_SIZE as u8;
                    let tile_x = x % TILE_SIZE as u8;
                    let tile_xy: usize = (TILE_SIZE * tile_y as usize + tile_x as usize) * 4;

                    let bg_color_ids = ColorIds::new(bus.read(0xFF47));
                    let bg_color_ids_arr: [u8; 4] = [
                        bg_color_ids.id_0(),
                        bg_color_ids.id_1(),
                        bg_color_ids.id_2(),
                        bg_color_ids.id_3(),
                    ];

                    for offset in 0..=7 {
                        let offset: usize = offset * 4;
                        let tile_data_offset = tile_xy + offset;
                        let background_color: PixelColor = [
                            tile_data[tile_data_offset],
                            tile_data[tile_data_offset + 1],
                            tile_data[tile_data_offset + 2],
                            tile_data[tile_data_offset + 3]
                        ];
                        self.screen.data[tile_framebuffer_xy + offset] = background_color[0];
                        self.screen.data[tile_framebuffer_xy + 1 + offset] = background_color[1];
                        self.screen.data[tile_framebuffer_xy + 2 + offset] = background_color[2];
                        self.screen.data[tile_framebuffer_xy + 3 + offset] = background_color[3];
                    }
                }

                // Draw the sprites on the line:
                {
                    for sprite_index in (0..160).step_by(4) {
                        let sx = bus.read(0xFE00 + sprite_index + 1).wrapping_sub(8);
                        let sy = bus.read(0xFE00 + sprite_index).wrapping_sub(16);
                        let sw: u8 = TILE_SIZE as u8;
                        let sh: u8 = TILE_SIZE as u8;

                        let sprite_tile_index = bus.read(0xFE00 + sprite_index + 2);
                        let sprite_flags = SpriteAttributeFlag(bus.read(0xFE00 + sprite_index + 3));

                        let is_in_y = ly >= sy && ly < sy + sh;
                        let in_bounds = is_in_y;

                        if !in_bounds {
                            continue;
                        }

                        let palette: Palette = if sprite_flags.dmg_palette() as u8 == 0 {
                            Palette::Obp0
                        } else {
                            Palette::Obp1
                        };

                        let color_address: u16 = match palette {
                            Palette::Bgp => 0xFF47,
                            Palette::Obp0 => 0xFF48,
                            Palette::Obp1 => 0xFF49
                        };

                        let color_ids = ColorIds::new(bus.read(color_address));
                        let color_ids_arr: [u8; 4] = [
                            color_ids.id_0(),
                            color_ids.id_1(),
                            color_ids.id_2(),
                            color_ids.id_3(),
                        ];

                        // Sprites always use the 8000 method.
                        let sprite_tile_data = get_tile_data(bus, (sprite_tile_index as u32) as u8, TileFetchMode::_8000_Only, palette);

                        let local_sy: u8 = ((ly as i64 - sy as i64).abs() as u8) % TILE_SIZE as u8;
                        let local_sx_xy = TILE_SIZE * local_sy as usize * 4;

                        let tile_framebuffer_xy = ((ly as usize * GAMEBOY_SCREEN_WIDTH as usize) + sx as usize) * 4;

                        for offset in 0..=7 {
                            let offset = offset as usize * 4;

                            let sprite_color: PixelColor = [
                                sprite_tile_data[local_sx_xy + offset],
                                sprite_tile_data[local_sx_xy + 1 + offset],
                                sprite_tile_data[local_sx_xy + 2 + offset],
                                sprite_tile_data[local_sx_xy + 3 + offset]
                            ];

                            if sprite_color == PIXEL_COLOR_MAP[color_ids.id_0() as usize] {
                                
                            } else if sprite_flags.priority() as u8 == 0 {
                                self.screen.data[tile_framebuffer_xy + offset] = sprite_color[0];
                                self.screen.data[tile_framebuffer_xy + 1 + offset] = sprite_color[1];
                                self.screen.data[tile_framebuffer_xy + 2 + offset] = sprite_color[2];
                                self.screen.data[tile_framebuffer_xy + 3 + offset] = sprite_color[3];
                            } else {
                                self.screen.data[tile_framebuffer_xy + offset] = sprite_color[0];
                                self.screen.data[tile_framebuffer_xy + 1 + offset] = sprite_color[1];
                                self.screen.data[tile_framebuffer_xy + 2 + offset] = sprite_color[2];
                                self.screen.data[tile_framebuffer_xy + 3 + offset] = sprite_color[3];
                            }
                        }
                    }
                }

                // 80 T-cycles
                self.cycles += 80 / 4;
            }
        } else if self.cycles >= 369 * 4 {
            // Enter mode 0. HBlank.
            interrupts_flag.insert(InterruptType::LCD);
            lcd_status.set_mode(Mode::HBlank);
            lcd_status.set_h_blank_interrupt(true);
            lcd_status.set_v_blank_interrupt(false);
            lcd_status.set_oam_interrupt(false);

            // 87 - 204 T cycles
            self.cycles += 204 / 4
        } else if self.cycles >= 80 * 4 {
            // Enter mode 3. Drawing.
            lcd_status.set_mode(Mode::DataTransferToLcd);
            lcd_status.set_oam_interrupt(false);
            lcd_status.set_v_blank_interrupt(false);
            lcd_status.set_h_blank_interrupt(false);

            // 172 - 289 T cycles
            self.cycles += 289 / 4;
        }

        if ly == bus.read(LYC as u16) {
            lcd_status.set_lcy_ly_equality(true);
            interrupts_flag.insert(InterruptType::LCD);
        } else {
            lcd_status.set_lcy_ly_equality(false);
        }
        
        lcd_status.set_lcy_ly_equality_read_only(lcd_status.lcy_ly_equality());
        bus.write(INTERRUPTS_FLAG as u16, interrupts_flag.as_u8());
        bus.write(STAT as u16, lcd_status.0);
    }
}

#[inline(always)]
pub fn get_tile_data(bus: &Bus, tile_number: u8, force_tile_fetch_method: TileFetchMode, palette: Palette) -> [u8; 8 * 8 * 4] {
    let mut tile_data: [u8; 8 * 8 * 4] = [0; 8 * 8 * 4];

    let mut tile_row: u16 = 0;

    let row_start: u16 = match force_tile_fetch_method {
        TileFetchMode::DefaultBehavior => {
            let lcd_control = EnumSet::<LcdControlOption>::from_u8(bus.read(LCDC as u16));
            // If bit 4 in LCDC is set, use the 8000 method, otherwise use the 8800 method.
            if lcd_control.contains(LcdControlOption::BgWindowTileDataSelect) {
                0x8000 + 16 * tile_number as u16
            } else {
                (0x9000 + 16 * ((tile_number as i8) as i32)) as u16
            }
        }
        TileFetchMode::_8000_Only => {
            0x8000 + 16 * tile_number as u16
        }
        TileFetchMode::_8800_Only => {
            (0x9000 + 16 * (tile_number as i8) as i32) as u16
        }
    };

    let color_address: u16 = match palette {
        Palette::Bgp => 0xFF47,
        Palette::Obp0 => 0xFF48,
        Palette::Obp1 => 0xFF49
    };

    let color_ids = ColorIds::new(bus.read(color_address));
    let color_ids_arr: [u8; 4] = [
        color_ids.id_0(),
        color_ids.id_1(),
        color_ids.id_2(),
        color_ids.id_3(),
    ];

    for row in (row_start..row_start + 16).step_by(2) {
        // Get the row pixels.
        let byte_1 = bus.read(row);
        let byte_2 = bus.read(row + 1);

        for bit_pos in 0..=7 {
            // 2 bits per pixel.
            // Extract the bit from each byte and resolve the color.
            let mask: u8 = 0x01 << bit_pos as u8;
            let bit_1 = (byte_1 & mask) >> bit_pos as u8;
            let bit_2 = (byte_2 & mask) >> bit_pos as u8;
            let pixel_val = (bit_2 << 1) | (bit_1);
            let pixel_color = PIXEL_COLOR_MAP[color_ids_arr[pixel_val as usize] as usize];

            // Set the pixel color in our framebuffer.
            let pixel_x: u16 = (7 - bit_pos) as u16;
            let pixel_y: u16 = tile_row;

            let pixel_offset = (8 * pixel_y + pixel_x) * 4;

            tile_data[pixel_offset as usize] = pixel_color[0];
            tile_data[(pixel_offset + 1) as usize] = pixel_color[1];
            tile_data[(pixel_offset + 2) as usize] = pixel_color[2];
            tile_data[(pixel_offset + 3) as usize] = pixel_color[3];
        }

        tile_row += 1;
    }

    tile_data
}

#[inline(always)]
pub fn blit_tile_on_to_layer (bus: &mut Bus, layer: &mut Layer, tile_num: u32, tile_framebuffer_current_tile_row: u32, tile_framebuffer_current_tile_column: u32, force_tile_fetch_method: TileFetchMode) -> (u32, u32) {
    let tile_data = get_tile_data(bus, tile_num as u8, force_tile_fetch_method, Palette::Bgp);

    let mut tile_framebuffer_current_tile_column = tile_framebuffer_current_tile_column;
    let mut tile_framebuffer_current_tile_row = tile_framebuffer_current_tile_row;

    for tile_y in 0..=7 {
        for tile_x in 0..=7 {
            let tile_framebuffer_x: u32 = tile_framebuffer_current_tile_column * 8 + tile_x as u32;
            let tile_framebuffer_y: u32 = tile_framebuffer_current_tile_row * 8 + tile_y as u32;
            let tile_framebuffer_xy: usize = (((layer.desired_tiles_per_row * 8) * tile_framebuffer_y + tile_framebuffer_x) * 4) as usize;

            let tile_xy: usize = (8 * tile_y as usize + tile_x as usize) * 4;
            layer.data[tile_framebuffer_xy] = tile_data[tile_xy];
            layer.data[tile_framebuffer_xy + 1] = tile_data[tile_xy + 1];
            layer.data[tile_framebuffer_xy + 2] = tile_data[tile_xy + 2];
            layer.data[tile_framebuffer_xy + 3] = tile_data[tile_xy + 3];
        }
    }

    // Keep track of what column and row we are on.
    tile_framebuffer_current_tile_column += 1;
    if tile_framebuffer_current_tile_column >= layer.desired_tiles_per_row {
        tile_framebuffer_current_tile_column = 0;
        tile_framebuffer_current_tile_row += 1;
    }

    (tile_framebuffer_current_tile_row, tile_framebuffer_current_tile_column)
}

#[inline(always)]
pub fn ppu_fill_tiles(bus: &mut Bus, ppu: &mut Ppu) {
    let mut tile_framebuffer_row: u32 = 0;
    let mut tile_framebuffer_column: u32 = 0;
    for tile_num in 0..=255 {
        // Get the first 256 tiles with the 8000 tile retrieval method.
        let (next_row, next_column) = blit_tile_on_to_layer(bus, &mut ppu.tiles, tile_num, tile_framebuffer_row, tile_framebuffer_column, TileFetchMode::_8000_Only);
        tile_framebuffer_row = next_row;
        tile_framebuffer_column = next_column;
    }
    for tile_num in 0..=127 {
        // Get the last 128 tiles with the 8800 tile retrieval method.
        let (next_row, next_column) = blit_tile_on_to_layer(bus, &mut ppu.tiles, tile_num, tile_framebuffer_row, tile_framebuffer_column, TileFetchMode::_8800_Only);
        tile_framebuffer_row = next_row;
        tile_framebuffer_column = next_column;
    }
}

#[inline(always)]
pub fn ppu_fill_background_tile_map_1(bus: &mut Bus, ppu: &mut Ppu) {
    let mut tile_framebuffer_row: u32 = 0;
    let mut tile_framebuffer_column: u32 = 0;

    // Tile Map 1 $9800-$9BFF
    for tile_map_index_address in 0x9800..=0x9BFF {
        let tile_map_index = bus.read(tile_map_index_address);
        let (next_row, next_column) = blit_tile_on_to_layer(bus, &mut ppu.background_tile_map_1, tile_map_index as u32, tile_framebuffer_row, tile_framebuffer_column, TileFetchMode::DefaultBehavior);
        tile_framebuffer_row = next_row;
        tile_framebuffer_column = next_column;
    }
}

#[inline(always)]
pub fn ppu_fill_background_tile_map_2(bus: &mut Bus, ppu: &mut Ppu) {
    let mut tile_framebuffer_row: u32 = 0;
    let mut tile_framebuffer_column: u32 = 0;

    // Tile Map 1 $9C00-$9FFF
    for tile_map_index_address in 0x9C00..=0x9FFF {
        let tile_map_index = bus.read(tile_map_index_address);
        let (next_row, next_column) = blit_tile_on_to_layer(bus, &mut ppu.background_tile_map_2, tile_map_index as u32, tile_framebuffer_row, tile_framebuffer_column, TileFetchMode::DefaultBehavior);
        tile_framebuffer_row = next_row;
        tile_framebuffer_column = next_column;
    }
}

#[inline(always)]
pub fn ppu_fill_oam_map(bus: &mut Bus, ppu: &mut Ppu) {
    let mut tile_framebuffer_row: u32 = 0;
    let mut tile_framebuffer_column: u32 = 0;

    for sprite_index in (0..159).step_by(4) {
        let tile_map_index = bus.read(0xFE00 + sprite_index + 2);
        // Sprites always use the 8000 method.
        let (next_row, next_column) = blit_tile_on_to_layer(bus, &mut ppu.oam_map, tile_map_index as u32, tile_framebuffer_row, tile_framebuffer_column, TileFetchMode::_8000_Only);
        tile_framebuffer_row = next_row;
        tile_framebuffer_column = next_column;
    }
}