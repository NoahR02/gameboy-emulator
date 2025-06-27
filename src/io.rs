use std::cell::RefCell;
use bitflags::bitflags;

pub struct Io {
    pub direction_buttons: DirectionalButtons,
    pub action_buttons: ActionButtons
}

thread_local! {
    pub static IO: RefCell<Io> = RefCell::new(Io {
        direction_buttons: DirectionalButtons::empty(),
        action_buttons: ActionButtons::empty()
    });
}


pub const P1_JOYPAD: usize = 0xFF00;

bitflags! {
    #[derive(Default, Copy, Clone)]
     pub struct DirectionalButtons: u8 {
        const Up = 2;
        const Down = 3;
        const Left = 1;
        const Right = 0;
    }
}

bitflags! {
     #[derive(Default, Copy, Clone)]
     pub struct ActionButtons: u8 {
        const Start = 3;
        const Select = 2;
        const A = 0;
        const B = 1;
    }
}