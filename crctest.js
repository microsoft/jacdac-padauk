
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
    const buf0 = Buffer.from(a, "hex")
    const buf1 = Buffer.from(b, "hex")
    const buf2 = Buffer.from(buf0)
    for (let i = 0; i < buf1.length; ++i)
        buf2[i] ^= buf1[i]

    const x = show(buf0)
    const y = show(buf1)
    const z = show(buf2)
    console.log((x ^ z).toString(16))
}

disp(
    "DEADF00D",
    "04000000"
)

disp(
    "9988aabb",
    "04000000"
)
