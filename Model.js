function pad2(value) {
  var n = parseInt(value, 10) || 0
  return n < 10 ? "0" + n : String(n)
}

function dateKey(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

var TRADITIONS = ["slavic", "greek"]
var CALENDARS = ["julian", "gregorian"]

function normalizeTradition(value) {
  return TRADITIONS.indexOf(value) >= 0 ? value : "slavic"
}

function normalizeCalendar(value) {
  return CALENDARS.indexOf(value) >= 0 ? value : "gregorian"
}

function defaultSettings() {
  return { tradition: "slavic", calendar: "gregorian" }
}

function parseSettings(raw) {
  try {
    var value = JSON.parse(String(raw || ""))
    return {
      tradition: normalizeTradition(value && value.tradition),
      calendar: normalizeCalendar(value && value.calendar)
    }
  } catch (e) {
    return defaultSettings()
  }
}

// orthocal.info's {year}/{month}/{day} path segment is a date *in the
// requested calendar*, not always the Gregorian civil date, so a Julian
// request needs the civil date converted to its Julian-calendar equivalent
// (currently 13 days behind) before it's put in the URL.
function gregorianToJDN(year, month, day) {
  var a = Math.floor((14 - month) / 12)
  var y = year + 4800 - a
  var m = month + 12 * a - 3
  return day + Math.floor((153 * m + 2) / 5) + 365 * y
    + Math.floor(y / 4) - Math.floor(y / 100) + Math.floor(y / 400) - 32045
}

function jdnToJulianDate(jdn) {
  var b = jdn + 32082
  var c = Math.floor((4 * b + 3) / 1461)
  var d = b - Math.floor(1461 * c / 4)
  var e = Math.floor((5 * d + 2) / 153)
  var day = d - Math.floor((153 * e + 2) / 5) + 1
  var month = e + 3 - 12 * Math.floor(e / 10)
  var year = c - 4800 + Math.floor(e / 10)
  return { year: year, month: month, day: day }
}

function julianDateFor(date) {
  return jdnToJulianDate(gregorianToJDN(date.getFullYear(), date.getMonth() + 1, date.getDate()))
}

function calendarDateFor(date, calendar) {
  return normalizeCalendar(calendar) === "julian"
    ? julianDateFor(date)
    : { year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate() }
}

// The {year}/{month}/{day} path segment is always the civil (Gregorian)
// date to look up — "cal" only controls which calendar's date the response
// reports back (see reportMatchesDate / calendarDateFor below).
function apiUrl(date, tradition, calendar) {
  return "https://orthocal.info/api/"
    + normalizeTradition(tradition) + "/" + normalizeCalendar(calendar) + "/"
    + date.getFullYear() + "/" + (date.getMonth() + 1) + "/" + date.getDate()
    + "/?translation=lxx2012-web"
}

function orthocalUrl(date, tradition, calendar) {
  return "https://orthocal.info/readings/"
    + normalizeTradition(tradition) + "/" + normalizeCalendar(calendar) + "/lxx2012-web/"
    + date.getFullYear() + "/" + (date.getMonth() + 1) + "/" + date.getDate() + "/"
}

function ocaReadingsUrl(date) {
  return "https://www.oca.org/readings/daily/" + date.getFullYear() + "/"
    + pad2(date.getMonth() + 1) + "/" + pad2(date.getDate())
}

function ocaSaintsUrl(date) {
  return "https://www.oca.org/saints/lives/" + date.getFullYear() + "/"
    + pad2(date.getMonth() + 1) + "/" + pad2(date.getDate())
}

function parseReport(raw) {
  try {
    var value = JSON.parse(String(raw || ""))
    return value && typeof value === "object" ? value : null
  } catch (e) {
    return null
  }
}

function reportMatchesDate(report, date, calendar) {
  var expected = calendarDateFor(date, calendar)
  return !!report
    && Number(report.year) === expected.year
    && Number(report.month) === expected.month
    && Number(report.day) === expected.day
}

function reportMatchesSettings(report, tradition, calendar) {
  return !!report
    && report.tradition === normalizeTradition(tradition)
    && report.calendar === normalizeCalendar(calendar)
}

function tagReport(report, tradition, calendar) {
  if (!report) return report
  var tagged = {}
  Object.keys(report).forEach(function(key) { tagged[key] = report[key] })
  tagged.tradition = normalizeTradition(tradition)
  tagged.calendar = normalizeCalendar(calendar)
  return tagged
}

function array(value) {
  return value && value.length ? value : []
}

function displayTitle(report) {
  if (!report) return "Orthodox Daily"
  return String(report.summary_title || array(report.titles)[0] || "Orthodox Daily")
}

function periodText(report) {
  if (!report) return ""
  var titles = array(report.titles)
  return titles.length ? titles.join(" · ") : String(report.feast_level_description || "")
}

function fastingStatus(report) {
  return report ? String(report.fast_level_desc || "No fast") : "Fasting rule unavailable"
}

function fastingTagline(report) {
  if (!report) return ""
  var status = fastingStatus(report)
  var exception = String(report.fast_exception_desc || "")
  return exception && exception.toLowerCase() !== status.toLowerCase() ? exception : ""
}

function fastingTitle(report) {
  var status = fastingStatus(report)
  var tagline = fastingTagline(report)
  return tagline ? status + " · " + tagline : status
}

function fastingDetail(report) {
  if (!report) return ""
  var abstentions = array(report.fast_abstentions)
  if (!abstentions.length) return "No food abstentions listed for today."
  var pretty = abstentions.map(function(item) {
    var text = String(item || "")
    return text.charAt(0).toUpperCase() + text.slice(1)
  })
  return "Abstain from: " + pretty.join(", ") + ". Follow your priest’s pastoral guidance."
}

function fastingRuleIcon(report) {
  if (!report) return "󰌪"

  var level = String(report.fast_level_desc || "").toLowerCase()
  var rule = String(report.fast_exception_desc || "").toLowerCase()
  if (Number(report.fast_level) === 0 || level === "no fast" || rule.indexOf("fast free") >= 0) return "󰒣"
  if (rule.indexOf("meat fast") >= 0) return "󱑨"
  if (rule.indexOf("caviar") >= 0) return ""
  if (rule.indexOf("fish") >= 0) return ""
  if (rule.indexOf("wine and oil") >= 0 || rule.indexOf("wine, oil") >= 0) return ""
  if (rule.indexOf("wine") >= 0) return "󰡶"
  return "󰌪"
}

function specialFastBanner(report) {
  if (!report) return { visible: false, title: "", icon: "", iconFontFamily: "" }

  var summary = String(report.summary_title || "").toLowerCase()
  var feastNames = array(report.feasts).join(" ").toLowerCase()
  var isHolyPascha = summary === "holy pascha"
    || feastNames.indexOf("the resurrection of our lord and savior jesus christ") >= 0
  if (isHolyPascha) return {
    visible: true,
    title: "Holy Pascha",
    icon: "\u2626\uFE0E",
    iconFontFamily: "Noto Sans Symbols"
  }

  switch (Number(report.fast_level)) {
    case 2: return { visible: true, title: "Lenten Fast", icon: "\u2626\uFE0E", iconFontFamily: "Noto Sans Symbols" }
    case 3: return { visible: true, title: "Apostles Fast", icon: "", iconFontFamily: "" }
    case 4: return { visible: true, title: "Dormition Fast", icon: "󱌔", iconFontFamily: "" }
    case 5: return { visible: true, title: "Nativity Fast", icon: "", iconFontFamily: "" }
    default: return { visible: false, title: "", icon: "", iconFontFamily: "" }
  }
}

function passageText(reading) {
  if (!reading) return ""
  var verses = array(reading.passage)
  return verses.map(function(verse) {
    return verse.chapter + ":" + verse.verse + "  " + String(verse.content || "")
  }).join("\n\n")
}

function readingSubtitle(reading) {
  if (!reading) return ""
  var parts = []
  if (reading.source) parts.push(String(reading.source))
  if (reading.description) parts.push(String(reading.description))
  return parts.join(" · ")
}

function isGospelReading(reading) {
  if (!reading) return false
  var metadata = [reading.source, reading.book, reading.description].join(" ").toLowerCase()
  if (metadata.indexOf("gospel") >= 0) return true
  return /^(matthew|mark|luke|john)\b/i.test(String(reading.display || ""))
}

function gospelsFirst(readings) {
  return array(readings).map(function(reading, index) {
    return { reading: reading, index: index, rank: isGospelReading(reading) ? 0 : 1 }
  }).sort(function(a, b) {
    return a.rank === b.rank ? a.index - b.index : a.rank - b.rank
  }).map(function(entry) { return entry.reading })
}

function decodeEntities(text) {
  return String(text || "")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&#(\d+);/g, function(_, code) { return String.fromCharCode(parseInt(code, 10)) })
}

function storyText(story) {
  var html = story && story.story ? String(story.story) : ""
  return decodeEntities(html
    .replace(/<\s*br\s*\/?\s*>/gi, "\n")
    .replace(/<\s*\/p\s*>/gi, "\n\n")
    .replace(/<\s*\/li\s*>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/^\s+|\s+$/g, ""))
}

function scriptureClipboardText(readings, dateLabel) {
  var header = "Scripture Readings — " + String(dateLabel || "")
  var body = array(readings).map(function(reading) {
    var title = String(reading.display || "Scripture")
    var passage = passageText(reading)
    return passage ? title + "\n\n" + passage : title
  }).join("\n\n")
  return body ? header + "\n\n" + body : header
}

function storiesClipboardText(stories, dateLabel) {
  var header = "Saints & Commemorations — " + String(dateLabel || "")
  var body = array(stories).map(function(story) {
    var title = String(story.title || "Life of a saint")
    var text = storyText(story)
    return text ? title + "\n\n" + text : title
  }).join("\n\n")
  return body ? header + "\n\n" + body : header
}

function prayerForDay(history, key) {
  var value = history && history[key] ? history[key] : null
  return {
    morning: !!(value && value.morning === true),
    evening: !!(value && value.evening === true),
    dayOnly: !!(value && value.dayOnly === true)
  }
}

function parsePrayerHistory(raw, currentKey) {
  try {
    var value = JSON.parse(String(raw || ""))
    var days = {}
    if (value && value.version === 2 && value.days && typeof value.days === "object") {
      Object.keys(value.days).forEach(function(key) {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(key)) return
        days[key] = prayerForDay(value.days, key)
      })
      return days
    }

    // Migrate the original one-day checklist without dropping its state.
    if (value && /^\d{4}-\d{2}-\d{2}$/.test(String(value.date || ""))) {
      days[value.date] = {
        morning: value.morning === true,
        evening: value.evening === true,
        dayOnly: false
      }
    }
    return days
  } catch (e) {
    return {}
  }
}

