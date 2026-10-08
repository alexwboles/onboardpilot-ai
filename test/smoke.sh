#!/bin/bash
# OnboardPilot AI — smoke tests
set -u
cd "$(dirname "$0")/.." || exit 1

pass=0; fail=0
ok()  { pass=$((pass+1)); echo "PASS: $1"; }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }

# --- files exist (5) ---
for f in index.html css/style.css js/logic.js js/app.js README.md; do
  if [ -f "$f" ]; then ok "file exists: $f"; else bad "file exists: $f"; fi
done

# --- node syntax checks (2) ---
if node --check js/logic.js; then ok "node --check js/logic.js"; else bad "node --check js/logic.js"; fi
if node --check js/app.js; then ok "node --check js/app.js"; else bad "node --check js/app.js"; fi

LOGIC=/home/hatch/workspace/onboardpilot-ai/js/logic.js
run() { node -e "$1" 2>/dev/null; }

# --- logic assertions ---
if run "
const OP = require('$LOGIC');
const roles = Object.keys(OP.ROLE_TEMPLATES);
if (roles.length < 6) { console.error('fewer than 6 built-in roles'); process.exit(1); }
for (const r of roles) {
  const cl = OP.generateChecklist(r, {});
  for (const ph of OP.PHASES) {
    const n = cl.filter(t => t.phase === ph).length;
    if (n < 3) { console.error(r + ' phase ' + ph + ' has ' + n + ' tasks'); process.exit(1); }
  }
}
console.log('ok');
" | grep -q ok; then ok "all built-in roles generate 3 phases with >=3 tasks each"; else bad "all built-in roles generate 3 phases with >=3 tasks each"; fi

if run "
const OP = require('$LOGIC');
const cl = OP.generateChecklist('Retail Associate', {});
const docs = cl.filter(t => t.doc);
const need = ['ID', 'withholding', 'direct deposit', 'emergency contact'];
const missing = need.filter(k => !docs.some(t => t.title.toLowerCase().includes(k.split(' ')[0].toLowerCase())));
if (docs.length < 4 || missing.length) { console.error('docs missing: ' + missing); process.exit(1); }
const noNote = docs.filter(t => !t.guidance || !t.guidance.includes('Generic guidance only'));
if (noNote.length) { console.error('doc without guidance note'); process.exit(1); }
const nonDocs = cl.filter(t => !t.doc);
if (nonDocs.some(t => t.guidance)) { console.error('non-doc has guidance'); process.exit(1); }
if (!OP.GENERIC_NOTE.toLowerCase().includes('not legal') && !OP.GENERIC_NOTE.toLowerCase().includes('local')) process.exit(1);
console.log('ok');
" | grep -q ok; then ok "Day-1 doc items carry generic-guidance note"; else bad "Day-1 doc items carry generic-guidance note"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Test Hire', 'Barista', '2026-09-28', null);
const day1 = h.checklist.filter(t => t.phase === 'day1');
if (day1.length !== 6) { console.error('expected 6 day1 tasks, got ' + day1.length); process.exit(1); }
OP.setItemDone(st, h.id, day1[0].id, true);
OP.setItemDone(st, h.id, day1[1].id, true);
const pct = OP.progressFor(h, 'day1');
// 2 of 6 -> 33
if (pct !== Math.round(2/6*100)) { console.error('pct=' + pct); process.exit(1); }
// custom 1-of-4 check: build a synthetic hire
const fake = { checklist: [{phase:'day1',done:true},{phase:'day1',done:false},{phase:'day1',done:false},{phase:'day1',done:false}] };
if (OP.progressFor(fake, 'day1') !== 25) { console.error('1-of-4 != 25%'); process.exit(1); }
console.log('ok');
" | grep -q ok; then ok "progress % math (1 of 4 = 25%)"; else bad "progress % math (1 of 4 = 25%)"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const past = OP.addHire(st, 'Past Hire', 'Barista', '2026-01-05', null);
const future = OP.addHire(st, 'Future Hire', 'Barista', '2030-01-05', null);
if (!OP.isOverdue(past, '2026-09-28')) { console.error('past not overdue'); process.exit(1); }
if (OP.isOverdue(future, '2026-09-28')) { console.error('future flagged overdue'); process.exit(1); }
// complete all day1 items -> no longer overdue
for (const t of past.checklist.filter(t => t.phase === 'day1')) OP.setItemDone(st, past.id, t.id, true);
if (OP.isOverdue(past, '2026-09-28')) { console.error('still overdue after completion'); process.exit(1); }
console.log('ok');
" | grep -q ok; then ok "overdue Day-1 detection"; else bad "overdue Day-1 detection"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
OP.createCustomRole(st, 'Dog Walker', { day1: [{title:'Meet the pack'}], week1: [{title:'Learn routes'}], day30: [{title:'Solo walks'}] });
OP.addCustomTask(st, 'Dog Walker', 'day1', 'Get house keys', 'Tools', 'Manager');
const cl = OP.generateChecklist('Dog Walker', st.customRoles);
if (!cl || cl.filter(t => t.phase === 'day1').length !== 2) { console.error('custom role checklist wrong'); process.exit(1); }
if (!OP.allRoles(st).includes('Dog Walker')) { console.error('custom role missing from allRoles'); process.exit(1); }
console.log('ok');
" | grep -q ok; then ok "custom role creation"; else bad "custom role creation"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const b = OP.addBuddy(st, 'Maria Gomez', 'Senior Associate');
const h = OP.addHire(st, 'New Person', 'Barista', '2026-09-28', b.id);
if (OP.getBuddyName(st, h.id) !== 'Maria Gomez') { console.error('buddy name mismatch'); process.exit(1); }
const dash = OP.dashboard(st, '2026-09-28');
if (dash[0].buddy !== 'Maria Gomez') { console.error('dashboard buddy missing'); process.exit(1); }
console.log('ok');
" | grep -q ok; then ok "buddy assignment + dashboard summary"; else bad "buddy assignment + dashboard summary"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Jane Doe', 'Barista', '2026-09-28', null);
let r = OP.draftWelcomeMessage(st, h.id);
if (!r || r.source !== 'local' || !r.message.includes('Jane Doe') || !r.message.includes('Barista')) { console.error('local welcome bad'); process.exit(1); }
const b = OP.addBuddy(st, 'Sam', 'Lead');
OP.assignBuddy(st, h.id, b.id);
r = OP.draftWelcomeMessage(st, h.id);
if (!r.message.includes('Sam')) { console.error('buddy not in welcome'); process.exit(1); }
// empty-key openai path must fall back to local without network
OP.openaiWelcomeMessage(null, '', h, null).then(x => {
  if (x.source !== 'local') { console.error('empty key did not fall back'); process.exit(1); }
  console.log('ok');
}).catch(e => { console.error(e); process.exit(1); });
" | grep -q ok; then ok "welcome message template works without key"; else bad "welcome message template works without key"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const b = OP.addBuddy(st, 'Ann', 'Cook');
const h = OP.addHire(st, 'X', 'Line Cook', '2026-09-28', b.id);
const s2 = OP.deserialize(OP.serialize(st));
if (s2.hires.length !== 1 || s2.buddies.length !== 1 || s2.hires[0].checklist.length !== h.checklist.length) { console.error('round-trip mismatch'); process.exit(1); }
console.log('ok');
" | grep -q ok; then ok "serialize/deserialize round-trip"; else bad "serialize/deserialize round-trip"; fi

