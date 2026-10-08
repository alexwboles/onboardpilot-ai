#!/bin/bash
# OnboardPilot AI — end-to-end flows (Node, no network)
set -u
cd "$(dirname "$0")/.." || exit 1

pass=0; fail=0
flow() {
  local name="$1"; shift
  if node -e "$1" 2>/dev/null | grep -q '^ok$'; then
    pass=$((pass+1)); echo "PASS: $name"
  else
    fail=$((fail+1)); echo "FAIL: $name"
  fi
}
LOGIC=/home/hatch/workspace/onboardpilot-ai/js/logic.js

# 1. Full hire lifecycle: create -> check items -> 100%
flow "hire lifecycle to 100%" "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Lena Wu', 'Barista', '2026-09-28', null);
if (OP.progressAll(h).overall !== 0) process.exit(1);
for (const t of h.checklist) OP.setItemDone(st, h.id, t.id, true);
const p = OP.progressAll(h);
if (p.overall !== 100 || p.day1 !== 100 || p.week1 !== 100 || p.day30 !== 100) process.exit(1);
console.log('ok');
"

# 2. Role switch regenerates checklist
flow "role switch regenerates checklist" "
const OP = require('$LOGIC');
const st = OP.blankState();
const h1 = OP.addHire(st, 'A', 'Barista', '2026-09-28', null);
OP.setItemDone(st, h1.id, h1.checklist[0].id, true);
OP.removeHire(st, h1.id);
const h2 = OP.addHire(st, 'A', 'Line Cook', '2026-09-28', null);
if (h2.role !== 'Line Cook') process.exit(1);
if (h2.checklist.some(t => t.done)) process.exit(1);
if (h2.checklist.length === h1.checklist.length && JSON.stringify(h2.checklist.map(t=>t.title)) === JSON.stringify(h1.checklist.map(t=>t.title))) process.exit(1);
console.log('ok');
"

# 3. Overdue detection with past start date
flow "overdue detection with past start date" "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Old Hire', 'Front Desk', '2026-08-01', null);
const dash = OP.dashboard(st, '2026-09-28');
const row = dash.find(r => r.id === h.id);
if (!row.overdue) process.exit(1);
for (const t of h.checklist.filter(t => t.phase === 'day1')) OP.setItemDone(st, h.id, t.id, true);
if (OP.dashboard(st, '2026-09-28').find(r => r.id === h.id).overdue) process.exit(1);
console.log('ok');
"

# 4. Custom role flow
flow "custom role flow" "
const OP = require('$LOGIC');
const st = OP.blankState();
OP.createCustomRole(st, 'Bike Mechanic', { day1: [{title:'Shop tour', category:'Culture', owner:'Buddy'}] });
OP.addCustomTask(st, 'Bike Mechanic', 'week1', 'Fix first flat', 'Training', 'Buddy');
OP.addCustomTask(st, 'Bike Mechanic', 'day30', 'Solo service', 'Training', 'New hire');
const h = OP.addHire(st, 'Rico', 'Bike Mechanic', '2026-09-28', null);
const counts = [OP.countsFor(h,'day1').total, OP.countsFor(h,'week1').total, OP.countsFor(h,'day30').total];
if (counts.join(',') !== '1,1,1') { console.error(counts); process.exit(1); }
OP.setItemDone(st, h.id, h.checklist[0].id, true);
if (OP.progressFor(h,'day1') !== 100) process.exit(1);
console.log('ok');
"

# 5. Buddy assign + dashboard summary
flow "buddy assign + dashboard summary" "
const OP = require('$LOGIC');
const st = OP.blankState();
const b1 = OP.addBuddy(st, 'Chris P.', 'Lead Barista');
const b2 = OP.addBuddy(st, 'Dana L.', 'Shift Lead');
const h = OP.addHire(st, 'Newbie', 'Barista', '2026-09-28', null);
OP.assignBuddy(st, h.id, b1.id);
let dash = OP.dashboard(st, '2026-09-28');
if (dash.find(r => r.id === h.id).buddy !== 'Chris P.') process.exit(1);
OP.assignBuddy(st, h.id, b2.id);
dash = OP.dashboard(st, '2026-09-28');
if (dash.find(r => r.id === h.id).buddy !== 'Dana L.') process.exit(1);
OP.removeBuddy(st, b2.id);
if (OP.getBuddyName(st, h.id) !== null) process.exit(1);
console.log('ok');
"

