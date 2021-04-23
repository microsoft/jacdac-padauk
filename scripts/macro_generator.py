import sys
import os
from struct import unpack
from os import urandom

PACKET_HEADER = "00001122334455667788"

packets ={
    "CTRL_FRAME":"0C001122334455667788080000000000000063A27314",
    "BUTTON_DOWN_ONLY":"080011223344556677880401010001000000",
    "BUTTON_UP_ONLY":"080011223344556677880401010002000000",
    "BUTTON_UP_CLICK":"1000112233445566778804010100020000000401010080000000",
    "BUTTON_UP_LONG_CLICK":"1000112233445566778804010100020000000401010081000000",
    "BUTTON_UP_HOLD":"080011223344556677880401010082000000",
}

def parse_packet_string(packet_string):
    data = [int(packet_string[i:i+2], 16) for i in range(0, len(packet_string), 2)]

    frame_size = data[0]
    packets = data[10:]

    if frame_size != len(packets):
        exit("Frame size and data length mismatch: %d %d" % (data[0], len(packets)))

    offset = 0

    while offset < frame_size:
        packet_size = data[10 + offset]
        offset += packet_size + 4

    if offset != frame_size:
        exit("frame size and data length mismatch: %d %d" % (frame_size, offset))

    return data

def jd_crc16(data):
    crc = 0xffff
    for d in data:
        x = (crc >> 8) ^ d
        x ^= x >> 4
        crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x
        crc = crc & 0xffff

    return (crc & 0xffff)

def rnd_udid():
    return list(unpack("BBBBBBBB", urandom(8)))

if len(sys.argv) == 1:
    udid = rnd_udid()
elif len(sys.argv[1]) == 16:
    udid = [int(sys.argv[1][i:i+2], 16) for i in range(0, len(sys.argv[1]), 2)]
else:
    exit("If trying to pass a udid to this script, please ensure each byte is represented by two ascii characters. e.g. for 128 the corresponding byte representation would be 80")

print("udid " + str(udid))

# generate crcs for "packets"
frame_sizes = []
crc_out = {}
for k in packets.keys():
    parsed = parse_packet_string(packets[k])
    parsed[2:10] = udid
    frame_sizes += [parsed[0]]
    crc = jd_crc16(parsed)
    print("%s: 0x%0.2X" % (k, jd_crc16(parsed)))
    crc_out[k] = { "hb":"%x" % ((crc & 0xff00) >> 8), "lb": ("%x" % (crc & 0xff)) }

# pre=compute crc for packet headers of anticipated sizes
frame_sizes = set(frame_sizes)
crc_jump_table = {}
# just the header
parsed = parse_packet_string(PACKET_HEADER)
parsed[2:10] = udid
for size in frame_sizes:
    parsed[0] = size
    crc = jd_crc16(parsed)
    crc_jump_table[size] = { "hb":"%x" % ((crc & 0xff00) >> 8), "lb": ("%x" % (crc & 0xff)) }


out_str = ["; generated using python macro_generator.py for udid  %s (%s)\r" % ("".join(["%0.2X" % i for i in udid]), hex(int.from_bytes(udid, "little")))]

for idx, i in enumerate(udid):
    out_str += ["#define UDID%s 0x%s\r" % (str(idx), "%x" % (i & 0xff))]
out_str += ["\r"]

for k in packets.keys():
    out_str += ["#define %s_CRCL 0x%s\r" % (k, crc_out[k]["lb"])]
    out_str += ["#define %s_CRCH 0x%s\r" % (k, crc_out[k]["hb"])]
    out_str += ["\r"]

out_str += ["; generated using python macro_generator.py for udid  %s (%s)\r" % ("".join(["%0.2X" % i for i in udid]), hex(int.from_bytes(udid, "little")))]

out_str += ["crc_table: \r"]
out_str += ["\tmov\ta, packet_buffer[2]\r"]
out_str += ["\tpcadd\ta\r"]

error_loop = ["crc_jmp_err:\r", "\tgoto\tcrc_jmp_err\r"]

load_table = []

static_overhead = len(out_str)

for k in sorted(crc_jump_table.keys()):
    #compute difference to add the correct number of nops
    difference = (int(k) - 1) - (len(out_str) - static_overhead)

    out_str += ["\tgoto\tcrc_jmp_err\r"]*difference
    out_str += ["\tgoto\tload_crc_%s\r" % (k)]

    load_table += ["load_crc_%s:\r" % (k)]
    load_table += ["\tmov\ta, 0x%s\r" % crc_jump_table[k]["hb"]]
    load_table += ["\tmov\tlb@crc, a\r"]
    load_table += ["\tmov\ta, 0x%s\r" % crc_jump_table[k]["lb"]]
    load_table += ["\tmov\thb@crc, a\r"]
    load_table += ["\tgoto\tcrc16_l\r"]

out_lines = out_str + load_table + error_loop

os.remove("jump_table.asm")

with open("jump_table.asm", "w+") as f:
    f.writelines(out_lines)

print(out_str)
