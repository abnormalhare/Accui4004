# CPU Instructions
This will get you acquainted with all the commands that are able to be run by the Intel 4004. All 2-byte commands and SRC are 2-cycle. All data sent from the CPU happens on timings X2 and X3.
This document will also help with writing programs for the disassembler
## Legend
`X` - any number  
`O` - any odd number  
`V` - any even number  

`C` - conditions (4-bit)  
`A` - address (8-bit)  
`AA` - address (12-bit)  
`R` - register pair (3-bit) (0: [reg0][reg1]) (anything with `R` has the last nibble `RRR0/RRR1`)  
 - *note: when writing for the assembler, this number is 0-7, not 0-14*  
`RR` - register (4-bit)  
`D` - data (4-bit)  
`DD` - data (8-bit)
## General Instructions
These are instructions that contain data within its second nibble.
### 0x0X - `NOP`
No Operation. Does nothing.
### 0x1X - `JCN C A` (2-byte)
Jump Conditional. The `C` bits are all different conditions. From most to least significant:  
Bit 0: Inverts the jump condition
Bit 1: Jumps if the accumulator is 0
Bit 2: Jumps if the carry is 1
Bit 3: Jumps if TEST pin is 0
If the condition succeeds, the program counter's mid and lower nibbles are set to `A`. Note: If `JCN` is stored on the last byte of the current ROM chip, the address will be on the *next* ROM chip as opposed to the current one.
To use these in the assembler: ! is bit 0, A is bit 1, C is bit 2, and T is bit 3. Any order is allowed, but this order is preferable. For example, to check if the carry is 0, write `JCN !C [A]`. To use all bits, you would write `JCN !ACT [A]`.
### 0x2V - `FIM R DD` (2-byte)
Fetch Immediate. Sets register pair `R` to `DD`, typically used for commands that use register pairs to index ROM.
### 0x2O - `SRC R`
Send Register Control. Sets CM-ROM pin and a CM-RAM pin, and sends register pair `R` to specify which ROM/RAM chip to send the command to.

