use crate::dma::dma;
use crate::timer::timer;
use crate::io::{ActionButtons, DirectionalButtons, IO, P1_JOYPAD};

pub const KILOBYTE: usize = 1024;

pub struct Memory {
    rom:          [u8; 32 * KILOBYTE],
    video_ram:    [u8; 8 * KILOBYTE],
    external_ram: [u8; 8 * KILOBYTE],
    work_ram:     [u8; 8 * KILOBYTE],
    oam_ram:      [u8; 160],
    pub(crate) io_ram:       [u8; 256],
    high_ram:     [u8; 128],
}

impl Memory {
    fn new() -> Self {
        Self {
            rom:          [0; 32 * KILOBYTE],
            video_ram:    [0; 8 * KILOBYTE],
            external_ram: [0; 8 * KILOBYTE],
            work_ram:     [0; 8 * KILOBYTE],
            oam_ram:      [0; 160],
            io_ram:       [0; 256],
            high_ram:     [0; 128],
        }
    }
}

pub struct Bus {
    pub memory: Memory,
    pub dma_transfer_requested: bool,
    pub blargg_debug_output: Vec<u8>,
}

pub const INTERRUPTS_FLAG: usize = 0xFF0F;

impl Bus {
    pub fn new() -> Bus {
        Self {
            memory: Memory::new(),
            dma_transfer_requested: false,
            blargg_debug_output: vec![],
        }
    }

    #[inline(always)]
    pub fn read(&self, address: u16) -> u8 {
        let address = address as usize;

        
        // LY must be 0x90 when running GB Doctor.
        // if address == 0xFF44 {
        //     return 0x90;
        // }

        // TODO: Implement the joypad.
        // Turn off joypad buttons. 1 = Off.
        if address == P1_JOYPAD {
            let p1_joypad = self.memory.io_ram[P1_JOYPAD - P1_JOYPAD];

            let action_buttons_enabled = (p1_joypad & 0b00_10_0000) == 0;
            let dpad_buttons_enabled = (p1_joypad & 0b00_01_0000) == 0;

            // fmt.println(select_buttons_enabled, dpad_buttons_enabled)
            if dpad_buttons_enabled {

                let mut direction_buttons_byte: u8 = 0;


                for directional_button in DirectionalButtons::all() {
                    let bit_offset = directional_button.bits();
                    let mut bit_to_set: u8 = 0x01 << bit_offset;

                    let direction_buttons = IO.with(|io| io.borrow().direction_buttons);

                    if direction_buttons.contains(directional_button) {
                        // Flip the bit.
                        bit_to_set = bit_to_set ^ bit_to_set;
                    }

                    direction_buttons_byte |= bit_to_set;
                }

                return p1_joypad | direction_buttons_byte;
            } else if action_buttons_enabled {
                let mut action_buttons_byte: u8 = 0;
                for action_button in ActionButtons::all() {
                    let bit_offset = action_button.bits();
                    let mut bit_to_set: u8 = 0x01 << bit_offset;

                    let action_buttons = IO.with(|io| io.borrow().action_buttons);


                    if action_buttons.contains(action_button) {
                        // Flip the bit.
                        bit_to_set = bit_to_set ^ bit_to_set;
                    }

                    action_buttons_byte = action_buttons_byte | bit_to_set;
                }
                return p1_joypad | action_buttons_byte;
            } else {
                // When neither the select buttons or the dpad are enabled, set every bit in the lower nibble.
                return p1_joypad | 0x0F;
            }
        }

        match address {
            0..0x8000 => {
                self.memory.rom[address]
            },
            // Video Ram
            0x8000..=0x9FFF => {
                self.memory.video_ram[address - 0x8000]
            }
            0xA000..=0xBFFF => {
                self.memory.external_ram[address - 0xA000]
            }
            // Cartridge Ram
            0xC000..=0xDFFF => {
                self.memory.work_ram[address - 0xC000]
            }
            // Shadow/Clone of working ram, should not be read from.
            0xE000..=0xFDFF => {
                0x00
            }
            // Sprites
            0xFE00..=0xFE9F => {
                self.memory.oam_ram[address - 0xFE00]
            }
            0xFEA0..=0xFEFF => {
                0x00
            }

            // IF
            INTERRUPTS_FLAG => {
                // The upper 3 bits are not writable and always 1 when read.
                let on_upper_3_bits: u8 = 0b111_000_00;
                self.memory.io_ram[address - 0xFF00] | on_upper_3_bits
            }

            // Memory Mapped IO
            0xFF00..=0xFF7F => {
                self.memory.io_ram[address - 0xFF00]
            }

            0xFF80..=0xFFFF => {
                self.memory.high_ram[address - 0xFF80]
            }
            _ => {
                panic!("0x{:X}", address)
            }
        }
    }

    #[inline(always)]
    pub fn write(&mut self, address: u16, data: u8) {
        let address = address as usize;

        // TODO: Move this into a seperate file!
        // DMA
        if address == 0xFF46 {
            self.dma_transfer_requested = true;
            dma(self, address as u16, data);
        }

        match address {
            0..0x8000 => {
                self.memory.rom[address] = data;
            },
            // Video Ram
            0x8000..=0x9FFF => {
                self.memory.video_ram[address - 0x8000] = data;
            }
            0xA000..=0xBFFF => {
                self.memory.external_ram[address - 0xA000] = data;
            }
            // Cartridge Ram
            0xC000..=0xDFFF => {
                self.memory.work_ram[address - 0xC000] = data;
            }
            // Shadow/Clone of working ram, should not be written to.
            0xE000..=0xFDFF => {
            }
            // Sprites
            0xFE00..=0xFE9F => {
                self.memory.oam_ram[address - 0xFE00] = data;
            }
            0xFEA0..=0xFEFF => {
                
            }

            // DIV, Any writes to the DIV register will reset the value of DIV.
            timer::DIV => {
                self.memory.io_ram[address - 0xFF00] = 0
            }

            // Memory Mapped IO
            0xFF00..=0xFF7F => {
                if address == P1_JOYPAD {
                    // The lower nibble is read-only.
                    self.memory.io_ram[address-P1_JOYPAD] = data & 0xF0;

                    return;
                }

                if address == 0xFF02 && data == 0x81 {
                    self.blargg_debug_output.push(self.read(0xFF01));
                }
                
                self.memory.io_ram[address - 0xFF00] = data;
            }

            0xFF80..=0xFFFF => {
                self.memory.high_ram[address - 0xFF80] = data;
            }
            _ => {}
        }
    }
}
