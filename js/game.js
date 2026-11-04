/* Tam İsabet — oyun mantığı, ilerleme (kilitler, başarımlar), öğretici, tüccar ve ekranlar */
const $ = s => document.querySelector(s);
const rnd = n => Math.floor(Math.random() * n);
const pick = a => a[rnd(a.length)];
const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = rnd(i + 1); [a[i], a[j]] = [a[j], a[i]]; } return a; };
const MAX_LIVES = 4, START_LIVES = 2, DECK_SIZE = 24, MAX_CHARMS = 5;
const CLASS_GLOW = { alchemist: '#6ff0b0', pyro: '#ff8a4a', seer: '#c1a2ff', guard: '#8cc2ff', neutral: '#ffd27a', curse: '#c8c4cc' };
const ROUND_TYPES = { small: 'Küçük Sınav', big: 'Büyük Sınav', boss: 'Bekçi' };
const PERKS = {
  life: { title: '+1 Can', icon: 'heart', price: 6, text: 'Canın 1 artar (en fazla 4).' },
  play: { title: 'Sabır', icon: 'hourglass', price: 8, text: 'Her tur +1 oynama hakkı.' },
  discard: { title: 'Esneklik', icon: 'swap', price: 5, text: 'Her tur +1 değiştirme hakkı.' },
  hand: { title: 'Geniş El', icon: 'hand', price: 7, text: 'Elinde 1 kart daha tutarsın.' },
};
let INSTANT = false; // testlerde animasyonları atlamak için

