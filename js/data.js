/* Tam İsabet — oyun verileri: renkler, nadirlikler, ikonlar, sınıflar, kartlar, tılsımlar,
   bekçiler, olaylar, başarımlar ve kilit açma sırası.
   Kart/olay etkileri game.js içindeki yardımcıları (S, inst, drawN, refill...) kullanır. */

const SUITS = {
  red:   { name: 'Kızıl', svg: '<circle cx="12" cy="12" r="8.5"/>' },
  blue:  { name: 'Mavi',  svg: '<rect x="4" y="4" width="16" height="16" rx="2.5"/>' },
  green: { name: 'Yeşil', svg: '<path d="M12 3 22 20H2z"/>' },
  gold:  { name: 'Sarı',  svg: '<path d="M12 2 21 12 12 22 3 12z"/>' },
};
const SUIT_KEYS = Object.keys(SUITS);

/* Nadirlik: basitten nadire beyaz, mavi, mor, sarı, kırmızı */
const RARITY = {
  common:    { name: 'Sıradan',  color: '#ece7db', w: 60,  max: 2, price: 3 },
  rare:      { name: 'Nadir',    color: '#4b8dff', w: 26,  max: 2, price: 5 },
  unique:    { name: 'Ender',    color: '#b066ff', w: 10,  max: 2, price: 7 },
  legendary: { name: 'Efsanevi', color: '#f5c518', w: 4,   max: 1, price: 9 },
  epic:      { name: 'Epik',     color: '#ff3b3b', w: 1.5, max: 1, price: 12 },
};
const RARITY_ORDER = ['common', 'rare', 'unique', 'legendary', 'epic'];

