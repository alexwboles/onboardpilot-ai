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

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Nora', 'Barista', '2026-09-28', null);
// notes: add, cap length, list, remove
const n1 = OP.addHireNote(st, h.id, '  Great energy in the interview.  ');
if (!n1 || !n1.id || !n1.at) { console.error('note shape'); process.exit(1); }
if (OP.hireNotes(st, h.id).length !== 1) { console.error('note list'); process.exit(1); }
if (OP.hireNotes(st, h.id)[0].text !== 'Great energy in the interview.') { console.error('note trim'); process.exit(1); }
if (OP.addHireNote(st, h.id, '   ') !== null) { console.error('blank note should be null'); process.exit(1); }
if (OP.addHireNote(st, 'nope', 'x') !== null) { console.error('note on missing hire should be null'); process.exit(1); }
const long = OP.addHireNote(st, h.id, new Array(2500).join('x'));
if (long.text.length !== 2000) { console.error('note not capped: ' + long.text.length); process.exit(1); }
if (!OP.removeHireNote(st, h.id, n1.id)) { console.error('remove note failed'); process.exit(1); }
if (OP.hireNotes(st, h.id).length !== 1) { console.error('note list after remove'); process.exit(1); }
console.log('ok');
" | grep -q ok; then ok "manager notes journal"; else bad "manager notes journal"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Nora', 'Barista', '2026-09-28', null);
// phase due dates anchored on the start date
if (OP.phaseDueDate(h, 'day1') !== '2026-09-29') { console.error('day1 due: ' + OP.phaseDueDate(h, 'day1')); process.exit(1); }
if (OP.phaseDueDate(h, 'week1') !== '2026-10-05') { console.error('week1 due'); process.exit(1); }
if (OP.phaseDueDate(h, 'day30') !== '2026-10-28') { console.error('day30 due'); process.exit(1); }
if (OP.phaseDueDate({ startDate: '' }, 'day1') !== null) { console.error('no-date due should be null'); process.exit(1); }
// milestone status: pending -> overdue -> done
let ms = OP.milestoneStatus(h, '2026-09-27');
if (ms[0].state !== 'pending' || ms[0].daysLeft !== 2) { console.error('pending ms: ' + JSON.stringify(ms[0])); process.exit(1); }
ms = OP.milestoneStatus(h, '2026-10-01');
if (ms[0].state !== 'overdue' || ms[0].daysLeft !== -2) { console.error('overdue ms: ' + JSON.stringify(ms[0])); process.exit(1); }
if (OP.milestoneLabel(ms[0]) !== 'Day 1 overdue by 2 days') { console.error('label: ' + OP.milestoneLabel(ms[0])); process.exit(1); }
if (OP.milestoneLabel({ label: 'Week 1', daysLeft: 1, dueDate: 'x' }) !== 'Week 1 due tomorrow') { console.error('tomorrow label'); process.exit(1); }
if (OP.milestoneLabel({ label: 'Day 30', daysLeft: 0, dueDate: 'x' }) !== 'Day 30 due today') { console.error('today label'); process.exit(1); }
// dashboard rows carry the next incomplete milestone
const rows = OP.dashboard(st, '2026-09-27');
if (!rows[0].nextMilestone || rows[0].nextMilestone.phase !== 'day1') { console.error('dash milestone'); process.exit(1); }
// completing all day-1 items advances the milestone to week 1
h.checklist.filter(t => t.phase === 'day1').forEach(t => OP.setItemDone(st, h.id, t.id, true));
const rows2 = OP.dashboard(st, '2026-09-27');
if (!rows2[0].nextMilestone || rows2[0].nextMilestone.phase !== 'week1') { console.error('milestone advance'); process.exit(1); }
// upcomingMilestones across hires, soonest first, archived skipped
const h2 = OP.addHire(st, 'Early Bird', 'Barista', '2026-09-20', null);
OP.archiveHire(st, h2.id);
const h3 = OP.addHire(st, 'Later', 'Barista', '2026-10-20', null);
const up = OP.upcomingMilestones(st, '2026-09-27');
if (up.length !== 2) { console.error('upcoming count: ' + up.length); process.exit(1); }
if (up[0].hireName !== 'Nora' || up[1].hireName !== 'Later') { console.error('upcoming order'); process.exit(1); }
console.log('ok');
" | grep -q ok; then ok "phase milestone due dates"; else bad "phase milestone due dates"; fi

if grep -q 'printHireBtn' js/app.js && grep -q 'print-hire' css/style.css && grep -q 'notes-sect' js/app.js && grep -q 'milestoneLabel' js/app.js; then ok "hire print + notes + milestone UI wired"; else bad "hire print + notes + milestone UI wired"; fi

