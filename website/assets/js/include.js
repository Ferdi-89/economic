// HTML include helper — loads header.html and footer.html
(async function() {
  const pagesDir = ''; // empty — relative to page location

  async function load(id, file) {
    const el = document.getElementById(id);
    if (!el) return;
    try {
      const res = await fetch(file);
      if (!res.ok) throw new Error(`Failed to load ${file}`);
      el.innerHTML = await res.text();
    } catch(e) {
      console.warn('Include error:', e);
    }
  }

  await Promise.all([
    load('header', 'header.html'),
    load('footer', 'footer.html'),
  ]);

  // Now fire main.js init (which needs DOM elements from includes)
  const script = document.createElement('script');
  script.src = 'assets/js/main.js';
  document.body.appendChild(script);
})();
