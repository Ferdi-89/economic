// ═══════════════════════════════════════════════
// Financier — Shared Script
// ═══════════════════════════════════════════════

(function() {
  'use strict';

  // ─── Navigation ───
  const nav = document.querySelector('nav');
  const toggle = document.getElementById('menuToggle');
  const links = document.getElementById('navLinks');

  // Scroll effect
  window.addEventListener('scroll', () => {
    nav?.classList.toggle('scrolled', window.scrollY > 16);
  });

  // Mobile menu toggle
  toggle?.addEventListener('click', () => {
    links?.classList.toggle('open');
  });

  // Close menu on link click
  links?.querySelectorAll('a').forEach(a => {
    a.addEventListener('click', () => links.classList.remove('open'));
  });

  // ─── Active nav link ───
  const current = location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.nav-links a').forEach(a => {
    const href = a.getAttribute('href');
    if (href === current || (current === '' && href === 'index.html')) {
      a.classList.add('active');
    }
  });

  // ─── Scroll animation ───
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
      }
    });
  }, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });

  document.querySelectorAll('.fade-up, .fade-in, .card').forEach(el => {
    observer.observe(el);
    el.classList.add('fade-up');
  });

})();
