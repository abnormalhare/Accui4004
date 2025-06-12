# Getting Started
The Intel 4004 is the first commercially produced microprocessor. It uses only 4-bits for its 16 registers, its accumulator, and its temp register, but has a 12-bit address space and has 8-bit an instruction decoder, as well as a carry.

With only this, the CPU is capable of doing basically nothing, because it needs a ROM chip in order to tell it what to do. The ROM chip has only an address decoder and a 256 byte ROM (emulated in my code as 512 nibble ROM, explained later), and you can have up to 16 of them for any given program. These two components work hand-in-hand to run code at a blistering 11 microseconds per instruction cycle.

## What can it do?
The ROM contains 4 IO pins for use with RAM. An SRC instruction can send a special signal to the ROM to indicate it wants to write something to RAM. The I/O pins can also be used with the Intel 4003 to allow for other accessories like keypads, mice, monitors, and more to be plugged into the computer.

## How can I program for it?
Hold your horses, you don't even know what the CPU's instructions are. Let's learn the specifics of the 4004.  
- *note: if you simply want to run programs, you can skip to [Using the emulator](7_Using-The-Emulator.md), however, I still suggest reading everything.*

[Next](2_Intel-4004.md)