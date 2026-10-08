// OnboardPilot AI — pure logic (no DOM). Works in browser (window.OnboardPilot) and Node (module.exports).
(function (g) {
  "use strict";

  const STORAGE_KEY = "onboardpilot_v1";
  const PHASES = ["day1", "week1", "day30"];
  const PHASE_LABELS = { day1: "Day 1", week1: "Week 1", day30: "Day 30" };
  const CATEGORIES = ["Paperwork", "Training", "Culture", "Tools"];
  const GENERIC_NOTE = "Generic guidance only — not legal or tax advice. Check your local rules.";

  // ---- Built-in role templates ------------------------------------------------
  const ROLE_TEMPLATES = {
    "Retail Associate": {
      day1: [
        { title: "Provide a government-issued photo ID", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete tax withholding form (W-4 in the US) — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete direct deposit / payroll enrollment form — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Submit emergency contact details", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Tour the sales floor, stockroom, and break area", category: "Culture", owner: "Buddy" },
        { title: "Get POS login and name badge", category: "Tools", owner: "Manager" }
      ],
      week1: [
        { title: "Shadow a senior associate on two full shifts", category: "Training", owner: "Buddy" },
        { title: "Complete register / POS training module", category: "Training", owner: "Manager" },
        { title: "Learn opening and closing procedures", category: "Training", owner: "Manager" },
        { title: "Review loss-prevention and safety policy", category: "Training", owner: "Manager" },
        { title: "Join the team lunch / shift huddle", category: "Culture", owner: "Buddy" }
      ],
      day30: [
        { title: "30-day check-in: review sales and service goals", category: "Culture", owner: "Manager" },
        { title: "Complete product-knowledge quiz", category: "Training", owner: "New hire" },
        { title: "Practice opening or closing independently", category: "Training", owner: "New hire" },
        { title: "Share first-month feedback with manager", category: "Culture", owner: "New hire" }
      ]
    },
    "Line Cook": {
      day1: [
        { title: "Provide a government-issued photo ID", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete tax withholding form (W-4 in the US) — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete direct deposit / payroll enrollment form — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Submit emergency contact details", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Food-handler / safety certification review", category: "Training", owner: "Manager" },
        { title: "Tour kitchen stations, storage, and exits", category: "Culture", owner: "Buddy" }
      ],
      week1: [
        { title: "Learn station setup and mise en place standards", category: "Training", owner: "Buddy" },
        { title: "Review allergy and cross-contamination protocols", category: "Training", owner: "Manager" },
        { title: "Practice the top 10 menu dishes with the sous chef", category: "Training", owner: "Buddy" },
        { title: "Learn ordering and inventory basics", category: "Training", owner: "Manager" }
      ],
      day30: [
        { title: "Run a station solo through one full service", category: "Training", owner: "New hire" },
        { title: "30-day performance review with head chef", category: "Culture", owner: "Manager" },
        { title: "Suggest one menu or process improvement", category: "Culture", owner: "New hire" }
      ]
    },
    "Barista": {
      day1: [
        { title: "Provide a government-issued photo ID", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete tax withholding form (W-4 in the US) — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete direct deposit / payroll enrollment form — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Submit emergency contact details", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Tour the café, storage, and back-of-house", category: "Culture", owner: "Buddy" },
        { title: "Get register login and apron/name tag", category: "Tools", owner: "Manager" }
      ],
      week1: [
        { title: "Espresso basics: grind, dose, tamp, extract", category: "Training", owner: "Buddy" },
        { title: "Milk steaming and latte art fundamentals", category: "Training", owner: "Buddy" },
        { title: "Memorize the core drink menu", category: "Training", owner: "New hire" },
        { title: "Shadow peak morning rush with a senior barista", category: "Training", owner: "Buddy" }
      ],
      day30: [
        { title: "Work the bar solo during a full shift", category: "Training", owner: "New hire" },
        { title: "30-day check-in with café manager", category: "Culture", owner: "Manager" },
        { title: "Learn seasonal menu items", category: "Training", owner: "New hire" }
      ]
    },
    "Front Desk": {
      day1: [
        { title: "Provide a government-issued photo ID", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete tax withholding form (W-4 in the US) — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete direct deposit / payroll enrollment form — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Submit emergency contact details", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Tour the property and front-office area", category: "Culture", owner: "Buddy" },
        { title: "Get front-desk system login and key access", category: "Tools", owner: "Manager" }
      ],
      week1: [
        { title: "Check-in / check-out walkthrough with senior staff", category: "Training", owner: "Buddy" },
        { title: "Phone etiquette and reservation system training", category: "Training", owner: "Manager" },
        { title: "Review guest-complaint and escalation process", category: "Training", owner: "Manager" },
        { title: "Shadow a full front-desk shift", category: "Training", owner: "Buddy" }
      ],
      day30: [
        { title: "Handle a full shift independently", category: "Training", owner: "New hire" },
        { title: "30-day review with front-office manager", category: "Culture", owner: "Manager" },
        { title: "Complete upsell and guest-loyalty training", category: "Training", owner: "New hire" }
      ]
    },
    "Warehouse Associate": {
      day1: [
        { title: "Provide a government-issued photo ID", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete tax withholding form (W-4 in the US) — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete direct deposit / payroll enrollment form — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Submit emergency contact details", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Safety walkthrough: exits, PPE, hazard zones", category: "Training", owner: "Manager" },
        { title: "Get badge, locker, and scanner assignment", category: "Tools", owner: "Manager" }
      ],
      week1: [
        { title: "Forklift / equipment certification (if required)", category: "Training", owner: "Manager" },
        { title: "Picking, packing, and labeling procedures", category: "Training", owner: "Buddy" },
        { title: "Inventory scanner and WMS basics", category: "Training", owner: "Buddy" },
        { title: "Shadow a full shift with a lead associate", category: "Training", owner: "Buddy" }
      ],
      day30: [
        { title: "Meet productivity targets for one full week", category: "Training", owner: "New hire" },
        { title: "30-day safety and performance review", category: "Culture", owner: "Manager" },
        { title: "Cross-train on a second warehouse zone", category: "Training", owner: "Buddy" }
      ]
    },
    "Office Admin": {
      day1: [
        { title: "Provide a government-issued photo ID", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete tax withholding form (W-4 in the US) — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Complete direct deposit / payroll enrollment form — " + GENERIC_NOTE, category: "Paperwork", owner: "New hire", doc: true },
        { title: "Submit emergency contact details", category: "Paperwork", owner: "New hire", doc: true },
        { title: "Office tour and workspace setup", category: "Culture", owner: "Buddy" },
        { title: "Get email, calendar, and systems access", category: "Tools", owner: "Manager" }
      ],
      week1: [
        { title: "Learn filing, scheduling, and supply ordering", category: "Training", owner: "Buddy" },
        { title: "Review company handbook and PTO policy", category: "Paperwork", owner: "New hire" },
        { title: "Meet key team members and stakeholders", category: "Culture", owner: "Buddy" },
        { title: "Shadow front-office coverage for a day", category: "Training", owner: "Buddy" }
      ],
      day30: [
        { title: "Own the weekly meeting schedule independently", category: "Training", owner: "New hire" },
        { title: "30-day check-in with office manager", category: "Culture", owner: "Manager" },
        { title: "Propose one process improvement", category: "Culture", owner: "New hire" }
      ]
    }
  };

  let _uid = 0;
  function uid(prefix) {
    _uid += 1;
    return (prefix || "id") + "_" + Date.now().toString(36) + "_" + _uid + "_" +
      Math.floor(Math.random() * 1e6).toString(36);
  }

  // ---- Checklist generation ---------------------------------------------------
  function buildTask(t, phase) {
    return {
      id: uid("task"),
      title: t.title,
      phase: phase,
      category: t.category || "Training",
      owner: t.owner || "Manager",
      doc: !!t.doc,
      guidance: t.doc ? GENERIC_NOTE : null,
      done: false,
      doneAt: null
    };
  }

  function generateChecklist(roleName, customRoles) {
    let template = ROLE_TEMPLATES[roleName];
    if (!template && customRoles && customRoles[roleName]) template = customRoles[roleName].tasks;
    if (!template) return null;
    const items = [];
    for (const phase of PHASES) {
      const list = template[phase] || [];
      for (const t of list) items.push(buildTask(t, phase));
    }
    return items;
  }

  // ---- State ------------------------------------------------------------------
  function blankState() {
    return { hires: [], buddies: [], customRoles: {}, settings: { openaiKey: "" } };
  }

  function serialize(state) { return JSON.stringify(state); }
  function deserialize(json) {
    try {
      const s = JSON.parse(json);
      if (!s || typeof s !== "object") return blankState();
      return Object.assign(blankState(), s);
    } catch (e) { return blankState(); }
  }

  // ---- Buddies ----------------------------------------------------------------
  function addBuddy(state, name, role) {
    name = (name || "").trim();
    if (!name) return null;
    const b = { id: uid("buddy"), name: name, role: role || "" };
    state.buddies.push(b);
    return b;
  }
  function removeBuddy(state, buddyId) {
    state.buddies = state.buddies.filter(b => b.id !== buddyId);
    for (const h of state.hires) if (h.buddyId === buddyId) h.buddyId = null;
  }

  // ---- Hires ------------------------------------------------------------------
  function addHire(state, name, role, startDate, buddyId) {
    name = (name || "").trim();
    if (!name || !role) return null;
    const checklist = generateChecklist(role, state.customRoles);
    if (!checklist) return null;
    const h = {
      id: uid("hire"),
      name: name,
      role: role,
      startDate: startDate || null, // ISO yyyy-mm-dd
      buddyId: buddyId || null,
      checklist: checklist,
      archived: false,
      createdAt: new Date().toISOString()
    };
    state.hires.push(h);
    return h;
  }
  function getHire(state, hireId) {
    return state.hires.find(h => h.id === hireId) || null;
  }
  function removeHire(state, hireId) {
    state.hires = state.hires.filter(h => h.id !== hireId);
  }
  function setItemDone(state, hireId, taskId, done) {
    const h = getHire(state, hireId);
    if (!h) return false;
    const t = h.checklist.find(x => x.id === taskId);
    if (!t) return false;
    t.done = !!done;
    t.doneAt = t.done ? new Date().toISOString() : null;
    return true;
  }
  function assignBuddy(state, hireId, buddyId) {
    const h = getHire(state, hireId);
    if (!h) return false;
    h.buddyId = buddyId || null;
    return true;
  }
  function getBuddyName(state, hireId) {
    const h = getHire(state, hireId);
    if (!h || !h.buddyId) return null;
    const b = state.buddies.find(x => x.id === h.buddyId);
    return b ? b.name : null;
  }

  function progressFor(hire, phase) {
    const items = phase ? hire.checklist.filter(t => t.phase === phase)
                        : hire.checklist;
    if (!items.length) return 0;
    const done = items.filter(t => t.done).length;
    return Math.round(done / items.length * 100);
  }
  function progressAll(hire) {
    const p = {};
    for (const ph of PHASES) p[ph] = progressFor(hire, ph);
    p.overall = progressFor(hire, null);
    return p;
  }
  function countsFor(hire, phase) {
    const items = phase ? hire.checklist.filter(t => t.phase === phase)
                        : hire.checklist;
    return { total: items.length, done: items.filter(t => t.done).length };
  }

  function isOverdue(hire, todayStr) {
    if (!hire.startDate) return false;
    const today = todayStr || new Date().toISOString().slice(0, 10);
    if (today <= hire.startDate) return false;
    return hire.checklist.some(t => t.phase === "day1" && !t.done);
  }

  function parseISODate(s) {
    const d = new Date(s + "T12:00:00");
    return isNaN(d.getTime()) ? null : d;
  }

  // Whole days until the hire's start date (negative = already started). null = no start date.
  function daysToStart(hire, todayStr) {
    if (!hire || !hire.startDate) return null;
    const today = todayStr || new Date().toISOString().slice(0, 10);
    const a = parseISODate(today), b = parseISODate(hire.startDate);
    if (!a || !b) return null;
    return Math.round((b - a) / 86400000);
  }

  function startLabel(hire, todayStr) {
    const d = daysToStart(hire, todayStr);
    if (d === null) return "no start date";
    if (d === 0) return "starts today";
    if (d === 1) return "starts tomorrow";
    if (d > 1) return "starts in " + d + " days";
    if (d === -1) return "started yesterday";
    return "started " + Math.abs(d) + " days ago";
  }

  function dashboard(state, todayStr) {
    return state.hires.filter(h => !h.archived).map(h => ({
      id: h.id,
      name: h.name,
      role: h.role,
      startDate: h.startDate,
      buddy: getBuddyName(state, h.id),
      progress: progressAll(h),
      overdue: isOverdue(h, todayStr),
      startIn: daysToStart(h, todayStr)
    }));
  }

  function archivedHires(state) {
    return (state.hires || []).filter(h => h.archived);
  }
  function archiveHire(state, hireId) {
    const h = getHire(state, hireId);
    if (!h) return false;
    h.archived = true;
    return true;
  }
  function unarchiveHire(state, hireId) {
    const h = getHire(state, hireId);
    if (!h) return false;
    h.archived = false;
    return true;
  }

  // Filter dashboard rows by name/role query (case-insensitive).
  function searchHires(rows, query) {
    const q = (query || "").trim().toLowerCase();
    if (!q) return (rows || []).slice();
    return (rows || []).filter(r => (r.name + " " + r.role).toLowerCase().includes(q));
  }

  // Sort dashboard rows. key: name | startDate | progress | overdue. overdue always first when key=overdue.
  function sortHires(rows, key, dir) {
    const d = dir === "desc" ? -1 : 1;
    const arr = (rows || []).slice();
    const val = r => {
      if (key === "startDate") return r.startDate || "";
      if (key === "progress") return r.progress ? r.progress.overall : 0;
      if (key === "overdue") return r.overdue ? 1 : 0;
      return (r.name || "").toLowerCase();
    };
    arr.sort((a, b) => {
      const va = val(a), vb = val(b);
      if (va < vb) return -1 * d;
      if (va > vb) return 1 * d;
      return 0;
    });
    return arr;
  }

  function csvCell(v) {
    const s = String(v === undefined || v === null ? "" : v);
    return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  }

  // Dashboard rows -> CSV for HR reports.
  function hiresToCSV(rows) {
    const head = ["Name", "Role", "Start date", "Buddy", "Overall %", "Day-1 overdue", "Start countdown"];
    const lines = (rows || []).map(r => [
      r.name, r.role, r.startDate || "", r.buddy || "",
      r.progress ? r.progress.overall : 0,
      r.overdue ? "yes" : "no",
      startInLabel(r)
    ]);
    return [head].concat(lines).map(l => l.map(csvCell).join(",")).join("\n");
  }
  function startInLabel(r) {
    if (r.startIn === null || r.startIn === undefined) return "";
    if (r.startIn === 0) return "today";
    return r.startIn > 0 ? "in " + r.startIn + "d" : Math.abs(r.startIn) + "d ago";
  }

  // ---- Custom roles -------------------------------------------------------------
  function createCustomRole(state, name, tasks) {
    name = (name || "").trim();
    if (!name) return null;
    const r = { name: name, custom: true, tasks: {} };
    for (const ph of PHASES) r.tasks[ph] = [];
    if (tasks) {
      for (const ph of PHASES) {
        for (const t of (tasks[ph] || [])) {
          r.tasks[ph].push({
            title: t.title, category: t.category, owner: t.owner, doc: !!t.doc
          });
        }
      }
    }
    state.customRoles[name] = r;
    return r;
  }
  function addCustomTask(state, roleName, phase, title, category, owner) {
    const r = state.customRoles[roleName];
    if (!r || !PHASES.includes(phase)) return null;
    const t = { title: title, category: category || "Training", owner: owner || "Manager", doc: false };
    r.tasks[phase].push(t);
    return t;
  }
  function removeCustomRole(state, roleName) {
    delete state.customRoles[roleName];
  }
  function allRoles(state) {
    return Object.keys(ROLE_TEMPLATES).concat(Object.keys(state.customRoles || {}));
  }

  // ---- Welcome message ----------------------------------------------------------
  function localWelcomeMessage(hire, buddyName) {
    const parts = [
      "Welcome to the team, " + hire.name + "!",
      "We're thrilled to have you join us as our new " + hire.role + "."
    ];
    if (buddyName) parts.push(buddyName + " will be your onboarding buddy — don't hesitate to ask them anything.");
    parts.push("Your Day 1 checklist is ready in OnboardPilot, so you'll always know what comes next.");
    return parts.join(" ");
  }
  function draftWelcomeMessage(state, hireId) {
    const h = getHire(state, hireId);
    if (!h) return null;
    return { source: "local", message: localWelcomeMessage(h, getBuddyName(state, hireId)) };
  }

  // The browser app calls this; in tests we verify it does NOT fire without a key.
  async function openaiWelcomeMessage(fetchFn, apiKey, hire, buddyName) {
    if (!apiKey) return { source: "local", message: localWelcomeMessage(hire, buddyName) };
    const res = await fetchFn("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": "Bearer " + apiKey },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content:
          "Write a warm, short (3-4 sentences) welcome message for a new hire named " +
          hire.name + " starting as " + hire.role + "." }]
      })
    });
    const data = await res.json();
    const msg = data && data.choices && data.choices[0] && data.choices[0].message &&
      data.choices[0].message.content;
    return { source: "ai", message: msg || localWelcomeMessage(hire, buddyName) };
  }

  const OnboardPilot = {
    STORAGE_KEY, PHASES, PHASE_LABELS, CATEGORIES, GENERIC_NOTE,
    ROLE_TEMPLATES,
    generateChecklist, buildTask,
    blankState, serialize, deserialize,
    addBuddy, removeBuddy,
    addHire, getHire, removeHire, setItemDone, assignBuddy, getBuddyName,
    progressFor, progressAll, countsFor, isOverdue, dashboard,
    daysToStart, startLabel, searchHires, sortHires, hiresToCSV,
    archiveHire, unarchiveHire, archivedHires,
    createCustomRole, addCustomTask, removeCustomRole, allRoles,
    localWelcomeMessage, draftWelcomeMessage, openaiWelcomeMessage
  };

  if (typeof module !== "undefined" && module.exports) module.exports = OnboardPilot;
  else g.OnboardPilot = OnboardPilot;
})(typeof window !== "undefined" ? window : globalThis);