# --- second sweep: owner reassignment, buddy nudges, feedback pulse ---
if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Owner Test', 'Barista', '2026-09-28', null);
const t = h.checklist[0];
if (OP.setItemOwner(st, h.id, t.id, 'Nope')) process.exit(1);
if (!OP.setItemOwner(st, h.id, t.id, 'New hire')) process.exit(1);
if (t.owner !== 'New hire') process.exit(1);
if (OP.setItemOwner(st, 'bogus', t.id, 'Buddy')) process.exit(1);
if (OP.setItemOwner(st, h.id, 'bogus', 'Buddy')) process.exit(1);
console.log('ok');
" | grep -q ok; then ok "setItemOwner validates owner + ids"; else bad "setItemOwner validates owner + ids"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const b = OP.addBuddy(st, 'Sam Mentor', 'Lead');
const h = OP.addHire(st, 'Nudge Me', 'Barista', '2026-09-01', b.id);
const nudges = OP.buddyCheckins(st, '2026-09-15');
if (nudges.length !== 1) { console.error('expected 1 nudge, got ' + nudges.length); process.exit(1); }
const n = nudges[0];
if (!n.text.includes('Sam Mentor') || !n.text.includes('Nudge Me')) process.exit(1);
if (n.openCount < 1) process.exit(1);
// completing all buddy tasks clears the nudge
h.checklist.filter(t => t.owner === 'Buddy').forEach(t => OP.setItemDone(st, h.id, t.id, true));
if (OP.buddyCheckins(st, '2026-09-15').length) process.exit(1);
console.log('ok');
" | grep -q ok; then ok "buddyCheckins flags overdue buddy tasks"; else bad "buddyCheckins flags overdue buddy tasks"; fi

if run "
const OP = require('$LOGIC');
const st = OP.blankState();
const h = OP.addHire(st, 'Pulse', 'Barista', '2026-09-28', null);
if (!OP.addHirePulse(st, h.id, 4, 'Settling in well')) process.exit(1);
if (OP.addHirePulse(st, h.id, 6, 'x')) process.exit(1);
if (OP.addHirePulse(st, h.id, 0, 'x')) process.exit(1);
if (!OP.addHirePulse(st, h.id, 5, '')) process.exit(1);
const ps = OP.hirePulses(st, h.id);
if (ps.length !== 2 || OP.pulseAverage(ps) !== 4.5) process.exit(1);
// pulses survive a serialize round-trip
const st2 = OP.deserialize(OP.serialize(st));
if (OP.hirePulses(st2, h.id).length !== 2) process.exit(1);
console.log('ok');
" | grep -q ok; then ok "feedback pulse add/avg/persist"; else bad "feedback pulse add/avg/persist"; fi

if grep -q 'data-copynudge' js/app.js && grep -q 'owner-select' js/app.js && grep -q 'pulseScore' js/app.js && grep -q 'addPulseBtn' js/app.js; then ok "nudge + owner + pulse UI wired"; else bad "nudge + owner + pulse UI wired"; fi

if grep -q 'class="shell"' index.html && grep -q 'local-pill' index.html; then ok "index.html uses sidebar shell"; else bad "index.html missing shell"; fi

if grep -q 'ring-fill' js/app.js && grep -q 'due-chip' js/app.js && grep -q 'taskDue' js/app.js; then ok "app.js wires progress ring + due chips"; else bad "app.js missing redesign wiring"; fi

if ! grep -E 'border-radius:[[:space:]]*[1-9]' css/style.css | grep -qv '50%'; then ok "no rounded edges in CSS"; else bad "rounded edges found in CSS"; fi

node -e "
var OP = require('./js/logic.js');
['taskDue','taskOverdue','overdueTasks'].forEach(function(f){ if(typeof OP[f]!=='function') throw new Error('missing '+f); });
var st = OP.blankState();
var h = OP.addHire(st, 'Testy McTest', 'Retail Associate', '2026-01-05', null);
if (!h) throw new Error('addHire failed');
var t = h.checklist.find(function(x){ return x.phase === 'day1'; });
if (OP.taskDue(h, t) !== '2026-01-06') throw new Error('day1 due should be start+1, got ' + OP.taskDue(h, t));
var t30 = h.checklist.find(function(x){ return x.phase === 'day30'; });
if (OP.taskDue(h, t30) !== '2026-02-04') throw new Error('day30 due should be start+30, got ' + OP.taskDue(h, t30));
if (!OP.taskOverdue(h, t, '2026-02-01')) throw new Error('day1 task should be overdue on 2026-02-01');
if (OP.taskOverdue(h, t30, '2026-02-01')) throw new Error('day30 task should NOT be overdue on 2026-02-01');
var od = OP.overdueTasks(h, '2026-02-01');
if (!od.length) throw new Error('overdueTasks empty');
var dash = OP.dashboard(st, '2026-02-01').find(function(r){ return r.id === h.id; });
if (!dash || dash.overdueCount !== od.length) throw new Error('dashboard overdueCount mismatch');
console.log('ok');
" | grep -q ok; if [ $? -eq 0 ]; then ok "per-task due dates + overdue detection work"; else bad "taskDue/taskOverdue/overdueTasks failed"; fi

echo ""
echo "smoke: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
