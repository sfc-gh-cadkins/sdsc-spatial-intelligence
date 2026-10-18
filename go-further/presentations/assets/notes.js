/* ==========================================================================
   notes.js — presenter notes in a pop-up window
   Works with any deck that marks the current slide with `.slide.active`
   (deck.js and the workshop-intro inline script both do).

   Markup contract
   ---------------
     <section class="slide">
       ...slide content...
       <aside class="notes">What to say on this slide.</aside>
     </section>

   Press N to open the notes window. It follows the deck as you flip, shows
   the current and next slide titles, the notes, and an elapsed timer.
   Arrow keys, space, Home, and End typed in the notes window drive the deck.
   ========================================================================== */

(function () {
  'use strict';

  var slides = Array.prototype.slice.call(document.querySelectorAll('.slide'));
  if (!slides.length) return;

  var style = document.createElement('style');
  style.textContent = '.slide aside.notes { display: none !important; }';
  document.head.appendChild(style);

  var win = null;
  var startedAt = null;
  var timerId = null;

  function titleOf(slide) {
    if (!slide) return '';
    var h = slide.querySelector('h1, h2, h3');
    return h ? h.textContent.trim() : '';
  }

  function currentIndex() {
    for (var i = 0; i < slides.length; i++) {
      if (slides[i].classList.contains('active')) return i;
    }
    return 0;
  }

  function el(doc, tag, cls, text) {
    var n = doc.createElement(tag);
    if (cls) n.className = cls;
    if (text) n.textContent = text;
    return n;
  }

  function render() {
    if (!win || win.closed) return;
    var doc = win.document;
    var i = currentIndex();
    var slide = slides[i];
    var notes = slide.querySelector('aside.notes');

    doc.getElementById('count').textContent = (i + 1) + ' / ' + slides.length;
    doc.getElementById('now').textContent = titleOf(slide) || 'Slide ' + (i + 1);
    doc.getElementById('next').textContent =
      i + 1 < slides.length ? 'Next: ' + (titleOf(slides[i + 1]) || 'Slide ' + (i + 2)) : 'Last slide';

    var body = doc.getElementById('notes');
    body.textContent = '';
    if (notes) {
      // Notes are authored in this repo, so cloning their markup is safe.
      Array.prototype.forEach.call(notes.childNodes, function (n) {
        body.appendChild(doc.importNode(n, true));
      });
    } else {
      body.appendChild(el(doc, 'p', 'empty', 'No notes for this slide.'));
    }
  }

  function tick() {
    if (!win || win.closed) { clearInterval(timerId); return; }
    var s = Math.floor((Date.now() - startedAt) / 1000);
    var mm = String(Math.floor(s / 60)).padStart(2, '0');
    var ss = String(s % 60).padStart(2, '0');
    win.document.getElementById('timer').textContent = mm + ':' + ss;
  }

  function build(doc) {
    doc.title = 'Speaker notes - ' + document.title;
    var css = el(doc, 'style');
    css.textContent =
      'body{margin:0;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#111827;color:#f3f4f6}' +
      'header{display:flex;justify-content:space-between;align-items:center;padding:12px 20px;background:#1f2937;font-variant-numeric:tabular-nums}' +
      '#count{font-weight:600}#timer{font-size:22px;font-weight:600;cursor:pointer}' +
      'main{padding:16px 20px}#now{font-size:22px;font-weight:700;margin:0 0 4px}' +
      '#next{color:#9ca3af;margin:0 0 16px}#notes{font-size:20px;line-height:1.55}' +
      '#notes ul{padding-left:1.2em}#notes li{margin:0 0 .4em}.empty{color:#6b7280;font-style:italic}' +
      'footer{position:fixed;bottom:0;left:0;right:0;padding:8px 20px;color:#6b7280;font-size:13px;background:#111827}';
    doc.head.appendChild(css);

    var header = el(doc, 'header');
    var count = el(doc, 'span'); count.id = 'count';
    var timer = el(doc, 'span', '', '00:00'); timer.id = 'timer'; timer.title = 'Click to reset';
    header.appendChild(count); header.appendChild(timer);

    var main = el(doc, 'main');
    var now = el(doc, 'h1'); now.id = 'now';
    var next = el(doc, 'p'); next.id = 'next';
    var notes = el(doc, 'div'); notes.id = 'notes';
    main.appendChild(now); main.appendChild(next); main.appendChild(notes);

    var footer = el(doc, 'footer', '', 'Arrow keys or space flip the deck from here. Click the timer to reset it.');

    doc.body.appendChild(header); doc.body.appendChild(main); doc.body.appendChild(footer);

    timer.addEventListener('click', function () { startedAt = Date.now(); tick(); });

    // Forward navigation keys to the deck so you can drive it from this window.
    doc.addEventListener('keydown', function (e) {
      var keys = ['ArrowRight', 'ArrowLeft', ' ', 'PageDown', 'PageUp', 'Enter', 'Home', 'End'];
      if (keys.indexOf(e.key) === -1) return;
      e.preventDefault();
      document.dispatchEvent(new KeyboardEvent('keydown', { key: e.key, bubbles: true }));
    });
  }

  function open() {
    if (win && !win.closed) { win.focus(); return; }
    win = window.open('', 'speaker-notes', 'width=720,height=560');
    if (!win) { alert('Allow pop-ups for this page to open speaker notes.'); return; }
    win.document.open();
    win.document.write('<!doctype html><html><head><meta charset="utf-8"></head><body></body></html>');
    win.document.close();
    build(win.document);
    startedAt = Date.now();
    clearInterval(timerId);
    timerId = setInterval(tick, 1000);
    render();
  }

  document.addEventListener('keydown', function (e) {
    var tag = (e.target.tagName || '').toLowerCase();
    if (['input', 'select', 'textarea'].indexOf(tag) !== -1) return;
    if ((e.key === 'n' || e.key === 'N') && !e.metaKey && !e.ctrlKey && !e.altKey) {
      e.preventDefault();
      open();
    }
  });

  var observer = new MutationObserver(render);
  slides.forEach(function (s) { observer.observe(s, { attributes: true, attributeFilter: ['class'] }); });
  window.addEventListener('beforeunload', function () { if (win && !win.closed) win.close(); });
})();
