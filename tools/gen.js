// Generates the plugin's Data.js from lunar-javascript (verification-only dep).
const { Solar, Lunar, LunarYear } = require("lunar-javascript")

const FIRST = 1900, LAST = 2100
const TERMS = ["小寒","大寒","立春","雨水","惊蛰","春分","清明","谷雨","立夏","小满","芒种","夏至",
               "小暑","大暑","立秋","处暑","白露","秋分","寒露","霜降","立冬","小雪","大雪","冬至"]

// Lunar years: bit 16 = leap month big, bits 15..4 = months 1..12 big (30 days), bits 3..0 = leap month.
const info = []
for (let y = FIRST; y <= LAST; y++) {
  const months = LunarYear.fromYear(y).getMonthsInYear()
  let bits = 0, leap = 0, leapBig = 0
  for (const m of months) {
    if (m.getYear() !== y) throw new Error("month outside year " + y)
    const big = m.getDayCount() === 30 ? 1 : 0
    if (m.isLeap()) { leap = Math.abs(m.getMonth()); leapBig = big }
    else bits |= big << (16 - m.getMonth())
  }
  info.push(bits | (leapBig << 16) | leap)
}
const first = Lunar.fromYmd(FIRST, 1, 1).getSolar()

// Solar terms: per Gregorian year, the day of month of each term, stored as an
// offset from that term's earliest day across the whole range.
const days = []
for (let y = FIRST; y <= LAST; y++) {
  const t = Lunar.fromYmd(y, 6, 1).getJieQiTable()
  days.push(TERMS.map((name, i) => {
    const s = i === 23 ? t["DONG_ZHI"] : t[name]
    if (s.getYear() !== y || s.getMonth() !== Math.floor(i / 2) + 1) throw new Error(`term ${name} ${y}`)
    return s.getDay()
  }))
}
const base = TERMS.map((_, i) => Math.min(...days.map(d => d[i])))
const rows = days.map(d => d.map((v, i) => v - base[i]).join(""))
const maxOff = Math.max(...rows.join("").split("").map(Number))

const chunk = (arr, n) => Array.from({ length: Math.ceil(arr.length / n) }, (_, i) => arr.slice(i * n, i * n + n))
const out = `.pragma library

// Generated table data for Lunar.js — lunar years ${FIRST}-${LAST} and the solar
// terms of Gregorian years ${FIRST}-${LAST}, in China Standard Time (UTC+8).

var FIRST_YEAR = ${FIRST}
var LAST_YEAR = ${LAST}

// Gregorian date of lunar ${FIRST}-01-01.
var EPOCH = [${first.getYear()}, ${first.getMonth()}, ${first.getDay()}]

// One entry per lunar year: bit 16 is the leap month's length (1 = 30 days),
// bits 15..4 months 1..12 (1 = 30 days, 0 = 29), bits 3..0 the leap month (0 = none).
var YEAR_INFO = [
${chunk(info.map(v => "0x" + v.toString(16).padStart(5, "0")), 10).map(r => "  " + r.join(", ")).join(",\n")}
]

// Earliest day of month each of the 24 terms (小寒 .. 冬至) falls on.
var TERM_BASE = [${base.join(", ")}]

// One string per Gregorian year: each digit is that term's offset from TERM_BASE.
var TERM_OFFSETS = [
${chunk(rows.map(r => '"' + r + '"'), 4).map(r => "  " + r.join(", ")).join(",\n")}
]
`
process.stdout.write(out)
console.error("max term offset", maxOff, "epoch", first.toYmd())
