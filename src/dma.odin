package gameboy

dma :: proc(memory_mapper: ^Memory_Mapper, address: u16, data: u8) {
    if address == 0xFF46 {
        source_address_start := u16(data) << 8
        oam_mem_start := u16(0xFE00)
        oam_mem_end := u16(0xFE9F)
        for i := u16(0); i < oam_mem_end - oam_mem_start; i += 1 {
            memory_mapper_write(memory_mapper, oam_mem_start + i, memory_mapper_read(memory_mapper^, source_address_start + i))
        }
    }
}