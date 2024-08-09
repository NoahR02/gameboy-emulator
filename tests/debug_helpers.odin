package tests

import "core:os"
import "core:log"
import "core:strings"
import "core:fmt"
import gameboy "../src"

file_console_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
    data := cast(^log.File_Console_Logger_Data)logger_data
    h: os.Handle = os.stdout if level <= log.Level.Error else os.stderr
    if data.file_handle != os.INVALID_HANDLE {
        h = data.file_handle
    }
    backing: [1024]byte
    buf := strings.builder_from_bytes(backing[:])

    fmt.fprintf(h, "%s%s\n", strings.to_string(buf), text)
}

gameboy_doctor_print_debug_state :: proc(gb_state: gameboy.Gb_State) {
    using gameboy
    using gb_state
    
    log.infof("A:%02x F:%02x B:%02x C:%02x D:%02x E:%02x H:%02x L:%02x SP:%04x PC:%04x PCMEM:%02x,%02x,%02x,%02x",
        cpu.registers.AF.high, cpu.registers.AF.low,
        cpu.registers.BC.high, cpu.registers.BC.low,
        cpu.registers.DE.high, cpu.registers.DE.low,
        cpu.registers.HL.high, cpu.registers.HL.low,
        u16(cpu.registers.SP),
        u16(cpu.registers.PC),
        memory_mapper_read(memory_mapper, u16(cpu.registers.PC)),
        memory_mapper_read(memory_mapper, u16(cpu.registers.PC) + 1),
        memory_mapper_read(memory_mapper, u16(cpu.registers.PC) + 2),
        memory_mapper_read(memory_mapper, u16(cpu.registers.PC) + 3),
    )
}