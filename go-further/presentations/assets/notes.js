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

   In the notes window, arrow keys, space, or the Back and Next buttons
   flip slides. Double-click the notes to edit them and press Esc when
   done; edits copy straight into the deck, so Cmd/Ctrl+S saves them.
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
    var aside = notesFor(slides[currentIndex()], false);
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
      'body{margin:0;background:#fff;color:#1f2937;font:20px/1.7 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}' +
      '#notes{padding:28px 32px 96px;outline:none;min-height:80vh}' +
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
      '#nav{position:fixed;right:20px;bottom:18px;display:flex;gap:10px;align-items:center}' +
      '#status{color:#6b7280;font:14px -apple-system,sans-serif;margin-right:4px}' +
      '#nav button{font:600 16px -apple-system,sans-serif;padding:10px 18px;border-radius:999px;border:1px solid #d1d5db;background:#fff;color:#1f2937;cursor:pointer;box-shadow:0 1px 4px rgba(0,0,0,.08)}' +
      '#nav button:hover{background:#f3f4f6}#nav .edit.on{border-color:#29b5e8;color:#11567f}' +
      '#nav .next{background:#29b5e8;border-color:#29b5e8;color:#fff}#nav .next:hover{background:#1e9fcc}';
    doc.head.appendChild(css);

    var notes = el(doc, 'div'); notes.id = 'notes';
    doc.body.appendChild(notes);

    var nav = el(doc, 'div'); nav.id = 'nav';
    var status = el(doc, 'span', 'status'); status.id = 'status';
    var edit = el(doc, 'button', 'edit', 'Edit');
    var saveBtn = el(doc, 'button', 'save', 'Save');
    var back = el(doc, 'button', 'back', '← Back');
    var fwd = el(doc, 'button', 'next', 'Next →');
    [status, edit, saveBtn, back, fwd].forEach(function (n) { nav.appendChild(n); });
    doc.body.appendChild(nav);

    function flip(key) {
      document.dispatchEvent(new KeyboardEvent('keydown', { key: key, bubbles: true }));
    }
    back.addEventListener('click', function () { stopEditing(); flip('ArrowLeft'); });
    fwd.addEventListener('click', function () { stopEditing(); flip('ArrowRight'); });

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
    }
    edit.addEventListener('click', function () {
      if (notes.isContentEditable) stopEditing(); else startEditing();
    });
    notes.addEventListener('dblclick', function () { if (!notes.isContentEditable) startEditing(); });
    saveBtn.addEventListener('click', function () { save(win, status); });
    // Keep focus off the buttons so Space and Enter don't flip twice.
    nav.addEventListener('mousedown', function (e) { e.preventDefault(); });

    // Copy edits into the deck so saving from either window keeps them.
    notes.addEventListener('input', function () {
      notesFor(slides[currentIndex()], true).innerHTML = notes.innerHTML;
      status.textContent = 'Unsaved changes';
    });

    doc.addEventListener('keydown', function (e) {
      if (isSave(e)) { e.preventDefault(); save(win, status); return; }
      // While editing, keys type; Esc stops editing.
      if (e.target.isContentEditable) { if (e.key === 'Escape') stopEditing(); return; }
      var keys = ['ArrowRight', 'ArrowLeft', ' ', 'PageDown', 'PageUp', 'Enter', 'Home', 'End'];
      if (keys.indexOf(e.key) === -1) return;
      e.preventDefault();
      flip(e.key);
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

  // Remembered after the first save, so later saves overwrite the same
  // file without asking again.
  var fileHandle = null;

  // ctx is the window the click or keypress happened in. Chrome only opens
  // the save dialog from the window that has the user gesture, so a save
  // started in the notes window must use the notes window's picker.
  function save(ctx, status) {
    ctx = ctx || window;
    var html = serialize();
    function say(t) { if (status) status.textContent = t; }
    function write(handle) {
      return handle.createWritable().then(function (w) {
        return w.write(html).then(function () { return w.close(); });
      }).then(function () { fileHandle = handle; say('Saved ' + new Date().toLocaleTimeString()); });
    }
    if (ctx.showSaveFilePicker) {
      var pick = fileHandle ? Promise.resolve(fileHandle) : ctx.showSaveFilePicker({
        suggestedName: 'index.html',
        types: [{ description: 'HTML', accept: { 'text/html': ['.html'] } }]
      });
      pick.then(write).catch(function (err) {
        if (err && err.name === 'AbortError') return;
        fileHandle = null;
        say('Save failed');
        ctx.alert('Save failed: ' + (err && err.message));
      });
      return;
    }
    var doc = ctx.document;
    var a = doc.createElement('a');
    a.href = URL.createObjectURL(new Blob([html], { type: 'text/html' }));
    a.download = 'index.html';
    doc.body.appendChild(a);
    a.click();
    setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
    say('Downloaded index.html');
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
