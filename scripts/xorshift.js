let a = 1
let b = 1
let c = 2

function periodLen(k) {
    const k0 = k
    let r=[]
    for (let i = 0; i < 256; ++i) {
        k ^= k << a
        k &= 0xff
        k ^= k >> b
        k ^= k << c
        k &= 0xff
        r.push(k)
        if (k == k0) {
            console.log(r.join(", "))
            console.log(r.length)
            return i
        }
    }
    throw new Error("whoops")
}

periodLen(1)

for (let i = 0; i < 0; ++i) {
    a = (Math.random() * 3 + 1) | 0
    b = (Math.random() * 3 + 1) | 0
    c = (Math.random() * 3 + 1) | 0
    const pl = periodLen(1)
    if (pl >= 254) {
        console.log(a, b, c, pl)
    }
}
