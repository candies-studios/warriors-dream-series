/*
 * WDS Fight Night 19 — Book Now page (tickets/wds-fight-night-19/).
 *
 * BOOK NOW opens a details form. On submit the visitor goes to the booking
 * page set in data-booking-url on <body> (where categories, seat prices and
 * payment are handled). While that attribute is empty, the form ends with a
 * "booking opens shortly" message instead.
 *
 * Nothing typed in the form is stored or sent anywhere by this page, and no
 * personal details are added to the booking link.
 */
(function () {
  'use strict';
  var $ = function (id) { return document.getElementById(id); };
  var EVENT_START = new Date('2026-12-12T17:00:00+05:30');
  var STATES = ['Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chandigarh',
    'Chhattisgarh', 'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh',
    'Jammu and Kashmir', 'Jharkhand', 'Karnataka', 'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh', 'Maharashtra',
    'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Outside India'];

  function bookingUrl() {
    var u = (document.body.getAttribute('data-booking-url') || '').trim();
    return /^https:\/\//i.test(u) ? u : '';
  }

  // ---------------------------------------------------------------- countdown
  (function () {
    var el = $('tk-countdown');
    if (!el) return;
    var parts = {};
    el.querySelectorAll('[data-cd]').forEach(function (b) { parts[b.getAttribute('data-cd')] = b; });
    var iv;
    function tick() {
      var diff = Math.max(0, EVENT_START.getTime() - Date.now());
      parts.d.textContent = String(Math.floor(diff / 86400000)).padStart(2, '0');
      parts.h.textContent = String(Math.floor(diff / 3600000) % 24).padStart(2, '0');
      parts.m.textContent = String(Math.floor(diff / 60000) % 60).padStart(2, '0');
      parts.s.textContent = String(Math.floor(diff / 1000) % 60).padStart(2, '0');
      if (!diff) { el.classList.add('is-live'); clearInterval(iv); }
    }
    tick();
    iv = setInterval(tick, 1000);
  })();

  // ---------------------------------------------------------------- dialog
  var modal = $('tk-modal');
  var form = $('tk-form');
  var lastFocus = null;

  function show(id) {
    ['tk-form', 'tk-going', 'tk-hold'].forEach(function (s) { $(s).hidden = s !== id; });
  }
  function open() {
    lastFocus = document.activeElement;
    show('tk-form');
    modal.hidden = false;
    document.body.classList.add('tk-noscroll');
    setTimeout(function () { $('f-name').focus(); }, 30);
  }
  function close() {
    if (!$('tk-going').hidden) return;
    modal.hidden = true;
    document.body.classList.remove('tk-noscroll');
    if (lastFocus) lastFocus.focus();
  }

  document.querySelectorAll('.js-book').forEach(function (b) {
    b.addEventListener('click', function (e) { e.preventDefault(); open(); });
  });
  modal.querySelectorAll('[data-close]').forEach(function (b) { b.addEventListener('click', close); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && !modal.hidden) close(); });
  $('tk-notify').addEventListener('click', function () {
    close();
    var b = document.querySelector('.header-cta.js-community-open');
    if (b) b.click();
  });

  $('f-state').innerHTML += STATES.map(function (s) { return '<option>' + s + '</option>'; }).join('');

  // ---------------------------------------------------------------- form
  function validate() {
    var v = {};
    ['name', 'email', 'phone', 'city', 'state', 'emergency_contact'].forEach(function (k) {
      v[k] = (form.elements[k].value || '').trim();
    });
    var err = {};
    if (v.name.length < 2) err.name = 'Enter your full name.';
    else if (!/^[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .'-]*$/.test(v.name)) err.name = 'Use English letters only.';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v.email)) err.email = 'Enter a valid email address.';
    var digits = v.phone.replace(/\D/g, '');
    if (!(/^(91)?[6-9]\d{9}$/.test(digits) || (v.phone.charAt(0) === '+' && digits.length >= 8 && digits.length <= 15))) {
      err.phone = 'Enter a valid 10-digit mobile number.';
    }
    if (v.city.length < 2) err.city = 'Enter your city.';
    if (!v.state) err.state = 'Select your state.';
    return { values: v, errors: err };
  }

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    var r = validate();
    form.querySelectorAll('[data-err]').forEach(function (s) {
      var k = s.getAttribute('data-err');
      s.textContent = r.errors[k] || '';
      form.elements[k].setAttribute('aria-invalid', r.errors[k] ? 'true' : 'false');
    });
    var first = Object.keys(r.errors)[0];
    if (first) { form.elements[first].focus(); return; }

    var url = bookingUrl();
    if (url) {
      show('tk-going');
      setTimeout(function () { window.location.href = url; }, 600);
    } else {
      $('tk-hold-name').textContent = r.values.name.split(/\s+/)[0];
      show('tk-hold');
    }
  });
})();
