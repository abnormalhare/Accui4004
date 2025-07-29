import sys

def get_hex(val: str, linenum: int) -> int:
    try:
        return int(val, base=16)
    except:
        try:
            if val[0] == '$':
                val = '0x' + val[1:]
                return int(val, base=16)
            elif val[:2] == '#$' or val[:2] == '0x':
                val = '0x' + val[2:]
                return int(val, base=16)
            else:
                print(f"ERROR: invalid number @ {linenum}")
                return -1
        except:
            print(f"ERROR: invalid number @ {linenum}")
            return -1

prg_size: int = 0

def write(file, *args: int) -> bytes:
    global prg_size

    b: bytes = b''
    for i in args:
        b += i.to_bytes(1, 'big')
        prg_size += 1

    return b

def interpret(file, line: str, linenum: int) -> bytes | int:
    line = line.split(" ")
    instruction: str = line[0].upper()
    ret: bytes = b''

    index = 1
    while instruction == "":
        if len(line) <= index:
            return b''
        instruction = line[index]
        index += 1
    
    if instruction == "NOP": ret += write(file, 0)
    elif instruction == "JCN":
        w: int = 0x10
        cond: str = line[index]
        addr: int = get_hex(line[index + 1], linenum)
        if addr == -1: return -1

        if '!' in cond: w += 8
        if 'A' in cond: w += 4
        if 'C' in cond: w += 2
        if 'T' in cond: w += 1
        if cond != "" and '!' not in cond and 'A' not in cond and 'C' not in cond and 'T' not in cond:
            print(f"ERROR: invalid condition set {cond} @ {linenum}")
            return -1

        ret += write(file, w, addr)
    elif instruction == "FIM":
        reg = 0x20 + get_hex(line[index], linenum) * 2
        data: int = get_hex(line[index + 1], linenum)
        if data == -1: return -1

        ret += write(file, reg, data)
    elif instruction == "SRC":
        val: int = 0x20 + get_hex(line[index], linenum) * 2 + 1
        ret += write(file, val)
    elif instruction == "FIN":
        val: int = 0x30 + get_hex(line[index], linenum) * 2
        ret += write(file, val)
    elif instruction == "JIN":
        val: int = 0x30 + get_hex(line[index], linenum) * 2 + 1
        ret += write(file, val)
    elif instruction == "JUN":
        addr: int = get_hex(line[index], linenum)
        byte1: int = 0x40 + (addr >> 8)
        byte2: int = addr & 0xFF
        ret += write(file, byte1, byte2)
    elif instruction == "JMS":
        addr: int = get_hex(line[index], linenum)
        byte1: int = 0x50 + (addr >> 8)
        byte2: int = addr & 0xFF
        ret += write(file, byte1, byte2)
    elif instruction == "INC":
        ret += write(file, 0x60 + get_hex(line[index], linenum))
    elif instruction == "ISZ":
        reg: int = 0x70 + get_hex(line[index], linenum)
        addr: int = get_hex(line[index + 1], linenum)
        ret += write(file, reg, addr)
    elif instruction == "ADD":
        ret += write(file, 0x80 + get_hex(line[index], linenum))
    elif instruction == "SUB":
        ret += write(file, 0x90 + get_hex(line[index], linenum))
    elif instruction == "LD":
        ret += write(file, 0xA0 + get_hex(line[index], linenum))
    elif instruction == "XCH":
        ret += write(file, 0xB0 + get_hex(line[index], linenum))
    elif instruction == "BBL":
        ret += write(file, 0xC0 + get_hex(line[index], linenum))
    elif instruction == "LDM":
        ret += write(file, 0xD0 + get_hex(line[index], linenum))
    elif instruction == "WRM": ret += write(file, 0xE0)
    elif instruction == "WMP": ret += write(file, 0xE1)
    elif instruction == "WRR": ret += write(file, 0xE2)
    elif instruction == "WPM": ret += write(file, 0xE3)
    elif instruction == "WR0": ret += write(file, 0xE4)
    elif instruction == "WR1": ret += write(file, 0xE5)
    elif instruction == "WR2": ret += write(file, 0xE6)
    elif instruction == "WR3": ret += write(file, 0xE7)
    elif instruction == "SBM": ret += write(file, 0xE8)
    elif instruction == "RDM": ret += write(file, 0xE9)
    elif instruction == "RDR": ret += write(file, 0xEA)
    elif instruction == "ADM": ret += write(file, 0xEB)
    elif instruction == "RD0": ret += write(file, 0xEC)
    elif instruction == "RD1": ret += write(file, 0xED)
    elif instruction == "RD2": ret += write(file, 0xEE)
    elif instruction == "RD3": ret += write(file, 0xEF)
    elif instruction == "CLB": ret += write(file, 0xF0)
    elif instruction == "CLC": ret += write(file, 0xF1)
    elif instruction == "IAC": ret += write(file, 0xF2)
    elif instruction == "CMC": ret += write(file, 0xF3)
    elif instruction == "CMA": ret += write(file, 0xF4)
    elif instruction == "RAL": ret += write(file, 0xF5)
    elif instruction == "RAR": ret += write(file, 0xF6)
    elif instruction == "TCC": ret += write(file, 0xF7)
    elif instruction == "DAC": ret += write(file, 0xF8)
    elif instruction == "TCS": ret += write(file, 0xF9)
    elif instruction == "STC": ret += write(file, 0xFA)
    elif instruction == "DAA": ret += write(file, 0xFB)
    elif instruction == "KBP": ret += write(file, 0xFC)
    elif instruction == "DCL": ret += write(file, 0xFD)
    elif ';' in instruction:
        pass
    elif instruction[-1] == ":":
        val: int = get_hex(instruction[:-1], linenum)
        if prg_size > val:
            print(f"ERROR: {val} @ {linenum} is earlier than expected. Program @ {prg_size}")
        while prg_size < val:
            ret += write(file, 0)
    else:
        print(f"ERROR: incorrect opcode '{instruction}' @ {linenum}")
        return -1

    return ret

linenum = 0   

def run(filename: str) -> None:
    global linenum

    fn_noext: str = filename.split('.')[0]
    if '.i4a' not in filename: filename += '.i4a'
    f = open(filename, 'r')
    g = open(f"{fn_noext}.i44", 'wb')

    # header
    g.write(b'i44\0\0\0\0\0\0\0\0\0\0\0\0\0')

    data: bytes = b''

    for n, line in enumerate(f.readlines()):
        line = line[:-1] if '\n' in line else line
        linenum = n+1
        temp = interpret(g, line, n+1)
        if isinstance(temp, int):
            break
        data += temp
    
    g.write(data)

    f.close()
    g.close()

if __name__ == "__main__":
    if (len(sys.argv) < 2 or "help" in sys.argv[1] or 'h' in sys.argv[1]):
        print("Usage: py asm.py [filename].i4a")
        sys.exit()
    
    try:
        run(sys.argv[1])
    except FileNotFoundError:
        print("ERROR: File not found")
    except Exception as E:
        print(E, f"@ line {linenum}")