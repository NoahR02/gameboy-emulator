use enumset::EnumSet;
use crate::bus::bus::{Bus, INTERRUPTS_FLAG};
use crate::GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK;
use crate::interrupt_controller::InterruptType;

// Timer Registers
// DIV
pub const DIV: usize = 0xFF04;
// TIMA: Timer counter
pub const TIMA: usize = 0xFF05;
// TMA: Timer modulo
pub const TMA: usize = 0xFF06;
// TAC: Timer control
pub const TAC: usize = 0xFF07;

pub const CLOCK_0: usize = 4096;
pub const CLOCK_1: usize = 262144;
pub const CLOCK_2: usize = 65536;
pub const CLOCK_3: usize = 16384;

pub struct Timer {
    pub counter_delta: usize,
    pub divider_delta: usize
}

impl Timer {
    pub fn step(&mut self, bus: &mut Bus, m_cycles_delta: usize) {
        self.divider_step(bus, m_cycles_delta);
        self.counter_step(bus, m_cycles_delta);
    }
    
    fn divider_step(&mut self, bus: &mut Bus, m_cycles_delta: usize) {
        self.divider_delta += m_cycles_delta;
    
        // Increment the timer divider counter every 64 memory cycles.
        if self.divider_delta >= 64 {
            self.divider_delta = 0;
            bus.memory.io_ram[DIV - 0xFF00] = bus.memory.io_ram[DIV - 0xFF00].wrapping_add(1);
        }
    }
    
    fn counter_step(&mut self, bus: &mut Bus, m_cycles_delta: usize) {
        if !self.counter_is_running(bus) {
            self.counter_delta = 0;
            return;
        }
    
        self.counter_delta += m_cycles_delta;
    
        // Increment the timer divier counter every n memory cycles.
        // n is variable because the timer counter can increment at different frequencies.
        let increment_on_n_m_cycles = (GAMEBOY_CPU_SPEED_WITH_MEMORY_BOTTLE_NECK / self.get_clock_frequency(bus) as u32) as usize;
        if self.counter_delta >= increment_on_n_m_cycles {
            self.counter_delta = 0;
    
            let timer_counter_data = bus.read(TIMA as u16);
            if timer_counter_data == 0xFF {
                // When counter overflows, (TIMA) = (TMA).
                bus.write(TIMA as u16, bus.read(TMA as u16));
                // Request timer interrupt.

                let mut interrupts_flag = EnumSet::<InterruptType>::from_u8(bus.read(INTERRUPTS_FLAG as u16));
                interrupts_flag.insert(InterruptType::Timer);
                bus.write(INTERRUPTS_FLAG as u16, interrupts_flag.as_u8());
            } else {
                bus.write(TIMA as u16, timer_counter_data + 1);
            }
    
        }
    }
    
    pub fn get_clock_frequency(&mut self, bus: &mut Bus) -> i64 {
        let clock_frequency = bus.read(TAC as u16) & 0x03;
    
        match clock_frequency {
            0 => CLOCK_0 as i64,
            1 => CLOCK_1 as i64,
            2 => CLOCK_2 as i64,
            3 => CLOCK_3 as i64,
            _ => {
                unreachable!()
            }
        }
    }
    
    pub fn counter_is_running(&mut self, bus: &mut Bus) -> bool {
        let timer_control_data = bus.read(TAC as u16);
        let is_running = ((timer_control_data & 0x04) >> 2) != 0;
        is_running
    }

}