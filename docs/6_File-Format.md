# File Format
This may be updated to include variable ROM and RAM sizes, accessories, etc. Currently the format consists of a 0x10 byte header, the first 3 bytes being "i44".  
The next 0x1000 bytes are for the ROM chips 0-16. Currently, the code errors if the file size is not at least 0x1010 bytes.

[Prev](5_CPU-Instructions.md)