/* 24x24 çizgi ikonlar (stroke = currentColor) */
const ICONS = {
  flask: '<path d="M9 3h6M10 3v6L4.5 19a1.5 1.5 0 0 0 1.3 2h12.4a1.5 1.5 0 0 0 1.3-2L14 9V3"/><path d="M7 15h10"/>',
  flame: '<path d="M12 21c-3.9 0-6-2.7-6-5.8 0-4 4-5.7 4-10.2 2.8 1.8 4 4 4 6.3 1-.8 1.7-1.8 2-3 1.6 1.8 2 4 2 6.9 0 3.1-2.1 5.8-6 5.8z"/>',
  eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>',
  star: '<path d="M12 3l2.6 5.6 6.1.7-4.5 4.2 1.2 6L12 16.6 6.6 19.5l1.2-6L3.3 9.3l6.1-.7z"/>',
  coin: '<circle cx="12" cy="12" r="8"/><path d="M12 6.5v11M14.8 9.2c-.6-.8-1.6-1.2-2.8-1.2-1.6 0-2.8.8-2.8 2s1.2 1.7 2.8 2 2.8.9 2.8 2.1-1.2 2-2.8 2c-1.3 0-2.4-.5-3-1.3"/>',
  skull: '<path d="M5 11a7 7 0 1 1 14 0v3l-2 1v3H7v-3l-2-1z"/><circle cx="9.5" cy="11.5" r="1.5"/><circle cx="14.5" cy="11.5" r="1.5"/><path d="M10 18v-2M14 18v-2"/>',
  dice: '<rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="9" cy="9" r="1"/><circle cx="15" cy="15" r="1"/><circle cx="15" cy="9" r="1"/><circle cx="9" cy="15" r="1"/><circle cx="12" cy="12" r="1"/>',
  mirror: '<ellipse cx="12" cy="9" rx="6" ry="7"/><path d="M12 16v5M9 21h6M9.5 6.5a3 3 0 0 1 2.5-1.5"/>',
  scale: '<path d="M12 3v18M5 7h14M5 7l-3 6h6zM19 7l-3 6h6zM8 21h8"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3"/>',
  rainbow: '<path d="M3 18a9 9 0 0 1 18 0M6.5 18a5.5 5.5 0 0 1 11 0M10 18a2 2 0 0 1 4 0"/>',
  hourglass: '<path d="M6 3h12M6 21h12M7 3c0 5 10 7 10 9s-10 4-10 9M17 3c0 5-10 7-10 9"/>',
  compass: '<circle cx="12" cy="12" r="9"/><path d="M15.5 8.5 13 13l-4.5 2.5L11 11z"/>',
  brush: '<path d="M18 3l3 3-9 9-3-3z"/><path d="M9 12c-3 0-5 2-5 5 0 1-1 2-2 2 2 2 7 2 9-1 1-1.5 1-3.5 1-3.5"/>',
  dagger: '<path d="M14 3l7 7-9 9-3-1-1-3z"/><path d="M5 19l-2 2M7 14l3 3"/>',
  return: '<path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/>',
  cards: '<rect x="5" y="3" width="11" height="15" rx="1.5"/><path d="M9 21h9a1.5 1.5 0 0 0 1.5-1.5V7"/>',
  rune: '<path d="M12 2l8 5v10l-8 5-8-5V7z"/><path d="M9 9h6v6H9z"/>',
  spear: '<path d="M20 4 9 15M20 4l-1 5-4-4zM9 15l-4 4M7 13l4 4"/>',
  banner: '<path d="M5 21V3M5 4h12l-3 4 3 4H5"/>',
  wall: '<path d="M3 20V8h18v12zM3 12h18M3 16h18M9 8v4M15 8v4M6 12v4M12 12v4M18 12v4M9 16v4M15 16v4"/>',
  volcano: '<path d="M3 20 9 9h6l6 11zM10 9l-1-4M14 9l1-4M12 9V3"/>',
  wave: '<path d="M2 14c3-4 5 4 8 0s5 4 8 0 3-2 4-1M2 19c3-4 5 4 8 0s5 4 8 0 3-2 4-1M8 9c1-3 3-5 4-6 1 2 3 3 3 6"/>',
  orb: '<circle cx="12" cy="10" r="7"/><path d="M7 21h10M8 17.5l-1 3.5M16 17.5l1 3.5M9 8a3 3 0 0 1 3-2"/>',
  moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.3 6.3 0 0 0 10.5 10.5z"/>',
  thread: '<path d="M4 20c4-8 12-8 16-16"/><circle cx="7" cy="16" r="1.5"/><circle cx="17" cy="7" r="1.5"/><path d="M4 4c3 1 4 3 4 5"/>',
  fog: '<path d="M3 10h14M6 14h15M3 18h12M8 6h9"/>',
  bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1"/>',
  gem: '<path d="M12 2 20 8 17 20H7L4 8z"/><path d="M4 8h16M9 8l3 12 3-12"/>',
  potion: '<path d="M10 2h4M10 2v5a6 6 0 1 0 4 0V2"/><path d="M7 14h10"/>',
  transform: '<path d="M4 12a8 8 0 0 1 14-5M20 12a8 8 0 0 1-14 5"/><path d="M18 3v4h-4M6 21v-4h4"/>',
  spark: '<path d="M12 2v6M12 16v6M2 12h6M16 12h6M5 5l3.5 3.5M15.5 15.5 19 19M5 19l3.5-3.5M15.5 8.5 19 5"/>',
  fireball: '<circle cx="14" cy="10" r="6"/><path d="M9 14 3 20M10 17l-3 4M7 12l-4 3"/>',
  ash: '<path d="M3 20h18M5 20c1-4 3-6 7-6s6 2 7 6M10 14c0-2 1-3 2-5 1 2 2 3 2 5"/>',
  fuel: '<path d="M5 21V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v16zM5 11h10M15 8h2a2 2 0 0 1 2 2v7a1.5 1.5 0 0 0 3 0V9l-3-3"/>',
  starmap: '<circle cx="6" cy="6" r="1.5"/><circle cx="18" cy="9" r="1.5"/><circle cx="10" cy="18" r="1.5"/><path d="M7 7l9.5 1.6M17 10.5 11 17"/>',
  swords: '<path d="M4 4l10 10M14 14l2 4 2-2-4-2M20 4 10 14M10 14l-2 4-2-2 4-2"/>',
  tower: '<path d="M6 21V8h12v13M6 8V4h2v2h2V4h4v2h2V4h2v4M10 21v-4h4v4"/>',
  stone: '<path d="M4 18l2.5-8L13 6l6 4 1.5 8z"/><path d="M9 12l3 2"/>',
  heart: '<path d="M12 20.5s-8-5-8-10.7A4.4 4.4 0 0 1 12 7.2a4.4 4.4 0 0 1 8 2.6c0 5.7-8 10.7-8 10.7z"/>',
  hand: '<path d="M8 13V5a1.5 1.5 0 0 1 3 0v6M11 11V4a1.5 1.5 0 0 1 3 0v7M14 11V5.5a1.5 1.5 0 0 1 3 0V14c0 4-2.5 7-6 7-2.5 0-4-1.5-5.5-3.5L3.8 15a1.5 1.5 0 0 1 2.4-1.8L8 15"/>',
  shift: '<path d="M4 9h15l-3-3M20 15H5l3 3"/>',
  reroll: '<path d="M20 12a8 8 0 1 1-2.4-5.7"/><path d="M20 4v4h-4"/>',
  gift: '<rect x="4" y="10" width="16" height="10" rx="1"/><path d="M3 7h18v3H3zM12 7v13M12 7C10 3 6 4 7.5 7M12 7c2-4 6-3 4.5 0"/>',
  mask: '<path d="M3 10c3-2 6-2 9 0 3-2 6-2 9 0-1 5.5-5.5 6.5-9 3.5-3.5 3-8 2-9-3.5z"/><circle cx="8" cy="11" r="1"/><circle cx="16" cy="11" r="1"/>',
  wind: '<path d="M3 9h11a3 3 0 1 0-3-3M3 15h15a3 3 0 1 1-3 3M3 12h6"/>',
  storm: '<path d="M7 15a4 4 0 1 1 1-7.9A5 5 0 0 1 17.6 9 3 3 0 0 1 17 15z"/><path d="M9 18l-1 3M13 18l-1 3M17 18l-1 3"/>',
  swap: '<rect x="3" y="6" width="8" height="12" rx="1.5"/><rect x="13" y="6" width="8" height="12" rx="1.5"/><path d="M7 3h10l-2-2M17 21H7l2 2"/>',
  spring: '<path d="M12 21c-4 0-7-2.5-7-6 0-4 4-6 7-12 3 6 7 8 7 12 0 3.5-3 6-7 6z"/><path d="M12 11v6M9 14h6"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
  crown: '<path d="M3 18 5 7l5 5 2-7 2 7 5-5 2 11z"/><path d="M3 21h18"/>',
  infinity: '<path d="M6.5 15.5c-2 0-3.5-1.6-3.5-3.5s1.5-3.5 3.5-3.5C10 8.5 14 15.5 17.5 15.5c2 0 3.5-1.6 3.5-3.5s-1.5-3.5-3.5-3.5C14 8.5 10 15.5 6.5 15.5z"/>',
  trophy: '<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M7 6H4a3 3 0 0 0 3 4M17 6h3a3 3 0 0 1-3 4"/>',
  tooth: '<path d="M7 3c-2 0-3 2-3 4 0 3 1 5 2 8s1 6 3 6 2-5 3-5 1 5 3 5 2-3 3-6 2-5 2-8c0-2-1-4-3-4-2 0-3 1-5 1S9 3 7 3z"/>',
  wolf: '<path d="M4 4l4 5h8l4-5v9l-4 6h-8l-4-6z"/><circle cx="9.5" cy="12" r="1"/><circle cx="14.5" cy="12" r="1"/><path d="M11 16h2"/>',
  bag: '<path d="M6 8h12l1 13H5zM9 8V6a3 3 0 0 1 6 0v2"/>',
  target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>',
};

