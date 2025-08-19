use craft::setup_craft;
use craft::components::Component;
use craft::geometry::Size;
use gameboy_emulator::bus::bus::Bus;
use gameboy_emulator::cpu::cpu::Cpu;
use gameboy_emulator::cpu::registers::{Register, Registers};
use gameboy_emulator::gui::custom_event_loop::GameboyEmulatorState;
use gameboy_emulator::gui::gui_app::GameboyApp;
use gameboy_emulator::ppu::ppu::Ppu;
use gameboy_emulator::timer::timer::Timer;
use gameboy_emulator::GameBoy;
use winit::event_loop::EventLoop;

fn main() {
    use craft::CraftOptions;

    let application = GameboyApp::component();
    let global_state = ();
    let mut options = CraftOptions::basic("GameBoy Emulator");
    let scale = 4.0;
    options.window_size = Some(Size::new(160.0 * scale, 144.0 * scale));


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

    let rom = include_bytes!("../assets/Dr. Mario (World).gb");
    game_boy.install_rom(rom);
    game_boy.configure_startup_values();
    
    let event_loop = EventLoop::new().expect("Failed to create winit event loop.");
    let craft_state = setup_craft(application, Box::new(global_state), Some(options));
    let mut winit_craft_state = GameboyEmulatorState::new(craft_state, game_boy);

    event_loop.run_app(&mut winit_craft_state).expect("run_app failed");
}
