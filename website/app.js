(() => {
  'use strict';

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------- Download details (written by the deploy workflow) ---------- */

  fetch('download/meta.json')
    .then((r) => (r.ok ? r.json() : Promise.reject()))
    .then((meta) => {
      $$('[data-version]').forEach((el) => (el.textContent = meta.version));
      $$('[data-size]').forEach((el) => (el.textContent = (meta.bytes / 1e6).toFixed(1) + ' MB'));
      $$('[data-sha]').forEach((el) => (el.textContent = meta.sha256));
    })
    .catch(() => { /* Keep the defaults written in the HTML. */ });

  /* ---------- Platform note ---------- */

  const ua = navigator.userAgent || '';
  const touch = /iPhone|iPad|iPod|Android/i.test(ua) || (navigator.maxTouchPoints > 1 && /Mac/.test(ua));
  const isMac = /Mac/i.test(navigator.userAgentData?.platform || navigator.platform || ua) && !touch;
  const note = $('[data-platform-note]');
  if (note && !isMac) {
    note.textContent = touch
      ? 'Waiting Room runs on Macs only. Open this page on your Mac to download it.'
      : 'Waiting Room runs on Apple silicon Macs only. You can still download the installer to move it to a Mac.';
    note.hidden = false;
  }

  /* ---------- After-click guidance ---------- */

  const after = $('[data-after]');
  $$('[data-download]').forEach((link) => {
    link.addEventListener('click', () => {
      if (!after) return;
      after.hidden = false;
      if (!link.closest('.hero')) {
        after.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth', block: 'center' });
      }
    });
  });

  /* ---------- Mode tabs ---------- */

  const tabs = $('[data-tabs]');
  if (tabs) {
    const buttons = $$('[role="tab"]', tabs);
    const select = (button) => {
      buttons.forEach((b) => {
        const on = b === button;
        b.setAttribute('aria-selected', String(on));
        b.tabIndex = on ? 0 : -1;
        $('#' + b.getAttribute('aria-controls')).hidden = !on;
      });
    };
    buttons.forEach((b, i) => {
      b.addEventListener('click', () => select(b));
      b.addEventListener('keydown', (e) => {
        const dir = { ArrowRight: 1, ArrowLeft: -1 }[e.key];
        if (!dir) return;
        e.preventDefault();
        const next = buttons[(i + dir + buttons.length) % buttons.length];
        select(next);
        next.focus();
      });
    });
  }

  /* ---------- Hero demo ----------
     A scripted run of what the app does: select a region, watch it change,
     notice that it stopped, and report back. Text strings mirror the app's own. */

  const demo = $('[data-demo]');
  if (!demo) return;

  const bar = $('[data-bar]', demo);
  const count = $('[data-count]', demo);
  const status = $('[data-status]', demo);
  const TOTAL = 212;
  let token = 0;

  const setState = (state, text) => {
    demo.dataset.state = state;
    status.textContent = text;
  };
  const setProgress = (n) => {
    count.textContent = n;
    bar.style.width = (n / TOTAL) * 100 + '%';
  };

  const reset = () => {
    demo.classList.remove('has-region');
    setProgress(0);
    setState('idle', 'Select a region');
  };

  const finishInstantly = () => {
    demo.classList.add('has-region');
    setProgress(TOTAL);
    setState('done', 'Done');
  };

  async function play() {
    const id = ++token;
    const alive = () => id === token;

    reset();
    if (reduceMotion) { finishInstantly(); return; }

    await sleep(900); if (!alive()) return;
    demo.classList.add('has-region');
    setState('armed', 'Waiting for activity to begin…');

    await sleep(1300); if (!alive()) return;
    for (let n = 0; n <= TOTAL; n += 3) {
      setProgress(Math.min(n, TOTAL));
      if (n === 0) setState('changing', 'Changing now');
      await sleep(45);
      if (!alive()) return;
    }
    setProgress(TOTAL);

    await sleep(500); if (!alive()) return;
    setState('quiet', 'Quiet. Alerting after 8s of stillness');

    await sleep(2200); if (!alive()) return;
    setState('done', 'Done');
  }

  $('[data-replay]', demo).addEventListener('click', play);

  // Start when the demo is on screen, so a visitor never misses it.
  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) { io.disconnect(); play(); }
    }, { threshold: 0.4 });
    io.observe(demo);
  } else {
    play();
  }
})();
