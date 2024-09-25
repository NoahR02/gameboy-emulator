package tests

import "core:testing"
import "core:os"
import "core:log"
import "vendor:glfw"
import gl "vendor:OpenGL"
import gameboy "../src"

tests :: [?]string {
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
}

import "core:fmt"
import "core:strings"

@(test)
test_cpu :: proc(t: ^testing.T) {


    assert(cast(bool)glfw.Init())
    defer glfw.Terminate()

    glfw.WindowHint(glfw.VISIBLE, false)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    window := glfw.CreateWindow(1280, 720, "yuki gb", nil, nil)
    assert(window != nil)
    defer glfw.DestroyWindow(window)

    glfw.MakeContextCurrent(window)
    // Vsync.
    glfw.SwapInterval(1)

    gl.load_up_to(3, 3, glfw.gl_set_proc_address)

    for test in tests {
        using gameboy
        gb_state := gb_state_make()
        defer gb_state_delete(&gb_state)
        connect_devices(&gb_state)
        
        rom, rom_read_success := os.read_entire_file(test)
        if !rom_read_success {
            log.panic("Failed to read the test rom!")
        }
        defer delete(rom)
        gameboy_install_rom(&gb_state, rom)
        gameboy_configure_startup_values_after_the_boot_rom(&gb_state)

        when ODIN_TEST {
            blargg_debug_output = make_dynamic_array([dynamic]u8)
            defer delete_dynamic_array(blargg_debug_output)
        }
        for int(gb_state.cpu.registers.PC) < 0xFFFF {
            gameboy_step(&gb_state)

            when ODIN_TEST {
                debug_output := strings.clone_from_bytes(blargg_debug_output[:], context.temp_allocator)
                if strings.contains(debug_output, "Passed") {
                    log.infof("Passed %s", test)
                    break
                } else if strings.contains(debug_output, "Failed") {
                    log.infof("Failed %s", test)
                    testing.fail(t)
                }
            }
        }
    }
    
}