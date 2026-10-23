// Checks the plugin's Lunar.js against lunar-javascript for every day in range.
const fs = require("fs")
const { Solar } = require("lunar-javascript")
const dir = process.argv[2] || __dirname + "/.."

// Load the QML JS libraries as plain scripts: drop the .pragma/.import lines.
const load = (file, deps) => {
  const src = fs.readFileSync(dir + "/" + file, "utf8").split("\n").filter(l => !l.startsWith(".")).join("\n")
  const names = src.match(/^(?:var|function) (\w+)/gm).map(s => s.split(" ")[1])
  return new Function(...Object.keys(deps), src + "\nreturn {" + names.join(",") + "}")(...Object.values(deps))
}
const Data = load("Data.js", {})
const L = load("Lunar.js", { Data })

let n = 0, bad = 0
const fail = (msg) => { if (bad++ < 20) console.log("MISMATCH", msg) }
for (let t = Date.UTC(1900, 0, 31); t <= Date.UTC(2100, 11, 31); t += 86400000) {
  const d = new Date(t), y = d.getUTCFullYear(), m = d.getUTCMonth() + 1, day = d.getUTCDate()
  const ref = Solar.fromYmd(y, m, day).getLunar()
  const mine = L.describe(y, m, day)
  const key = `${y}-${m}-${day}`
  n++
  if (!mine.lunar) { fail(key + " out of range"); continue }
  const lu = mine.lunar
  if (lu.year !== ref.getYear() || lu.month !== Math.abs(ref.getMonth()) || lu.leap !== ref.getMonth() < 0 || lu.day !== ref.getDay())
    fail(`${key} lunar ${lu.year}-${lu.leap ? "闰" : ""}${lu.month}-${lu.day} vs ${ref.getYear()}-${ref.getMonth()}-${ref.getDay()}`)
  if (lu.monthName !== ref.getMonthInChinese() + "月" || lu.dayName !== ref.getDayInChinese())
    fail(`${key} names ${lu.monthName}${lu.dayName} vs ${ref.getMonthInChinese()}${ref.getDayInChinese()}`)
  if (lu.yearName !== ref.getYearInGanZhi() || lu.zodiac !== ref.getYearShengXiao())
    fail(`${key} year ${lu.yearName}${lu.zodiac} vs ${ref.getYearInGanZhi()}${ref.getYearShengXiao()}`)
  if (mine.dayCycle !== ref.getDayInGanZhi()) fail(`${key} day ${mine.dayCycle} vs ${ref.getDayInGanZhi()}`)
  const refTerm = ref.getJieQi()
  if (mine.term !== refTerm) fail(`${key} term '${mine.term}' vs '${refTerm}'`)
  const isEve = ref.getFestivals().includes("除夕")
  if (mine.festivals.includes("除夕") !== isEve) fail(`${key} 除夕 ${mine.festivals} vs ${ref.getFestivals()}`)
}
// Spot checks the reference cannot make for us.
const around = L.termsAround(2026, 10, 23)
console.log("2026-10-23:", JSON.stringify(L.describe(2026, 10, 23).lunar), "| term now", around.current.name, around.current.days, "| next", around.next.name, around.next.days)
console.log("母亲节 2026:", L.describe(2026, 5, 10).festivals, " 父亲节 2026:", L.describe(2026, 6, 21).festivals)
console.log("out of range:", L.fromSolar(1900, 1, 30), L.fromSolar(2101, 6, 1))
console.log("grid rows", L.monthGrid(2026, 10, 1, "2026-10-23").map(w => w.days.map(c => c.day + c.label).join(" ")).join("\n"))
console.log(`checked ${n} days, ${bad} mismatches`)