# 6. Persistence round-trip via serialize/deserialize
flow "persistence round-trip" "
const OP = require('$LOGIC');
const st = OP.blankState();
const b = OP.addBuddy(st, 'Mentor Max', 'Manager');
const h = OP.addHire(st, 'Persist Pat', 'Office Admin', '2026-09-28', b.id);
OP.setItemDone(st, h.id, h.checklist[3].id, true);
OP.createCustomRole(st, 'Custom', { day1: [], week1: [], day30: [] });
st.settings.openaiKey = 'sk-test';
const st2 = OP.deserialize(OP.serialize(st));
const h2 = OP.getHire(st2, h.id);
if (!h2 || h2.checklist[3].done !== true) process.exit(1);
if (OP.getBuddyName(st2, h.id) !== 'Mentor Max') process.exit(1);
if (!st2.customRoles['Custom'] || st2.settings.openaiKey !== 'sk-test') process.exit(1);
console.log('ok');
"

# 7. Start-date countdown labels
flow "start-date countdown labels" "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Countdown Cal', 'Barista', '2026-10-10', null);
if (OP.startLabel(h, '2026-09-28') !== 'starts in 12 days') process.exit(1);
if (OP.startLabel(h, '2026-10-10') !== 'starts today') process.exit(1);
if (OP.startLabel(h, '2026-10-11') !== 'started yesterday') process.exit(1);
if (OP.startLabel(h, '2026-10-20') !== 'started 10 days ago') process.exit(1);
const dash = OP.dashboard(st, '2026-09-28');
if (dash.find(r => r.id === h.id).startIn !== 12) process.exit(1);
console.log('ok');
"

# 8. Search + sort dashboard
flow "dashboard search and sort" "
const OP = require('$LOGIC');
const st = OP.blankState();
OP.addHire(st, 'Zoe Park', 'Barista', '2026-09-28', null);
const h2 = OP.addHire(st, 'Amy Chen', 'Line Cook', '2026-10-05', null);
const rows = OP.dashboard(st, '2026-09-28');
if (OP.searchHires(rows, 'CHEN').length !== 1) process.exit(1);
const byStart = OP.sortHires(rows, 'startDate', 'asc');
if (byStart[0].name !== 'Zoe Park') process.exit(1);
// finish all of Zoe's tasks -> she should sort first by progress desc
rows.forEach(r => { const h = OP.getHire(st, r.id); h.checklist.forEach(t => OP.setItemDone(st, h.id, t.id, true)); });
const fresh = OP.dashboard(st, '2026-09-28');
const byProg = OP.sortHires(fresh, 'progress', 'desc');
if (byProg[0].progress.overall !== 100) process.exit(1);
console.log('ok');
"

# 9. CSV export content
flow "hires CSV export content" "
const OP = require('$LOGIC');
const st = OP.blankState();
const b = OP.addBuddy(st, 'Mentor', 'Lead');
OP.addHire(st, 'Csv Sam', 'Barista', '2026-09-28', b.id);
const rows = OP.dashboard(st, '2026-09-28');
const csv = OP.hiresToCSV(rows);
if (csv.split('\n').length !== 2) process.exit(1);
if (!csv.includes('Csv Sam') || !csv.includes('Mentor') || !csv.includes('Barista')) process.exit(1);
console.log('ok');
"

# 10. Archive lifecycle
flow "archive lifecycle" "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Gone Girl', 'Barista', '2026-09-28', null);
OP.archiveHire(st, h.id);
if (OP.dashboard(st, '2026-09-28').some(r => r.id === h.id)) process.exit(1);
if (!OP.archivedHires(st).some(x => x.id === h.id)) process.exit(1);
// serialize round-trips the archived flag
const st2 = OP.deserialize(OP.serialize(st));
if (!OP.archivedHires(st2).some(x => x.id === h.id)) process.exit(1);
OP.unarchiveHire(st, h.id);
if (!OP.dashboard(st, '2026-09-28').some(r => r.id === h.id)) process.exit(1);
console.log('ok');
"

echo ""
echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
