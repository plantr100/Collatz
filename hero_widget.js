(function () {
  async function fetchStats() {
    try {
      const response = await fetch('/collatz_state.json', { cache: 'no-store' });
      if (!response.ok) {
        throw new Error('HTTP ' + response.status);
      }
      return await response.json();
    } catch (error) {
      console.error('Failed to load Collatz stats:', error);
      return null;
    }
  }

  function renderCard(data) {
    if (!data) return;

    const container = document.querySelector('.hero-right');
    if (!container) return;

    let card = container.querySelector('.collatz-card');
    if (!card) {
      card = document.createElement('div');
      card.className = 'collatz-card';
      card.innerHTML = [
        '<h3>Collatz Tracker</h3>',
        '<dl class="collatz-metrics"></dl>',
        '<div class="collatz-sequences">',
        '  <section class="most-efficient">',
        '    <h4>Most Efficient Prime</h4>',
        '    <pre class="sequence sequence-efficient"></pre>',
        '  </section>',
        '  <section class="highest-value">',
        '    <h4>Highest Collatz Value</h4>',
        '    <pre class="sequence sequence-high-value"></pre>',
        '  </section>',
        '</div>'
      ].join('');
      container.appendChild(card);
    }

    const dl = card.querySelector('.collatz-metrics');
    const metrics = data.metrics || {};
    const efficient = metrics.most_efficient || {};
    const highest = metrics.highest_value || {};

    dl.innerHTML = [
      `<div><dt>Largest Prime</dt><dd>${metrics.largest_prime || '—'}</dd></div>`,
      `<div><dt>Most Efficient Prime</dt><dd>${efficient.prime || '—'} (${efficient.steps || '—'} steps, ratio ${efficient.ratio || '—'})</dd></div>`,
      `<div><dt>Highest Value</dt><dd>${highest.max_value || '—'} (prime ${highest.prime || '—'})</dd></div>`,
      `<div><dt>Last Exec Time</dt><dd>${metrics.latest_exec_time || '—'} s</dd></div>`,
      `<div><dt>Generated</dt><dd>${data.generated_at || '—'}</dd></div>`
    ].join('');

    const efficientSeq = card.querySelector('.sequence-efficient');
    const highSeq = card.querySelector('.sequence-high-value');

    efficientSeq.textContent = (efficient.sequence || '').replace(/\u2192/g, '→');
    highSeq.textContent = (highest.sequence || '').replace(/\u2192/g, '→');
  }

  async function updateCard() {
    const data = await fetchStats();
    renderCard(data);
  }

  document.addEventListener('DOMContentLoaded', () => {
    updateCard();
    setInterval(updateCard, 15000);
  });
})();
