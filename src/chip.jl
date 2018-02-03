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

    # get X and Y
    X = c8.opcode & 0x0f00 >> 8 + 1
    Y = c8.opcode & 0x00f0 >> 4 + 1

    # process opcode
    # 0x1NNN Jumps to address NNN.
    if first4 == 0x1000 
        c8.pc = c8.opcode & 0x0FFF + 0x0001
    # 0x3XNN Skips the next instruction if VX equals NN.
    elseif first4 == 0x3000
        if V[X] == c8.opcode & 0x00ff
            c8.pc += 4
        else
            c8.pc += 2
        end
    # 0x4XNN Skips the next instruction if VX doesn't equal NN.
    elseif first4 == 0x4000
        if V[X] != c8.opcode & 0x00ff
            c8.pc += 4
        else
            c8.pc += 2
        end
    # 0x5XY0 Skips the next instruction if VX equals VY.
    elseif first4 == 0x5000
        if V[X] == V[Y]
            c8.pc += 4
        else
            c8.pc += 2
        end
    # 0x6XNN Sets VX to NN
    elseif first4 == 0x6000
        V[X] = c8.opcode & 0x00ff 
        c8.pc += 2
    # 0x7XNN Adds NN to VX
    elseif first4 == 0x7000
        V[X] += c8.opcode & 0x00ff 
        c8.pc += 2
    # 0x8XY* Manipulation of VX and VY
    elseif first4 == 0x8000
        last4 = c8.opcode & 0x000f

        # Sets VX to the value of VY.
        if last4 == 0x000
            V[X] = V[Y]
        # Sets VX to VX or VY. (Bitwise OR operation)
        elseif last4 == 0x0001
            V[X] |= V[Y]
        # Sets VX to VX and VY. (Bitwise AND operation)
        elseif last4 == 0x0002
            V[X] &= V[Y]
        # Sets VX to VX xor VY.
        elseif last4 == 0x0003
            V[X] ⊻= V[Y]
        # Adds VY to VX. 
        # VF is set to 1 when there's a carry, and to 0 when there isn't.
        elseif last4 == 0x0004
            if V[Y] > (0xff - V[X])
                V[16] = 1
            else
                V[16] = 0
            end
            V[X] += V[Y]
        # VY is subtracted from VX. 
        # VF is set to 0 when there's a borrow, and 1 when there isn't.
        elseif last4 == 0x0005
            if V[Y] > V[X]
                V[16] = 0
            else
                V[16] = 1
            end
            V[X] -= V[Y]
        # Shifts VX right by one
        # VF is set to the value of the least significant bit of VX 
        # before the shift (modern implementation of 0x8XY6)
        elseif last4 == 0x0006
            V[16] = V[X] & 0x1
            V[X] >>= 1
        # Sets VX to VY minus VX. 
        # VF is set to 0 when there's a borrow, and 1 when there isn't.
        elseif last4 == 0x0007
            if V[X] > V[Y]
                V[16] = 0
            else
                V[16] = 1
            end
            V[X] = V[Y] - V[X]
        # Shifts VX left by one
        # VF is set to the value of the most significant bit of VX 
        # before the shift (modern implementation of 0x8XYE)
        elseif last4 == 0x000E
            V[16] = V[X] >> 7
            V[X] <<= 1
        else
            warn("Unknown opcode [0x8000]")
        end

        c8.pc += 2
    # 0x9XY0 Skips the next instruction if VX doesn't equal VY.
    elseif first4 == 0x9000
        if V[X] != V[Y]
            c8.pc += 4
        else
            c8.pc += 2
        end
    # Sets I to the address NNN.
    elseif first4 == 0xa000
        I = c8.opcode & 0x0fff
        c8.pc += 2
    # Jumps to the address NNN plus V0.
    elseif first4 == 0xb000
        c8.pc = (c8.opcode & 0x0fff) + V[1]
    # Sets VX to the result of a bitwise and operation on a 
    # random number (Typically: 0 to 255) and NN.
    elseif first4 == 0xc000
        V[X] = rand(0x00:0xff) & (c8.opcode * 0x00ff)
        c8.pc += 2
    # temporary for testing
    else
        c8.pc += 2
    end
end
