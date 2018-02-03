@testset "IO" begin
    c8 = Chip()
    @test_nowarn CHIP8.loadApplication(c8, "pong2.c8")
end
