/* Tam İsabet — görsel efektler: parçacıklar, ortam kıvılcımları, halkalar, uçan kartlar, yazılar, banner */
const FX = (() => {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const cv = document.getElementById('fx');
  const ctx = cv.getContext('2d');
  let parts = [], ambient = 0, running = false, W = 0, H = 0;

  function size() {
    const dpr = Math.min(2, devicePixelRatio || 1);
    W = innerWidth; H = innerHeight;
    cv.width = W * dpr; cv.height = H * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  addEventListener('resize', size);
  size();

  function start() { if (!running) { running = true; requestAnimationFrame(loop); } }

  function loop() {
    if (ambient > 0 && Math.random() < ambient) {
      parts.push({ type: 'glow', x: Math.random() * W, y: H + 10, vx: (Math.random() - .5) * .3, vy: -(.4 + Math.random() * .9),
        life: 1, decay: .003 + Math.random() * .004, size: 1 + Math.random() * 2, color: Math.random() < .7 ? '#ffae55' : '#ffe0a0', wob: Math.random() * 6 });
    }
    ctx.clearRect(0, 0, W, H);
    for (const p of parts) {
      p.vy += p.g || 0;
      if (p.drag) { p.vx *= p.drag; p.vy *= p.drag; }
      p.x += p.vx + (p.wob ? Math.sin(p.life * 18 + p.wob) * .35 : 0);
      p.y += p.vy;
      p.rot = (p.rot || 0) + (p.vr || 0);
      p.life -= p.decay;
      draw(p);
    }
    parts = parts.filter(p => p.life > 0 && p.y > -60 && p.y < H + 60);
    if (parts.length || ambient > 0) requestAnimationFrame(loop);
    else { running = false; ctx.clearRect(0, 0, W, H); }
  }

  function draw(p) {
    const a = Math.max(0, Math.min(1, p.life));
    ctx.save();
    if (p.type === 'glow') {
      ctx.globalCompositeOperation = 'lighter';
      ctx.globalAlpha = a;
      const r = p.size * 3;
      const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, r);
      g.addColorStop(0, p.color); g.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, 7); ctx.fill();
    } else if (p.type === 'smoke') {
      ctx.globalAlpha = a * .3;
      ctx.fillStyle = p.color;
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size * (1 + (1 - p.life) * 2.5), 0, 7); ctx.fill();
    } else {
      ctx.globalAlpha = a;
      ctx.translate(p.x, p.y); ctx.rotate(p.rot || 0);
      ctx.fillStyle = p.color;
      ctx.fillRect(-p.size / 2, -p.size / 3, p.size, p.size * .66);
    }
    ctx.restore();
  }

  /* x,y noktasında patlama. type: spark (konfeti) | glow (ışık) | smoke (duman) */
  function burst(x, y, { n = 40, colors = ['#ffe7a3'], speed = 6, g = .18, type = 'spark', size = [4, 9], decay = .014, drag = .98, up = 2.5 } = {}) {
    if (reduce) return;
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2, sp = speed * (.4 + Math.random() * .8);
      parts.push({ type, x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - up, g, drag, decay: decay * (.7 + Math.random() * .6),
        life: 1, size: size[0] + Math.random() * (size[1] - size[0]), color: colors[i % colors.length], rot: Math.random() * 6, vr: (Math.random() - .5) * .4 });
    }
    start();
  }

  const center = el => { const r = el.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; };

  function ring(x, y, color = '#ffe7a3', scale = 5) {
    if (reduce) return;
    const d = document.createElement('div');
    d.className = 'ring';
    d.style.cssText = `left:${x}px;top:${y}px;--rc:${color};--rs:${scale}`;
    document.body.appendChild(d);
    d.addEventListener('animationend', () => d.remove());
  }

  function floater(text, x, y, cls = '') {
    if (reduce) return;
    const d = document.createElement('div');
    d.className = 'floater ' + cls;
    d.textContent = text;
    d.style.left = x + 'px'; d.style.top = y + 'px';
    document.body.appendChild(d);
    d.addEventListener('animationend', () => d.remove());
  }

  function banner(title, sub = '') {
    if (reduce) return;
    const b = document.getElementById('banner');
    b.innerHTML = `<div class="rays"></div><div class="btxt"><h2>${title}</h2>${sub ? `<p>${sub}</p>` : ''}</div>`;
    b.classList.remove('show'); void b.offsetWidth; b.classList.add('show');
    b.onanimationend = e => { if (e.animationName === 'bannerOut') { b.classList.remove('show'); b.innerHTML = ''; } };
  }

  function vflash(color) {
    if (reduce) return;
    const v = document.getElementById('vflash');
    v.style.setProperty('--vc', color);
    v.classList.remove('on'); void v.offsetWidth; v.classList.add('on');
  }

  function shake(el) {
    if (reduce || !el) return;
    el.classList.remove('shake'); void el.offsetWidth; el.classList.add('shake');
  }

  function cloneOf(el) {
    const r = el.getBoundingClientRect(), cl = el.cloneNode(true);
    cl.classList.remove('deal', 'sel');
    cl.removeAttribute('aria-label');
    cl.removeAttribute('id');
    Object.assign(cl.style, { position: 'fixed', left: r.left + 'px', top: r.top + 'px', width: r.width + 'px', margin: 0, zIndex: 28, pointerEvents: 'none', animation: 'none', transform: 'none', transition: 'none' });
    cl.style.setProperty('--w', r.width + 'px');
    cl.classList.add('flying');
    document.body.appendChild(cl);
    return [cl, r];
  }

  /* Oynanan kartlar: isabette hedefe uçar, ıskada aşağı düşer */
  function flyCards(uids, hit, targetEl) {
    if (reduce) return;
    const [tx, ty] = center(targetEl);
    uids.forEach((id, i) => {
      const el = document.querySelector(`#hand [data-uid="${id}"]`);
      if (!el) return;
      const [cl, r] = cloneOf(el);
      const dx = tx - (r.left + r.width / 2), dy = ty - (r.top + r.height / 2), rot = (i - (uids.length - 1) / 2) * 16;
      const frames = hit
        ? [{ transform: 'translateY(-20px) scale(1.05)' }, { transform: `translate(${dx * .5}px,${dy * .5 - 40}px) rotate(${rot}deg) scale(.9)`, offset: .5 }, { transform: `translate(${dx}px,${dy}px) rotate(${rot * 2}deg) scale(.25)`, opacity: .2 }]
        : [{ transform: 'translateY(-20px)' }, { transform: `translate(${dx * .25}px,${dy * .35}px) rotate(${rot}deg)`, offset: .4 }, { transform: `translate(${dx * .25 + rot * 3}px,${innerHeight}px) rotate(${rot * 5}deg)`, opacity: .4 }];
      cl.animate(frames, { duration: hit ? 520 : 850, delay: i * 60, easing: hit ? 'cubic-bezier(.5,0,.3,1)' : 'cubic-bezier(.4,0,.8,.5)', fill: 'forwards' }).onfinish = () => cl.remove();
      if (!hit) setTimeout(() => { const [x, y] = [r.left + r.width / 2, r.top + r.height / 2]; burst(x, y, { n: 10, type: 'smoke', colors: ['#5a2a24', '#3a1a16'], size: [8, 14], speed: 1.5, g: -.02, decay: .02, up: .5 }); }, 250 + i * 60);
    });
  }

  /* Büyü kartı: ekranın ortasına büyür, ışığa dönüşür */
  function castCard(uid, color) {
    if (reduce) return;
    const el = document.querySelector(`#hand [data-uid="${uid}"]`);
    if (!el) return;
    const [cl, r] = cloneOf(el);
    const tx = innerWidth / 2, ty = innerHeight * .42;
    const dx = tx - (r.left + r.width / 2), dy = ty - (r.top + r.height / 2);
    cl.animate([
      { transform: 'none', filter: 'brightness(1)' },
      { transform: `translate(${dx}px,${dy}px) scale(1.9)`, filter: 'brightness(1.3)', offset: .55 },
      { transform: `translate(${dx}px,${dy}px) scale(2.1)`, filter: 'brightness(3)', opacity: 0 },
    ], { duration: 900, easing: 'cubic-bezier(.3,.7,.3,1)', fill: 'forwards' }).onfinish = () => cl.remove();
    setTimeout(() => {
      ring(tx, ty, color, 7);
      burst(tx, ty, { n: 50, type: 'glow', colors: [color, '#ffffff'], speed: 5, g: 0, size: [2, 5], decay: .018, up: 0, drag: .95 });
    }, 560);
  }

  function sparkleAt(el, color, n = 18) {
    if (reduce || !el) return;
    const [x, y] = center(el);
    burst(x, y, { n, type: 'glow', colors: [color, '#fff6d0'], speed: 3, g: 0, size: [1.5, 3.5], decay: .02, up: 0, drag: .94 });
  }

  function setAmbient(v) { ambient = reduce ? 0 : v; if (ambient > 0) start(); }

  /* Oynanan kartları elden alıp sahneye (zone öğesinin üstüne) dizer. { uid: klon } döner */
  function stageCards(uids, zone) {
    const out = {};
    if (reduce || !zone) return out;
    const z = zone.getBoundingClientRect();
    const w = Math.min(62, (z.width - 8 * (uids.length - 1)) / uids.length);
    const total = uids.length * w + (uids.length - 1) * 8;
    uids.forEach((id, i) => {
      const el = document.querySelector(`#hand [data-uid="${id}"]`);
      if (!el) return;
      const [cl, r] = cloneOf(el);
      const tx = z.left + (z.width - total) / 2 + i * (w + 8), ty = z.top + z.height / 2 - w * .7;
      const s = w / r.width;
      cl.style.transformOrigin = '0 0';
      cl.animate([{ transform: 'none' }, { transform: `translate(${tx - r.left}px,${ty - r.top}px) scale(${s})` }],
        { duration: 300, delay: i * 40, easing: 'cubic-bezier(.2,.8,.3,1.1)', fill: 'forwards' });
      out[id] = cl;
    });
    return out;
  }
  function pop(el, k = 1.22) {
    if (reduce || !el) return;
    el.animate([{ scale: '1' }, { scale: String(k) }, { scale: '1' }], { duration: 260, easing: 'ease-out' });
  }
  /* Sahnedeki kartları kaldırır: isabette hedefe uçar, ıskada düşer */
  function clearStage(map, hit, targetEl) {
    const els = Object.values(map);
    if (!els.length) return;
    const [tx, ty] = center(targetEl);
    els.forEach((cl, i) => {
      const start = getComputedStyle(cl).transform;
      const r = cl.getBoundingClientRect();
      const dx = tx - (r.left + r.width / 2), dy = ty - (r.top + r.height / 2);
      const end = hit
        ? `translate(${dx}px,${dy}px) ${start === 'none' ? '' : start} scale(.3)`
        : `translate(${(i - els.length / 2) * 30}px,${innerHeight}px) ${start === 'none' ? '' : start} rotate(${(i - 1) * 40}deg)`;
      cl.animate([{ transform: start, opacity: 1 }, { transform: end, opacity: hit ? .2 : .5 }],
        { duration: hit ? 420 : 700, delay: i * 50, easing: hit ? 'cubic-bezier(.5,0,.3,1)' : 'cubic-bezier(.4,0,.8,.5)', fill: 'forwards' }).onfinish = () => cl.remove();
    });
  }

  return { burst, ring, floater, banner, vflash, shake, flyCards, castCard, sparkleAt, setAmbient, center, reduce, stageCards, pop, clearStage };
})();
