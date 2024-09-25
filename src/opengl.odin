package gameboy

import gl "vendor:OpenGL"

Texture :: struct {
    handle: u32,
    width: u32,
    height: u32
}

texture_make :: proc() -> (self: Texture) {
    gl.GenTextures(1, &self.handle)
    gl.BindTexture(gl.TEXTURE_2D, self.handle)
    return
}

texture_update :: proc(self: ^Texture, data: []u8, width, height: u32) {
    self.width = width
    self.height = height
    gl.BindTexture(gl.TEXTURE_2D, self.handle)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

    // Upload pixels into the texture.
    gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(width), i32(height), 0, gl.RGBA, gl.UNSIGNED_BYTE, &data[0])
}

texture_destroy :: proc(self: ^Texture) {
    gl.DeleteTextures(1, &self.handle)
}