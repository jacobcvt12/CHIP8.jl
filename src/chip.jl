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

    drawFlag::Bool
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
         delay_timer, sound_timer,
         true)
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
    if first4 == 0x0000
        # Clears the screen.
        if c8.opcode == 0x00e0
            fill!(c8.gfx, 0x00)
        # Returns from a subroutine.
        elseif c8.opcode == 0x00ee
            c8.sp -= 1
            c8.pc = c8.stack[c8.sp + 1]
            c8.pc += 2
        else
            warn("Unknown opcode")
        end
    # 0x1NNN Jumps to address NNN.
    elseif first4 == 0x1000 
        c8.pc = c8.opcode & 0x0FFF + 0x0001
    # 0x2NNN Calls subroutine at NNN.
    elseif first4 == 0x2000 
        c8.stack[c8.sp+1] = c8.pc
        c8.sp += 1
        c8.pc = c8.opcode & 0x0fff
    # 0x3XNN Skips the next instruction if VX equals NN.
    elseif first4 == 0x3000
        if c8.V[X] == c8.opcode & 0x00ff
            c8.pc += 4
        else
            c8.pc += 2
        end
    # 0x4XNN Skips the next instruction if VX doesn't equal NN.
    elseif first4 == 0x4000
        if c8.V[X] != c8.opcode & 0x00ff
            c8.pc += 4
        else
            c8.pc += 2
        end
    # 0x5XY0 Skips the next instruction if VX equals VY.
    elseif first4 == 0x5000
        if c8.V[X] == c8.V[Y]
            c8.pc += 4
        else
            c8.pc += 2
        end
    # 0x6XNN Sets VX to NN
    elseif first4 == 0x6000
        c8.V[X] = c8.opcode & 0x00ff 
        c8.pc += 2
    # 0x7XNN Adds NN to VX
    elseif first4 == 0x7000
        c8.V[X] += c8.opcode & 0x00ff 
        c8.pc += 2
    # 0x8XY* Manipulation of VX and VY
    elseif first4 == 0x8000
        last4 = c8.opcode & 0x000f

        # Sets VX to the value of VY.
        if last4 == 0x000
            c8.V[X] = c8.V[Y]
        # Sets VX to VX or VY. (Bitwise OR operation)
        elseif last4 == 0x0001
            c8.V[X] |= c8.V[Y]
        # Sets VX to VX and VY. (Bitwise AND operation)
        elseif last4 == 0x0002
            c8.V[X] &= c8.V[Y]
        # Sets VX to VX xor VY.
        elseif last4 == 0x0003
            c8.V[X] ⊻= c8.V[Y]
        # Adds VY to VX. 
        # VF is set to 1 when there's a carry, and to 0 when there isn't.
        elseif last4 == 0x0004
            if c8.V[Y] > (0xff - c8.V[X])
                c8.V[16] = 1
            else
                c8.V[16] = 0
            end
            c8.V[X] += c8.V[Y]
        # VY is subtracted from VX. 
        # VF is set to 0 when there's a borrow, and 1 when there isn't.
        elseif last4 == 0x0005
            if c8.V[Y] > c8.V[X]
                c8.V[16] = 0
            else
                c8.V[16] = 1
            end
            c8.V[X] -= c8.V[Y]
        # Shifts VX right by one
        # VF is set to the value of the least significant bit of VX 
        # before the shift (modern implementation of 0x8XY6)
        elseif last4 == 0x0006
            c8.V[16] = c8.V[X] & 0x1
            c8.V[X] >>= 1
        # Sets VX to VY minus VX. 
        # VF is set to 0 when there's a borrow, and 1 when there isn't.
        elseif last4 == 0x0007
            if c8.V[X] > c8.V[Y]
                c8.V[16] = 0
            else
                c8.V[16] = 1
            end
            c8.V[X] = c8.V[Y] - c8.V[X]
        # Shifts VX left by one
        # VF is set to the value of the most significant bit of VX 
        # before the shift (modern implementation of 0x8XYE)
        elseif last4 == 0x000E
            c8.V[16] = c8.V[X] >> 7
            c8.V[X] <<= 1
        else
            warn("Unknown opcode [0x8000]")
        end

        c8.pc += 2
    # 0x9XY0 Skips the next instruction if VX doesn't equal VY.
    elseif first4 == 0x9000
        if c8.V[X] != c8.V[Y]
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
        c8.pc = (c8.opcode & 0x0fff) + c8.V[1]
    # Sets VX to the result of a bitwise and operation on a 
    # random number (Typically: 0 to 255) and NN.
    elseif first4 == 0xc000
        c8.V[X] = rand(0x00:0xff) & (c8.opcode * 0x00ff)
        c8.pc += 2
    # Draws a sprite at coordinate (VX, VY) that has a width of 8 pixels 
    # and a height of N pixels. Each row of 8 pixels is read as 
    # bit-coded starting from memory location I; I value doesn’t 
    # change after the execution of this instruction. 
    # As described above, VF is set to 1 if any screen pixels are 
    # flipped from set to unset when the sprite is drawn, and to 0 
    # if that doesn’t happen
    elseif first4 == 0xd000
        height = c8.opcode & 0x000f
        pixel = 0x0000

        V[16] = 0x00

        for yline in 0:(height-1)
            pixel = memory[c8.I + yline + 1]
            for xline in 0:7
                if (pixel & (0x80 >> (xline))) != 0
                    if(gfx[(V[X] + xline + ((V[Y] + yline) * 64))] == 1)
                        V[16] = 1
                        gfx[V[X] + xline + ((V[Y] + yline) * 64)] ⊻= 1
                    end
                end
            end
        end

        c8.drawFlag = true
        c8.pc += 2
    # temporary for testing
    else
        c8.pc += 2
    end
end