const CLASSES = {
  guard: {
    name: 'Muhafız', icon: 'shield', tagline: 'Sabırlı oynar, canını korur.',
    power: { name: 'Siper', icon: 'tower', text: 'Bu tur +1 oynama hakkı kazan.' },
  },
  alchemist: {
    name: 'Simyacı', icon: 'flask', tagline: 'Sayıları büker, sonucu ince ayarlar.',
    power: { name: 'Damıtma', icon: 'potion', text: 'Sonraki oynamada toplam hedefe 1 uzaksa da isabet sayılır.' },
  },
  pyro: {
    name: 'Kor Büyücüsü', icon: 'flame', tagline: 'Elini yakar, büyük sayılarla vurur.',
    power: { name: 'Kor Yığını', icon: 'spark', text: 'Seçili kartları ıskartaya at, yerine 1 fazlasını çek. Değiştirme hakkı harcamaz.' },
  },
  seer: {
    name: 'Kâhin', icon: 'eye', tagline: 'Olayları önceden görür ve yönlendirir.',
    power: { name: 'Kehanet', icon: 'orb', text: 'Sıradaki olayı iki seçenekten biriyle değiştir.' },
  },
};
const CLASS_KEYS = Object.keys(CLASSES);

/* Sayı kartları: 4 renk × 1–9 */
const NUMBER_CARDS = [];
for (const c of SUIT_KEYS) for (let v = 1; v <= 9; v++) {
  NUMBER_CARDS.push({ id: `n-${c}-${v}`, name: `${SUITS[c].name} ${v}`, cls: 'neutral', rarity: 'common', kind: 'num', value: v, color: c, isNumber: true, text: `Değeri ${v}.` });
}

/* Özel kartlar.
   kind: num (renkli sayı) | add (renksiz değer) | op (işlem) | wild (joker) | spell (büyü, tek başına kullanılır) | curse
   onPlay / onHit / onMiss: play() içinde işlenen etkiler · spell: SPELLS anahtarı · exhaust: oynanınca desteden kalıcı çıkar */
