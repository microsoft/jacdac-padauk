const fs = require("fs")
const path = require("path")

function looksRandom(n) {
    const s = n.toString(16)
    const h = "0123456789abcdef"
    for (let i = 0; i < h.length; ++i) {
        const hh = h[i]
        if (s.indexOf(hh + hh + hh) >= 0) return false
    }
    if (/f00d|dead|deaf|beef/.test(s)) return false
    return true
}

function genRandom() {
    for (; ;) {
        const m = (Math.random() * 0xfff_ffff) | 0x3000_0000
        if (looksRandom(m)) return m
    }
}

function fail(msg) {
    console.error(msg)
    process.exit(1)
}

const fwidmap = {}
function validateFile(prjFn) {
    console.log(`scan: ${prjFn}`)
    const prj = fs.readFileSync(prjFn, "utf-8")
    let mainASM = ""
    let links = false
    for (const ln of prj.split(/\r?\n/)) {
        if (!mainASM && links && ln[0] == "~") {
            mainASM = ln.slice(1)
            links = false
        }
        if (ln == "[LINKS]")
            links = true
    }
    if (!mainASM) fail(`can't find main.asm in ${prjFn}`)
    mainASM = path.join(path.dirname(prjFn), mainASM)
    console.log(`  main: ${mainASM}`)
    let main = fs.readFileSync(mainASM, "utf-8")
    const m = /#define CFG_FW_ID (0[xX]?[a-fA-F0-9]*)/.exec(main)
    if (!m) fail(`no CFG_FW_ID in ${mainASM}`)
    let fwid = parseInt(m[1])
    let fwidstr = `0x${fwid.toString(16)}`
    if (fwid === 0) {
        fwid = genRandom()
        fwidstr = `0x${fwid.toString(16)}`
        main = main.replace(m[0], `#define CFG_FW_ID ${fwidstr}`)
        console.log(`  setting firmware ID to: ${fwidstr}`)
        fs.writeFileSync(mainASM, main)
    }
    if (fwidmap[fwidstr])
        fail(`firmware ID conflict on ${fwidstr} between ${mainASM} and ${fwidmap[fwidstr]}; replace one of them with 0x0 to re-generate`)

    fwidmap[fwidstr] = mainASM
}

const files = process.argv.slice(2)
if (files.length == 0)
    fail(`usage: node ${process.argv[1]} folder/device.prj...`)
files.forEach(validateFile)
console.log("All good!")
