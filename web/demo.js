(() => {
  const panel = document.getElementById('feedback-panel');
  const trigger = document.getElementById('feedback-trigger');
  const closeButton = document.getElementById('feedback-close');
  const backdrop = document.getElementById('feedback-backdrop');
  const form = document.getElementById('feedback-form');
  const submit = document.getElementById('feedback-submit');
  const status = document.getElementById('feedback-status');

  const isMobilePanel = () => window.matchMedia('(max-width: 1040px)').matches;
  panel.inert = isMobilePanel();
  panel.setAttribute('aria-hidden', String(isMobilePanel()));

  function setPanelOpen(open) {
    if (!isMobilePanel()) return;
    document.body.classList.toggle('feedback-open', open);
    trigger.setAttribute('aria-expanded', String(open));
    backdrop.hidden = !open;
    panel.inert = !open;
    panel.setAttribute('aria-hidden', String(!open));
    if (open) {
      document.getElementById('feedback-message').focus();
    } else {
      trigger.focus();
    }
  }

  trigger.addEventListener('click', () => setPanelOpen(true));
  closeButton.addEventListener('click', () => setPanelOpen(false));
  backdrop.addEventListener('click', () => setPanelOpen(false));
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && document.body.classList.contains('feedback-open')) {
      setPanelOpen(false);
    }
    if (event.key === 'Tab' && document.body.classList.contains('feedback-open')) {
      const focusable = [...panel.querySelectorAll('button, textarea, input[type="email"]')];
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
  });
  window.addEventListener('resize', () => {
    if (!isMobilePanel()) {
      document.body.classList.remove('feedback-open');
      trigger.setAttribute('aria-expanded', 'false');
      backdrop.hidden = true;
      panel.inert = false;
      panel.setAttribute('aria-hidden', 'false');
    } else if (!document.body.classList.contains('feedback-open')) {
      panel.inert = true;
      panel.setAttribute('aria-hidden', 'true');
    }
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!form.reportValidity()) return;

    submit.disabled = true;
    submit.textContent = 'Sending…';
    status.textContent = '';
    status.classList.remove('is-error', 'is-success');

    try {
      const data = new FormData(form);
      if (!data.get('email')?.toString().trim()) data.delete('email');
      data.set('source', 'AI Nutrient Tracker web demo');
      const response = await fetch(form.action, {
        method: 'POST',
        body: data,
        headers: { Accept: 'application/json' },
      });
      if (!response.ok) throw new Error('Submission failed');
      form.reset();
      status.textContent = 'Thank you — your feedback has been sent.';
      status.classList.add('is-success');
    } catch (_) {
      status.textContent = 'We couldn’t send your note. Please try again.';
      status.classList.add('is-error');
    } finally {
      submit.disabled = false;
      submit.innerHTML = 'Send feedback <span aria-hidden="true">↗</span>';
    }
  });
})();
