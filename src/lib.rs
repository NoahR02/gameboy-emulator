use crate::bus::bus::{Bus, INTERRUPTS_FLAG, KILOBYTE};
use crate::cpu::cpu::Cpu;
use crate::io::P1_JOYPAD;

use crate::cpu::registers::Register;
use crate::interrupt_controller::{interrupt_controller_handle_interrupts, INTERRUPTS_ENABLED};
use crate::lcd::{LCDC, LY, STAT};
use crate::ppu::ppu::Ppu;
use crate::timer::timer::{Timer, DIV, TAC};

pub mod bus;
pub mod cpu;
pub mod io;
pub mod timer;
pub mod dma;
pub mod ppu;
pub mod lcd;
pub mod interrupt_controller;
pub mod helpers;
pub mod gui;

pub const GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK: u32 = 1_048_576;
pub const GAMEBOY_CPU_SPEED: u32 = GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK * 4;
pub const GAMEBOY_SCREEN_WIDTH: u32 = 160;
pub const GAMEBOY_SCREEN_HEIGHT: u32 = 144;
pub const TILE_SIZE: usize = 8;


pub struct GameBoy {
    pub cpu: Cpu,
    pub ppu: Ppu,
    pub timer: Timer,
    pub bus: Bus,
    pub current_cycle: usize,
}

impl GameBoy {
    pub fn install_rom(&mut self, rom: &[u8]) {
        for address in 0..32 * KILOBYTE {
            self.bus.write(address as u16, rom[address]);
        }
    }

    pub fn configure_startup_values(&mut self) {
        // The state after executing the boot rom
        self.cpu.registers.AF = Register(0x01b0);
        self.cpu.registers.BC = Register(0x0013);
        self.cpu.registers.DE = Register(0x00d8);
        self.cpu.registers.HL = Register(0x014d);
        self.cpu.registers.SP = Register(0xfffe);
        self.cpu.registers.PC = Register(0x0100);
        self.bus.write(0xFF44, 0x90);
        self.bus.memory.io_ram[DIV - 0xFF00] = 0x18;
        self.bus.write(TAC as u16, 0xf8);
        self.bus.write(INTERRUPTS_FLAG as u16, 0xe1);
        self.bus.write(INTERRUPTS_ENABLED as u16, 0x00);

        // LCD
        self.bus.write(LY as u16, 0x91);
        self.bus.write(LCDC as u16, 0x91);
        self.bus.write(STAT as u16, 0x81);
        self.bus.write(LCDC as u16, 0x91);
        self.bus.write(0xFF46, 0xFF);
        self.bus.write(P1_JOYPAD as u16, 0xCF);
    }

    pub fn step(&mut self) {
        let old_cycle_count = self.current_cycle;
        self.current_cycle += self.cpu.step(&mut self.bus);

        // Account for how long a DMA transfer takes.
        if self.bus.dma_transfer_requested {
            self.bus.dma_transfer_requested = false;
            self.current_cycle += 160
        }

        let p1_joypad = self.bus.memory.io_ram[P1_JOYPAD - P1_JOYPAD];
        let action_buttons_enabled = (p1_joypad & 0b00_10_0000) == 0;
        let dpad_buttons_enabled = (p1_joypad & 0b00_01_0000) == 0;

        //directional_keys_to_glfw_key: [Directional_Buttons] i32 = {
        //    .Up = glfw.KEY_W,
        //    .Left = glfw.KEY_A,
        //    .Down = glfw.KEY_S,
        //    .Right = glfw.KEY_D
        //};

        //action_keys_to_glfw_key: [Action_Buttons] i32 = {
        //    .Start = glfw.KEY_ENTER,
        //    .Select = glfw.KEY_LEFT_SHIFT,
        //    .A = glfw.KEY_Z,
        //    .B = glfw.KEY_K,
        //};

        //for direction in Directional_Buttons {
        //    let directional_key_state = key_states[directional_keys_to_glfw_key[direction]];
        //    
        //    if directional_key_state == glfw.PRESS || directional_key_state == glfw.REPEAT
        //    {
        //        let interrupts_flag = transmute(Interrupt_Set)bus_read(gb_state.bus, INTERRUPTS_FLAG);
        //        interrupts_flag += {.Joypad};
        //        bus_write(&gb_state.bus, INTERRUPTS_FLAG, transmute(byte)interrupts_flag);
        //        
        //        gb_state.io.direction_buttons += { direction } ;
        //    } else if(directional_key_state == glfw.RELEASE) {
        //        gb_state.io.direction_buttons -= { direction} ;
        //    }
        //}

        //for action_key in Action_Buttons {
        //    action_key_state := key_states[action_keys_to_glfw_key[action_key]]
        //
        //    if action_key_state == glfw.PRESS || action_key_state == glfw.REPEAT
        //    {
        //        interrupts_flag := transmute(Interrupt_Set)bus_read(gb_state.bus, INTERRUPTS_FLAG);
        //        interrupts_flag += {.Joypad};
        //        bus_write(&gb_state.bus, INTERRUPTS_FLAG, transmute(byte)interrupts_flag);
        //        gb_state.io.action_buttons += { action_key } ;
        //    } else if action_key_state == glfw.RELEASE {
        //        gb_state.io.action_buttons -= { action_key} 
        //    }
        //}

        self.current_cycle += interrupt_controller_handle_interrupts(&mut self.bus, &mut self.cpu);

        let m_cycles_delta = self.current_cycle - old_cycle_count;

        self.ppu.cycles += m_cycles_delta;
        self.ppu.step(&mut self.bus);
        self.timer.step(&mut self.bus, m_cycles_delta);
    }
}