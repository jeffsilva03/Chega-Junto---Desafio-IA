(() => {
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* Navegação: fundo ao rolar, barra de progresso e menu mobile */
  const nav = $('.nav');
  const bar = $('.scroll-progress span');
  const rail = $('.rail');
  const onScroll = () => {
    const y = scrollY;
    nav.classList.toggle('is-scrolled', y > 12);
    const max = document.documentElement.scrollHeight - innerHeight;
    bar.style.transform = `scaleX(${max > 0 ? y / max : 0})`;
    rail.classList.toggle('is-visible', y > innerHeight * .6);
  };
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  const toggle = $('.nav__toggle');
  const menu = $('#menu-mobile');
  const setMenu = open => {
    toggle.setAttribute('aria-expanded', open);
    toggle.setAttribute('aria-label', open ? 'Fechar menu' : 'Abrir menu');
    menu.hidden = !open;
  };
  toggle.addEventListener('click', () => setMenu(menu.hidden));
  $$('a', menu).forEach(a => a.addEventListener('click', () => setMenu(false)));
  addEventListener('keydown', e => { if (e.key === 'Escape') setMenu(false); });

  /* Revelação ao entrar na tela */
  const revealIO = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (!e.isIntersecting) return;
      e.target.classList.add('is-in');
      $$('[data-count]', e.target).forEach(countUp);
      revealIO.unobserve(e.target);
    });
  }, { threshold: .15, rootMargin: '0px 0px -40px 0px' });
  $$('.reveal').forEach(el => revealIO.observe(el));

  /* Contadores */
  const fmt = (n, dec) => n.toLocaleString('pt-BR', { minimumFractionDigits: dec, maximumFractionDigits: dec });
  function countUp(el) {
    if (el.dataset.done) return;
    el.dataset.done = 1;
    const end = parseFloat(el.dataset.count);
    const dec = parseInt(el.dataset.decimals || '0', 10);
    if (reduced) { el.textContent = fmt(end, dec); return; }
    const dur = end > 1000 ? 2000 : 1300;
    const t0 = performance.now();
    const tick = t => {
      const p = Math.min(1, (t - t0) / dur);
      const eased = 1 - Math.pow(1 - p, 4);
      el.textContent = fmt(end * eased, dec);
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }
  // Contadores fora de .reveal (ex.: estatísticas do hero)
  const countIO = new IntersectionObserver(entries => entries.forEach(e => {
    if (e.isIntersecting) { countUp(e.target); countIO.unobserve(e.target); }
  }), { threshold: .6 });
  $$('[data-count]').forEach(el => { if (!el.closest('.reveal')) countIO.observe(el); });

  /* Trilha lateral e link ativo do menu */
  const chapters = $$('[data-chapter]');
  const railLinks = $$('.rail a');
  const navLinks = $$('.nav__links a');
  const chapterIO = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (!e.isIntersecting) return;
      const id = e.target.dataset.chapter;
      const idx = chapters.findIndex(c => c.dataset.chapter === id);
      railLinks.forEach((a, i) => {
        a.classList.toggle('is-active', a.dataset.rail === id);
        a.classList.toggle('is-done', i < idx);
      });
      navLinks.forEach(a => a.classList.toggle('is-active', a.getAttribute('href') === '#' + id));
    });
  }, { rootMargin: '-45% 0px -50% 0px' });
  chapters.forEach(c => chapterIO.observe(c));

  /* Jornada: troca a tela do celular conforme a etapa */
  const screens = $$('.phone--stage img');
  const dots = $$('.stage__dots i');
  const steps = $$('.step');
  const show = n => {
    screens.forEach(img => img.classList.toggle('is-on', +img.dataset.screen === n));
    dots.forEach((d, i) => d.classList.toggle('is-on', i === n));
    steps.forEach(s => s.classList.toggle('is-active', +s.dataset.step === n));
  };
  const stepIO = new IntersectionObserver(entries => {
    entries.forEach(e => { if (e.isIntersecting) show(+e.target.dataset.step); });
  }, { rootMargin: '-48% 0px -48% 0px' });
  steps.forEach(s => stepIO.observe(s));
  show(0);

  /* Vídeo do pitch */
  const video = $('.video video');
  const cover = $('.video__cover');
  cover.addEventListener('click', () => {
    cover.parentElement.classList.add('is-playing');
    video.play().catch(() => {});
    video.focus();
  });

  /* Abas de download */
  const tabs = $$('[role="tab"]');
  const selectTab = (name, focus) => {
    tabs.forEach(t => {
      const on = t.id === 'tab-' + name;
      t.setAttribute('aria-selected', on);
      t.tabIndex = on ? 0 : -1;
      $('#' + t.getAttribute('aria-controls')).hidden = !on;
      if (on && focus) t.focus();
    });
  };
  tabs.forEach((t, i) => {
    t.addEventListener('click', () => selectTab(t.id.slice(4)));
    t.addEventListener('keydown', e => {
      const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
      if (!d) return;
      e.preventDefault();
      selectTab(tabs[(i + d + tabs.length) % tabs.length].id.slice(4), true);
    });
  });
  // Abre a aba certa conforme o aparelho de quem visita
  const ua = navigator.userAgent;
  const isIOS = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (/Android/i.test(ua)) selectTab('android');
  else if (isIOS) selectTab('ios');

  // Cartão do iPhone leva ao passo a passo; o do Android baixa e mostra o guia
  $$('[data-open-tab]').forEach(card => card.addEventListener('click', e => {
    const name = card.dataset.openTab;
    if (name === 'ios') e.preventDefault();
    selectTab(name);
    $('#guia').scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'start' });
  }));

  /* Copiar link */
  const toast = $('.toast');
  let toastTimer;
  const notify = msg => {
    toast.textContent = msg;
    toast.classList.add('is-on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('is-on'), 2400);
  };
  $$('[data-copy]').forEach(btn => btn.addEventListener('click', async () => {
    const text = btn.dataset.copy;
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const ta = Object.assign(document.createElement('textarea'), { value: text });
      document.body.append(ta); ta.select(); document.execCommand('copy'); ta.remove();
    }
    notify(btn.dataset.copyMsg || 'Link copiado! Cole no Safari do iPhone.');
  }));
})();
