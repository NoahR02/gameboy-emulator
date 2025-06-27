use bit_field::BitField;
use enumset::EnumSetType;
use std::ops::RangeInclusive;

pub const LCDC: usize = 0xFF40;
pub const LY:   usize = 0xFF44;
pub const LYC:  usize = 0xFF45;
pub const STAT: usize = 0xFF41;


#[derive(EnumSetType, Debug)]
#[repr(u8)]
pub enum LcdControlOption {
    BgWindowDisplayPriority = 0,
    ObjDisplayEnable = 1,
    ObjSize = 2,
    BgTileMapDisplaySelect = 3,
    BgWindowTileDataSelect = 4,
    WindowDisplayEnable = 5,
    WindowTileMapDisplaySelect = 6,
    LcdDisplayEnable = 7,
}

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    HBlank = 0,
    VBlank = 1,
    SearchingOam = 2,
    DataTransferToLcd = 3,
}

impl From<u8> for Mode {
    fn from(value: u8) -> Self {
        match value {
            0 => Mode::HBlank,
            1 => Mode::VBlank,
            2 => Mode::SearchingOam,
            3 => Mode::DataTransferToLcd,
            _ => {
                unreachable!()
            }
        }
    }
}

pub struct LcdStatusRegister(pub u8);

impl LcdStatusRegister {
    const MODE_RANGE: RangeInclusive<usize> = 0..=1;

    pub fn mode(&self) -> Mode                      { self.0.get_bits(Self::MODE_RANGE).into() }
    pub fn lcy_ly_equality_read_only(&self) -> bool { self.0.get_bit(2) }
    pub fn h_blank_interrupt(&self) -> bool         { self.0.get_bit(3) }
    pub fn v_blank_interrupt(&self) -> bool         { self.0.get_bit(4) }
    pub fn oam_interrupt(&self) -> bool             { self.0.get_bit(5) }
    pub fn lcy_ly_equality(&self) -> bool           { self.0.get_bit(6) }

    pub fn set_mode(&mut self, mode: Mode)                     { self.0.set_bits(Self::MODE_RANGE, mode as u8); }
    pub fn set_lcy_ly_equality_read_only(&mut self, val: bool) { self.0.set_bit(2, val); }
    pub fn set_h_blank_interrupt(&mut self, val: bool)         { self.0.set_bit(3, val); }
    pub fn set_v_blank_interrupt(&mut self, val: bool)         { self.0.set_bit(4, val); }
    pub fn set_oam_interrupt(&mut self, val: bool)             { self.0.set_bit(5, val); }
    pub fn set_lcy_ly_equality(&mut self, val: bool)           { self.0.set_bit(6, val); }
}