# CPU Instructions
This will get you acquainted with all the commands that are able to be run by the Intel 4004. All 2-byte commands are 2-cycle as well. All data sent happens on timings X2 and X3.
## Legend
`X` - any number  
`O` - any odd number  
`V` - any even number  

`C` - conditions (4-bit)  
`A` - address (8-bit)  
`AA` - address (12-bit)  
`R` - register pair (3-bit) (0: [reg0][reg1]) (anything with `R` has the last nibble `RRR0/RRR1`)  
`RR` - register (4-bit)  
`D` - data (4-bit)  
`DD` - data (8-bit)
## Instructions
### 0x0X - `NOP`
No Operation. Does nothing.
### 0x1X - `JCN C A` (2-byte)
Jump Conditional. The `C` bits are all different conditions. From most to least significant:  
Bit 0: Inverts the jump condition
Bit 1: Jumps if the accumulator is 0
Bit 2: Jumps if the carry is 1
Bit 3: Jumps if TEST pin is 0
If the condition succeeds, the program counter's mid and lower nibbles are set to `A`. Note: If `JCN` is stored on the last byte of the current ROM chip, the address will be on the *next* ROM chip as opposed to the current one.
### 0x2V - `FIM R DD` (2-byte)
Fetch Immediate. Sets register pair `R` to `DD`, typically used for commands that use register pairs to index ROM.
### 0x2O - `SRC R`
Send Register Control. Sets CM-ROM pin and a CM-RAM pin, and sends register pair `R` to specify which ROM/RAM chip to send the command to.
### 0x3V - `FIN R` (2-cycle)
Fetch Indirect. On the next instruction cycle, the high byte of the stack, as well as the register pair `0` is sent to the ROM. That data is stored in register pair `R`. Note: If `FIN` is stored on the last byte of the current ROM chip, data will be read from the *next* ROM chip as opposed to the current one. This is useful for using an entire chip (aside from 0x00) as data.
### 0x4X - `JUN AA` (2-byte)
Jump Unconditionally. Sets the program counter to `AA`.
### 0x5X - `JMS AA` (2-byte)
Jump Subroutine. Moves all of stack up one and sets the program counter to `AA`.
### 0x6X - `INC RR`
Increment. Increases the register `RR` by 1.
### 0x7X - `ISZ RR A` (2-byte)
Increment Conditional. Jumps to address `A` if register `R` is not zero. Otherwise, continues. Note: If `ISZ` is stored on the last byte of the current ROM chip, the address will be on the *next* ROM chip as opposed to the current one.
### 0x8X - `ADD RR`
Adds register `R` to the accumulator with carry.
### 0x9X - `SUB RR`
Subtracts register `R` from the accumulator with borrow.
### 0xAX - `LD RR`
Loads register `R` into the accumulator.