use enumset::{EnumSet, EnumSetType};
use crate::bus::bus::Bus;
use crate::cpu::cpu::Cpu;
use crate::cpu::registers::Register;

#[derive(EnumSetType, Debug)]
#[repr(u8)]
pub enum InterruptType {
    VBlank = 0,
    LCD = 1,
    Timer = 2,
    Serial = 3,
    Joypad = 4,
    unused_1 = 5,
    unused_2 = 6,
    unused_3 = 7,
}

// IF
pub const INTERRUPTS_FLAG: usize = 0xFF0F;
// IE
pub const INTERRUPTS_ENABLED: usize = 0xFFFF;


pub fn interrupt_controller_handle_interrupts(bus: &mut Bus, cpu: &mut Cpu) -> usize {
    let mut m_cycles: usize = 0;

    let interrupts_enabled = EnumSet::<InterruptType>::from_u8(bus.read(INTERRUPTS_ENABLED as u16));
    let mut interrupts_flag = EnumSet::<InterruptType>::from_u8(bus.read(INTERRUPTS_FLAG as u16));
    let mut did_interrupt_occur = false;

    if
    interrupts_enabled.contains(InterruptType::VBlank) && interrupts_flag.contains(InterruptType::VBlank) || 
    interrupts_enabled.contains(InterruptType::LCD) && interrupts_flag.contains(InterruptType::LCD) ||
    interrupts_enabled.contains(InterruptType::Timer) && interrupts_flag.contains(InterruptType::Timer) || 
    interrupts_enabled.contains(InterruptType::Serial) && interrupts_flag.contains(InterruptType::Serial) ||
    interrupts_enabled.contains(InterruptType::Joypad) && interrupts_flag.contains(InterruptType::Joypad) {
        did_interrupt_occur = true;
    };

    // If any interrupts happen, wake up the CPU.
    if did_interrupt_occur {
        cpu.is_halted = false;
    }

    if cpu.ime {

        fn push_pc(bus: &mut Bus, cpu: &mut Cpu) {
            bus.write((cpu.registers.SP.as_u16()) - 1, cpu.registers.PC.high());
            bus.write((cpu.registers.SP.as_u16()) - 2, cpu.registers.PC.low());
            cpu.registers.SP = Register((cpu.registers.SP.as_u16()) - 2);
        }

        // In order from the highest priority to the lowest priority.
        if interrupts_enabled.contains(InterruptType::VBlank) && interrupts_flag.contains(InterruptType::VBlank) {
            push_pc(bus, cpu);
            cpu.registers.PC = Register(0x40);
            interrupts_flag.remove(InterruptType::VBlank);
        } else if interrupts_enabled.contains(InterruptType::LCD) && interrupts_flag.contains(InterruptType::LCD) {
            push_pc(bus, cpu);
            cpu.registers.PC = Register(0x48);
            interrupts_flag.remove(InterruptType::LCD);
        } else if interrupts_enabled.contains(InterruptType::Timer) && interrupts_flag.contains(InterruptType::Timer) {
            push_pc(bus, cpu);
            cpu.registers.PC = Register(0x50);
            interrupts_flag.remove(InterruptType::Timer);
        } else if interrupts_enabled.contains(InterruptType::Serial) && interrupts_flag.contains(InterruptType::Serial) {
            push_pc(bus, cpu);
            cpu.registers.PC = Register(0x58);
            interrupts_flag.remove(InterruptType::Serial);
        } else if interrupts_enabled.contains(InterruptType::Joypad) && interrupts_flag.contains(InterruptType::Joypad) {
            push_pc(bus, cpu);
            cpu.registers.PC = Register(0x60);
            interrupts_flag.remove(InterruptType::Joypad);
        }

        if did_interrupt_occur {
            m_cycles += 5;
            bus.write(INTERRUPTS_FLAG as u16, interrupts_flag.as_u8());
        }
    }

    m_cycles
}