if run "
const OP = require('$LOGIC');
['daysToStart','startLabel','searchHires','sortHires','hiresToCSV','archiveHire','unarchiveHire','archivedHires'].forEach(f => {
  if (typeof OP[f] !== 'function') { console.error('missing export: ' + f); process.exit(1); }
});
const st = OP.blankState();
const h = OP.addHire(st, 'T', 'Barista', '2026-10-05', null);
if (OP.daysToStart(h, '2026-09-28') !== 7) { console.error('daysToStart wrong'); process.exit(1); }
if (OP.daysToStart(h, '2026-10-06') !== -1) { console.error('past daysToStart wrong'); process.exit(1); }
if (OP.startLabel(h, '2026-09-28') !== 'starts in 7 days') { console.error('startLabel wrong: ' + OP.startLabel(h, '2026-09-28')); process.exit(1); }
if (OP.daysToStart(OP.addHire(st, 'NoDate', 'Barista', '', null), '2026-09-28') !== null) { console.error('no-date should be null'); process.exit(1); }
console.log('ok');
" | grep -q ok; then ok "start-date countdown math"; else bad "start-date countdown math"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
OP.addHire(st, 'Zoe Park', 'Barista', '2026-09-28', null);
OP.addHire(st, 'Amy Chen', 'Line Cook', '2026-10-05', null);
const rows = OP.dashboard(st, '2026-09-28');
if (OP.searchHires(rows, 'zoe').length !== 1) { console.error('name search failed'); process.exit(1); }
if (OP.searchHires(rows, 'line cook').length !== 1) { console.error('role search failed'); process.exit(1); }
if (OP.searchHires(rows, '').length !== 2) { console.error('empty query should return all'); process.exit(1); }
const sorted = OP.sortHires(rows, 'name', 'asc');
if (sorted[0].name !== 'Amy Chen') { console.error('sort by name failed'); process.exit(1); }
const csv = OP.hiresToCSV(rows).split('\n');
if (csv[0] !== 'Name,Role,Start date,Buddy,Overall %,Day-1 overdue,Start countdown') { console.error('csv header: ' + csv[0]); process.exit(1); }
if (csv.length !== 3) { console.error('csv rows: ' + csv.length); process.exit(1); }
console.log('ok');
" | grep -q ok; then ok "dashboard search + sort + CSV export"; else bad "dashboard search + sort + CSV export"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Archie', 'Barista', '2026-09-28', null);
if (OP.dashboard(st, '2026-09-28').length !== 1) { console.error('should be 1'); process.exit(1); }
OP.archiveHire(st, h.id);
if (OP.dashboard(st, '2026-09-28').length !== 0) { console.error('archived hire still on dashboard'); process.exit(1); }
if (OP.archivedHires(st).length !== 1) { console.error('archived list wrong'); process.exit(1); }
OP.unarchiveHire(st, h.id);
if (OP.dashboard(st, '2026-09-28').length !== 1) { console.error('restore failed'); process.exit(1); }
console.log('ok');
" | grep -q ok; then ok "hire archive + restore"; else bad "hire archive + restore"; fi

echo ""
echo "smoke: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