function prayerWeek(date, history) {
  var current = new Date(date.getFullYear(), date.getMonth(), date.getDate())
  var sunday = new Date(current.getFullYear(), current.getMonth(), current.getDate())
  sunday.setDate(sunday.getDate() - sunday.getDay())
  var labels = ["S", "M", "T", "W", "T", "F", "S"]
  var days = []

  for (var index = 0; index < 7; index++) {
    var day = new Date(sunday.getFullYear(), sunday.getMonth(), sunday.getDate() + index)
    var key = dateKey(day)
    var prayers = prayerForDay(history, key)
    var future = day.getTime() > current.getTime()
    days.push({
      key: key,
      label: labels[index],
      displayDate: day.toLocaleDateString(undefined, { month: "short", day: "numeric" }),
      morning: prayers.morning,
      evening: prayers.evening,
      complete: !future && (prayers.dayOnly || prayers.morning || prayers.evening),
      today: key === dateKey(current),
      future: future
    })
  }
  return days
}

// Kept for callers that only need the current day's legacy-shaped result.
function parseChecklist(raw, key) {
  return prayerForDay(parsePrayerHistory(raw, key), key)
}

if (typeof module !== "undefined") {
  module.exports = {
    pad2: pad2,
    dateKey: dateKey,
    apiUrl: apiUrl,
    orthocalUrl: orthocalUrl,
    ocaReadingsUrl: ocaReadingsUrl,
    ocaSaintsUrl: ocaSaintsUrl,
    parseReport: parseReport,
    reportMatchesDate: reportMatchesDate,
    reportMatchesSettings: reportMatchesSettings,
    tagReport: tagReport,
    normalizeTradition: normalizeTradition,
    normalizeCalendar: normalizeCalendar,
    defaultSettings: defaultSettings,
    parseSettings: parseSettings,
    julianDateFor: julianDateFor,
    calendarDateFor: calendarDateFor,
    array: array,
    displayTitle: displayTitle,
    periodText: periodText,
    fastingStatus: fastingStatus,
    fastingTagline: fastingTagline,
    fastingTitle: fastingTitle,
    fastingDetail: fastingDetail,
    fastingRuleIcon: fastingRuleIcon,
    specialFastBanner: specialFastBanner,
    passageText: passageText,
    readingSubtitle: readingSubtitle,
    isGospelReading: isGospelReading,
    gospelsFirst: gospelsFirst,
    storyText: storyText,
    scriptureClipboardText: scriptureClipboardText,
    storiesClipboardText: storiesClipboardText,
    prayerForDay: prayerForDay,
    parsePrayerHistory: parsePrayerHistory,
    prayerWeek: prayerWeek,
    parseChecklist: parseChecklist
  }
}
