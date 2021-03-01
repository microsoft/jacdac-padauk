import sys
import os

def jd_crc16(data):
    crc = 0xffff
    for d in data:
        x = (crc >> 8) ^ d
        x ^= x >> 4
        crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x
        crc = crc & 0xffff

    return (crc & 0xffff)


if not len(sys.argv) == 4:
    print("incompatible argument list. python crc_gen.py sizes flags udid")
    print("sizes - csv list of sizes to generate")
    print("flags - the flags for the packet")
    print("udid - ascending byte order")

sizes = [int(s) for s in sys.argv[1].split(",")]
flags = int(sys.argv[2])
udid = [int(sys.argv[3][i:i+2], 16) for i in range(0, 16, 2)]

out = {}

for size in sizes:
    packet = [size, flags] + udid
    crc = jd_crc16(packet)
    out[size] = { "lb":"%x" % ((crc & 0xff00) >> 8), "hb": ("%x" % (crc & 0xff)) }

out_str = ["; generated using python crc_gen.py %s %d %s\r" % (",".join([str(s) for s in sizes]), flags, sys.argv[3]), "crc_table:\r"]
out_str += ["\tmov\ta, packet_buffer[2]\r"]
out_str += ["\tpcadd\ta\r"]

error_loop = ["crc_jmp_err:\r", "\tgoto\tcrc_jmp_err\r"]

load_table = []

static_overhead = len(out_str)

for k in sorted(out.keys()):
    #compute difference to add the correct number of nops
    difference = (int(k) - 1) - (len(out_str) - static_overhead)

    out_str += ["\tgoto\tcrc_jmp_err\r"]*difference
    out_str += ["\tgoto\tload_crc_%s\r" % (k)]

    load_table += ["load_crc_%s:\r" % (k)]
    load_table += ["\tmov\ta, 0x%s\r" % out[k]["lb"]]
    load_table += ["\tmov\tlb@crc, a\r"]
    load_table += ["\tmov\ta, 0x%s\r" % out[k]["hb"]]
    load_table += ["\tmov\thb@crc, a\r"]
    load_table += ["\tgoto\tcrc16_l\r"]

out_lines = out_str + load_table + error_loop

os.remove("jump_table.asm")

with open("jump_table.asm", "w+") as f:
    f.writelines(out_lines)

print(out)