use gameboy_emulator::bus::bus::Bus;
use gameboy_emulator::cpu::cpu::Cpu;
use gameboy_emulator::cpu::registers::{Register, Registers};
use gameboy_emulator::ppu::ppu::Ppu;
use gameboy_emulator::timer::timer::Timer;
use gameboy_emulator::GameBoy;

const CPU_TESTS: [&str; 11] = [
    "tests/cpu_instrs/01-special.gb",
    "tests/cpu_instrs/02-interrupts.gb",
    "tests/cpu_instrs/03-op sp_hl.gb",
    "tests/cpu_instrs/04-op r_imm.gb",
    "tests/cpu_instrs/05-op rp.gb",
    "tests/cpu_instrs/06-ld r_r.gb",
    "tests/cpu_instrs/07-jr_jp_call_ret_rst.gb",
    "tests/cpu_instrs/08-misc instrs.gb",
    "tests/cpu_instrs/09-op r_r.gb",
    "tests/cpu_instrs/10-bit ops.gb",
    "tests/cpu_instrs/11-op-a_hl.gb",
];
use std::thread;

use std::fmt::Write;

pub fn gameboy_doctor_format_debug_state(gb: &GameBoy, buffer: &mut String) {
    let cpu = &gb.cpu;
    let bus = &gb.bus;

    let af_high = cpu.registers.AF.high();
    let af_low = cpu.registers.AF.low();
    let bc_high = cpu.registers.BC.high();
    let bc_low = cpu.registers.BC.low();
    let de_high = cpu.registers.DE.high();
    let de_low = cpu.registers.DE.low();
    let hl_high = cpu.registers.HL.high();
    let hl_low = cpu.registers.HL.low();
    let sp = cpu.registers.SP.0;
    let pc = cpu.registers.PC.0;

    let mem0 = bus.read(pc);
    let mem1 = bus.read(pc.wrapping_add(1));
    let mem2 = bus.read(pc.wrapping_add(2));
    let mem3 = bus.read(pc.wrapping_add(3));

    writeln!(
        buffer,
        "A:{:02X} F:{:02X} B:{:02X} C:{:02X} D:{:02X} E:{:02X} H:{:02X} L:{:02X} SP:{:04X} PC:{:04X} PCMEM:{:02X},{:02X},{:02X},{:02X}",
        af_high, af_low, bc_high, bc_low, de_high, de_low, hl_high, hl_low, sp, pc, mem0, mem1, mem2, mem3
    ).unwrap();
}

#[test]
fn cpu_test() {
    
    let handles: Vec<_> = CPU_TESTS.iter().map(|test| {
        let test = test.to_string();
        thread::spawn(move || {
            let mut game_boy = GameBoy {
                cpu: Cpu {
                    registers: Registers {
                        BC: Register(0),
                        DE: Register(0),
                        HL: Register(0),
                        AF: Register(0),
                        PC: Register(0),
                        SP: Register(0),
                    },
                    ime: false,
                    is_halted: false,
                },
                ppu: Ppu::new(),
                timer: Timer {
                    counter_delta: 0,
                    divider_delta: 0,
                },
                bus: Bus::new(),
                current_cycle: 0,
            };

            let rom = std::fs::read(&test).expect("Failed to read test ROM");
            game_boy.install_rom(rom.as_slice());
            game_boy.configure_startup_values();

            // let mut log_buffer = String::new();
            //gameboy_doctor_format_debug_state(&game_boy, &mut log_buffer);
            while (game_boy.cpu.registers.PC.0 as usize) < 0xFFFF {
                game_boy.step();
                //gameboy_doctor_format_debug_state(&game_boy, &mut log_buffer);
                
                let debug_output = String::from_utf8(game_boy.bus.blargg_debug_output.clone())
                    .unwrap_or_default();

                if debug_output.contains("Passed") {
                    println!("✅ Passed {}", test);
                    break;
                } else if debug_output.contains("Failed") {
                    println!("❌ Failed {}", test);
                    break;
                }
            }
            // std::fs::write("debug_log.txt", log_buffer).expect("Failed to write to the debug log.");
        })
    }).collect();

    for handle in handles {
        handle.join().expect("Test thread panicked");
    }
}
