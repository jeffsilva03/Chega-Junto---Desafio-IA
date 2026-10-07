/* Interações leves: navegação suave, animações de entrada e gráficos progressivos. */
document.addEventListener("DOMContentLoaded", () => {
  // Núcleo do diagrama de IA em SVG: círculos, caminhos e rótulos compartilham
  // o mesmo viewBox para não se deformarem ao mudar a largura da tela.
  document.querySelectorAll(".ai-visual").forEach((visual) => {
    if (visual.querySelector(".ai-vector-core")) return;
    visual.insertAdjacentHTML("afterbegin", `
      <svg class="ai-vector-core" viewBox="0 0 970 670" aria-hidden="true">
        <defs>
          <radialGradient id="core-fill" cx="50%" cy="34%" r="72%"><stop offset="0" stop-color="#194a80"/><stop offset=".58" stop-color="#0b2b57"/><stop offset="1" stop-color="#061d3e"/></radialGradient>
          <radialGradient id="core-halo"><stop offset="0" stop-color="#c8fa4d" stop-opacity=".34"/><stop offset="1" stop-color="#c8fa4d" stop-opacity="0"/></radialGradient>
          <filter id="core-glow" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="5" result="blur"/><feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
        </defs>
        <circle cx="410" cy="246" r="247" fill="none" stroke="#729bc5" stroke-opacity=".18"/>
        <circle cx="410" cy="246" r="180" fill="none" stroke="#c8fa4d" stroke-opacity=".55" stroke-dasharray="3 5"/>
        <circle cx="410" cy="246" r="155" fill="none" stroke="#80a8cf" stroke-opacity=".18"/>
        <circle cx="410" cy="246" r="143" fill="url(#core-halo)" opacity=".64"/>
        <path class="core-line" d="M205 115 C242 115 267 147 295 174 M615 115 C580 115 554 147 527 174 M205 378 C242 378 267 347 295 319 M615 378 C580 378 554 347 527 319"/>
        <g fill="#9ee739" stroke="#d9ff70" stroke-width="2" filter="url(#core-glow)">
          <circle cx="205" cy="115" r="6"/><circle cx="615" cy="115" r="6"/><circle cx="205" cy="378" r="6"/><circle cx="615" cy="378" r="6"/>
          <circle cx="295" cy="174" r="6"/><circle cx="527" cy="174" r="6"/><circle cx="295" cy="319" r="6"/><circle cx="527" cy="319" r="6"/>
        </g>
        <circle cx="410" cy="246" r="130" fill="none" stroke="#c8fa4d" stroke-opacity=".13" stroke-width="25"/>
        <circle cx="410" cy="246" r="115" fill="url(#core-fill)" stroke="#c8fa4d" stroke-width="1.3"/>
        <text class="core-word" x="410" y="92" text-anchor="middle">ORGANIZA</text>
        <text class="core-word" x="566" y="249" text-anchor="middle" transform="rotate(90 566 249)">SIMPLIFICA</text>
        <text class="core-word" x="410" y="407" text-anchor="middle">APOIA</text>
        <text class="core-word" x="255" y="249" text-anchor="middle" transform="rotate(-90 255 249)">CONECTA</text>
        <path d="M410 187 L423 232 L455 246 L423 260 L410 305 L397 260 L365 246 L397 232 Z" fill="#c8fa4d" filter="url(#core-glow)"/>
        <text class="core-name" x="410" y="294" text-anchor="middle">IA</text>
        <text class="core-sub" x="410" y="315" text-anchor="middle">CHEGA JUNTO</text>
      </svg>
    `);
  });

  const revealItems = document.querySelectorAll(".reveal");
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });
  revealItems.forEach((item) => observer.observe(item));

  const animatedBars = document.querySelectorAll("[data-width]");
  animatedBars.forEach((bar) => { bar.style.width = "0"; });
  const chartObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.querySelectorAll("[data-width]").forEach((bar, index) => {
        window.setTimeout(() => { bar.style.width = `${bar.dataset.width}%`; }, index * 110);
      });
      chartObserver.unobserve(entry.target);
    });
  }, { threshold: 0.3 });
  document.querySelectorAll(".capacity-chart, .barrier-list").forEach((item) => chartObserver.observe(item));

  // Indicadores das evidências: cada valor é mantido no HTML como dado e
  // animado apenas quando o bloco entra na tela. O valor final também é
  // aplicado imediatamente como fallback para navegadores sem observador.
  const counters = document.querySelectorAll(".count[data-count]");
  const formatCount = (value, decimals) => new Intl.NumberFormat("pt-BR", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);

  const revealCount = (counter) => {
    if (counter.dataset.countDone === "true") return;
    counter.dataset.countDone = "true";

    const target = Number.parseFloat(counter.dataset.count);
    const decimals = Number.parseInt(counter.dataset.decimals || "0", 10);
    if (!Number.isFinite(target)) return;

    const showFinalValue = () => { counter.textContent = formatCount(target, decimals); };
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      showFinalValue();
      return;
    }

    const duration = 1150;
    const startedAt = performance.now();
    const tick = (now) => {
      const progress = Math.min((now - startedAt) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      counter.textContent = formatCount(target * eased, decimals);
      if (progress < 1) window.requestAnimationFrame(tick);
      else showFinalValue();
    };
    window.requestAnimationFrame(tick);
  };

  if ("IntersectionObserver" in window) {
    const counterObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.querySelectorAll(".count[data-count]").forEach(revealCount);
        counterObserver.unobserve(entry.target);
      });
    }, { threshold: 0.12 });
    document.querySelectorAll(".evidence").forEach((section) => counterObserver.observe(section));
  } else {
    counters.forEach(revealCount);
  }

  // Demonstração da jornada: relato inicial, pergunta neutra e resumo final.
  // Nada é enviado ou armazenado; o texto fica somente no cartão da página.
  document.querySelectorAll("[data-story]").forEach((story) => {
    const question = story.querySelector(".story-question");
    const prompt = story.querySelector(".story-ai-prompt");
    const step = story.querySelector(".story-step");
    const response = story.querySelector(".story-response");
    const feedbackAnswer = story.querySelector(".story-feedback-answer");
    const back = story.querySelector('[data-story-nav="back"]');
    const next = story.querySelector('[data-story-nav="next"]');
    const nextLabel = next.querySelector("span");
    let currentStep = 0;

    const renderStory = (shouldFocus = false) => {
      story.dataset.storyState = ["intro", "question", "summary"][currentStep];
      step.textContent = `${currentStep + 1} de 3`;
      back.disabled = currentStep === 0;

      if (currentStep === 0) {
        question.textContent = "O que você gostaria de contar antes da consulta?";
        nextLabel.textContent = "Continuar";
      }

      if (currentStep === 1) {
        question.textContent = "A IA encontrou uma pergunta que pode ajudar a organizar seu relato.";
        prompt.textContent = "Há quanto tempo isso acontece e como tem afetado sua rotina? Responda com suas palavras, se quiser.";
        nextLabel.textContent = "Ver resumo";
        if (shouldFocus) window.setTimeout(() => response.focus(), 0);
      }

      if (currentStep === 2) {
        question.textContent = "Seu relato está mais claro para você revisar.";
        const answer = response.value.trim();
        const feedbackAnswerText = feedbackAnswer.querySelector("em");
        feedbackAnswerText.textContent = answer
          ? answer
          : "Você pode adicionar uma resposta depois, se quiser complementar seu relato.";
        nextLabel.textContent = "Recomeçar";
      }
    };

    const swapStory = (update, shouldFocus = false) => {
      if (story.classList.contains("is-story-changing")) return;
      const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      const applyUpdate = () => {
        update();
        renderStory(shouldFocus);
        story.classList.remove("is-story-changing");
        if (!reduceMotion) {
          story.classList.remove("is-story-entering");
          void story.offsetWidth;
          story.classList.add("is-story-entering");
        }
      };

      if (reduceMotion) {
        applyUpdate();
        return;
      }
      story.classList.remove("is-story-entering");
      story.classList.add("is-story-changing");
      window.setTimeout(applyUpdate, 160);
    };

    next.addEventListener("click", () => {
      swapStory(() => {
        if (currentStep === 2) currentStep = 0;
        else currentStep += 1;
      }, currentStep === 0);
    });
    back.addEventListener("click", () => {
      if (currentStep === 0) return;
      swapStory(() => { currentStep -= 1; });
    });
    renderStory();
  });

  const navLinks = document.querySelectorAll(".nav-links a");
  const sections = [...document.querySelectorAll("section[id]")];
  const navigationObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      navLinks.forEach((link) => link.classList.toggle("active", link.getAttribute("href") === `#${entry.target.id}`));
    });
  }, { rootMargin: "-40% 0px -50% 0px" });
  sections.forEach((section) => navigationObserver.observe(section));
});
