// Scroll effects. Content is only hidden once this script runs, so the pages read
// fine without JavaScript, and nothing animates for people who ask for less motion.
(() => {
  const root = document.documentElement;
  const header = document.querySelector('.top');
  const onScroll = () => header && header.classList.toggle('scrolled', window.scrollY > 8);
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches || !('IntersectionObserver' in window)) return;

  root.classList.add('fx');
  const items = document.querySelectorAll('main .card, main > p');
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add('in');
      observer.unobserve(entry.target);
    }
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

  items.forEach((item) => {
    const siblings = item.parentElement.classList.contains('grid') ? [...item.parentElement.children] : [];
    if (siblings.length) item.style.transitionDelay = `${siblings.indexOf(item) * 90}ms`;
    observer.observe(item);
  });
})();
