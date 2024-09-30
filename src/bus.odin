package gameboy

import "core:fmt"
import "core:encoding/endian"

when ODIN_TEST {
    blargg_debug_output: [dynamic]u8
}


Memory :: struct {
    // [0x0000, 0x8000)
    _rom:           [32 * KILOBYTE]byte, // 0x8000
    // [0x8000, 0x9FFF]
    _video_ram:     [8 * KILOBYTE]byte,  // 0x2000
    // [0xA000, 0xBFFF]
    _external_ram:  [8 * KILOBYTE]byte,  // 0x2000
    // [0xC000, 0xDFFF]
    _work_ram:      [8 * KILOBYTE]byte,  // 0x2000
    _oam_ram:       [160]byte,
    _io_ram:        [256]byte,
    _high_ram:      [128]byte,
}

/*
 Instead of the cpu communicating directly with other devices it uses something called memory mapping.
 For example instead of talking to the PPU/GPU, it will write and read to an area of memory dedicated to the PPU/GPU.
*/
Bus :: struct {
    using memory: Memory,
    dma_transfer_requested: bool,
    cpu: ^Cpu,
    ppu: ^Ppu,
    timer: ^Timer,
}

P1_JOYPAD :: 0xFF00

select_buttons: byte
dpad_buttons: byte

bus_connect_devices :: proc(self: ^Bus, cpu: ^Cpu, ppu: ^Ppu, timer: ^Timer) {
    // This is a bit nasty because it will create circular references, but most of the time each device cannot operate in isolation.
    // TODO: Rework how the devices communicate.
    self.cpu = cpu
    self.ppu = ppu
    self.timer = timer

    cpu.bus = self
    ppu.bus = self
    timer.bus = self
}

bus_read :: proc(bus: Bus, address: u16) -> u8 {

    // TODO: Implement the joypad.
    // Turn off joypad buttons. 1 = Off.
    if address == P1_JOYPAD {
        p1_joypad := bus._io_ram[P1_JOYPAD-0xFF00]
        select_buttons_enabled := (p1_joypad & 0b00_10_0000) == 0
        dpad_buttons_enabled := (p1_joypad & 0b00_01_0000) == 0
        // fmt.println(select_buttons_enabled, dpad_buttons_enabled)
        if select_buttons_enabled {
            return (p1_joypad & 0xF0) | select_buttons
        } else if dpad_buttons_enabled {
            return (p1_joypad & 0xF0) | select_buttons
        } else {
            // When neither the select buttons or the dpad are enabled, set every bit in the lower nibble.
            return p1_joypad | 0x0F
        }
    }

    switch {
        case address < 0x8000:
            return bus._rom[address]
        case address >= 0x8000 && address <= 0x9FFF:
            // Video Ram
            return bus._video_ram[address-0x8000]
        case address >= 0xA000 && address <= 0xBFFF:
            return bus._external_ram[address-0xA000]
            // Cartridge Ram
        case address >= 0xC000 && address <= 0xDFFF:
            return bus._work_ram[address-0xC000]
        case address >= 0xE000 && address <= 0xFDFF:
            // Shadow/Clone of working ram, should not be read from.
            return 0x00
        case address >= 0xFE00 && address <= 0xFE9F:
            // Sprites
            return bus._oam_ram[address-0xFE00]
        case address >= 0xFEA0 && address <= 0xFEFF:
            return 0x00

        // IF
        case address == INTERRUPTS_FLAG: {
            // The upper 3 bits are not writable and always 1 when read.
            on_upper_3_bits: byte = 0b111_000_00
            return bus._io_ram[address-0xFF00] | on_upper_3_bits
        }

        case address >= 0xFF00 && address <= 0xFF7F:
            // Memory Mapped IO
            return bus._io_ram[address-0xFF00]
        case address >= 0xFF80 && address <= 0xFFFF:
            return bus._high_ram[address-0xFF80]
        case:
            panic(fmt.aprintf("%x\n", address))
    }

}

bus_write :: proc(bus: ^Bus, address: u16, data: u8) {

    // TODO: Move this into a seperate file!
    // DMA
    if address == 0xFF46 {
        bus.dma_transfer_requested = true
        dma(bus, address, data)
    }

    switch {
        case address < 0x8000:
            bus._rom[address] = data
        case address >= 0x8000 && address <= 0x9FFF:
            // Video Ram
            bus._video_ram[address-0x8000] = data
        case address >= 0xA000 && address <= 0xBFFF:
            bus._external_ram[address-0xA000] = data
        case address >= 0xC000 && address <= 0xDFFF:
            bus._work_ram[address-0xC000] = data
        case address >= 0xE000 && address <= 0xFDFF:
            // Shadow/Clone of working ram, should not be written to.
        case address >= 0xFE00 && address <= 0xFE9F:
            // Sprites
            bus._oam_ram[address-0xFE00] = data
        case address >= 0xFEA0 && address <= 0xFEFF:
            //panic(fmt.aprintf("Invalid memory write to %x\n", address))
            // Unusable

        // DIV, Any writes to the DIV register will reset the value of DIV.
        case address == DIV: {
            bus._io_ram[address-0xFF00] = 0
        }

        case address >= 0xFF00 && address <= 0xFF7F: {
            if address == P1_JOYPAD {
                // The lower nibble is read-only.
                bus._io_ram[address-0xFF00] = (data & 0xF0) | (bus._io_ram[address-0xFF00] & 0x0F)
                return
            }

            // Memory Mapped IO
            if address == 0xFF02 && data == 0x81 {
                when ODIN_TEST {
                    append_elem(&blargg_debug_output,  bus_read(bus^, 0xFF01))
                }
            }
            bus._io_ram[address-0xFF00] = data
        }
        case address >= 0xFF80 && address <= 0xFFFF:
            bus._high_ram[address-0xFF80] = data
    }
}