/* ───────── Kalıcı veriler (bu cihazda) ───────── */
const store = {
  get(k, d) { try { const v = localStorage.getItem(k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { } },
};
let best = +store.get('tam-isabet-best', 0) || 0;
let savedDecks = store.get('tam-isabet-decks', {}) || {};
function freshProgress() {
  return { v: 1, unlocked: [...STARTER_UNLOCKS], classes: [...STARTER_CLASSES], ach: [], stats: { rounds: 0, hits: 0, spells: 0, runs: 0, bestRound: 0 }, tutorialDone: false };
}
let P = (() => { const d = store.get('tam-isabet-progress', null); return d && d.v === 1 ? d : freshProgress(); })();
const saveP = () => store.set('tam-isabet-progress', P);
function saveBest() { if (S && S.score > best) { best = S.score; store.set('tam-isabet-best', best); } }

/* ───────── Durum ───────── */
let S = null, B = null, screen = 'splash', uiModal = null, uid = 1;
let heartFx = null, fxQueue = [], seen = new Set(), lastTarget = null, lastTap = null;

/* ───────── Kart yardımcıları ───────── */
const T = c => CARD[c.tid];
function inst(tid) { const t = CARD[tid]; return { uid: uid++, tid, value: t.value ?? 0, color: t.color || null }; }
const isNum = c => T(c).kind === 'num';
const isSpell = c => T(c).kind === 'spell';
function val(c) { const t = T(c); if (t.dyn === 'ash') return Math.min(15, S ? S.discard.length : 0); return c.value; }
function cardName(c) { const t = T(c); return t.isNumber ? `${SUITS[c.color].name} ${c.value}` : t.name; }
const icon = k => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[k] || ''}</svg>`;
const suitSVG = c => `<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">${SUITS[c].svg}</svg>`;
const esc = s => String(s).replace(/"/g, '&quot;');
const fmtMult = m => Number.isInteger(m) ? String(m) : m.toFixed(1);
const isUnlocked = id => P.unlocked.includes(id);
const hasCharm = id => S && S.charms.some(c => c.cid === id);
const KIND_ORDER = { num: 0, add: 1, wild: 2, op: 3, spell: 4, curse: 5 };
const byRarity = (a, b) => (RARITY_ORDER.indexOf(a.rarity) - RARITY_ORDER.indexOf(b.rarity)) || ((KIND_ORDER[a.kind] ?? 9) - (KIND_ORDER[b.kind] ?? 9)) || ((a.value || 0) - (b.value || 0)) || a.name.localeCompare(b.name, 'tr');

function gemClass(t, color) {
  if (t.kind === 'num') return color === 'rainbow' ? 'g-rainbow' : 'g-' + color;
  if (t.kind === 'spell') return 'g-spell';
  if (t.kind === 'curse') return 'g-curse';
  return 'g-arcane';
}

/* src: kart örneği ({uid,tid,...}) ya da kart kimliği (string) */
function cardHTML(src, { mini = false, sel = false, extra = '', tag = 'div', attrs = '', count = null, locked = false } = {}) {
  const isInst = typeof src === 'object';
  const t = isInst ? CARD[src.tid] : CARD[src];
  const color = isInst ? src.color : t.color;
  const value = isInst ? val(src) : t.value;
  const name = t.isNumber ? `${SUITS[color].name} ${value}` : t.name;
  let gem = t.gem ?? (t.kind === 'spell' ? '✦' : '');
  if (t.kind === 'num' || (isInst && (t.roll || t.dyn))) gem = String(value);
  const art = locked ? icon('lock')
    : t.glyph ? `<span class="glyph">${t.glyph}</span>`
    : t.isNumber ? `<span class="suitart">${suitSVG(color)}<b>${value}</b></span>`
    : icon(t.icon);
  const cls = ['card', 'cl-' + t.cls, 'r-' + t.rarity, 'k-' + t.kind];
  if (color && color !== 'rainbow') cls.push('c-' + color);
  if (mini) cls.push('mini');
  if (sel) cls.push('sel');
  if (locked) cls.push('locked');
  if (extra) cls.push(extra);
  const boosted = isInst && S && t.kind === 'num' && color === boostColor();
  return `<${tag} class="${cls.join(' ')}" aria-label="${esc(locked ? 'Kilitli kart' : name)}" ${attrs}>`
    + `<span class="body"><span class="art">${art}<span class="rgem"></span></span><span class="nameplate">${locked ? 'Kilitli' : name}</span><span class="text">${locked ? RARITY[t.rarity].name + ' kart. Turları geçtikçe ve başarımlarla açılır.' : t.text}</span></span>`
    + `<span class="gem ${locked ? 'g-curse' : gemClass(t, color)}"><span>${locked ? '?' : gem}</span></span>`
    + (boosted ? '<span class="boosttag">×2</span>' : '')
    + (count != null ? `<span class="count">${count}</span>` : '')
    + `</${tag}>`;
}
function charmHTML(cid, { mini = false, tag = 'div', attrs = '', extra = '', state = null } = {}) {
  const c = CHARM[cid];
  const st = state && state.m ? ` (+${state.m})` : '';
  return `<${tag} class="card charm cl-charm r-${c.rarity}${mini ? ' mini' : ''}${extra ? ' ' + extra : ''}" aria-label="${esc(c.name)}" ${attrs}>`
    + `<span class="body"><span class="art">${icon(c.icon)}<span class="rgem"></span></span><span class="nameplate">${c.name}</span><span class="text">${c.text}${st}</span></span>`
    + `<span class="gem g-charm"><span>✧</span></span></${tag}>`;
}
function perkHTML(k) {
  const p = PERKS[k];
  return `<div class="card cl-${k === 'life' ? 'pyro' : 'guard'} r-rare k-perk" aria-label="${esc(p.title)}">`
    + `<span class="body"><span class="art">${icon(p.icon)}<span class="rgem"></span></span><span class="nameplate">${p.title}</span><span class="text">${p.text}</span></span>`
    + `<span class="gem g-gold"><span>+1</span></span></div>`;
}
const eventCard = (id, cls = '') => `<div class="ecard tone-${EVENTS[id].tone} ${cls}">${icon(EVENTS[id].icon)}</div>`;
const coinSVG = `<svg class="coin" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" fill="#f5c518" stroke="#7a5800" stroke-width="1.5"/><circle cx="12" cy="12" r="5.5" fill="none" stroke="#b88a0a" stroke-width="1.2"/></svg>`;

/* ───────── Hesaplama ───────── */
const boostColor = () => { const m = S && S.mods.find(m => m.type === 'boost'); return m ? m.color : null; };
const mirrorNum = n => (n < 0 ? -1 : 1) * parseInt(String(Math.abs(n)).split('').reverse().join(''), 10);
function sameColor(nums) { const cols = new Set(nums.map(c => c.color).filter(c => c !== 'rainbow')); return cols.size <= 1; }
function isCombo(cards) { const nums = cards.filter(isNum); return nums.length >= 3 && sameColor(nums); }
const eventEvery = () => hasCharm('seereye') ? 2 : 3;

function evaluate(cards, target = S.target) {
  const bc = boostColor();
  const nums = cards.filter(isNum);
  const ops = cards.filter(c => T(c).kind === 'op').map(T);
  const wilds = cards.filter(c => T(c).kind === 'wild').map(T);
  const adds = cards.filter(c => ['add', 'curse'].includes(T(c).kind));
  const has = o => ops.filter(t => t.op === o);

  let nv = nums.map(c => (S.boss === 'redban' && c.color === 'red') ? 0 : val(c) * (bc && c.color === bc ? 2 : 1));
  if (has('equalize').length && nv.length) { const m = Math.max(...nv); nv = nv.map(() => m); }
  const maxN = nv.length ? Math.max(...nv) : 0;
  const terms = nv.map(String);
  let fixed = nv.reduce((a, b) => a + b, 0);
  for (const c of adds) { const v = val(c); fixed += v; terms.push(v < 0 ? '−' + Math.abs(v) : String(v)); }
  for (const _ of has('copy')) { fixed += maxN; terms.push('↺' + maxN); }
  for (const _ of has('perCard')) { fixed += cards.length; terms.push(String(cards.length)); }
  if (nums.length >= 2 && sameColor(nums)) for (const t of has('discipline')) { fixed += t.value; terms.push(String(t.value)); }

  const mul = has('mul').reduce((a, t) => a * t.value, 1);
  const div = has('div').reduce((a, t) => a * t.value, 1);
  const sq = has('square').length > 0;
  const mir = has('mirror').length % 2 === 1;
  const tol = Math.max(0, S.tolNext || 0, hasCharm('nearshot') ? 1 : 0, ...has('tolerance').map(t => t.value));
  const calc = w => { let b = fixed + w; if (sq) b = b * b; const r = Math.trunc(b * mul / div); return mir ? mirrorNum(r) : r; };

  let ws = 0;
  if (wilds.length) {
    const lo = wilds.length, hi = wilds.reduce((a, t) => a + t.max, 0);
    let bd = Infinity;
    for (let s = lo; s <= hi; s++) { const d = Math.abs(calc(s) - target); if (d < bd) { bd = d; ws = s; } }
    terms.push('★' + ws);
  }
  const total = calc(ws);
  let e = terms.length ? terms.join(' + ').replace(/\+ −/g, '− ') : '0';
  if (sq) e = `(${e})²`;
  else if ((mul > 1 || div > 1) && terms.length > 1) e = `(${e})`;
  if (mul > 1) e += ` ×${mul}`;
  if (div > 1) e += ` ÷${div}`;
  if (mir) e = `⇄ ${e}`;
  return { total, expr: e, tol, hit: Math.abs(total - target) <= tol };
}

/* İsabet skoru: Puan × Çarpan. Adımlar animasyonda tek tek gösterilir. */
function scorePlay(cards, preview = false) {
  const steps = [];
  let chips = 0, mult = 1, x = 1;
  const push = (src, label, kind) => steps.push({ src, label, kind, chips, mult: mult * x });
  chips = S.target; push({ t: 'dial' }, `Hedef ${S.target}`, 'chips');
  for (const c of cards) {
    const add = 5 + (isNum(c) ? Math.abs(val(c)) : 0);
    chips += add; push({ t: 'card', uid: c.uid }, `+${add}`, 'chips');
  }
  const combo = isCombo(cards);
  if (combo) { mult += 2; push({ t: 'combo' }, 'Renk serisi +2', 'mult'); }
  const coin = cards.find(c => T(c).onHit === 'triple');
  if (coin) { x *= 3; push({ t: 'card', uid: coin.uid }, '×3', 'x'); }
  const nums = cards.filter(isNum), stones = S.master.filter(c => c.tid === 'stone').length;
  S.charms.forEach((ch, i) => {
    const def = CHARM[ch.cid];
    if (!def.score) return;
    def.score({
      cards, nums, combo, target: S.target, discards: S.discards, spells: S.spellsRound, first: S.playsUsed === 0, stones, state: ch.state, preview,
      chips: (n, l) => { chips += n; push({ t: 'charm', i }, l, 'chips'); },
      mult: (n, l) => { mult += n; push({ t: 'charm', i }, l, 'mult'); },
      x: (n, l) => { x *= n; push({ t: 'charm', i }, l, 'x'); },
    });
  });
  return { steps, chips, mult: mult * x, total: Math.floor(chips * mult * x), combo };
}

/* ───────── Deste işlemleri ───────── */
function newTarget() {
  const lo = 6 + 2 * S.round, hi = 12 + 3 * S.round;
  let t;
  do { t = lo + rnd(hi - lo + 1); } while (t === S.target);
  return t;
}
const handLimit = () => S.handSize + (S.boss === 'heavy' ? -1 : 0);
function onDrawn(c) { const t = T(c); if (t.roll) c.value = t.roll[0] + rnd(t.roll[1] - t.roll[0] + 1); return c; }
function drawOne() {
  if (!S.draw.length) { if (!S.discard.length) return null; S.draw = shuffle(S.discard); S.discard = []; }
  return onDrawn(S.draw.pop());
}
function refill() { while (S.hand.length < handLimit()) { const c = drawOne(); if (!c) break; S.hand.push(c); } sortHand(); }
function drawN(n) { for (let i = 0; i < n; i++) { const c = drawOne(); if (!c) break; S.hand.push(c); } sortHand(); }
function insertRandom(c) { S.draw.splice(rnd(S.draw.length + 1), 0, c); }
function removeForever(c) {
  const f = x => x.uid !== c.uid;
  S.master = S.master.filter(f); S.hand = S.hand.filter(f); S.draw = S.draw.filter(f); S.discard = S.discard.filter(f);
  S.sel = S.sel.filter(id => id !== c.uid);
}
function sortHand() {
  if (!S || !S.sortMode) return;
  const key = c => {
    const t = T(c), k = KIND_ORDER[t.kind];
    if (S.sortMode === 'color') return [k, SUIT_KEYS.indexOf(c.color), c.value];
    return [k, c.value, SUIT_KEYS.indexOf(c.color)];
  };
  S.hand.sort((a, b) => { const A = key(a), B2 = key(b); for (let i = 0; i < 3; i++) if (A[i] !== B2[i]) return A[i] - B2[i]; return 0; });
}

/* Açık kart havuzu ve nadirliğe göre rastgele seçim */
const collectible = cls => SPECIAL_CARDS.filter(c => !c.noCollect && (c.cls === 'neutral' || c.cls === cls));
function weightedPick(pool, luck = 1, cls = null) {
  if (!pool.length) return null;
  const w = c => RARITY[c.rarity].w * (c.rarity === 'common' ? 1 : luck) * (cls && c.cls === cls ? 1.5 : 1);
  let r = Math.random() * pool.reduce((s, c) => s + w(c), 0);
  for (const c of pool) { r -= w(c); if (r <= 0) return c; }
  return pool[pool.length - 1];
}
function rollCardId(cls, luck = 1, exclude = []) {
  let pool = collectible(cls).filter(c => isUnlocked(c.id) && !exclude.includes(c.id));
  if (!pool.length) pool = collectible(cls).filter(c => isUnlocked(c.id));
  return (weightedPick(pool, luck, cls) || CARD.add5).id;
}
function rollCharmId(exclude = []) {
  const pool = CHARMS.filter(c => isUnlocked(c.id) && !hasCharm(c.id) && !exclude.includes(c.id));
  const c = weightedPick(pool);
  return c ? c.id : null;
}

/* ───────── İlerleme: kilitler, başarımlar, bildirimler ───────── */
function unlock(id) {
  if (id.startsWith('class:')) {
    const k = id.slice(6);
    if (P.classes.includes(k)) return;
    P.classes.push(k);
    (CLASS_UNLOCK_CARDS[k] || []).forEach(c => { if (!isUnlocked(c)) P.unlocked.push(c); });
    toast({ kind: 'class', k });
    saveP(); return;
  }
  if (isUnlocked(id)) return;
  P.unlocked.push(id);
  toast({ kind: CHARM[id] ? 'charm' : 'card', id });
  saveP();
}
function achieve(id) {
  if (P.ach.includes(id)) return;
  const a = ACHIEVEMENTS.find(x => x.id === id);
  if (!a) return;
  P.ach.push(id);
  toast({ kind: 'ach', a });
  a.unlocks.forEach(unlock);
  saveP();
}
function progressUnlock() {
  const next = UNLOCK_ORDER.find(u => !isUnlocked(u.id) && (u.cls === 'neutral' || P.classes.includes(u.cls)));
  if (next) unlock(next.id);
}
function checkAch() {
  if (!S) return;
  if (S.gold >= 25) achieve('rich');
  if (S.lives >= 4) achieve('lives4');
  if (S.charms.length >= 3) achieve('charms3');
  if (S.score >= 1000) achieve('score1000');
  if (P.stats.spells >= 10) achieve('spells10');
}

let toastQ = [], toastBusy = false;
function toast(t) { if (INSTANT) return; toastQ.push(t); if (!toastBusy) nextToast(); }
function nextToast() {
  const t = toastQ.shift();
  if (!t) { toastBusy = false; return; }
  toastBusy = true;
  let pic, eyebrow, title, sub;
  if (t.kind === 'ach') { pic = `<span class="tpic trophy">${icon(t.a.icon)}</span>`; eyebrow = 'Başarım açıldı'; title = t.a.name; sub = t.a.text; }
  else if (t.kind === 'class') { const C = CLASSES[t.k]; pic = `<span class="tpic emblem cl-${t.k}">${icon(C.icon)}</span>`; eyebrow = 'Yeni sınıf açıldı'; title = C.name; sub = C.tagline; }
  else if (t.kind === 'charm') { const c = CHARM[t.id]; pic = `<span class="tpic">${charmHTML(t.id, { mini: true })}</span>`; eyebrow = 'Yeni tılsım açıldı'; title = c.name; sub = RARITY[c.rarity].name + ' · ' + c.text; }
  else { const c = CARD[t.id]; pic = `<span class="tpic">${cardHTML(t.id, { mini: true })}</span>`; eyebrow = 'Yeni kart açıldı'; title = c.name; sub = RARITY[c.rarity].name + ' · ' + c.text; }
  const el = document.createElement('div');
  el.className = 'toast' + (t.kind === 'ach' ? ' ach' : '');
  el.setAttribute('role', 'status');
  el.innerHTML = `${pic}<span class="tbody"><span class="tey">${eyebrow}</span><b>${title}</b><small>${sub}</small></span>`;
  $('#toasts').appendChild(el);
  setTimeout(() => FX.sparkleAt(el.querySelector('.tpic'), t.kind === 'ach' ? '#f5c518' : '#ffffff', 20), 250);
  setTimeout(() => { el.classList.add('out'); setTimeout(() => { el.remove(); nextToast(); }, 380); }, 3000);
}

/* ───────── Oyun akışı ───────── */
function deckFor(cls) {
  const d = savedDecks[cls];
  return Array.isArray(d) && d.length === DECK_SIZE && d.every(id => CARD[id] && isUnlocked(id)) ? d : RECOMMENDED[cls];
}
function startRun(cls, { tutorial = false } = {}) {
  uid = 1; seen = new Set(); lastTarget = null; lastTap = null;
  S = {
    cls, round: 0, score: 0, gold: 4, lives: START_LIVES, master: deckFor(cls).map(inst), draw: [], discard: [], hand: [], sel: [],
    charms: [], target: 0, goal: 0, roundScore: 0, rtype: 'small', boss: null,
    plays: 0, discards: 0, maxPlays: 4, maxDiscards: 3, handSize: 7, mods: [], playsUsed: 0, spellsRound: 0,
    msg: '', msgKind: '', modal: null, evCount: 0, nextEvent: pickNextEvent(null), eventDue: false,
    powerUsed: false, shield: false, tolNext: 0, sortMode: 'value', lastScore: null, busy: false, shop: null,
    tut: tutorial ? { step: 0 } : null,
  };
  P.stats.runs++; saveP();
  show('game');
  startRound();
  if (S.tut) tutSetup();
  FX.banner(tutorial ? 'Öğretici' : CLASSES[cls].name, tutorial ? 'Adım adım öğren' : 'Macera başlıyor');
}
function goalFor(r) {
  const f = Math.ceil(r / 3), base = 50 * Math.pow(2.9, f - 1), k = [1, 1.5, 2][(r - 1) % 3];
  return Math.round(base * k / 5) * 5;
}
function startRound() {
  S.round++;
  S.rtype = ['small', 'big', 'boss'][(S.round - 1) % 3];
  S.boss = S.rtype === 'boss' ? pick(Object.keys(BOSSES)) : null;
  S.goal = goalFor(S.round);
  S.roundScore = 0; S.lastScore = null;
  S.draw = shuffle(S.master.slice()); S.discard = []; S.hand = []; S.sel = [];
  const playsMod = S.charms.reduce((a, c) => a + (CHARM[c.cid].playsMod || 0), 0);
  S.plays = Math.max(1, S.maxPlays + playsMod + (S.boss === 'short' ? -1 : 0));
  S.discards = S.boss === 'nodiscard' ? 0 : S.maxDiscards;
  S.mods = []; S.playsUsed = 0; S.spellsRound = 0;
  S.powerUsed = false; S.shield = false; S.tolNext = 0;
  if (S.tut && S.round === 1) { S.plays = 9; S.goal = 70; }
  S.target = newTarget();
  refill();
  S.msg = S.boss ? `Bekçi: ${BOSSES[S.boss].name}. ${BOSSES[S.boss].text}` : `Tur ${S.round}: ${S.goal} skora ulaş.`;
  S.msgKind = S.boss ? 'miss' : '';
  S.modal = null;
  if (S.eventDue) { S.eventDue = false; fireEvent(); }
  if (S.boss) fxQueue.push({ type: 'boss' });
  render();
}
function retryRound() { S.round--; startRound(); S.msg = `Tur ${S.round} yeniden başladı. ${S.goal} skora ulaş.`; render(); }

const selCards = () => S.hand.filter(c => S.sel.includes(c.uid));
const animated = () => !FX.reduce && !INSTANT;

function play() {
  if (S.busy || S.modal || !S.sel.length) return;
  const cards = selCards();
  if (cards.some(isSpell)) {
    if (cards.length === 1) castSpell(cards[0]);
    else { S.msg = 'Büyü kartları tek başına kullanılır.'; S.msgKind = 'miss'; render(); }
    return;
  }
  if (S.plays <= 0) return;
  const r = evaluate(cards);
  const sc = r.hit ? scorePlay(cards) : null;
  const stage = animated() ? FX.stageCards(S.sel.slice(), $('#preview')) : {};
  S.plays--;
  S.hand = S.hand.filter(c => !S.sel.includes(c.uid)); S.discard.push(...cards); S.sel = [];
  S.tolNext = 0;
  let extraDraw = 0;
  for (const c of cards) {
    const h = T(c).onPlay;
    if (h === 'loseDiscard') S.discards = Math.max(0, S.discards - 1);
    if (h === 'draw1') extraDraw++;
  }
  S.playsUsed++;
  if (r.hit) {
    S.evCount++;
    for (const c of cards) {
      const h = T(c).onHit;
      if (h === 'omen') S.evCount++;
      if (h === 'heal' && S.lives < MAX_LIVES) { S.lives++; heartFx = { type: 'gain', i: S.lives - 1 }; }
    }
    S.roundScore += sc.total; S.score += sc.total;
    let gold = 0;
    S.charms.forEach(ch => { const d = CHARM[ch.cid]; if (d.gold) gold += d.gold; if (d.onHit) d.onHit(ch.state); });
    S.gold += gold;
    P.stats.hits++;
    achieve('firsthit');
    if (sc.combo) achieve('combo');
    if (cards.length >= 5) achieve('five');
    if (sc.total >= 200) achieve('big200');
    S.msg = `${sc.combo ? 'Renk serisi! ' : 'Tam isabet! '}${sc.chips} × ${fmtMult(sc.mult)} = ${sc.total} skor${gold ? `, +${gold} altın` : ''}.` + (r.total !== S.target ? ` (${r.total} ≈ ${S.target})` : '');
    S.msgKind = 'hit';
    fxQueue.push({ type: 'hit', combo: sc.combo, pts: sc.total });
  } else {
    if (cards.some(c => T(c).onMiss === 'losePlay')) S.plays = Math.max(0, S.plays - 1);
    S.msg = `Iska: ${r.total}, hedef ${S.target}. Skor yok.`;
    S.msgKind = 'miss';
    fxQueue.push({ type: 'miss' });
  }
  S.lastScore = sc;
  for (const c of cards) if (T(c).exhaust) removeForever(c);
  S.mods.forEach(m => m.turns--); S.mods = S.mods.filter(m => m.turns > 0);
  refill(); drawN(extraDraw);
  saveP(); checkAch();
  const eventReady = S.evCount >= eventEvery();
  if (S.roundScore >= S.goal) {
    if (eventReady) S.eventDue = true;
    roundCleared();
  } else if (S.plays <= 0) {
    if (eventReady) S.eventDue = true;
    loseLife();
  } else {
    if (r.hit || S.boss === 'slippery') { S.target = newTarget(); S.msg += ` Yeni hedef: ${S.target}.`; }
    if (!checkStuck() && eventReady) fireEvent();
  }
  if (r.hit) tutEvent('hit');
  finishAction(sc, stage, r.hit);
}

/* Skor animasyonu sürerken pencereler bekler ve girişler kilitlenir */
function finishAction(sc, stage, hit) {
  if (!animated()) { render(); return; }
  S.busy = true;
  render();
  runScoring(sc, stage, hit, () => { S.busy = false; render(); });
}
function runScoring(sc, stage, hit, done) {
  const chipsEl = $('#chips'), multEl = $('#mult');
  if (!hit || !sc) {
    setTimeout(() => FX.clearStage(stage, false, $('#dial')), 250);
    setTimeout(done, 750);
    return;
  }
  chipsEl.textContent = '0'; multEl.textContent = '1';
  let i = 0;
  const step = () => {
    if (i >= sc.steps.length) {
      const [bx, by] = FX.center($('#scorebox'));
      $('#scorebox').classList.add('fire');
      FX.pop($('#scorebox'), 1.12);
      FX.floater(String(sc.total), bx, by - 34);
      setTimeout(() => FX.clearStage(stage, true, $('#dial')), 250);
      setTimeout(() => { $('#scorebox').classList.remove('fire'); done(); }, 760);
      return;
    }
    const s = sc.steps[i++];
    chipsEl.textContent = s.chips;
    multEl.textContent = fmtMult(s.mult);
    FX.pop(s.kind === 'chips' ? chipsEl : multEl, 1.3);
    let src = null;
    if (s.src.t === 'card') src = stage[s.src.uid];
    else if (s.src.t === 'charm') src = document.querySelector(`#charms [data-ci="${s.src.i}"]`);
    else if (s.src.t === 'dial') src = $('#dial');
    else src = $('#scorebox');
    if (src) {
      FX.pop(src, 1.18);
      const [x, y] = FX.center(src);
      FX.floater(s.label, x, y - 30, 'tiny ' + (s.kind === 'chips' ? 'chips' : 'mult'));
    }
    setTimeout(step, Math.max(140, 300 - i * 18));
  };
  setTimeout(step, 320);
}

function roundCleared() {
  saveBest();
  P.stats.rounds++;
  P.stats.bestRound = Math.max(P.stats.bestRound, S.round);
  if (S.round >= 3) achieve('round3');
  if (S.round >= 6) achieve('round6');
  if (S.round >= 9) achieve('round9');
  if (S.rtype === 'boss') achieve('boss1');
  progressUnlock();
  if (S.tut && S.tut.step < TUT.length - 1) S.tut.step = TUT.length - 1;
  const lines = [[`${ROUND_TYPES[S.rtype]} ödülü`, { small: 3, big: 4, boss: 5 }[S.rtype]]];
  if (S.plays > 0) lines.push([`Kalan oynama hakkı (${S.plays})`, S.plays]);
  const interest = Math.min(5, Math.floor(S.gold / 5));
  if (interest) lines.push(['Faiz (her 5 altına 1)', interest]);
  const total = lines.reduce((a, l) => a + l[1], 0);
  S.gold += total;
  checkAch(); saveP();
  S.modal = { type: 'cashout', lines, total };
  fxQueue.push({ type: 'round' });
}

function loseLife() {
  const gs = S.charms.find(c => c.cid === 'goldshield');
  if (S.shield || gs) {
    if (!S.shield && gs) S.charms = S.charms.filter(c => c !== gs);
    S.shield = false;
    S.modal = { type: 'life', shielded: true, broke: !!gs };
    fxQueue.push({ type: 'shield' });
    return;
  }
  S.lives--; heartFx = { type: 'lost', i: S.lives }; saveBest();
  fxQueue.push({ type: 'lifeLost' });
  S.modal = S.lives <= 0 ? { type: 'over' } : { type: 'life' };
}

/* Deste tükendiyse oynanacak kart kalmaz: tur kaybedilmiş sayılır */
function checkStuck() {
  if (S.hand.length || S.modal) return false;
  S.msg = 'Destende oynanacak kart kalmadı.'; S.msgKind = 'miss';
  loseLife();
  return true;
}

function swapCards() {
  if (S.busy || S.modal || !S.sel.length || S.discards <= 0) return;
  const cards = selCards();
  S.hand = S.hand.filter(c => !S.sel.includes(c.uid)); S.discard.push(...cards); S.sel = []; S.discards--;
  refill();
  S.msg = `${cards.length} kart değiştirildi.`; S.msgKind = '';
  tutEvent('swap');
  render();
}

/* Büyüler */
const SPELLS = {
  draw2() { drawN(2); return '2 kart çektin.'; },
  recall() {
    for (let i = S.discard.length - 1; i >= 0; i--) if (isNum(S.discard[i])) { const c = S.discard.splice(i, 1)[0]; S.hand.push(c); sortHand(); return `${cardName(c)} eline döndü.`; }
    return 'Iskartada sayı kartı yoktu.';
  },
  paint() {
    const cnt = {};
    S.hand.filter(c => isNum(c) && c.color !== 'rainbow').forEach(c => cnt[c.color] = (cnt[c.color] || 0) + 1);
    const col = Object.keys(cnt).sort((a, b) => cnt[b] - cnt[a])[0];
    if (!col) return 'Elinde boyanacak sayı kartı yoktu.';
    S.hand.forEach(c => { if (isNum(c) && c.color !== 'rainbow') c.color = col; });
    return `Sayı kartların ${SUITS[col].name.toLowerCase()} oldu.`;
  },
  shield() { S.shield = true; return 'Bu tur can kaybetmeyeceksin.'; },
  plays2() { S.plays += 2; return '+2 oynama hakkı.'; },
  plays1() { S.plays += 1; return '+1 oynama hakkı.'; },
  compass() { const old = S.target; S.target = Math.max(4, S.target - (1 + rnd(3))); return `Hedef ${old} iken ${S.target} oldu.`; },
  sacrifice() {
    S.plays++;
    if (!S.hand.length) return '+1 oynama hakkı.';
    const c = pick(S.hand); removeForever(c);
    return `${cardName(c)} kurban edildi, +1 oynama hakkı.`;
  },
  transmute() { let n = 0; S.hand.forEach(c => { if (isNum(c) && c.value <= 2) { c.value = 6; n++; } }); return n ? `${n} kart 6 oldu.` : 'Elinde 1 veya 2 yoktu.'; },
  elixir() { S.powerUsed = false; drawN(1); return 'Sınıf gücün yenilendi, 1 kart çektin.'; },
  flamewave() { const n = S.hand.length; S.discard.push(...S.hand); S.hand = []; drawN(n + 1); return `${n + 1} yeni kart çektin.`; },
  fuel() {
    S.discards++;
    if (!S.hand.length) return '+1 değiştirme hakkı.';
    const c = pick(S.hand); removeForever(c);
    return `${cardName(c)} yandı, +1 değiştirme hakkı.`;
  },
  orb() { S.evCount++; return 'Olay sayacı ilerledi.'; },
  starmap() {
    const nums = S.draw.filter(isNum);
    if (!nums.length) return 'Çekme destesinde sayı kartı yok.';
    const c = nums.sort((a, b) => b.value - a.value)[0];
    S.draw = S.draw.filter(x => x !== c); S.hand.push(c); sortHand();
    return `${cardName(c)} eline geldi.`;
  },
  thirdeye() { S.nextEvent = pickNextEvent(S.nextEvent); drawN(1); return `Sıradaki olay artık ${EVENTS[S.nextEvent].name}.`; },
  wall() { S.shield = true; S.discards++; return 'Bu tur can kaybetmeyeceksin, +1 değiştirme hakkı.'; },
};

function castSpell(c) {
  if (S.boss === 'silence') { S.msg = 'Sessizlik: bu tur büyü kullanılamaz.'; S.msgKind = 'miss'; render(); return; }
  const t = T(c);
  FX.castCard(c.uid, CLASS_GLOW[t.cls]);
  S.hand = S.hand.filter(x => x.uid !== c.uid); S.discard.push(c); S.sel = [];
  const res = SPELLS[t.spell](c) || '';
  if (t.exhaust) removeForever(c);
  S.spellsRound++; P.stats.spells++;
  S.msg = `${t.name}: ${res}`; S.msgKind = 'spell';
  fxQueue.push({ type: 'spell', name: t.name });
  refill(); saveP(); checkAch();
  tutEvent('spell');
  if (checkStuck()) { render(); return; }
  if (S.evCount >= eventEvery() && !S.modal) fireEvent();
  render();
}

/* Sınıf gücü (tur başına bir kez) */
function usePower() {
  if (S.busy || S.modal || S.powerUsed) return;
  const C = CLASSES[S.cls];
  if (S.cls === 'alchemist') { S.tolNext = 1; S.msg = 'Damıtma: sonraki oynamada 1 farkla da isabet sayılır.'; }
  else if (S.cls === 'pyro') {
    if (!S.sel.length) { S.msg = 'Kor Yığını için önce ıskartaya atılacak kartları seç.'; S.msgKind = ''; render(); return; }
    const cards = selCards();
    S.hand = S.hand.filter(c => !S.sel.includes(c.uid)); S.discard.push(...cards); S.sel = [];
    drawN(cards.length + 1);
    S.msg = `Kor Yığını: ${cards.length} kart atıldı, ${cards.length + 1} kart çekildi.`;
  }
  else if (S.cls === 'seer') {
    const a = pickNextEvent(S.nextEvent); let b = pickNextEvent(S.nextEvent);
    for (let i = 0; i < 10 && b === a; i++) b = pickNextEvent(S.nextEvent);
    S.modal = { type: 'prophecy', options: [a, b] };
    render(); return;
  }
  else if (S.cls === 'guard') { S.plays++; S.msg = 'Siper: +1 oynama hakkı.'; }
  S.powerUsed = true; S.msgKind = 'spell';
  fxQueue.push({ type: 'power', name: C.power.name });
  tutEvent('power');
  render();
}

/* Olaylar */
function pickNextEvent(exclude) {
  const ids = Object.keys(EVENTS).filter(id => id !== exclude);
  let r = Math.random() * ids.reduce((s, id) => s + EVENTS[id].w, 0);
  for (const id of ids) { r -= EVENTS[id].w; if (r <= 0) return id; }
  return ids[0];
}
function fireEvent() {
  let id = S.nextEvent;
  if (EVENTS[id].ok && !EVENTS[id].ok()) id = pick(Object.keys(EVENTS).filter(k => !EVENTS[k].ok || EVENTS[k].ok()));
  const res = EVENTS[id].run();
  S.modal = { type: 'event', id, ...res };
  S.evCount = 0;
  S.nextEvent = pickNextEvent(id);
  fxQueue.push({ type: 'event', tone: EVENTS[id].tone });
}

/* ───────── Tüccar ───────── */
const discount = () => S.charms.reduce((a, c) => a + (CHARM[c.cid].discount || 0), 0);
const priceOf = base => Math.max(1, base - discount());
function stockShop() {
  const cards = [];
  for (let i = 0; i < 3; i++) cards.push(inst(rollCardId(S.cls, 1, cards.map(c => c.tid))));
  const charms = [];
  for (let i = 0; i < 2; i++) { const id = rollCharmId(charms); if (id) charms.push(id); }
  const perks = Object.keys(PERKS).filter(k => !(k === 'life' && S.lives >= MAX_LIVES) && !(k === 'hand' && S.handSize >= 9));
  const perk = S.lives < MAX_LIVES && Math.random() < .45 ? 'life' : pick(perks);
  return { cards: cards.map(c => ({ c, sold: false })), charms: charms.map(id => ({ id, sold: false })), perk: { k: perk, sold: false } };
}
function openShop() {
  S.shop = { ...stockShop(), rerollCost: 2, removed: false };
  S.modal = { type: 'shop' };
  render();
}
function buy(kind, i) {
  const sh = S.shop;
  if (kind === 'card') {
    const o = sh.cards[i], p = priceOf(RARITY[T(o.c).rarity].price);
    if (o.sold || S.gold < p) return;
    S.gold -= p; o.sold = true; S.master.push(o.c);
    S.msg = `${cardName(o.c)} destene eklendi.`;
  } else if (kind === 'charm') {
    const o = sh.charms[i], p = priceOf(RARITY[CHARM[o.id].rarity].price + 1);
    if (o.sold || S.gold < p || S.charms.length >= MAX_CHARMS) return;
    S.gold -= p; o.sold = true; S.charms.push({ uid: uid++, cid: o.id, state: {} });
    S.msg = `${CHARM[o.id].name} tılsımı takıldı.`;
  } else if (kind === 'perk') {
    const o = sh.perk, p = priceOf(PERKS[o.k].price);
    if (o.sold || S.gold < p) return;
    S.gold -= p; o.sold = true;
    if (o.k === 'life' && S.lives < MAX_LIVES) { S.lives++; heartFx = { type: 'gain', i: S.lives - 1 }; }
    if (o.k === 'play') S.maxPlays++;
    if (o.k === 'discard') S.maxDiscards++;
    if (o.k === 'hand') S.handSize++;
  }
  S.msgKind = '';
  fxQueue.push({ type: 'buy' });
  checkAch();
  render();
}
function sellCharm(i) {
  const ch = S.charms[i]; if (!ch) return;
  const p = Math.max(1, Math.floor((RARITY[CHARM[ch.cid].rarity].price + 1) / 2));
  S.charms.splice(i, 1); S.gold += p;
  render();
}
function reroll() {
  if (S.gold < S.shop.rerollCost) return;
  S.gold -= S.shop.rerollCost; S.shop.rerollCost++;
  Object.assign(S.shop, stockShop());
  render();
}

/* ───────── Öğretici ───────── */
const TUT = [
  { text: 'Tam İsabet’e hoş geldin! Amacın elindeki kartlarla ortadaki <b>HEDEF</b> sayısını tam tutturmak.', focus: '#dial', next: true },
  { text: 'Toplamı <b>10</b> eden kartları seç. Örneğin Kızıl 4 ile Mavi 6.', focus: '#hand', on: 'select',
    setup() { setHand(['n-red-4', 'n-blue-6', 'n-green-2', 'n-gold-3', 'n-red-1', 'n-blue-5', 'n-green-7']); S.target = 10; } },
  { text: 'Toplam 10 oldu. Şimdi <b>Oyna</b>’ya bas.', focus: '#playBtn', on: 'hit' },
  { text: 'Her isabet <b>Puan × Çarpan</b> kadar skor verir. Hedef sayı ve kartlar Puan’ı, renk serileri ve tılsımlar Çarpan’ı artırır. Turu geçmek için tur hedefine ulaş.', focus: '#scorepanel', next: true },
  { text: 'İşine yaramayan kartları seçip <b>Değiştir</b>’e basarsan yerine yenileri gelir. Bir kart seç ve Değiştir’e bas.', focus: '#swapBtn', on: 'swap' },
  { text: '<b>×2 Çarpan</b> toplamı ikiye katlar. Yeşil 6 ile ×2 Çarpan’ı seçip 12 yap ve oyna.', focus: '#hand', on: 'hit',
    setup() { addToHand(['n-green-6', 'mul2']); S.target = 12; } },
  { text: 'Mor taşlı kartlar <b>büyüdür</b>. Keşif’i tek başına seç ve <b>Kullan</b>’a bas.', focus: '#hand', on: 'spell',
    setup() { addToHand(['scout']); } },
  { text: 'Her sınıfın tur başına bir <b>gücü</b> var. Muhafız’ın Siper gücüne bas, +1 oynama hakkı al.', focus: '#powerBtn', on: 'power' },
  { text: 'Sağdaki kart <b>sıradaki olay</b>: birkaç isabette bir gerçekleşir. Üstteki kalpler <b>canların</b>: tur hedefine ulaşamazsan bir can gider.', focus: '#omen', next: true },
  { text: 'Şimdi turu kendin bitir. Tur hedefine ulaşınca altın kazanıp <b>tüccara</b> gideceksin.', focus: '#scorepanel', next: true },
  { text: 'Burası tüccar. Altınla kart, <b>tılsım</b> ve güçlendirme alabilirsin. Tılsımlar kalıcı bonus verir ve skorunu katlar. Hazır olunca sonraki tura geç.', focus: null, on: 'shopnext', when: 'shop' },
];
function setHand(ids) { S.discard.push(...S.hand); S.hand = ids.map(id => { const c = inst(id); S.master.push(c); return c; }); S.sel = []; }
function addToHand(ids) { ids.forEach(id => { const c = inst(id); S.master.push(c); S.hand.push(c); }); }
function tutSetup() { const st = TUT[S.tut.step]; if (st && st.setup) { const keep = S.sortMode; S.sortMode = null; st.setup(); S.sortMode = keep; } render(); }
function tutEvent(ev) {
  if (!S || !S.tut) return;
  const st = TUT[S.tut.step];
  if (!st || st.on !== ev) return;
  if (ev === 'select' && !evaluate(selCards()).hit) return;
  tutAdvance();
}
function tutAdvance() {
  S.tut.step++;
  if (S.tut.step >= TUT.length) { endTutorial(); return; }
  tutSetup();
}
function endTutorial() {
  S.tut = null; P.tutorialDone = true; saveP();
  achieve('tutorial');
  render();
}

/* ───────── Ekran yönetimi ───────── */
function show(name) {
  screen = name;
  for (const s of ['splash', 'classes', 'builder', 'game']) $('#scr-' + s).hidden = s !== name;
  FX.setAmbient(name === 'splash' ? .4 : name === 'game' ? .05 : .12);
  scrollTo(0, 0);
  if (name === 'splash') renderSplash();
  if (name === 'classes') renderClasses();
  if (name === 'builder') renderBuilder();
  if (name === 'game') render();
  renderModal();
  renderCoach();
}

function renderSplash() {
  $('#splashCards').innerHTML = ['joker', 'philo', 'mul2'].map((id, i) => `<div class="sc s${i + 1}">${cardHTML(id)}</div>`).join('');
  $('#splashBest').textContent = best;
  const total = UNLOCK_ORDER.length + NUMBER_CARDS.length;
  $('#splashProg').textContent = `${P.unlocked.length}/${total} kart ve tılsım açık · ${P.ach.length}/${ACHIEVEMENTS.length} başarım`;
  $('#btnContinue').hidden = !(S && S.lives > 0 && !(S.modal && S.modal.type === 'over'));
  $('#btnStart').textContent = P.tutorialDone ? 'Maceraya Başla' : 'Öğreticiyle Başla';
}

function classLockText(k) { const a = ACHIEVEMENTS.find(a => a.unlocks.includes('class:' + k)); return a ? a.text : ''; }
function renderClasses() {
  $('#classGrid').innerHTML = CLASS_KEYS.map(k => {
    const C = CLASSES[k], open = P.classes.includes(k), custom = savedDecks[k] && savedDecks[k].length === DECK_SIZE;
    const nOpen = SPECIAL_CARDS.filter(c => c.cls === k && isUnlocked(c.id)).length, nAll = SPECIAL_CARDS.filter(c => c.cls === k).length;
    return `<article class="cpanel cl-${k}${open ? '' : ' locked'}">
      <div class="emblem">${icon(open ? C.icon : 'lock')}</div>
      <h3>${C.name}</h3>
      <p class="tag">${open ? C.tagline : 'Kilitli: ' + classLockText(k)}</p>
      <div class="cpower"><span class="pico">${icon(C.power.icon)}</span><span><b>${C.power.name}</b><small>${C.power.text}</small></span></div>
      ${open ? `<p class="cdeck">${custom ? 'Kendi desteni kullanıyorsun.' : 'Önerilen deste kullanılıyor.'} Sınıf kartları: ${nOpen}/${nAll} açık.</p>
      <div class="cbtns"><button class="plaque small" type="button" data-edit="${k}">Desteyi Düzenle</button><button class="plaque gold small" type="button" data-play="${k}">Oyna</button></div>` : ''}
    </article>`;
  }).join('');
}

/* ───────── Deste oluşturucu (koleksiyon) ───────── */
function openBuilder(cls) { B = { cls, list: deckFor(cls).slice(), tab: 'class', open: false }; show('builder'); }
const countIn = (list, id) => list.filter(x => x === id).length;
const maxCopies = id => RARITY[CARD[id].rarity].max;
function builderPool() {
  if (B.tab === 'num') return NUMBER_CARDS.slice().sort(byRarity).map(c => c.id);
  if (B.tab === 'class') return SPECIAL_CARDS.filter(c => c.cls === B.cls).sort(byRarity).map(c => c.id);
  return SPECIAL_CARDS.filter(c => c.cls === 'neutral' && !c.noCollect).sort(byRarity).map(c => c.id);
}
function renderBuilder() {
  const C = CLASSES[B.cls], n = B.list.length, pool = builderPool();
  $('#bTitle').textContent = `${C.name} Destesi`;
  $('#bCount').textContent = `${n}/${DECK_SIZE}`;
  $('#tabClass').textContent = C.name;
  document.querySelectorAll('#bTabs [data-tab]').forEach(b => b.setAttribute('aria-selected', String(b.dataset.tab === B.tab)));
  const nums = B.list.filter(id => CARD[id].kind === 'num').length, open = pool.filter(isUnlocked).length;
  $('#bHint').textContent = `Bu sekmede ${open}/${pool.length} kart açık. Kartlar nadirliğe göre sıralı: beyaz, mavi, mor, sarı, kırmızı. Aynı karttan en fazla 2, efsanevi ve epik karttan 1 tane. Destende ${nums} sayı kartı var.`;
  $('#coll').innerHTML = pool.map(id => {
    if (!isUnlocked(id)) return cardHTML(id, { locked: true });
    const k = countIn(B.list, id), mx = maxCopies(id);
    return cardHTML(id, { tag: 'button', extra: k >= mx ? 'maxed' : '', attrs: `type="button" data-add="${id}"`, count: k ? `${k}/${mx}` : null });
  }).join('');
  const uniq = [...new Set(B.list)].map(id => CARD[id]).sort(byRarity);
  $('#bSummary').textContent = `Deste listesi · ${n}/${DECK_SIZE} kart`;
  $('#bToggle').setAttribute('aria-expanded', String(B.open));
  $('#bList').hidden = !B.open;
  $('#bList').innerHTML = uniq.length ? uniq.map(t => `<button class="lrow cl-${t.cls} ${gemClass(t, t.color)}" type="button" data-rm="${t.id}" aria-label="${esc(t.name)} çıkar" style="--rc:${RARITY[t.rarity].color}"><span class="lgem">${t.kind === 'num' ? t.value : t.gem || '✦'}</span><span class="lname">${t.name}</span><span class="lcount">×${countIn(B.list, t.id)}</span></button>`).join('')
    : '<p class="bhint">Desten boş. Yukarıdaki kartlara dokunarak ekle.</p>';
  $('#bSave').disabled = n !== DECK_SIZE;
  $('#bSave').textContent = n === DECK_SIZE ? 'Kaydet ve Oyna' : `${DECK_SIZE - n} kart eksik`;
}

/* ───────── Oyun ekranı çizimi ───────── */
function heartsHTML() {
  return Array.from({ length: MAX_LIVES }, (_, i) => {
    const fx = heartFx && heartFx.i === i ? ' ' + heartFx.type : '';
    return `<svg class="heart${i < S.lives ? ' full' : ''}${fx}" viewBox="0 0 24 24" aria-hidden="true">${ICONS.heart}</svg>`;
  }).join('');
}
function countTo(el, v) {
  const from = +el.textContent || 0;
  el.dataset.to = v;
  if (FX.reduce || INSTANT || v <= from) { el.textContent = v; return; }
  const t0 = performance.now();
  const step = t => {
    if (+el.dataset.to !== v) return;
    const k = Math.min(1, (t - t0) / 600);
    el.textContent = Math.round(from + (v - from) * (1 - Math.pow(1 - k, 3)));
    if (k < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

function render() {
  renderCoach();
  if (screen !== 'game' || !S) { renderModal(); return; }
  const C = CLASSES[S.cls];
  $('#hearts').innerHTML = heartsHTML();
  $('#hearts').setAttribute('aria-label', `${S.lives} can`);
  $('#round').textContent = `${Math.ceil(S.round / 3)}·${S.round}`;
  $('#gold').textContent = S.gold;

  $('#charms').innerHTML = Array.from({ length: MAX_CHARMS }, (_, i) => {
    const ch = S.charms[i];
    return ch ? charmHTML(ch.cid, { mini: true, tag: 'button', attrs: `type="button" data-ci="${i}"`, state: ch.state, extra: lastTap === 'c' + i ? 'sel' : '' })
      : `<span class="slot" aria-hidden="true"></span>`;
  }).join('');

  const hero = $('#hero');
  hero.className = 'hero cl-' + S.cls;
  hero.innerHTML = `<div class="portrait">${icon(C.icon)}</div><span class="hname">${C.name}</span>
    <button class="powerbtn${S.powerUsed ? '' : ' ready'}" id="powerBtn" type="button" ${S.powerUsed || S.modal || S.busy ? 'disabled' : ''} title="${esc(C.power.text)}"><span class="pi">${icon(C.power.icon)}</span><span>${C.power.name}</span></button>`;

  const tg = $('#target');
  tg.textContent = S.target;
  if (lastTarget !== null && S.target !== lastTarget) { tg.classList.remove('flip'); void tg.offsetWidth; tg.classList.add('flip'); }
  lastTarget = S.target;

  const ev = EVENTS[S.nextEvent], every = eventEvery(), left = every - S.evCount;
  $('#omen').innerHTML = `${eventCard(S.nextEvent)}<span class="oname">${ev.name}</span>
    <span class="odots" title="${left <= 0 ? 'Sırada' : left + ' isabet sonra'}">${Array.from({ length: every }, (_, i) => `<i class="${i < S.evCount ? 'on' : ''}"></i>`).join('')}</span>`;
  $('#omen').title = `Sıradaki olay: ${ev.name}. ${ev.hint}`;

  $('#roundLabel').textContent = S.tut && S.round === 1 ? 'Öğretici' : ROUND_TYPES[S.rtype] + (S.boss ? ': ' + BOSSES[S.boss].name : '');
  $('#scorepanel').classList.toggle('boss', !!S.boss);
  $('#goal').textContent = S.goal;
  if (!S.busy) {
    countTo($('#rscore'), S.roundScore);
    const p = Math.min(1, S.roundScore / S.goal);
    $('#goalBar').style.width = (p * 100) + '%';
    $('#dial').style.setProperty('--p', p);
  }
  $('#playsTxt').textContent = S.plays;
  $('#discTxt').textContent = S.discards;

  const chips = S.mods.map(m => `<span class="chip">${SUITS[m.color].name} ×2 · ${m.turns} oynama</span>`);
  if (S.boss) chips.unshift(`<span class="chip boss">${BOSSES[S.boss].name}: ${BOSSES[S.boss].text}</span>`);
  if (S.tolNext) chips.push('<span class="chip cool">Damıtma: ±1</span>');
  if (S.shield) chips.push('<span class="chip cool">Kalkan aktif</span>');
  $('#mods').innerHTML = chips.join('');
  const msg = $('#msg'); msg.textContent = S.msg; msg.className = 'msg ' + S.msgKind;

  const sc = selCards(), pv = $('#preview');
  const spellOnly = sc.length === 1 && isSpell(sc[0]);
  let preview = null;
  if (!sc.length) { $('#expr').textContent = 'Kart seç, toplamı hedefe eşitle.'; $('#tot').textContent = '0'; pv.className = 'preview'; }
  else if (spellOnly) { $('#expr').textContent = `Büyü: ${T(sc[0]).text}`; $('#tot').textContent = '✦'; pv.className = 'preview spell'; }
  else if (sc.some(isSpell)) { $('#expr').textContent = 'Büyü kartları tek başına kullanılır.'; $('#tot').textContent = '–'; pv.className = 'preview over'; }
  else {
    const r = evaluate(sc);
    if (r.hit) preview = scorePlay(sc, true);
    $('#expr').innerHTML = r.expr + (isCombo(sc) ? '<em>Renk serisi: +2 Çarpan</em>' : '') + (r.tol ? `<em>Tolerans ±${r.tol}</em>` : '');
    $('#tot').textContent = r.total;
    pv.className = 'preview' + (r.hit ? ' ok' : r.total > S.target ? ' over' : '');
  }
  if (!S.busy) {
    const show = preview || S.lastScore;
    $('#chips').textContent = show ? show.chips : 0;
    $('#mult').textContent = show ? fmtMult(show.mult) : 0;
    $('#scorebox').classList.toggle('ghost', !!preview);
  }

  let info = 'Kartlara dokunarak seç. Seçtiğin kartın açıklaması burada görünür.';
  if (typeof lastTap === 'string' && S.charms[+lastTap.slice(1)]) {
    const ch = S.charms[+lastTap.slice(1)], d = CHARM[ch.cid];
    info = `<b>${d.name}</b> <span class="rar" style="color:${RARITY[d.rarity].color}">${RARITY[d.rarity].name} tılsım</span><br>${d.text}${ch.state.m ? ` Şu an +${ch.state.m}.` : ''}`;
  } else {
    const ic = S.hand.find(c => c.uid === lastTap) || sc[sc.length - 1];
    if (ic) { const t = T(ic); info = `<b>${cardName(ic)}</b> <span class="rar" style="color:${RARITY[t.rarity].color}">${RARITY[t.rarity].name}${t.cls !== 'neutral' && t.cls !== 'curse' ? ' · ' + CLASSES[t.cls].name : ''}</span><br>${t.text}`; }
  }
  $('#info').innerHTML = info;

  renderHand();

  const playB = $('#playBtn');
  playB.textContent = spellOnly ? 'Kullan' : `Oyna (${S.plays})`;
  playB.disabled = S.busy || !sc.length || (sc.some(isSpell) && !spellOnly) || (!spellOnly && S.plays <= 0);
  $('#swapBtn').textContent = `Değiştir (${S.discards})`;
  $('#swapBtn').disabled = S.busy || !sc.length || S.discards <= 0;
  $('#sortBtn').textContent = S.sortMode === 'color' ? 'Sırala: Renk' : 'Sırala: Değer';
  $('#drawN').textContent = S.draw.length;
  $('#deckN').textContent = S.master.length;
  $('#stack').classList.toggle('empty', !S.draw.length);

  renderModal();
  runFx();
  heartFx = null;
}

function renderHand() {
  const el = $('#hand'), n = S.hand.length;
  const W = el.clientWidth || 340, pad = 10;
  const cw = Math.round(Math.min(84, Math.max(58, W / 4.6)));
  const step = n > 1 ? Math.min(cw * .9, (W - 2 * pad - cw) / (n - 1)) : 0;
  const start = (W - (cw + step * (n - 1))) / 2;
  el.style.setProperty('--hw', cw + 'px');
  el.innerHTML = S.hand.map((c, i) => {
    const d = i - (n - 1) / 2;
    const x = start + i * step, y = d * d * (n > 6 ? 1.6 : 2.4), r = d * (n > 6 ? 2.8 : 4.2);
    const sel = S.sel.includes(c.uid);
    return cardHTML(c, { mini: true, sel, tag: 'button', extra: seen.has(c.uid) ? '' : 'deal',
      attrs: `type="button" data-uid="${c.uid}" aria-pressed="${sel}" style="--x:${x}px;--y:${y}px;--r:${r}deg;--z:${i + 1}"` });
  }).join('');
  const hr = el.getBoundingClientRect(), sr = $('#stack').getBoundingClientRect();
  let k = 0;
  el.querySelectorAll('.card.deal').forEach(cardEl => {
    cardEl.style.setProperty('--dx', (sr.left + sr.width / 2 - hr.left - cw / 2) + 'px');
    cardEl.style.setProperty('--dy', (sr.top + sr.height / 2 - hr.top - 30 - cw * .7) + 'px');
    const delay = k++ * 60;
    cardEl.style.animationDelay = delay + 'ms';
    const r = ['legendary', 'epic', 'unique'].find(x => cardEl.classList.contains('r-' + x));
    if (r) setTimeout(() => FX.sparkleAt(cardEl, RARITY[r].color, r === 'unique' ? 14 : 26), delay + 420);
  });
  S.hand.forEach(c => seen.add(c.uid));
}

/* Sıradaki efektleri çalıştır (çizimden sonra, konumlar belli olunca) */
function runFx() {
  if (S && S.busy) return;
  const q = fxQueue; fxQueue = [];
  if (INSTANT) return;
  for (const f of q) {
    const [dx, dy] = FX.center($('#dial'));
    if (f.type === 'hit') {
      FX.ring(dx, dy, f.combo ? '#ffd25a' : '#ffe7a3', 5);
      if (f.combo) setTimeout(() => FX.ring(dx, dy, '#6be0a4', 7), 120);
      FX.burst(dx, dy, { n: f.combo ? 110 : 60, colors: ['#ffe7a3', '#e2b35a', '#6be0a4', '#ff5a4b', '#4b8dff'], speed: 7 });
      FX.floater(f.combo ? 'Renk Serisi!' : 'Tam İsabet!', dx, dy - 70);
      const a = $('#arena'); a.classList.remove('hit'); void a.offsetWidth; a.classList.add('hit');
      FX.shake(a);
    }
    if (f.type === 'miss') { FX.floater('Iska', dx, dy - 60, 'miss'); FX.vflash('rgba(255,60,40,.35)'); }
    if (f.type === 'round') setTimeout(() => {
      FX.banner('Tur Geçildi', `${S.roundScore} / ${S.goal} skor`);
      FX.burst(innerWidth / 2, innerHeight * .4, { n: 140, colors: ['#ffe7a3', '#e2b35a', '#6be0a4', '#b77bff', '#4b8dff', '#ff5a4b'], speed: 10, size: [5, 10], decay: .009 });
    }, 200);
    if (f.type === 'boss') setTimeout(() => { FX.banner(BOSSES[S.boss].name, BOSSES[S.boss].text); FX.vflash('rgba(255,40,40,.4)'); }, 300);
    if (f.type === 'lifeLost') {
      FX.vflash('rgba(255,30,60,.65)');
      const h = document.querySelector('#hearts .heart.lost');
      if (h) { const [hx, hy] = FX.center(h); FX.burst(hx, hy, { n: 30, colors: ['#ff4d6a', '#ff9aa9', '#8a1022'], speed: 4, size: [3, 6] }); }
      FX.shake($('#scr-game'));
    }
    if (f.type === 'shield') FX.vflash('rgba(110,180,255,.5)');
    if (f.type === 'spell') setTimeout(() => FX.floater(f.name, innerWidth / 2, innerHeight * .42 - 90, 'spell'), 560);
    if (f.type === 'buy') { const g = $('#sheet .goldchip'); if (g) FX.sparkleAt(g, '#f5c518', 16); }
    if (f.type === 'power') {
      const p = document.querySelector('#hero .portrait');
      $('#hero').classList.add('cast');
      if (p) { const [px, py] = FX.center(p); FX.ring(px, py, CLASS_GLOW[S.cls], 3.5); FX.sparkleAt(p, CLASS_GLOW[S.cls], 30); FX.floater(f.name, px + 30, py - 40, 'spell small'); }
    }
    if (f.type === 'event') setTimeout(() => {
      const col = f.tone === 'good' ? '#6be0a4' : f.tone === 'bad' ? '#ff6b5b' : '#ffd27a';
      FX.burst(innerWidth / 2, innerHeight * .35, { n: 40, type: 'glow', colors: [col, '#ffffff'], speed: 5, g: 0, size: [2, 4], decay: .015, up: 0, drag: .95 });
      if (f.tone === 'bad') FX.vflash('rgba(255,70,50,.3)');
    }, 150);
  }
  const hg = document.querySelector('#hearts .heart.gain');
  if (hg) FX.sparkleAt(hg, '#ff9aa9', 24);
}

/* ───────── Öğretici balonu ───────── */
function renderCoach() {
  const el = $('#coach');
  document.querySelectorAll('.tut-focus').forEach(e => e.classList.remove('tut-focus'));
  const st = S && S.tut && screen === 'game' ? TUT[S.tut.step] : null;
  const visible = st && !S.busy && (st.when === 'shop' ? S.modal && S.modal.type === 'shop' : !S.modal);
  if (!visible) { el.hidden = true; return; }
  el.hidden = false;
  el.classList.toggle('low', st.when === 'shop');
  el.innerHTML = `<span class="cstep">Öğretici · ${S.tut.step + 1}/${TUT.length}</span><p>${st.text}</p>
    <div class="cbtn">${st.next ? '<button class="plaque gold small" type="button" data-coach="next">Devam</button>' : ''}<button class="linkbtn" type="button" data-coach="skip">Öğreticiyi atla</button></div>`;
  if (st.focus) { const f = $(st.focus); if (f) f.classList.add('tut-focus'); }
}

/* ───────── Pencereler ───────── */
const HOWTO = `<p class="eyebrow">Kurallar</p><h2>Nasıl Oynanır</h2><ul>
  <li>Elinden kart seç. Toplamları <b>hedefe tam eşit</b> olsun ve <b>Oyna</b>ya bas.</li>
  <li>Her isabet <b>Puan × Çarpan</b> kadar skor verir. Puan: hedef sayı + her kart için 5 + sayı kartlarının değeri. Çarpan: renk serisi ve tılsımlar.</li>
  <li>Oynama hakların bitmeden <b>tur hedef skoruna</b> ulaş. Ulaşamazsan <b>1 can</b> gider ve tur yeniden başlar. 2 canla başlarsın, en fazla 4 olur.</li>
  <li>Her kat 3 turdur: Küçük Sınav, Büyük Sınav ve özel kurallı <b>Bekçi</b>.</li>
  <li>Tur sonunda altın kazanırsın: tur ödülü, kalan oynama hakları ve faiz. <b>Tüccarda</b> kart, tılsım ve güçlendirme alırsın.</li>
  <li><b>Tılsımlar</b> (en fazla 5) kalıcı bonus verir.</li>
  <li>Sıradaki <b>olay</b> birkaç isabette bir gerçekleşir. Büyü kartları (mor taş) tek başına <b>Kullan</b> ile oynanır.</li>
  <li>Başta kartların çoğu <b>kilitlidir</b>. Turları geçtikçe ve başarımlar kazandıkça yenileri açılır.</li>
  <li>Nadirlik: <b style="color:#ece7db">beyaz</b> Sıradan, <b style="color:#4b8dff">mavi</b> Nadir, <b style="color:#b066ff">mor</b> Ender, <b style="color:#f5c518">sarı</b> Efsanevi, <b style="color:#ff3b3b">kırmızı</b> Epik.</li></ul>`;

function shopHTML() {
  const sh = S.shop, full = S.charms.length >= MAX_CHARMS;
  const priceBtn = (p, can, attrs, label) => `<button class="pricebtn" type="button" ${attrs} ${can ? '' : 'disabled'}>${coinSVG}<span>${label || p}</span></button>`;
  const cards = sh.cards.map((o, i) => {
    const p = priceOf(RARITY[T(o.c).rarity].price);
    return `<div class="ware${o.sold ? ' sold' : ''}">${cardHTML(o.c)}${o.sold ? '<span class="soldtag">Alındı</span>' : priceBtn(p, S.gold >= p, `data-act="buy" data-kind="card" data-i="${i}"`)}</div>`;
  }).join('');
  const charms = sh.charms.length ? sh.charms.map((o, i) => {
    const p = priceOf(RARITY[CHARM[o.id].rarity].price + 1);
    return `<div class="ware${o.sold ? ' sold' : ''}">${charmHTML(o.id)}${o.sold ? '<span class="soldtag">Takıldı</span>' : priceBtn(p, S.gold >= p && !full, `data-act="buy" data-kind="charm" data-i="${i}"`, full ? 'Yuva dolu' : p)}</div>`;
  }).join('') : '<p class="bhint">Açık tılsımların hepsi sende.</p>';
  const pk = sh.perk, pp = priceOf(PERKS[pk.k].price);
  const owned = S.charms.length ? S.charms.map((ch, i) => {
    const sp = Math.max(1, Math.floor((RARITY[CHARM[ch.cid].rarity].price + 1) / 2));
    return `<div class="ware small">${charmHTML(ch.cid, { mini: true, state: ch.state })}<button class="pricebtn sell" type="button" data-act="sell" data-i="${i}">Sat +${sp}</button></div>`;
  }).join('') : '<p class="bhint">Henüz tılsımın yok.</p>';
  return `<div class="shophead"><div><p class="eyebrow">Kat ${Math.ceil((S.round + 1) / 3)} · Sıradaki: ${ROUND_TYPES[['small', 'big', 'boss'][S.round % 3]]}</p><h2>Tüccar</h2></div><span class="goldchip">${coinSVG}<b>${S.gold}</b></span></div>
    <h3 class="shelfh">Kartlar</h3><div class="shelf">${cards}</div>
    <h3 class="shelfh">Tılsımlar <small>${S.charms.length}/${MAX_CHARMS} yuva</small></h3><div class="shelf">${charms}
      <div class="ware${pk.sold ? ' sold' : ''}">${perkHTML(pk.k)}${pk.sold ? '<span class="soldtag">Alındı</span>' : priceBtn(pp, S.gold >= pp, 'data-act="buy" data-kind="perk" data-i="0"')}</div></div>
    <h3 class="shelfh">Tılsımların</h3><div class="shelf owned">${owned}</div>
    <div class="shopbtns">
      <button class="plaque small" type="button" data-act="reroll" ${S.gold >= sh.rerollCost ? '' : 'disabled'}>Yenile · ${sh.rerollCost}</button>
      <button class="plaque small" type="button" data-act="toRemove" ${sh.removed || S.gold < 3 || S.master.length <= 12 ? 'disabled' : ''}>Kart çıkar · 3</button>
    </div>
    <button class="plaque gold" type="button" data-act="nextRound">Sonraki tura geç</button>`;
}

function achievementsHTML() {
  return `<p class="eyebrow">${P.ach.length}/${ACHIEVEMENTS.length} tamamlandı</p><h2>Başarımlar</h2>
    <div class="achlist">${ACHIEVEMENTS.map(a => {
      const done = P.ach.includes(a.id);
      const rewards = a.unlocks.map(u => u.startsWith('class:') ? CLASSES[u.slice(6)].name + ' sınıfı' : (CARD[u] || CHARM[u]).name).join(', ');
      return `<div class="achrow${done ? ' done' : ''}"><span class="aicon">${icon(done ? a.icon : 'lock')}</span><span><b>${a.name}</b><small>${a.text}</small><small class="arew">Ödül: ${rewards}</small></span></div>`;
    }).join('')}</div>
    <p class="bhint">Ayrıca her geçtiğin tur, sıradaki kilitli kartı ya da tılsımı açar.</p>
    <button class="plaque gold" type="button" data-act="uiclose">Kapat</button>`;
}

function renderModal() {
  const ov = $('#ov'), sh = $('#sheet');
  const m = uiModal || (screen === 'game' && S && !S.busy ? S.modal : null);
  if (!m) { ov.hidden = true; sh.innerHTML = ''; return; }
  ov.hidden = false;
  sh.className = 'sheet' + (m.type === 'shop' ? ' wide' : '');
  let h = '';
  if (m.type === 'howto') h = HOWTO + '<button class="plaque gold" type="button" data-act="uiclose">Anladım</button>';
  else if (m.type === 'achievements') h = achievementsHTML();
  else if (m.type === 'event') {
    const ev = EVENTS[m.id];
    h = `<p class="eyebrow">Olay</p><h2>${ev.name}</h2>
      <div class="show">${eventCard(m.id, 'bigevent')}${m.card ? cardHTML(m.card) : ''}</div>
      <p>${m.text}</p><p>Sıradaki olay: <b style="color:var(--gold-3)">${EVENTS[S.nextEvent].name}</b></p>
      <button class="plaque gold" type="button" data-act="close">Devam</button>`;
  } else if (m.type === 'prophecy') {
    h = `<p class="eyebrow">Kehanet</p><h2>Kaderi seç</h2><p>Sıradaki olay ${EVENTS[S.nextEvent].name}. Yerine hangisi gelsin?</p>
      <div class="opt2">${m.options.map(id => `<button type="button" data-act="prophecy" data-id="${id}">${eventCard(id)}${EVENTS[id].name}<small>${EVENTS[id].hint}</small></button>`).join('')}</div>
      <button class="plaque small" type="button" data-act="close">Vazgeç</button>`;
  } else if (m.type === 'cashout') {
    h = `<p class="eyebrow">${ROUND_TYPES[S.rtype]} geçildi · ${S.roundScore}/${S.goal} skor</p><h2>Ganimet</h2>
      <div class="cash">${m.lines.map(l => `<div><span>${l[0]}</span><b>+${l[1]}</b></div>`).join('')}<div class="ctotal"><span>Toplam</span><b>${coinSVG} +${m.total}</b></div></div>
      <button class="plaque gold" type="button" data-act="toShop">Tüccara git</button>`;
  } else if (m.type === 'shop') h = shopHTML();
  else if (m.type === 'remove') {
    h = `<p class="eyebrow">Desteni incelt · 3 altın</p><h2>Hangi kart gitsin?</h2><p>Destende ${S.master.length} kart var. Dokunduğun kart kalıcı olarak çıkar.</p>
      <div class="mgrid">${S.master.slice().sort((a, b) => byRarity(T(a), T(b))).map(c => cardHTML(c, { mini: true, tag: 'button', attrs: `type="button" data-act="remove" data-uid="${c.uid}"` })).join('')}</div>
      <button class="plaque small" type="button" data-act="back">Geri</button>`;
  } else if (m.type === 'deck') {
    h = `<p class="eyebrow">Nadirliğe göre sıralı</p><h2>Destende ${S.master.length} kart</h2><p>Çekme destesinde ${S.draw.length}, ıskartada ${S.discard.length}, elinde ${S.hand.length} kart var.</p>
      <div class="mgrid">${S.master.slice().sort((a, b) => byRarity(T(a), T(b))).map(c => cardHTML(c, { mini: true })).join('')}</div>
      <button class="plaque gold" type="button" data-act="close">Kapat</button>`;
  } else if (m.type === 'life') {
    h = m.shielded
      ? `<p class="eyebrow">${m.broke ? 'Altın Kalkan kırıldı' : 'Kalkan seni korudu'}</p><h2>Can kaybı yok</h2><p>Tur hedefine ulaşamadın ama canın gitmedi. Tur ${S.round} yeni kartlarla baştan başlayacak.</p><button class="plaque gold" type="button" data-act="retry">Turu yeniden dene</button>`
      : `<p class="eyebrow">Oynama hakkın bitti</p><h2>Bir can gitti</h2><div class="hearts">${heartsHTML()}</div>
        <p>${S.goal} skor hedefinin ${S.roundScore} kadarına ulaştın. ${S.lives} canın kaldı. Tur ${S.round} yeni kartlarla baştan başlayacak.</p>
        <button class="plaque gold" type="button" data-act="retry">Turu yeniden dene</button>`;
  } else if (m.type === 'over') {
    h = `<p class="eyebrow">Canın kalmadı</p><h2>Oyun bitti</h2>
      <div class="final"><div><span class="label">Tur</span><b>${S.round}</b></div><div><span class="label">Skor</span><b>${S.score}</b></div><div><span class="label">Rekor</span><b>${Math.max(best, S.score)}</b></div></div>
      <p>${CLASSES[S.cls].name} olarak ${Math.ceil(S.round / 3)}. kata kadar geldin. Açtığın kartlar ve başarımlar kalıcı.</p>
      <div class="btns"><button class="plaque gold" type="button" data-act="restart">Aynı sınıfla yeniden oyna</button><button class="plaque" type="button" data-act="menu">Ana menü</button></div>`;
  } else if (m.type === 'pause') {
    h = `<p class="eyebrow">${CLASSES[S.cls].name} · Tur ${S.round}</p><h2>Duraklatıldı</h2>
      <div class="btns"><button class="plaque gold" type="button" data-act="close">Devam et</button>
      <button class="plaque" type="button" data-act="howto">Nasıl oynanır</button>
      <button class="plaque" type="button" data-act="menu">Ana menü</button>
      <button class="plaque" type="button" data-act="restart">Yeni oyun başlat</button></div>`;
  }
  sh.innerHTML = h;
  const f = sh.querySelector('button:not(:disabled)'); if (f) f.focus({ preventScroll: true });
}

/* ───────── Olay dinleyicileri ───────── */
$('#btnStart').addEventListener('click', () => {
  if (!P.tutorialDone) { startRun('guard', { tutorial: true }); return; }
  $('#classesTitle').textContent = 'Sınıfını Seç'; show('classes');
});
$('#btnDecks').addEventListener('click', () => { $('#classesTitle').textContent = 'Koleksiyon ve Desteler'; show('classes'); });
$('#btnContinue').addEventListener('click', () => show('game'));
$('#btnTutorial').addEventListener('click', () => startRun('guard', { tutorial: true }));
$('#btnAch').addEventListener('click', () => { uiModal = { type: 'achievements' }; renderModal(); });
$('#btnHowto').addEventListener('click', () => { uiModal = { type: 'howto' }; renderModal(); });
document.addEventListener('click', e => { const b = e.target.closest('[data-back]'); if (b) show(b.dataset.back); });
$('#classGrid').addEventListener('click', e => {
  const p = e.target.closest('[data-play]'), ed = e.target.closest('[data-edit]');
  if (p) startRun(p.dataset.play);
  if (ed) openBuilder(ed.dataset.edit);
});

$('#bTabs').addEventListener('click', e => { const b = e.target.closest('[data-tab]'); if (b) { B.tab = b.dataset.tab; renderBuilder(); } });
$('#coll').addEventListener('click', e => {
  const b = e.target.closest('[data-add]'); if (!b) return;
  const id = b.dataset.add;
  if (B.list.length >= DECK_SIZE || countIn(B.list, id) >= maxCopies(id)) return;
  B.list.push(id);
  renderBuilder();
  const nb = document.querySelector(`#coll [data-add="${id}"]`);
  if (nb) { nb.classList.add('pop'); FX.sparkleAt(nb, RARITY[CARD[id].rarity].color, 12); }
});
$('#bList').addEventListener('click', e => {
  const b = e.target.closest('[data-rm]'); if (!b) return;
  const i = B.list.lastIndexOf(b.dataset.rm); if (i >= 0) B.list.splice(i, 1);
  renderBuilder();
});
$('#bToggle').addEventListener('click', () => { B.open = !B.open; renderBuilder(); });
$('#bRec').addEventListener('click', () => { B.list = RECOMMENDED[B.cls].slice(); renderBuilder(); });
$('#bClear').addEventListener('click', () => { B.list = []; B.open = false; renderBuilder(); });
$('#bSave').addEventListener('click', () => {
  if (B.list.length !== DECK_SIZE) return;
  savedDecks[B.cls] = B.list.slice(); store.set('tam-isabet-decks', savedDecks);
  startRun(B.cls);
});

$('#hand').addEventListener('click', e => {
  const b = e.target.closest('.card'); if (!b || S.modal || S.busy) return;
  const id = +b.dataset.uid;
  lastTap = id;
  S.sel = S.sel.includes(id) ? S.sel.filter(x => x !== id) : [...S.sel, id];
  tutEvent('select');
  render();
});
$('#charms').addEventListener('click', e => { const b = e.target.closest('[data-ci]'); if (!b) return; lastTap = 'c' + b.dataset.ci; render(); });
$('#playBtn').addEventListener('click', play);
$('#swapBtn').addEventListener('click', swapCards);
$('#sortBtn').addEventListener('click', () => { if (S.busy) return; S.sortMode = S.sortMode === 'color' ? 'value' : 'color'; sortHand(); render(); });
$('#deckBtn').addEventListener('click', () => { if (S.modal || S.busy) return; S.modal = { type: 'deck' }; render(); });
$('#btnPause').addEventListener('click', () => { if (S.modal || S.busy) return; S.modal = { type: 'pause' }; render(); });
$('#hero').addEventListener('click', e => { if (e.target.closest('#powerBtn')) usePower(); });
$('#hero').addEventListener('animationend', () => $('#hero').classList.remove('cast'));
addEventListener('resize', () => { if (screen === 'game' && S) renderHand(); });

$('#coach').addEventListener('click', e => {
  const b = e.target.closest('[data-coach]'); if (!b) return;
  if (b.dataset.coach === 'next') tutAdvance();
  else endTutorial();
});

$('#ov').addEventListener('click', e => {
  const b = e.target.closest('[data-act]'); if (!b || b.disabled) return;
  const a = b.dataset.act, m = S && S.modal;
  if (a === 'uiclose') { uiModal = null; renderModal(); return; }
  if (a === 'howto') { uiModal = { type: 'howto' }; renderModal(); return; }
  if (a === 'close') { S.modal = null; refill(); checkStuck(); render(); }
  else if (a === 'prophecy') { S.nextEvent = b.dataset.id; S.powerUsed = true; S.modal = null; S.msg = `Kehanet: sıradaki olay artık ${EVENTS[S.nextEvent].name}.`; S.msgKind = 'spell'; fxQueue.push({ type: 'power', name: 'Kehanet' }); render(); }
  else if (a === 'toShop') openShop();
  else if (a === 'buy') buy(b.dataset.kind, +b.dataset.i);
  else if (a === 'sell') sellCharm(+b.dataset.i);
  else if (a === 'reroll') reroll();
  else if (a === 'nextRound') { tutEvent('shopnext'); S.shop = null; startRound(); }
  else if (a === 'toRemove') { S.modal = { type: 'remove', back: m }; render(); }
  else if (a === 'back') { S.modal = m.back; render(); }
  else if (a === 'remove') {
    const c = S.master.find(c => c.uid === +b.dataset.uid);
    if (c && S.gold >= 3) { removeForever(c); S.gold -= 3; S.shop.removed = true; S.modal = m.back; render(); }
  }
  else if (a === 'retry') retryRound();
  else if (a === 'restart') startRun(S.cls);
  else if (a === 'menu') { if (S.modal && S.modal.type === 'pause') S.modal = null; show('splash'); }
});

/* ───────── Başlangıç ───────── */
function boot(data) {
  if (data && data.S && data.S.cls && data.S.charms) {
    S = data.S; B = data.B || null; S.busy = false;
    const ids = [...S.master, ...S.draw, ...S.discard, ...S.hand].map(c => c.uid);
    uid = Math.max(0, ...ids) + 1000;
    S.hand.forEach(c => seen.add(c.uid));
    show(data.screen === 'builder' && !B ? 'classes' : data.screen || 'game');
  } else show('splash');
}
window.claude?.hot?.snapshot?.(() => ({ S, B, screen }));
window.claude?.hot?.ready ? window.claude.hot.ready(boot) : boot(window.claude?.hot?.data ?? {});
