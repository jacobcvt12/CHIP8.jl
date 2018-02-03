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
    pc = 0x201      # Program counter stars at 0x200 + 1 (1-based index)
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

"Read in c8 file"
function loadApplication(c8::Chip, fname::String)
    i = 512 + 1
    open(fname) do f
        while !eof(f)
            buffer = read(f, UInt8)
            c8.memory[i] = buffer

            i += 1
        end
    end
end

"Start the emulation"
function emulateCycle(c8::Chip)
    # fetch the opcode
    c8.opcode = UInt16(c8.memory[c8.pc]) << 8 |
                c8.memory[c8.pc + 1]

    # get the first 4 bits
    first4 = c8.opcode & 0xF000

    # process opcode
    # 0x1NNN Jumps to address NNN.
    if first4 == 0x1000 
        c8.pc = c8.opcode & 0x0FFF + 0x0001
    # 0x3XNN Skips the next instruction if VX equals NN.
    elseif first4 == 0x3000
        if V[c8.opcode & 0x0f00 >> 8 + 1] == c8.opcode & 0x00ff
            c8.pc += 4
        else
            c8.pc += 2
        end
    # 0x4XNN Skips the next instruction if VX doesn't equal NN.
    elseif first4 == 0x4000
        if V[c8.opcode & 0x0f00 >> 8 + 1] != c8.opcode & 0x00ff
            c8.pc += 4
        else
            c8.pc += 2
        end
    # 0x5XY0 Skips the next instruction if VX equals VY.
    elseif first4 == 0x5000
        if V[c8.opcode & 0x0f00 >> 8 + 1] == 
           V[c8.opcode & 0x00f0 >> 4 + 1]
            c8.pc += 4
        else
            c8.pc += 2
        end
    # 0x6XNN Sets VX to NN
    elseif first4 == 0x6000
        V[c8.opcode & 0x0f00 >> 8 + 1] = c8.opcode & 0x00ff 
        c8.pc += 2
    # 0x7XNN Adds NN to VX
    elseif first4 == 0x7000
        V[c8.opcode & 0x0f00 >> 8 + 1] += c8.opcode & 0x00ff 
        c8.pc += 2
    end
end
