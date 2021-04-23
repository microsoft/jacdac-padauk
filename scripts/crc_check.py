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


if not len(sys.argv) == 2:
    print("incompatible argument list. python crc_crc_check.py data")
    print("data -- lsb first")

data = [int(sys.argv[1][i:i+2], 16) for i in range(0, len(sys.argv[1]), 2)]

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

print("0x%0.2X" % jd_crc16(data))