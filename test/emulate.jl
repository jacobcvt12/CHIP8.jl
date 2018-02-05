@testset "emulate" begin
    # try emulating one cycle
    c8 = Chip()
    CHIP8.loadApplication(c8, "pong2.c8")
    @test_nowarn CHIP8.emulateCycle(c8)

    # now run entire emulation
    @test_nowarn emulate("pong2.c8")
end
