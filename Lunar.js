.pragma library
.import "Data.js" as Data

// The Chinese lunar calendar and the 24 solar terms, read from the tables in
// Data.js. Months are 1-based throughout (January = 1, 正月 = 1); dates out
// of the tables' range come back as null rather than a guess.

var MONTH_NAMES = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
var DIGITS = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
var STEMS = "甲乙丙丁戊己庚辛壬癸"
var BRANCHES = "子丑寅卯辰巳午未申酉戌亥"
var ZODIAC = "鼠牛虎兔龙蛇马羊猴鸡狗猪"
var TERMS = ["小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
             "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"]

var LUNAR_FESTIVALS = {
  "1-1": "春节", "1-15": "元宵节", "2-2": "龙抬头", "5-5": "端午节", "7-7": "七夕",
  "7-15": "中元节", "8-15": "中秋节", "9-9": "重阳节", "12-8": "腊八节", "12-23": "小年"
}

var SOLAR_FESTIVALS = {
  "1-1": "元旦", "2-14": "情人节", "3-8": "妇女节", "3-12": "植树节", "5-1": "劳动节",
  "5-4": "青年节", "6-1": "儿童节", "7-1": "建党节", "8-1": "建军节", "9-10": "教师节",
  "10-1": "国庆节", "12-24": "平安夜", "12-25": "圣诞节"
}

// 1970-01-01 is 辛巳, the 18th day of the sexagenary cycle.
var DAY_CYCLE_OFFSET = 17

// Days since 1970-01-01, counted in UTC so no time zone or DST shift can
// move a date onto its neighbour.
function dayNumber(year, month, day) {
  return Math.floor(Date.UTC(year, month - 1, day) / 86400000)
}

function dateOfDayNumber(n) {
  var d = new Date(n * 86400000)
  return { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() }
}

function leapMonth(year) {
  return Data.YEAR_INFO[year - Data.FIRST_YEAR] & 0xf
}

function monthLength(year, month, leap) {
  var info = Data.YEAR_INFO[year - Data.FIRST_YEAR]
  if (leap) return (info & 0x10000) ? 30 : 29
  return ((info >> (16 - month)) & 1) ? 30 : 29
}

function yearLength(year) {
  var total = leapMonth(year) ? monthLength(year, 0, true) : 0
  for (var m = 1; m <= 12; m++) total += monthLength(year, m, false)
  return total
}

// Day number of each lunar new year, built once on first use.
var yearStarts = null

function lunarYearStarts() {
  if (yearStarts) return yearStarts
  var starts = []
  var n = dayNumber(Data.EPOCH[0], Data.EPOCH[1], Data.EPOCH[2])
  for (var y = Data.FIRST_YEAR; y <= Data.LAST_YEAR + 1; y++) {
    starts.push(n)
    if (y <= Data.LAST_YEAR) n += yearLength(y)
  }
  yearStarts = starts
  return starts
}

function yearName(year) {
  return STEMS.charAt((year - 4) % 10) + BRANCHES.charAt((year - 4) % 12)
}

function zodiac(year) {
  return ZODIAC.charAt((year - 4) % 12)
}

function monthName(month, leap) {
  return (leap ? "闰" : "") + MONTH_NAMES[month - 1] + "月"
}

function dayName(day) {
  if (day === 10) return "初十"
  if (day === 20) return "二十"
  if (day === 30) return "三十"
  var tens = ["初", "十", "廿"][Math.floor(day / 10)]
  return tens + DIGITS[(day - 1) % 10]
}

function dayCycleName(year, month, day) {
  var i = (dayNumber(year, month, day) + DAY_CYCLE_OFFSET) % 60
  if (i < 0) i += 60
  return STEMS.charAt(i % 10) + BRANCHES.charAt(i % 12)
}

// The lunar date of a Gregorian date, or null outside the table.
function fromSolar(year, month, day) {
  var starts = lunarYearStarts()
  var n = dayNumber(year, month, day)
  if (n < starts[0] || n >= starts[starts.length - 1]) return null

  var i = 0
  while (starts[i + 1] <= n) i++
  var ly = Data.FIRST_YEAR + i
  var offset = n - starts[i]
  var leap = leapMonth(ly)

  for (var m = 1; m <= 12; m++) {
    var len = monthLength(ly, m, false)
    if (offset < len) return lunarDate(ly, m, false, offset + 1, len)
    offset -= len
    if (leap === m) {
      len = monthLength(ly, m, true)
      if (offset < len) return lunarDate(ly, m, true, offset + 1, len)
      offset -= len
    }
  }
  return null
}

