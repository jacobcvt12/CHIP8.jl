function emulate(fname::String)
    myChip8 = Chip()
    loadApplication(myChip8, fname)
end
