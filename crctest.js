
function jdCrc16(p) {
    let crc = 0xffff;
    for (let i = 0; i < p.length; ++i) {
        const data = p[i];
        let x = (crc >> 8) ^ data;
        x ^= x >> 4;
        crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x;
        crc &= 0xffff;
    }
    return crc;
}

function show(b) {
    const x = jdCrc16(b)
    console.log(b.toString("hex"), x.toString(16))
    return x
}
function disp(a, b) {
    const buf0 = Buffer.from(a.replace(/ /g, ""), "hex")
    const buf1 = Buffer.from(b.replace(/ /g, ""), "hex")
    const buf2 = Buffer.from(buf0)
//    for (let i = 0; i < buf1.length; ++i)
//        buf2[i] ^= buf1[i]

    const x = show(buf0)
    const y = show(buf1)
//    const z = show(buf2)
    console.log((x ^ y).toString(16))
}


disp(
    "04 00 01 23 45 67 80 ab cd ef",
       "04 00 01 23 45 67 89 AB CD EF   "
    // "0C 00 01 23 45 67 89 AB CD EF 08 00 00 00 01 01 00 00 63 A2 73 14 "
)

