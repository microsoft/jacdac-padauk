
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
function disp(a) {
    const buf0 = Buffer.from(a.replace(/ /g, ""), "hex")
    const buf1 = Buffer.from(a.replace(/ /g, ""), "hex")

    const x = show(buf0)

    for (let i = 0; buf1[0] < 40+4; ++i) {
        buf1[0] += 1
        const y = jdCrc16(buf1)
        const diff = x ^ y
        console.log(`ret 0x${(diff & 0xff).toString(16)}  // ${buf1[0] - 4}`)
        console.log(`ret 0x${(diff >> 8).toString(16)}`)
    }
}


//disp( "04 00 4242424242007969")

show("08 00 37df482e11223344 04000300 8011 44AB")

