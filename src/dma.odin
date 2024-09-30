package gameboy

dma :: proc(bus: ^Bus, address: u16, data: u8) {
    if address == 0xFF46 {
        source_address_start := u16(data) << 8
        oam_mem_start := u16(0xFE00)
        oam_mem_end := u16(0xFE9F)
        for i := u16(0); i < oam_mem_end - oam_mem_start; i += 1 {
            bus_write(bus, oam_mem_start + i, bus_read(bus^, source_address_start + i))
        }
    }
}