const SPECIAL_CARDS = [
  // Nötr
  { id: 'mul2', name: '×2 Çarpan', cls: 'neutral', rarity: 'rare', kind: 'op', op: 'mul', value: 2, gem: '×2', glyph: '×2', text: 'Seçimin toplamını 2 katına çıkarır.' },
  { id: 'mul3', name: '×3 Çarpan', cls: 'neutral', rarity: 'unique', kind: 'op', op: 'mul', value: 3, gem: '×3', glyph: '×3', text: 'Seçimin toplamını 3 katına çıkarır.' },
  { id: 'div2', name: '÷2 Bölücü', cls: 'neutral', rarity: 'common', kind: 'op', op: 'div', value: 2, gem: '÷2', glyph: '÷2', text: 'Toplamı ikiye böler, küsuratı atar.' },
  { id: 'joker', name: 'Joker', cls: 'neutral', rarity: 'rare', kind: 'wild', max: 9, gem: '★', icon: 'star', text: '1 ile 9 arasında gereken değeri alır.' },
  { id: 'shadow2', name: 'Gölge', cls: 'neutral', rarity: 'common', kind: 'add', value: -2, gem: '−2', icon: 'moon', text: 'Toplamdan 2 düşer.' },
  { id: 'shadow5', name: 'Derin Gölge', cls: 'neutral', rarity: 'rare', kind: 'add', value: -5, gem: '−5', icon: 'moon', text: 'Toplamdan 5 düşer.' },
  { id: 'add5', name: 'Takviye', cls: 'neutral', rarity: 'common', kind: 'add', value: 5, gem: '+5', glyph: '+5', text: 'Toplama 5 ekler.' },
  { id: 'add10', name: 'Kuşatma', cls: 'neutral', rarity: 'rare', kind: 'add', value: 10, gem: '+10', glyph: '+10', text: 'Toplama 10 ekler.' },
  { id: 'square', name: 'Kare Rünü', cls: 'neutral', rarity: 'legendary', kind: 'op', op: 'square', gem: 'x²', icon: 'rune', text: 'Toplamın karesini alır. Çarpanlardan önce uygulanır.' },
  { id: 'mirror', name: 'Ayna', cls: 'neutral', rarity: 'legendary', kind: 'op', op: 'mirror', gem: '⇄', icon: 'mirror', text: 'Sonucun basamaklarını ters çevirir: 17, 71 olur.' },
  { id: 'equal', name: 'Eşitleyici', cls: 'neutral', rarity: 'rare', kind: 'op', op: 'equalize', gem: '=', icon: 'scale', text: 'Seçimdeki tüm sayı kartları en yükseğinin değerini alır.' },
  { id: 'echo', name: 'Yansıma', cls: 'neutral', rarity: 'common', kind: 'op', op: 'copy', gem: '↺', icon: 'copy', text: 'Seçimdeki en yüksek sayı kartının değerini bir kez daha ekler.' },
  { id: 'rainbow', name: 'Gökkuşağı', cls: 'neutral', rarity: 'rare', kind: 'num', value: 3, color: 'rainbow', icon: 'rainbow', text: 'Değeri 3. Her rengin yerine geçer, renk serisini tamamlar.' },
  { id: 'dice', name: 'Kumarbaz Zarı', cls: 'neutral', rarity: 'rare', kind: 'add', roll: [1, 12], value: 6, gem: '?', icon: 'dice', text: 'Eline her geldiğinde değeri 1–12 arasında yeniden belirlenir.' },
  { id: 'coin', name: 'Altın Sikke', cls: 'neutral', rarity: 'unique', kind: 'num', value: 7, color: 'gold', icon: 'coin', onHit: 'triple', onMiss: 'losePlay', text: 'Değeri 7. İsabette skor ×3. Iskada 1 oynama hakkı daha gider.' },
  { id: 'cursed13', name: 'Lanetli 13', cls: 'neutral', rarity: 'rare', kind: 'add', value: 13, gem: '13', icon: 'skull', onPlay: 'loseDiscard', text: 'Değeri 13. Oynandığında 1 değiştirme hakkı yer.' },
  { id: 'scout', name: 'Keşif', cls: 'neutral', rarity: 'common', kind: 'spell', spell: 'draw2', icon: 'cards', text: '2 kart çek.' },
  { id: 'recall', name: 'Geri Çağır', cls: 'neutral', rarity: 'common', kind: 'spell', spell: 'recall', icon: 'return', text: 'Iskartadaki son sayı kartını eline geri al.' },
  { id: 'painter', name: 'Boyacı', cls: 'neutral', rarity: 'rare', kind: 'spell', spell: 'paint', icon: 'brush', text: 'Elindeki sayı kartlarını en çok bulunan renge boyar.' },
  { id: 'shield', name: 'Kalkan', cls: 'neutral', rarity: 'unique', kind: 'spell', spell: 'shield', icon: 'shield', text: 'Bu tur oynama hakların biterse can kaybetmezsin.' },
  { id: 'timewarp', name: 'Zaman Bükümü', cls: 'neutral', rarity: 'epic', kind: 'spell', spell: 'plays2', icon: 'hourglass', text: 'Bu tur +2 oynama hakkı.' },
  { id: 'compass', name: 'Pusula', cls: 'neutral', rarity: 'common', kind: 'spell', spell: 'compass', icon: 'compass', text: 'Hedefi 1–3 azaltır.' },
  { id: 'sacrifice', name: 'Kurban', cls: 'neutral', rarity: 'rare', kind: 'spell', spell: 'sacrifice', icon: 'dagger', text: 'Elinden rastgele bir kartı kalıcı olarak yok et, +1 oynama hakkı kazan.' },

  // Muhafız
  { id: 'spear', name: 'Mızrak', cls: 'guard', rarity: 'common', kind: 'num', value: 8, color: 'blue', icon: 'spear', text: 'Değeri 8.' },
  { id: 'watch', name: 'Nöbet', cls: 'guard', rarity: 'common', kind: 'add', value: 4, gem: '+4', icon: 'tower', text: 'Toplama 4 ekler.' },
  { id: 'fortify', name: 'Tahkimat', cls: 'guard', rarity: 'rare', kind: 'spell', spell: 'plays1', icon: 'tower', text: 'Bu tur +1 oynama hakkı.' },
  { id: 'discipline', name: 'Disiplin', cls: 'guard', rarity: 'rare', kind: 'op', op: 'discipline', value: 5, gem: '+5', icon: 'swords', text: 'Seçimdeki sayı kartlarının hepsi aynı renkse toplama 5 ekler.' },
  { id: 'wall', name: 'Kalkan Duvarı', cls: 'guard', rarity: 'unique', kind: 'spell', spell: 'wall', icon: 'wall', text: 'Bu tur can kaybını önler, +1 değiştirme hakkı verir.' },
  { id: 'standard', name: 'Sancak', cls: 'guard', rarity: 'legendary', kind: 'num', value: 5, color: 'gold', icon: 'banner', onHit: 'heal', text: 'Değeri 5. İsabette 1 can kazandırır (en fazla 4).' },

  // Simyacı
  { id: 'distill', name: 'Damıtık Öz', cls: 'alchemist', rarity: 'common', kind: 'add', value: 3, gem: '+3', icon: 'potion', text: 'Toplama 3 ekler.' },
  { id: 'catalyst', name: 'Katalizör', cls: 'alchemist', rarity: 'common', kind: 'op', op: 'perCard', gem: '+n', icon: 'gear', text: 'Seçimdeki her kart için toplama 1 ekler.' },
  { id: 'transmute', name: 'Dönüşüm', cls: 'alchemist', rarity: 'rare', kind: 'spell', spell: 'transmute', icon: 'transform', text: 'Elindeki 1 ve 2 değerli sayı kartları 6 olur.' },
  { id: 'elixir', name: 'İksir', cls: 'alchemist', rarity: 'rare', kind: 'spell', spell: 'elixir', icon: 'flask', text: 'Sınıf gücünü yeniler ve 1 kart çeker.' },
  { id: 'div3', name: 'Çözücü', cls: 'alchemist', rarity: 'unique', kind: 'op', op: 'div', value: 3, gem: '÷3', glyph: '÷3', text: 'Toplamı üçe böler, küsuratı atar.' },
  { id: 'philo', name: 'Filozof Taşı', cls: 'alchemist', rarity: 'legendary', kind: 'wild', max: 20, gem: '★', icon: 'gem', text: '1 ile 20 arasında gereken değeri alır.' },

  // Kor Büyücüsü
  { id: 'spark', name: 'Kıvılcım', cls: 'pyro', rarity: 'common', kind: 'num', value: 2, color: 'red', icon: 'spark', onPlay: 'draw1', text: 'Değeri 2. Oynandığında 1 kart çek.' },
  { id: 'fuel', name: 'Yakıt', cls: 'pyro', rarity: 'common', kind: 'spell', spell: 'fuel', icon: 'fuel', text: 'Elinden rastgele bir kart yanar. +1 değiştirme hakkı kazan.' },
  { id: 'flamewave', name: 'Alev Dalgası', cls: 'pyro', rarity: 'rare', kind: 'spell', spell: 'flamewave', icon: 'wave', text: 'Elini ıskartaya at, 1 fazla kart çek.' },
  { id: 'fireball', name: 'Ateş Topu', cls: 'pyro', rarity: 'rare', kind: 'add', value: 11, gem: '11', icon: 'fireball', exhaust: true, text: 'Değeri 11. Oynandıktan sonra desteden kalıcı olarak yanar.' },
  { id: 'ash', name: 'Kül Yığını', cls: 'pyro', rarity: 'unique', kind: 'add', dyn: 'ash', value: 0, gem: 'X', icon: 'ash', text: 'Değeri ıskartadaki kart sayısı kadar, en fazla 15.' },
  { id: 'volcano', name: 'Volkan', cls: 'pyro', rarity: 'epic', kind: 'op', op: 'mul', value: 4, gem: '×4', icon: 'volcano', exhaust: true, text: 'Toplamı 4 katına çıkarır. Oynandıktan sonra yanar.' },

  // Kâhin
  { id: 'moonlight', name: 'Ay Işığı', cls: 'seer', rarity: 'common', kind: 'num', value: 6, color: 'blue', icon: 'moon', onHit: 'omen', text: 'Değeri 6. İsabette olay sayacını 1 ilerletir.' },
  { id: 'thirdeye', name: 'Üçüncü Göz', cls: 'seer', rarity: 'common', kind: 'spell', spell: 'thirdeye', icon: 'eye', text: 'Sıradaki olayı yenisiyle değiştirir ve 1 kart çeker.' },
  { id: 'fog', name: 'Sis', cls: 'seer', rarity: 'common', kind: 'add', value: -3, gem: '−3', icon: 'fog', onPlay: 'draw1', text: 'Toplamdan 3 düşer. Oynandığında 1 kart çek.' },
  { id: 'orb', name: 'Kristal Küre', cls: 'seer', rarity: 'rare', kind: 'spell', spell: 'orb', icon: 'orb', text: 'Olay sayacını 1 ilerletir.' },
  { id: 'starmap', name: 'Yıldız Haritası', cls: 'seer', rarity: 'unique', kind: 'spell', spell: 'starmap', icon: 'starmap', text: 'Çekme destesindeki en yüksek sayı kartını eline al.' },
  { id: 'fate', name: 'Kader İpliği', cls: 'seer', rarity: 'epic', kind: 'op', op: 'tolerance', value: 3, gem: '≈', icon: 'thread', text: 'Toplam hedefe 3 veya daha yakınsa isabet sayılır.' },

  // Lanet (olaylarla desteye girer, koleksiyonda yok)
  { id: 'stone', name: 'Taş', cls: 'curse', rarity: 'common', kind: 'curse', value: 0, gem: '0', icon: 'stone', noCollect: true, text: 'Değeri 0. Elinde yer kaplar.' },
];