For a ROM, the first register is used to determine the chip number.  For a RAM, the first register is used to select the chip (high 2 bits) and the register (low 2 bits). The second register is used to select the character within the register.
### 0x3V - `FIN R` (2-cycle)
Fetch Indirect. On the next instruction cycle, the high byte of the stack, as well as the register pair `0` is sent to the ROM. That data is stored in register pair `R`. Note: If `FIN` is stored on the last byte of the current ROM chip, data will be read from the *next* ROM chip as opposed to the current one. This is useful for using an entire chip (aside from 0x00) as data.
### 0x3O - `JIN R`
Jump Indirect. Jumps to the address in the register pair `R` in the current ROM chip.
### 0x4X - `JUN AA` (2-byte)
Jump Unconditionally. Sets the program counter to `AA`.
### 0x5X - `JMS AA` (2-byte)
Jump Subroutine. Moves all of stack up one and sets the program counter to `AA`.
### 0x6X - `INC RR`
Increment. Increases the register `RR` by 1.
### 0x7X - `ISZ RR A` (2-byte)
Increment Conditional. Jumps to address `A` if register `RR` is not zero. Otherwise, continues. Note: If `ISZ` is stored on the last byte of the current ROM chip, the address will be on the *next* ROM chip as opposed to the current one.
### 0x8X - `ADD RR`
Add. Adds register `RR` to the accumulator with carry.
### 0x9X - `SUB RR`
Subtract. Subtracts register `RR` from the accumulator with borrow.
### 0xAX - `LD RR`
Load. Loads register `RR` into the accumulator.
### 0xBX - `XCH RR`
Exchange. Exchanges the data between register `RR` and the accumulator.
### 0xCX - `BBL D`
Branch Back. Essentially, a return function. Pushes the stack back down and sets the accumulator to `D`.
### 0xDX - `LDM DD`
Load Immediate. Loads `D` into the accumulator.
## Specific Instructions
These are instructions that do not use data from the instruction itself.
### 0xEX - Communication Instructions
These send data to the ROM/RAM after sending a `SRC` instruction.
0xE0 - `WRM` | Write RAM Character. Sends the accumulator to the specified RAM character.
0xE1 - `WMP` | Write RAM Port. Sends the accumulator to the RAM's output lines.
0xE2 - `WRR` | Write ROM Port. Sends the accumulator to the ROM's I/O lines
0xE3 - `WPM` | Write Program Memory. Sends the accumulator to the 4008/4009 to write data to RAM.
0xE4 - `WR0` | Write RAM 0. Sends the accumulator to the specified RAM register's status 0.
0xE5 - `WR1` | Write RAM 1. Sends the accumulator to the specified RAM register's status 1.
0xE6 - `WR2` | Write RAM 2. Sends the accumulator to the specified RAM register's status 2.
0xE7 - `WR3` | Write RAM 3. Sends the accumulator to the specified RAM register's status 3.
0xE8 - `SBM` | Subtract with Borrow Memory. Subtracts the specified RAM's character from the accumulator with borrow (done within the CPU).
0xE9 - `RDM` | Read RAM Character. Reads the specified RAM's character into the accumulator.
0xEA - `RDR` | Read ROM Port. Reads the ROM's I/O lines into the accumulator.
0xEB - `ADM` | Add with Carry Memory. Adds the specified RAM's character from the accumulator with borrow (done within the CPU).
0xEC - `RD0` | Read RAM 0. Reads the specified RAM register's status 0 into the accumulator.
0xED - `RD1` | Read RAM 1. Reads the specified RAM register's status 1 into the accumulator.
0xEE - `RD2` | Read RAM 2. Reads the specified RAM register's status 2 into the accumulator.
0xEF - `RD3` | Read RAM 3. Reads the specified RAM register's status 3 into the accumulator.
### 0xFX - Accumulator/Carry Commands
All instructions in this section influence the accumulator internally (aside from one).
0xF0 - `CLB` | Clear Both. Sets the accumulator and carry to 0.
0xF1 - `CLC` | Clear Carry. Sets the carry to 0.
0xF2 - `IAC` | Increment Accumulator. Increases the accumulator amount by 1.
0xF3 - `CMC` | Complement Carry. Inverts the carry bit.
0xF4 - `CMA` | Complement Accumulator. Inverts all accumulator bits.
0xF5 - `RAL` | Rotate Left. Shifts the accumulator bits to the left by one. The carry puts its bit into the low bit of the accumulator and recieves the high bit. (ex: 0 1101 -> 1 1010 -> 1 0101)
0xF6 - `RAR` | Rotate Right. Shifts the accumulator bits to the right by one. The carry puts its bit into the high bit of the accumulator and recieves the low bit. (ex: 0 1101 -> 1 0110 -> 0 1011)
0xF7 - `TCC` | Transfer Carry to Accumulator. Sets the accumlator to 0 + carry, and clears carry.
0xF8 - `DAC` | Decrement Accumulator. Decreases the accumulator amount by 1.
0xF9 - `TCS` | Transfer Carry Subtract. Sets the accumulator to 9 + carry, and clears carry.
0xFA - `STC` | Set Carry. Sets the carry to 1.
0xFB - `DAA` | Decimal Adjust Accumulator. Adds 6 to the accumulator if it as a 5 bit number (including the carry) is greater than 9. (e.g. 0x0B -> 0x11). The hex reads as though it is in base 10.
0xFC - `KBP` | Keyboard Process. If there is only one bit in the accumulator enabled, it sets the accumulator to the position of the bit from lowest to highest (e.g. 0b0100 -> 3, 0b1000 -> 4). Otherwise sets accumulator to 15 to signal an error.
0xFD - `DCL` | Designate Command Line. The low 3 bits are used to determine which bank to use for CM-RAM signalling. This allows for 8 different sets of 4 RAM carts to be used. Those signals are:  
0b000 -> CM-RAM 0  
0b001 -> CM-RAM 1  
0b010 -> CM-RAM 2  
0b011 -> CM-RAM 1 & 2  
0b100 -> CM-RAM 3  
0b101 -> CM-RAM 1 & 3
0b110 -> CM-RAM 2 & 3
0b111 -> CM-RAM 1, 2, & 3  
## Writing for the Assembler
When writing for the assembler (located in assembler/), all numbers are assumbed to be hexadecimal. This includes registers. For example, if you would like to load in the 12th register to the accumulator, you would write `LD C`  
Even though all values are automatically considered, hexadecimal, `$C`, `#$C`, and `0xC` are supported as well.  
Jumping to certain addresses in the assembler is admittedly confusing because I am dumb. When jumping to an address, say, running `JUN 020`, you can write `020:` to place code there. As long as this is at or greater than the program size up to this point, there is no issue, but if it *isn't*, the assembler will error.
If you're on Windows, a complimentary `assemble.bat` comes with the repo that quickly assembles a given .i4a file and moves it into the base repo for easy running. Happy coding!

[Prev](2_Intel-4002.md) | [Next](6_File-Format.md)
