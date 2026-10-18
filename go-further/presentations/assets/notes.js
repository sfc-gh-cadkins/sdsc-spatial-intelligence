/* ==========================================================================
   notes.js — presenter notes in a pop-up window, plus in-browser editing
   Works with any deck that marks the current slide with `.slide.active`
   (deck.js and the workshop-intro inline script both do).

   Markup contract
   ---------------
     <section class="slide">
       ...slide content...
       <aside class="notes">What to say on this slide.</aside>
     </section>

   Keys
   ----
     N            open the notes window. It follows the deck as you flip.
     E            toggle edit mode: click any slide text and type.
     Cmd/Ctrl+S   save the page, including edited slides and notes. In
                  Chrome and Edge you pick the file to overwrite (choose
                  this deck's index.html); other browsers download a copy.

   Notes are editable in the notes window; edits copy straight into the
   deck, so Cmd/Ctrl+S from either window saves them. Arrow keys in the
   notes window flip slides unless you're typing in the notes.
   ========================================================================== */

(function () {
  'use strict';

  var slides = Array.prototype.slice.call(document.querySelectorAll('.slide'));
  if (!slides.length) return;

  var MARK = 'data-notes-js';
  var style = document.createElement('style');
  style.setAttribute(MARK, '');
  style.textContent =
    '.slide aside.notes { display: none !important; }' +
    '.notes-editing [contenteditable="true"]:hover { outline: 1px dashed rgba(41,181,232,.7); }' +
    '.notes-edit-banner { position: fixed; top: 10px; left: 50%; transform: translateX(-50%); z-index: 9999;' +
    ' background: #29b5e8; color: #fff; font: 600 13px/1 -apple-system, sans-serif; padding: 8px 14px;' +
    ' border-radius: 999px; box-shadow: 0 2px 8px rgba(0,0,0,.25); }';
  document.head.appendChild(style);

  var win = null;
  var editing = false;
  var banner = null;
  var deckRoot = document.querySelector('.deck') || document.body;

  function titleOf(slide) {
    if (!slide) return '';
    var h = slide.querySelector('h1, h2, h3');
    return h ? h.textContent.replace(/\s+/g, ' ').trim() : '';
  }

  function currentIndex() {
    for (var i = 0; i < slides.length; i++) {
      if (slides[i].classList.contains('active')) return i;
    }
    return 0;
  }

  function notesFor(slide, create) {
    var aside = slide.querySelector('aside.notes');
    if (!aside && create) {
      aside = document.createElement('aside');
      aside.className = 'notes';
      slide.appendChild(aside);
    }
    return aside;
  }

  function el(doc, tag, cls, text) {
    var n = doc.createElement(tag);
    if (cls) n.className = cls;
    if (text) n.textContent = text;
    return n;
  }

  /* ---------- notes window ---------- */

  function render() {
    if (!win || win.closed) return;
    var doc = win.document;
    var i = currentIndex();
    var slide = slides[i];
    var aside = notesFor(slide, false);

    doc.getElementById('count').textContent = (i + 1) + ' / ' + slides.length;
    doc.getElementById('now').textContent = titleOf(slide) || 'Slide ' + (i + 1);
    doc.getElementById('next').textContent =
      i + 1 < slides.length ? 'Next: ' + (titleOf(slides[i + 1]) || 'Slide ' + (i + 2)) : 'Last slide';

    var body = doc.getElementById('notes');
    // Notes are authored in this repo, so copying their markup is safe.
    body.innerHTML = aside && aside.innerHTML.trim() ? aside.innerHTML : '';
    body.scrollTop = 0;
    doc.documentElement.scrollTop = 0;
  }

  function build(doc) {
    doc.title = 'Speaker notes - ' + document.title;
    var css = el(doc, 'style');
    css.textContent =
      'body{margin:0;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#111827;color:#f3f4f6}' +
      'header{position:sticky;top:0;display:flex;justify-content:space-between;align-items:center;padding:12px 20px;background:#1f2937}' +
      '#count{font-weight:600;font-variant-numeric:tabular-nums}#hint{color:#9ca3af;font-size:13px}' +
      'main{padding:16px 20px 48px}#now{font-size:22px;font-weight:700;margin:0 0 4px}' +
      '#next{color:#9ca3af;margin:0 0 16px}' +
      '#notes{font-size:19px;line-height:1.55;outline:none;min-height:3em;border-radius:6px;padding:4px}' +
      '#notes:focus{box-shadow:0 0 0 1px #29b5e8}#notes:empty:before{content:"No notes for this slide. Click to add some.";color:#6b7280;font-style:italic}' +
      '#notes h3{font-size:15px;text-transform:uppercase;letter-spacing:.06em;color:#29b5e8;margin:1.2em 0 .3em}' +
      '#notes ul{padding-left:1.2em}#notes li{margin:0 0 .4em}#notes blockquote{margin:.4em 0;padding-left:12px;border-left:3px solid #29b5e8}' +
      '#notes table{border-collapse:collapse;font-size:16px}#notes td{border-top:1px solid #374151;padding:6px 8px;vertical-align:top}' +
      '#notes hr{border:0;border-top:1px solid #374151;margin:1.5em 0}';
    doc.head.appendChild(css);

    var header = el(doc, 'header');
    var count = el(doc, 'span'); count.id = 'count';
    var hint = el(doc, 'span', '', 'Click notes to edit · Cmd/Ctrl+S saves'); hint.id = 'hint';
    header.appendChild(count); header.appendChild(hint);

    var main = el(doc, 'main');
    var now = el(doc, 'h1'); now.id = 'now';
    var next = el(doc, 'p'); next.id = 'next';
    var notes = el(doc, 'div'); notes.id = 'notes';
    notes.contentEditable = 'true';
    main.appendChild(now); main.appendChild(next); main.appendChild(notes);
    doc.body.appendChild(header); doc.body.appendChild(main);

    // Copy edits into the deck so saving from either window keeps them.
    notes.addEventListener('input', function () {
      notesFor(slides[currentIndex()], true).innerHTML = notes.innerHTML;
    });

    doc.addEventListener('keydown', function (e) {
      if (isSave(e)) { e.preventDefault(); save(); return; }
      if (e.target.isContentEditable) return;
      var keys = ['ArrowRight', 'ArrowLeft', ' ', 'PageDown', 'PageUp', 'Enter', 'Home', 'End'];
      if (keys.indexOf(e.key) === -1) return;
      e.preventDefault();
      document.dispatchEvent(new KeyboardEvent('keydown', { key: e.key, bubbles: true }));
    });
  }

  function openNotes() {
    if (win && !win.closed) { win.focus(); return; }
    win = window.open('', 'speaker-notes', 'width=760,height=640');
    if (!win) { alert('Allow pop-ups for this page to open speaker notes.'); return; }
    win.document.open();
    win.document.write('<!doctype html><html><head><meta charset="utf-8"></head><body></body></html>');
    win.document.close();
    build(win.document);
    render();
  }

  /* ---------- edit mode ---------- */

  function setEditing(on) {
    editing = on;
    deckRoot.contentEditable = on ? 'true' : 'false';
    if (!on) deckRoot.removeAttribute('contenteditable');
    document.body.classList.toggle('notes-editing', on);
    if (on && !banner) {
      banner = document.createElement('div');
      banner.className = 'notes-edit-banner';
      banner.setAttribute(MARK, '');
      banner.textContent = 'Editing · Esc to stop · Cmd/Ctrl+S to save';
      document.body.appendChild(banner);
    } else if (!on && banner) {
      banner.remove();
      banner = null;
    }
  }

  /* ---------- save ---------- */

  function isSave(e) {
    return (e.metaKey || e.ctrlKey) && (e.key === 's' || e.key === 'S');
  }

  function serialize() {
    var root = document.documentElement.cloneNode(true);
    Array.prototype.forEach.call(root.querySelectorAll('[' + MARK + ']'), function (n) { n.remove(); });
    Array.prototype.forEach.call(root.querySelectorAll('[contenteditable]'), function (n) { n.removeAttribute('contenteditable'); });
    var body = root.querySelector('body');
    if (body) {
      body.classList.remove('notes-editing');
      if (!body.className) body.removeAttribute('class');
    }
    // Save with the first slide active, matching how the deck opens.
    Array.prototype.forEach.call(root.querySelectorAll('.slide'), function (s, i) {
      s.classList.toggle('active', i === 0);
    });
    return '<!DOCTYPE html>\n' + root.outerHTML + '\n';
  }

  function save() {
    var html = serialize();
    if (window.showSaveFilePicker) {
      window.showSaveFilePicker({
        suggestedName: 'index.html',
        types: [{ description: 'HTML', accept: { 'text/html': ['.html'] } }]
      }).then(function (handle) {
        return handle.createWritable().then(function (w) {
          return w.write(html).then(function () { return w.close(); });
        });
      }).catch(function (err) {
        if (err && err.name !== 'AbortError') alert('Save failed: ' + err.message);
      });
      return;
    }
    var a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([html], { type: 'text/html' }));
    a.download = 'index.html';
    document.body.appendChild(a);
    a.click();
    setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
  }

  /* ---------- keys ---------- */

  // Capture phase, so typing in edit mode never reaches the deck's
  // navigation handler (which would flip slides on space or arrows).
  window.addEventListener('keydown', function (e) {
    if (isSave(e)) { e.preventDefault(); e.stopImmediatePropagation(); save(); return; }
    if (editing && e.target.isContentEditable) {
      if (e.key === 'Escape') { e.preventDefault(); setEditing(false); }
      e.stopImmediatePropagation();
      return;
    }
    var tag = (e.target.tagName || '').toLowerCase();
    if (['input', 'select', 'textarea'].indexOf(tag) !== -1) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (e.key === 'n' || e.key === 'N') { e.preventDefault(); e.stopImmediatePropagation(); openNotes(); }
    else if (e.key === 'e' || e.key === 'E') { e.preventDefault(); e.stopImmediatePropagation(); setEditing(!editing); }
  }, true);

  var observer = new MutationObserver(render);
  slides.forEach(function (s) { observer.observe(s, { attributes: true, attributeFilter: ['class'] }); });
  window.addEventListener('beforeunload', function () { if (win && !win.closed) win.close(); });
})();
