/* ==========================================================================
   notes.js — presenter notes in a pop-up window, with autosave
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
     N   open the notes window. It follows the deck as you flip.
     E   toggle slide edit mode: click any slide text and type. Esc stops.

   In the notes window, arrow keys, space, or the Back and Next buttons flip
   slides. Click Edit to change the notes, then Done or Esc.

   Notes-only pages
   ----------------
   Notes for the parts of the talk that happen outside the deck (labs,
   demos) go after the last slide:
     <section class="notes-page" data-topic="Lab: Types">
       <aside class="notes">...</aside>
     </section>
   They never show in the deck. In the notes window, Next on the last slide
   moves on to them without moving the deck, and the topic menu jumps
   straight to any of them.

   Autosave
   --------
   Edits save about a second after you stop typing.
     - Served by serve.py (python3 serve.py in this folder): edits are
       written straight into this deck's index.html.
     - Anywhere else (GitHub Pages, a plain file): note edits are kept in
       this browser only and reapplied when the deck reopens. Slide edits
       need serve.py.
   ========================================================================== */

(function () {
  'use strict';

  var slides = Array.prototype.slice.call(document.querySelectorAll('.slide'));
  if (!slides.length) return;
  // Slides, then notes-only pages. Notes pages follow every slide in the
  // file, so pages[i] is slides[i] for every slide index.
  var pages = Array.prototype.slice.call(document.querySelectorAll('.slide, .notes-page'));
  var extras = pages.slice(slides.length);

  var MARK = 'data-notes-js';
  var STORE_KEY = 'speaker-notes:' + location.pathname;
  var style = document.createElement('style');
  style.setAttribute(MARK, '');
  style.textContent =
    '.slide aside.notes, .notes-page { display: none !important; }' +
    '.notes-editing [contenteditable="true"]:hover { outline: 1px dashed rgba(41,181,232,.7); }' +
    '.notes-edit-banner { position: fixed; top: 10px; left: 50%; transform: translateX(-50%); z-index: 9999;' +
    ' background: #29b5e8; color: #fff; font: 600 13px/1 -apple-system, sans-serif; padding: 8px 14px;' +
    ' border-radius: 999px; box-shadow: 0 2px 8px rgba(0,0,0,.25); }';
  document.head.appendChild(style);

  var win = null;
  // The page whose notes the notes window is showing; edits save to it.
  var shownIndex = 0;
  var editing = false;
  var banner = null;
  var deckRoot = document.querySelector('.deck') || document.body;

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

  /* ---------- runtime-state snapshot ----------
     Deck scripts change classes and inline styles as you present (reveal
     steps, progress bar). Record them at load so a save writes the deck
     back the way it was authored, not mid-presentation. */

  var RUNTIME = '.substep, .reveal-item, #progress, #counter';
  var snapshot = Array.prototype.map.call(document.querySelectorAll(RUNTIME), function (n) {
    return { cls: n.getAttribute('class'), style: n.getAttribute('style'), text: n.id === 'counter' ? n.textContent : null };
  });

  function restoreAttr(n, name, value) {
    if (value === null) n.removeAttribute(name); else n.setAttribute(name, value);
  }

  function serialize() {
    var root = document.documentElement.cloneNode(true);
    Array.prototype.forEach.call(root.querySelectorAll('[' + MARK + ']'), function (n) { n.remove(); });
    Array.prototype.forEach.call(root.querySelectorAll('[contenteditable]'), function (n) { n.removeAttribute('contenteditable'); });
    Array.prototype.forEach.call(root.querySelectorAll('[data-revealed]'), function (n) { n.removeAttribute('data-revealed'); });
    Array.prototype.forEach.call(root.querySelectorAll(RUNTIME), function (n, i) {
      var s = snapshot[i];
      if (!s) return;
      restoreAttr(n, 'class', s.cls);
      restoreAttr(n, 'style', s.style);
      if (s.text !== null) n.textContent = s.text;
    });
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

  /* ---------- autosave ---------- */

  var statusEls = [];
  var saveTimer = null;
  var lastStatus = '';
  // Slide edits need the whole page; note edits only send the notes, so the
  // server can swap them into the file without touching any other markup.
  var slidesDirty = false;

  function setStatus(text) {
    lastStatus = text;
    statusEls.forEach(function (s) { s.textContent = text; });
  }

  function readStore() {
    try { return JSON.parse(localStorage.getItem(STORE_KEY) || '{}'); } catch (e) { return {}; }
  }

  function currentNotes() {
    return pages.map(function (s) {
      var a = notesFor(s, false);
      return a ? a.innerHTML : '';
    });
  }

  // Notes as the file had them when the page loaded (before any stored edits),
  // so a save sends only slides whose notes actually changed.
  var savedNotes = currentNotes();

  function changedNotes() {
    var out = {};
    currentNotes().forEach(function (n, i) { if (n !== savedNotes[i]) out[i] = n; });
    return out;
  }

  function writeStore() {
    var data = {};
    currentNotes().forEach(function (n, i) { data[i] = n; });
    try { localStorage.setItem(STORE_KEY, JSON.stringify(data)); return true; } catch (e) { return false; }
  }

  function saveNow() {
    clearTimeout(saveTimer);
    saveTimer = null;
    var full = slidesDirty;
    var changed = changedNotes();
    var sending = currentNotes();
    if (!full && !Object.keys(changed).length) { setStatus('No changes'); return; }
    var canPut = location.protocol === 'http:' || location.protocol === 'https:';
    var put = canPut
      ? fetch(location.pathname, {
          method: 'PUT',
          headers: {
            'Content-Type': full ? 'text/html; charset=utf-8' : 'application/json',
            'X-Notes-Save': '1'
          },
          body: full ? serialize() : JSON.stringify({ notes: changed })
        }).then(function (r) { return r.ok; }).catch(function () { return false; })
      : Promise.resolve(false);
    put.then(function (ok) {
      var time = new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
      if (ok) {
        if (full) slidesDirty = false;
        savedNotes = sending;
        try { localStorage.removeItem(STORE_KEY); } catch (e) { /* ignore */ }
        setStatus('Saved to file ' + time);
      } else if (writeStore()) {
        setStatus('Saved in this browser ' + time + ' (run serve.py to save to the file)');
      } else {
        setStatus('Not saved');
      }
    });
  }

  function scheduleSave() {
    setStatus('Saving…');
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveNow, 900);
  }

  // Reapply note edits kept in this browser from a session without serve.py.
  (function applyStored() {
    var data = readStore();
    Object.keys(data).forEach(function (k) {
      var s = pages[+k];
      if (!s) return;
      var a = notesFor(s, true);
      if (a.innerHTML !== data[k]) a.innerHTML = data[k];
    });
  })();

  /* ---------- notes window ---------- */

  // Show the notes for the deck's current slide.
  function render() {
    shownIndex = currentIndex();
    paint();
  }

  function paint() {
    if (!win || win.closed) return;
    var doc = win.document;
    var aside = notesFor(pages[shownIndex], false);
    var body = doc.getElementById('notes');
    // Notes are authored in this repo, so copying their markup is safe.
    body.innerHTML = aside && aside.innerHTML.trim() ? aside.innerHTML : '';
    var menu = doc.getElementById('topic');
    if (menu) menu.value = shownIndex < slides.length ? 'slides' : String(shownIndex);
    doc.documentElement.scrollTop = 0;
  }

  function build(doc) {
    doc.title = 'Speaker notes - ' + document.title;
    var css = el(doc, 'style');
    css.textContent =
      'body{margin:0;background:#fff;color:#1f2937;font:20px/1.7 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}' +
      '#notes{padding:28px 32px 110px;outline:none;min-height:80vh}' +
      '#notes[contenteditable="true"]{box-shadow:inset 0 0 0 2px #29b5e8}' +
      '#notes:empty:before{content:"No notes for this slide.";color:#9ca3af;font-style:italic}' +
      '#notes p,#notes ul,#notes blockquote,#notes table{margin:0 0 1.1em}' +
      '#notes ul{padding-left:1.3em}#notes li{margin:0 0 .6em}' +
      '#notes h3{font-size:14px;text-transform:uppercase;letter-spacing:.07em;color:#11567f;margin:2em 0 .6em;padding-top:1em;border-top:1px solid #e5e7eb}' +
      '#notes h3:first-child{margin-top:0;padding-top:0;border-top:0}' +
      '#notes blockquote{padding:.2em 0 .2em 14px;border-left:3px solid #29b5e8;color:#374151}' +
      '#notes table{border-collapse:collapse;font-size:18px}#notes td{border-top:1px solid #e5e7eb;padding:8px 10px;vertical-align:top}' +
      '#notes hr{border:0;border-top:2px solid #e5e7eb;margin:2em 0}' +
      '#notes code{font-size:.9em;background:#f3f4f6;padding:1px 5px;border-radius:4px}' +
      '#bar{position:fixed;left:0;right:0;bottom:0;display:flex;gap:10px;align-items:center;justify-content:flex-end;padding:12px 20px;background:rgba(255,255,255,.94);border-top:1px solid #e5e7eb}' +
      '#status{flex:1;color:#6b7280;font:14px -apple-system,sans-serif}' +
      '#bar button{font:600 16px -apple-system,sans-serif;padding:10px 18px;border-radius:999px;border:1px solid #d1d5db;background:#fff;color:#1f2937;cursor:pointer}' +
      '#bar button:hover{background:#f3f4f6}#bar .edit.on{border-color:#29b5e8;color:#11567f}' +
      '#bar select{font:15px -apple-system,sans-serif;padding:9px 10px;border-radius:10px;border:1px solid #d1d5db;background:#fff;color:#1f2937;max-width:240px}' +
      '#bar .next{background:#29b5e8;border-color:#29b5e8;color:#fff}#bar .next:hover{background:#1e9fcc}';
    doc.head.appendChild(css);

    var notes = el(doc, 'div'); notes.id = 'notes';
    doc.body.appendChild(notes);

    var bar = el(doc, 'div'); bar.id = 'bar';
    var status = el(doc, 'span'); status.id = 'status'; status.textContent = lastStatus;
    var edit = el(doc, 'button', 'edit', 'Edit');
    var back = el(doc, 'button', 'back', '\u2190 Back');
    var fwd = el(doc, 'button', 'next', 'Next \u2192');
    var items = [status];
    var menu = null;
    if (extras.length) {
      menu = el(doc, 'select'); menu.id = 'topic';
      var first = el(doc, 'option', null, 'Slides'); first.value = 'slides';
      menu.appendChild(first);
      extras.forEach(function (p, i) {
        var o = el(doc, 'option', null, p.getAttribute('data-topic') || 'Notes ' + (i + 1));
        o.value = String(slides.length + i);
        menu.appendChild(o);
      });
      items.push(menu);
    }
    items.push(edit, back, fwd);
    items.forEach(function (n) { bar.appendChild(n); });
    doc.body.appendChild(bar);
    statusEls.push(status);

    function flip(key) {
      document.dispatchEvent(new KeyboardEvent('keydown', { key: key, bubbles: true }));
    }

    // Notes are read-only until you click Edit, so arrow keys always flip
    // slides. Done, Esc, Back, or Next stops editing.
    function startEditing() {
      notes.contentEditable = 'true';
      edit.textContent = 'Done';
      edit.classList.add('on');
      notes.focus();
    }
    function stopEditing() {
      if (!notes.isContentEditable) return;
      notes.removeAttribute('contenteditable');
      notes.blur();
      edit.textContent = 'Edit';
      edit.classList.remove('on');
      if (saveTimer) saveNow();
    }

    // Step forward or back. Past the last slide, step through the notes-only
    // pages and leave the deck where it is.
    function go(dir) {
      stopEditing();
      var last = slides.length - 1;
      if (shownIndex > last) {
        shownIndex += dir;
        if (shownIndex > pages.length - 1) shownIndex = pages.length - 1;
        if (shownIndex <= last) { render(); return; }
        paint();
        return;
      }
      if (dir > 0 && currentIndex() === last && extras.length) {
        shownIndex = last + 1;
        paint();
        return;
      }
      flip(dir > 0 ? 'ArrowRight' : 'ArrowLeft');
    }

    edit.addEventListener('click', function () { if (notes.isContentEditable) stopEditing(); else startEditing(); });
    back.addEventListener('click', function () { go(-1); });
    fwd.addEventListener('click', function () { go(1); });
    if (menu) {
      menu.addEventListener('change', function () {
        stopEditing();
        if (menu.value === 'slides') render(); else { shownIndex = +menu.value; paint(); }
        menu.blur();
      });
    }
    notes.addEventListener('dblclick', function () { if (!notes.isContentEditable) startEditing(); });
    // Keep focus off the buttons so Space and Enter don't flip twice.
    bar.addEventListener('mousedown', function (e) { if (e.target.tagName !== 'SELECT') e.preventDefault(); });

    // Copy edits into the deck, then autosave.
    notes.addEventListener('input', function () {
      notesFor(pages[shownIndex], true).innerHTML = notes.innerHTML;
      scheduleSave();
    });

    doc.addEventListener('keydown', function (e) {
      if (isSave(e)) { e.preventDefault(); saveNow(); return; }
      if (e.target.isContentEditable) { if (e.key === 'Escape') stopEditing(); return; }
      if (e.target.tagName === 'SELECT') return;
      if (['ArrowRight', ' ', 'PageDown', 'Enter'].indexOf(e.key) !== -1) { e.preventDefault(); go(1); return; }
      if (['ArrowLeft', 'PageUp'].indexOf(e.key) !== -1) { e.preventDefault(); go(-1); return; }
      if (e.key === 'Home' || e.key === 'End') { e.preventDefault(); flip(e.key); render(); }
    });
  }

  function openNotes() {
    if (win && !win.closed) { win.focus(); return; }
    win = window.open('', 'speaker-notes', 'width=760,height=640');
    if (!win) { alert('Allow pop-ups for this page to open speaker notes.'); return; }
    win.document.open();
    win.document.write('<!doctype html><html><head><meta charset="utf-8"></head><body></body></html>');
    win.document.close();
    statusEls = [];
    build(win.document);
    render();
  }

  /* ---------- slide edit mode ---------- */

  function setEditing(on) {
    editing = on;
    if (on) deckRoot.contentEditable = 'true'; else deckRoot.removeAttribute('contenteditable');
    document.body.classList.toggle('notes-editing', on);
    if (on && !banner) {
      banner = document.createElement('div');
      banner.className = 'notes-edit-banner';
      banner.setAttribute(MARK, '');
      banner.textContent = 'Editing slides · Esc to stop · autosaves';
      document.body.appendChild(banner);
    } else if (!on && banner) {
      banner.remove();
      banner = null;
      if (slidesDirty) saveNow();
    }
  }

  deckRoot.addEventListener('input', function () {
    if (!editing) return;
    slidesDirty = true;
    scheduleSave();
  });

  /* ---------- keys ---------- */

  function isSave(e) {
    return (e.metaKey || e.ctrlKey) && (e.key === 's' || e.key === 'S');
  }

  // Capture phase, so typing in edit mode never reaches the deck's
  // navigation handler (which would flip slides on space or arrows).
  window.addEventListener('keydown', function (e) {
    if (isSave(e)) { e.preventDefault(); e.stopImmediatePropagation(); saveNow(); return; }
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
  window.addEventListener('beforeunload', function () {
    if (saveTimer) saveNow();
    if (win && !win.closed) win.close();
  });
})();