function lunarDate(year, month, leap, day, length) {
  return {
    year: year,
    month: month,
    leap: leap,
    day: day,
    monthLength: length,
    yearName: yearName(year),
    zodiac: zodiac(year),
    monthName: monthName(month, leap),
    dayName: dayName(day)
  }
}

// ---- Solar terms -----------------------------------------------------------

function termInRange(year) {
  return year >= Data.FIRST_YEAR && year <= Data.LAST_YEAR
}

// The day of month term index (0 = 小寒 .. 23 = 冬至) falls on in year.
function termDay(year, index) {
  var row = Data.TERM_OFFSETS[year - Data.FIRST_YEAR]
  return Data.TERM_BASE[index] + Number(row.charAt(index))
}

function termOn(year, month, day) {
  if (!termInRange(year)) return ""
  for (var i = (month - 1) * 2; i < month * 2; i++)
    if (termDay(year, i) === day) return TERMS[i]
  return ""
}

function termAt(year, index) {
  var month = Math.floor(index / 2) + 1
  var day = termDay(year, index)
  return { name: TERMS[index], index: index, year: year, month: month, day: day, n: dayNumber(year, month, day) }
}

// The latest term on or before the date, and the first one after it, each
// with how many days lie between it and the date. Null outside the table.
function termsAround(year, month, day) {
  if (!termInRange(year)) return null
  var n = dayNumber(year, month, day)
  var current = null, next = null
  for (var y = year - 1; y <= year + 1 && !next; y++) {
    if (!termInRange(y)) continue
    for (var i = 0; i < 24; i++) {
      var t = termAt(y, i)
      if (t.n <= n) current = t
      else { next = t; break }
    }
  }
  if (!current || !next) return null
  current.days = n - current.n
  next.days = next.n - n
  return { current: current, next: next }
}

// ---- Festivals ---------------------------------------------------------------

// The nth weekday (0 = Sunday) of a month: 母亲节 and 父亲节 move with the week.
function nthWeekday(year, month, weekday, nth) {
  var first = new Date(Date.UTC(year, month - 1, 1)).getUTCDay()
  return 1 + (weekday - first + 7) % 7 + (nth - 1) * 7
}

function festivals(year, month, day, lunar) {
  var names = []
  if (lunar && !lunar.leap) {
    if (lunar.month === 12 && lunar.day === lunar.monthLength) names.push("除夕")
    var lf = LUNAR_FESTIVALS[lunar.month + "-" + lunar.day]
    if (lf) names.push(lf)
  }
  var sf = SOLAR_FESTIVALS[month + "-" + day]
  if (sf) names.push(sf)
  if (month === 5 && day === nthWeekday(year, 5, 0, 2)) names.push("母亲节")
  if (month === 6 && day === nthWeekday(year, 6, 0, 3)) names.push("父亲节")
  return names
}

// ---- One day, everything the panel shows about it ----------------------------

function describe(year, month, day) {
  var lunar = fromSolar(year, month, day)
  var term = termOn(year, month, day)
  var fests = festivals(year, month, day, lunar)
  var label = "", kind = "day"
  if (fests.length > 0) { label = fests[0]; kind = "festival" }
  else if (term !== "") { label = term; kind = "term" }
  else if (lunar && lunar.day === 1) { label = lunar.monthName; kind = "month" }
  else if (lunar) label = lunar.dayName
  return {
    year: year, month: month, day: day,
    lunar: lunar,
    term: term,
    festivals: fests,
    dayCycle: dayCycleName(year, month, day),
    label: label,
    labelKind: kind
  }
}

function keyFor(year, month, day) {
  return year + "-" + month + "-" + day
}

// Six weeks of cells for a Gregorian month, starting on weekStart
// (0 = Sunday, 1 = Monday), so the grid keeps one height all year.
function monthGrid(year, month, weekStart, todayKey) {
  var firstN = dayNumber(year, month, 1)
  var firstWeekday = new Date(firstN * 86400000).getUTCDay()
  var start = firstN - (firstWeekday - weekStart + 7) % 7
  var weeks = []
  for (var w = 0; w < 6; w++) {
    var days = []
    for (var d = 0; d < 7; d++) {
      var n = start + w * 7 + d
      var date = dateOfDayNumber(n)
      var cell = describe(date.year, date.month, date.day)
      var weekday = new Date(n * 86400000).getUTCDay()
      cell.inMonth = date.month === month
      cell.weekend = weekday === 0 || weekday === 6
      cell.key = keyFor(date.year, date.month, date.day)
      cell.today = cell.key === todayKey
      days.push(cell)
    }
    weeks.push({ days: days })
  }
  return weeks
}

function stepMonth(year, month, delta) {
  var index = year * 12 + (month - 1) + delta
  return { year: Math.floor(index / 12), month: index % 12 + 1 }
}
