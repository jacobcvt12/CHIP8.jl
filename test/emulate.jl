@testset "emulate" begin
    c8 = Chip()
    CHIP8.loadApplication(c8, "pong2.c8")
    @test_nowarn CHIP8.emulateCycle(c8)
end
