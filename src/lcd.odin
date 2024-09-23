package gameboy

LCDC :: 0xFF40
LY :: 0xFF44
LYC :: 0xFF45
STAT :: 0xFF41

Lcd_Control_Option :: enum {
    BG_Window_Display_Priority = 0,
    OBJ_Display_Enable = 1,
    OBJ_Size = 2,
    BG_Tile_Map_Display_Select = 3,
    BG_Window_Tile_Data_Select = 4,
    Window_Display_Enable = 5,
    Window_Tile_Map_Display_Select = 6,
    LCD_Display_Enable = 7
}

Mode :: enum u8 {
    H_Blank,
    V_Blank,
    Searching_Oam,
    Data_Transfer_To_Lcd,
}

Lcd_Status_Register :: bit_field u8 {
    mode: Mode | 2,
    lcy_ly_equality_read_only: bool | 1,
    h_blank_interrupt: bool | 1,
    v_blank_interrupt: bool | 1,
    oam_interrupt: bool | 1,
    lcy_ly_equality: bool | 1,
}

Lcd_Control_Register :: bit_set[Lcd_Control_Option]