const CARD = {};
for (const c of [...NUMBER_CARDS, ...SPECIAL_CARDS]) CARD[c.id] = c;

/* Tılsımlar: kalıcı bonuslar (en fazla 5). score(ctx) isabet skoruna katkı yapar.
   ctx.chips(n, etiket) · ctx.mult(n, etiket) · ctx.x(n, etiket) */
const suitMult = col => ctx => { const n = ctx.nums.filter(c => c.color === col || c.color === 'rainbow').length; if (n) ctx.mult(n, `+${n} Çarpan`); };
const CHARMS = [
  { id: 'c_red', name: 'Kızıl Mühür', rarity: 'common', icon: 'gem', suit: 'red', text: 'İsabetteki her Kızıl kart +1 Çarpan.', score: suitMult('red') },
  { id: 'c_blue', name: 'Mavi Mühür', rarity: 'common', icon: 'gem', suit: 'blue', text: 'İsabetteki her Mavi kart +1 Çarpan.', score: suitMult('blue') },
  { id: 'c_green', name: 'Yeşil Mühür', rarity: 'common', icon: 'gem', suit: 'green', text: 'İsabetteki her Yeşil kart +1 Çarpan.', score: suitMult('green') },
  { id: 'c_gold', name: 'Sarı Mühür', rarity: 'common', icon: 'gem', suit: 'gold', text: 'İsabetteki her Sarı kart +1 Çarpan.', score: suitMult('gold') },
  { id: 'crowd', name: 'Kalabalık', rarity: 'common', icon: 'hand', text: '4 veya daha fazla kartla yapılan isabette +3 Çarpan.', score: ctx => { if (ctx.cards.length >= 4) ctx.mult(3, '+3 Çarpan'); } },
  { id: 'goldtooth', name: 'Altın Diş', rarity: 'common', icon: 'tooth', text: 'Her isabette +1 altın kazandırır.', gold: 1 },
  { id: 'lone', name: 'Yalnız Kurt', rarity: 'rare', icon: 'wolf', text: '2 veya daha az kartla yapılan isabette +4 Çarpan.', score: ctx => { if (ctx.cards.length <= 2) ctx.mult(4, '+4 Çarpan'); } },
  { id: 'hunter', name: 'Seri Avcısı', rarity: 'rare', icon: 'rainbow', text: 'Renk serisi yapan isabette +4 Çarpan.', score: ctx => { if (ctx.combo) ctx.mult(4, '+4 Çarpan'); } },
  { id: 'hoarder', name: 'Biriktirici', rarity: 'rare', icon: 'swap', text: 'Kalan her değiştirme hakkı için +1 Çarpan.', score: ctx => { if (ctx.discards) ctx.mult(ctx.discards, `+${ctx.discards} Çarpan`); } },
  { id: 'merchant', name: 'Tüccar Dostu', rarity: 'rare', icon: 'bag', text: 'Tüccardaki her şey 1 altın ucuz.', discount: 1 },
  { id: 'even', name: 'Simetri', rarity: 'rare', icon: 'scale', text: 'Hedef çift sayıysa +3 Çarpan.', score: ctx => { if (ctx.target % 2 === 0) ctx.mult(3, '+3 Çarpan'); } },
  { id: 'spellbag', name: 'Büyü Kesesi', rarity: 'rare', icon: 'potion', text: 'Bu tur kullandığın her büyü için +2 Çarpan.', score: ctx => { if (ctx.spells) ctx.mult(ctx.spells * 2, `+${ctx.spells * 2} Çarpan`); } },
  { id: 'nearshot', name: 'Yakın Atış', rarity: 'unique', icon: 'target', text: 'Toplam hedefe 1 uzaksa da isabet sayılır.', tolerance: 1 },
  { id: 'firststrike', name: 'İlk Darbe', rarity: 'unique', icon: 'bolt', text: 'Turun ilk oynaması isabetse skor ×2.', score: ctx => { if (ctx.first) ctx.x(2, '×2'); } },
  { id: 'prime', name: 'Asal Ruh', rarity: 'unique', icon: 'rune', text: 'Hedef asal sayıysa skor ×2.', score: ctx => { const p = n => { if (n < 2) return false; for (let i = 2; i * i <= n; i++) if (n % i === 0) return false; return true; }; if (p(ctx.target)) ctx.x(2, '×2'); } },
  { id: 'gambler', name: 'Kumar Masası', rarity: 'unique', icon: 'dice', text: 'Her isabette 0–6 arası rastgele Çarpan.', score: ctx => { if (ctx.preview) return; const n = Math.floor(Math.random() * 7); ctx.mult(n, `+${n} Çarpan`); } },
  { id: 'stoneheart', name: 'Taş Kalp', rarity: 'unique', icon: 'stone', text: 'Destendeki her Taş için +2 Çarpan.', score: ctx => { if (ctx.stones) ctx.mult(ctx.stones * 2, `+${ctx.stones * 2} Çarpan`); } },
  { id: 'seereye', name: 'Kâhin Gözü', rarity: 'legendary', icon: 'eye', text: 'Olaylar 3 yerine 2 isabette bir gerçekleşir.', eventEvery: 2 },
  { id: 'giant', name: 'Dev Avcısı', rarity: 'legendary', icon: 'tower', text: 'Hedef 30 veya üstüyse skor ×2.', score: ctx => { if (ctx.target >= 30) ctx.x(2, '×2'); } },
  { id: 'goldshield', name: 'Altın Kalkan', rarity: 'legendary', icon: 'shield', text: 'Bir kez can kaybını önler, sonra kırılır.', lifeSave: true },
  { id: 'infinity', name: 'Sonsuz Halka', rarity: 'epic', icon: 'infinity', text: 'Her isabette kalıcı olarak +1 Çarpan biriktirir.', score: ctx => { const m = ctx.state.m || 0; if (m) ctx.mult(m, `+${m} Çarpan`); }, onHit: st => { st.m = (st.m || 0) + 1; } },
  { id: 'crown', name: 'Hükümdar Tacı', rarity: 'epic', icon: 'crown', text: 'Skor ×3, ama her tur 1 oynama hakkın eksik olur.', score: ctx => ctx.x(3, '×3'), playsMod: -1 },
];
const CHARM = {};
for (const c of CHARMS) CHARM[c.id] = c;

