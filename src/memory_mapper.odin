package gameboy

import "core:fmt"
import "core:encoding/endian"

when ODIN_TEST {
    blargg_debug_output: [dynamic]u8
}

/*
 Instead of the cpu communicating directly with other devices it uses something called memory mapping.
 For example instead of talking to the PPU/GPU, it will write and read to an area of memory dedicated to the PPU/GPU.
*/
Memory_Mapper :: struct {
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
    dma_transfer_requested: bool
}

memory_mapper_read :: proc(memory_mapper: Memory_Mapper, address: u16) -> u8 {

    // TODO: Implement the joypad.
    // Turn off joypad buttons. 1 = Off.
    if address == 0xff00 {
        return 0xFF
    }

    switch {
        case address < 0x8000:
            return memory_mapper._rom[address]
        case address >= 0x8000 && address <= 0x9FFF:
            // Video Ram
            return memory_mapper._video_ram[address-0x8000]
        case address >= 0xA000 && address <= 0xBFFF:
            return memory_mapper._external_ram[address-0xA000]
            // Cartridge Ram
        case address >= 0xC000 && address <= 0xDFFF:
            return memory_mapper._work_ram[address-0xC000]
        case address >= 0xE000 && address <= 0xFDFF:
            // Shadow/Clone of working ram, should not be read from.
            return 0x00
        case address >= 0xFE00 && address <= 0xFE9F:
            // Sprites
            return memory_mapper._oam_ram[address-0xFE00]
        case address >= 0xFEA0 && address <= 0xFEFF:
            return 0x00

        // IF
        case address == INTERRUPTS_FLAG: {
            // The upper 3 bits are not writable and always 1 when read.
            on_upper_3_bits: byte = 0b111_000_00
            return memory_mapper._io_ram[address-0xFF00] | on_upper_3_bits
        }

        case address >= 0xFF00 && address <= 0xFF7F:
            // Memory Mapped IO
            return memory_mapper._io_ram[address-0xFF00]
        case address >= 0xFF80 && address <= 0xFFFF:
            return memory_mapper._high_ram[address-0xFF80]
        case:
            panic(fmt.aprintf("%x\n", address))
    }

}

memory_mapper_write :: proc(memory_mapper: ^Memory_Mapper, address: u16, data: u8) {

    // TODO: Move this into a seperate file!
    // DMA
    if address == 0xFF46 {
        memory_mapper.dma_transfer_requested = true
        dma(memory_mapper, address, data)
    }

    switch {
        case address < 0x8000:
            memory_mapper._rom[address] = data
        case address >= 0x8000 && address <= 0x9FFF:
            // Video Ram
            memory_mapper._video_ram[address-0x8000] = data
        case address >= 0xA000 && address <= 0xBFFF:
            memory_mapper._external_ram[address-0xA000] = data
        case address >= 0xC000 && address <= 0xDFFF:
            memory_mapper._work_ram[address-0xC000] = data
        case address >= 0xE000 && address <= 0xFDFF:
            // Shadow/Clone of working ram, should not be written to.
        case address >= 0xFE00 && address <= 0xFE9F:
            // Sprites
            memory_mapper._oam_ram[address-0xFE00] = data
        case address >= 0xFEA0 && address <= 0xFEFF:
            //panic(fmt.aprintf("Invalid memory write to %x\n", address))
            // Unusable

        // DIV, Any writes to the DIV register will reset the value of DIV.
        case address == DIV: {
            memory_mapper._io_ram[address-0xFF00] = 0
        }

        case address >= 0xFF00 && address <= 0xFF7F:
            // Memory Mapped IO
            if address == 0xFF02 && data == 0x81 {
                when ODIN_TEST {
                    append_elem(&blargg_debug_output,  memory_mapper_read(memory_mapper^, 0xFF01))
                }
            }
            memory_mapper._io_ram[address-0xFF00] = data
        case address >= 0xFF80 && address <= 0xFFFF:
            memory_mapper._high_ram[address-0xFF80] = data
    }
}