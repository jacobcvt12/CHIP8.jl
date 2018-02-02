mutable struct Chip
    gfx::Vector{UInt8}      # Total amount of pixels: 2048
    key::Vector{UInt8}

    pc::UInt16              # Program counter
    opcode::UInt16          # Current opcode
    I::UInt16               # Index register
    sp::UInt16              # Stack pointer

    V::Vector{UInt8}        # V-regs (V0-VF)
    stack::Vector{UInt16}   # Stack (16 levels)
    memory::Vector{UInt8}   # Memory (size=4k)

    delay_timer::Char       # Delay timer
    sound_timer::Char       # Sound timer
end

"Construct Chip-8"
function Chip()
    pc = 0x200      # Program counter stars at 0x200
    opcode = 0x00   # Reset current opcode
    I = 0x00        # Reset index register
    sp = 0x00       # Reset stack pointer

    # clear display
    gfx = zeros(UInt8, 2048)

    # clear stack
    stack = zeros(UInt16, 16)
    V = zeros(UInt8, 16)
    key = V

    # clear memory
    memory = zeros(UInt8, 4096)

    # load fontset
    memory[1:80] = [
        0xF0, 0x90, 0x90, 0x90, 0xF0, #0
        0x20, 0x60, 0x20, 0x20, 0x70, #1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, #2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, #3
        0x90, 0x90, 0xF0, 0x10, 0x10, #4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, #5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, #6
        0xF0, 0x10, 0x20, 0x40, 0x40, #7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, #8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, #9
        0xF0, 0x90, 0xF0, 0x90, 0x90, #A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, #B
        0xF0, 0x80, 0x80, 0x80, 0xF0, #C
        0xE0, 0x90, 0x90, 0x90, 0xE0, #D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, #E
        0xF0, 0x80, 0xF0, 0x80, 0x80  #F
    ]

    # reset timers
    delay_timer = 0x00
    sound_timer = 0x00

    Chip(gfx, key, 
         pc, opcode, I, sp,
         V, stack, memory,
         delay_timer, sound_timer)
end