/* Bekçiler: her katın 3. turu özel kurallıdır */
const BOSSES = {
  redban: { name: 'Kızıl Yasak', icon: 'skull', text: 'Kızıl sayı kartları 0 değerinde sayılır.' },
  nodiscard: { name: 'Kısır Döngü', icon: 'swap', text: 'Bu tur değiştirme hakkı yok.' },
  slippery: { name: 'Kaygan Hedef', icon: 'shift', text: 'Her oynamadan sonra hedef değişir.' },
  heavy: { name: 'Ağır El', icon: 'hand', text: 'Elinde 1 kart eksik tutarsın.' },
  silence: { name: 'Sessizlik', icon: 'fog', text: 'Büyü kartları kullanılamaz.' },
  short: { name: 'Dar Vakit', icon: 'hourglass', text: '1 oynama hakkın eksik.' },
};

/* Önerilen desteler: 20 sayı + 4 sınıfa uygun başlangıç kartı = 24 */
const BASE_NUMS = [];
for (const c of SUIT_KEYS) for (let v = 1; v <= 4; v++) BASE_NUMS.push(`n-${c}-${v}`);
BASE_NUMS.push('n-red-6', 'n-blue-7', 'n-green-8', 'n-gold-9');
const RECOMMENDED = {
  guard: [...BASE_NUMS, 'mul2', 'spear', 'watch', 'add5'],
  alchemist: [...BASE_NUMS, 'mul2', 'distill', 'catalyst', 'add5'],
  pyro: [...BASE_NUMS, 'mul2', 'spark', 'fuel', 'add5'],
  seer: [...BASE_NUMS, 'mul2', 'moonlight', 'thirdeye', 'fog'],
};

