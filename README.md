# Accui4004
This is a (almost sub-)cycle accurate emulator of the Intel 4004 Chip written in Zig. This is my first real project I've completed in Zig and it was really cool to work on. Information on how to make a program for this is [here](docs/1_Getting-Started.md)

## How to build
This requires Zig to build. Zig's latest version can be downloaded [here](https://ziglang.org/download)  
Build using `zig build`. The command arguments are `Accui4004.exe [filename].i44`. 

<img width="493" height="251" alt="image" src="https://github.com/user-attachments/assets/e2568228-c217-4d55-b19a-2ebdbbb2f970" />

## The controller
The emulator has a builtin "controller" hardcoded to map to the keys W A S D E Q ; and '. The last 2 may vary on Windows systems with different keyboards. If this is the case, they are the two keys between the letter L and the enter key.

*Fibonacci.i44 running in Accui4004*
# Make your own 4004 system!
While at the moment it is cumbersome, no "chip" in this emulator requires another! Opening `motherboard.zig` and scrolling to the `sync_motherboard` function will allow you to edit the "wires" of the simulation.
