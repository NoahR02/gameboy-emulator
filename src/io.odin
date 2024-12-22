package gameboy

Io :: struct {
    direction_buttons: bit_set[Directional_Buttons],
    action_buttons: bit_set[Action_Buttons]
}

P1_JOYPAD :: 0xFF00

Directional_Buttons :: enum {
    Up,
    Down,
    Left,
    Right,
}

Directional_Buttons_Bit_Offsets := [Directional_Buttons] byte {
    .Up = 2,
    .Down = 3,
    .Left = 1,
    .Right = 0,
}

Directional_Buttons_Set :: bit_set[Directional_Buttons]

Action_Buttons :: enum {
    Start,
    Select,
    A,
    B,
}

Action_Buttons_Bit_Offsets := [Action_Buttons] byte {
    .Start = 3,
    .Select = 2,
    .A = 0,
    .B = 1,
}