/* Kilitler: başlangıçta açık olanlar, sınıf açılınca gelenler, turları geçtikçe açılma sırası */
const STARTER_UNLOCKS = [...NUMBER_CARDS.map(c => c.id), 'mul2', 'add5', 'shadow2', 'div2', 'scout', 'spear', 'watch', 'distill', 'catalyst', 'c_red', 'c_blue', 'crowd', 'goldtooth'];
const STARTER_CLASSES = ['guard', 'alchemist'];
const CLASS_UNLOCK_CARDS = { pyro: ['spark', 'fuel'], seer: ['moonlight', 'thirdeye', 'fog'] };
const rarityRank = r => RARITY_ORDER.indexOf(r);
const UNLOCK_ORDER = [...SPECIAL_CARDS.filter(c => !c.noCollect).map(c => ({ id: c.id, rarity: c.rarity, cls: c.cls })), ...CHARMS.map(c => ({ id: c.id, rarity: c.rarity, cls: 'neutral' }))]
  .sort((a, b) => rarityRank(a.rarity) - rarityRank(b.rarity));

/* Başarımlar: koşul sağlanınca ödülleri açılır */
const ACHIEVEMENTS = [
  { id: 'tutorial', name: 'Çırak', icon: 'star', text: 'Öğreticiyi bitir.', unlocks: ['joker', 'echo'] },
  { id: 'firsthit', name: 'İlk İsabet', icon: 'target', text: 'İlk isabetini yap.', unlocks: ['compass'] },
  { id: 'combo', name: 'Renk Ustası', icon: 'rainbow', text: 'Bir renk serisi yap.', unlocks: ['rainbow', 'c_green'] },
  { id: 'round3', name: 'Yolun Başı', icon: 'banner', text: 'Bir oyunda 3. turu geç.', unlocks: ['class:pyro'] },
  { id: 'boss1', name: 'Bekçi Avcısı', icon: 'skull', text: 'Bir bekçiyi yen.', unlocks: ['shield', 'hunter'] },
  { id: 'round6', name: 'Kararlı', icon: 'tower', text: 'Bir oyunda 6. turu geç.', unlocks: ['class:seer'] },
  { id: 'big200', name: 'Dev Vuruş', icon: 'bolt', text: 'Tek oynamada 200 skor yap.', unlocks: ['mul3'] },
  { id: 'score1000', name: 'Bin Puan', icon: 'coin', text: 'Bir oyunda toplam 1000 skora ulaş.', unlocks: ['add10', 'c_gold'] },
  { id: 'spells10', name: 'Büyücü Çırağı', icon: 'potion', text: 'Toplam 10 büyü kullan.', unlocks: ['painter', 'spellbag'] },
  { id: 'charms3', name: 'Koleksiyoncu', icon: 'bag', text: 'Aynı anda 3 tılsım taşı.', unlocks: ['merchant'] },
  { id: 'five', name: 'Kalabalık El', icon: 'hand', text: '5 veya daha fazla kartla isabet yap.', unlocks: ['equal'] },
  { id: 'lives4', name: 'Dört Can', icon: 'heart', text: '4 cana ulaş.', unlocks: ['standard'] },
  { id: 'rich', name: 'Hazine', icon: 'coin', text: 'Aynı anda 25 altına sahip ol.', unlocks: ['goldshield'] },
  { id: 'round9', name: 'Efsane', icon: 'crown', text: 'Bir oyunda 9. turu geç.', unlocks: ['timewarp'] },
];

