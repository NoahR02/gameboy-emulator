use crate::bus::bus::Bus;

pub fn dma(bus: &mut Bus, address: u16, data: u8) {
    if address == 0xFF46 {
        let source_address_start: u16 = (data as u16) << 8;
        let oam_mem_start: u16 = 0xFE00;
        let oam_mem_end: u16 = 0xFE9F;
        for i in 0u16..(oam_mem_end - oam_mem_start) {
            bus.write(oam_mem_start + i, bus.read(source_address_start + i));
        }
    }
}