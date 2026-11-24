/* Juvecom Dashboard: ícones visuais, sem alterações em dados. */
(() => {
  'use strict';
  const paths = {
    users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    checkCircle: '<circle cx="12" cy="12" r="10"/><path d="m8 12 3 3 5-6"/>',
    xCircle: '<circle cx="12" cy="12" r="10"/><path d="m15 9-6 6m0-6 6 6"/>',
    ban: '<circle cx="12" cy="12" r="10"/><path d="m5 5 14 14"/>',
    file: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M8 13h8M8 17h8"/>',
    handshake: '<path d="M2 12 7 7l4 1 3-2 8 6-5 6-4-1-3 2-3-2-2 1-3-3z"/><path d="m9 11 3 2 3-1m-4 5 2-2"/>',
    alert: '<path d="m10.3 3.3-8.5 15A2 2 0 0 0 3.5 21h17a2 2 0 0 0 1.7-2.7l-8.5-15a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4m0 4h.01"/>',
    mail: '<rect x="2" y="4" width="20" height="16" rx="2"/><path d="m22 7-10 7L2 7"/>',
    headset: '<path d="M3 14v-3a9 9 0 0 1 18 0v3"/><path d="M3 14h4v7H5a2 2 0 0 1-2-2v-5Zm18 0h-4v7h2a2 2 0 0 0 2-2v-5Z"/>',
    calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4m10-4v4M3 10h18"/>',
    layers: '<path d="m12 2 10 5-10 5L2 7l10-5Zm-10 10 10 5 10-5M2 17l10 5 10-5"/>',
    chart: '<path d="M3 3v18h18M7 17v-5m5 5V7m5 10V9"/>',
  };
  const icons = {
    clientes: [['users','orange'],['check','green'],['checkCircle','blue'],['xCircle','red'],['ban','orange']],
    contratos: [['file','orange'],['handshake','green'],['alert','orange'],['checkCircle','blue'],['ban','red']],
    contato: [['mail','orange'],['headset','green'],['xCircle','red']],
    financeiro: [['calendar','blue'],['layers','orange'],['chart','purple']],
  };
  function groupFromHeading(text) {
    const normalized = text.toLocaleLowerCase('pt-BR').normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim();
    if (normalized.includes('indicadores financeiros')) return 'financeiro';
    if (normalized.includes('clientes')) return 'clientes';
    if (normalized.includes('contratos')) return 'contratos';
    if (normalized.includes('contato')) return 'contato';
    return null;
  }
  function init() {
    const root = document.querySelector('.dashboard');
    if (!root) return;
    const headings = [...root.querySelectorAll('h2')];
    root.querySelectorAll('.dashboard__cards').forEach((container) => {
      let group = null;
      headings.forEach((heading) => {
        if (heading.compareDocumentPosition(container) & Node.DOCUMENT_POSITION_FOLLOWING) {
          group = groupFromHeading(heading.textContent || '') || group;
        }
      });
      if (!group) return;
      const defs = icons[group];
      [...container.querySelectorAll(':scope > .dashboard__card')].forEach((card, index) => {
        if (card.querySelector('.dashboard__card-icon')) return;
        const def = defs[index];
        if (!def) return;
        const [name, color] = def;
        const icon = document.createElement('span');
        icon.className = 'dashboard__card-icon';
        icon.setAttribute('aria-hidden', 'true');
        icon.dataset.color = color;
        icon.innerHTML = `<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">${paths[name]}</svg>`;
        card.prepend(icon);
      });
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