/* Olaylar: her isabet sayısına ulaşıldığında sıradaki olay gerçekleşir */
const EVENTS = {
  shift: { w: 3, name: 'Hedef Kaydı', tone: 'neutral', hint: 'Hedef 1–4 sayı kayar.', icon: 'shift',
    run() { const old = S.target, d = (1 + rnd(4)) * (Math.random() < .5 ? -1 : 1); S.target = Math.max(4, S.target + d); return { text: `Hedef ${old} iken ${S.target} oldu.` }; } },
  reroll: { w: 2, name: 'Yeni Hedef', tone: 'neutral', hint: 'Hedef baştan belirlenir.', icon: 'reroll',
    run() { const old = S.target; S.target = newTarget(); return { text: `Hedef ${old} yerine artık ${S.target}.` }; } },
  gift: { w: 3, name: 'Hediye Kart', tone: 'good', hint: 'Destene güçlü bir kart girer.', icon: 'gift',
    run() { const c = inst(rollCardId(S.cls, 1.6)); S.master.push(c); insertRandom(c); return { text: `Destene kalıcı olarak ${cardName(c)} eklendi.`, card: c }; } },
  treasure: { w: 2, name: 'Hazine Sandığı', tone: 'good', hint: '3–6 altın kazanırsın.', icon: 'coin',
    run() { const g = 3 + rnd(4); S.gold += g; return { text: `${g} altın buldun. Artık ${S.gold} altının var.` }; } },
  stone: { w: 2, name: 'Taş Düştü', tone: 'bad', hint: 'Destene 0 değerli bir Taş girer.', icon: 'stone',
    run() { const c = inst('stone'); S.master.push(c); S.draw.push(c); return { text: 'Destene bir Taş girdi, sıradaki çekişte eline gelecek. Tüccarda desteden çıkarabilirsin.', card: c }; } },
  burn: { w: 2, name: 'Yangın', tone: 'bad', hint: 'Elinden rastgele bir kart yanar.', icon: 'flame', ok: () => S.hand.length > 0,
    run() { const c = pick(S.hand); removeForever(c); refill(); return { text: `Elindeki ${cardName(c)} yandı ve desteden tamamen çıktı.`, card: c }; } },
  thief: { w: 1, name: 'Hırsız', tone: 'bad', hint: 'En yüksek sayı kartın çalınır.', icon: 'mask', ok: () => S.hand.some(isNum),
    run() { const c = S.hand.filter(isNum).sort((a, b) => b.value - a.value)[0]; removeForever(c); refill(); return { text: `En yüksek kartın ${cardName(c)} çalındı.`, card: c }; } },
  boost: { w: 2, name: 'Renk Fırtınası', tone: 'good', hint: 'Bir renk 2 oynama boyunca ×2 değer.', icon: 'bolt', ok: () => !S.mods.some(m => m.type === 'boost'),
    run() { const col = pick(SUIT_KEYS); S.mods.push({ type: 'boost', color: col, turns: 2 }); return { text: `Sonraki 2 oynamada ${SUITS[col].name.toLowerCase()} sayı kartları iki kat değerli.` }; } },
  wind: { w: 2, name: 'Arka Rüzgâr', tone: 'good', hint: '+1 oynama hakkı kazanırsın.', icon: 'wind',
    run() { S.plays++; return { text: 'Bu tur için +1 oynama hakkı kazandın.' }; } },
  storm: { w: 1, name: 'Fırtına', tone: 'bad', hint: '1 değiştirme hakkı gider.', icon: 'storm', ok: () => S.discards > 0,
    run() { S.discards--; return { text: 'Bu tur 1 değiştirme hakkını kaybettin.' }; } },
  shadow: { w: 2, name: 'Gölge Kart', tone: 'neutral', hint: 'Destene eksi değerli bir kart girer.', icon: 'moon',
    run() { const c = inst(Math.random() < .7 ? 'shadow2' : 'shadow5'); S.master.push(c); insertRandom(c); return { text: `Destene ${cardName(c)} eklendi. Toplamdan düşer, ince ayar için işe yarar.`, card: c }; } },
  swap: { w: 1, name: 'Takas', tone: 'neutral', hint: 'Elindeki tüm kartlar yenilenir.', icon: 'swap',
    run() { S.discard.push(...S.hand); S.hand = []; S.sel = []; refill(); return { text: 'Elindeki tüm kartlar ıskartaya gitti, yeni bir el çekildi.' }; } },
  heal: { w: 1, name: 'Şifa Kaynağı', tone: 'good', hint: '1 can kazanırsın (en fazla 4).', icon: 'spring', ok: () => S.lives < MAX_LIVES,
    run() { S.lives++; heartFx = { type: 'gain', i: S.lives - 1 }; return { text: `Bir can kazandın. Artık ${S.lives} canın var.` }; } },
};
