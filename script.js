// Add slight reveal animations on scroll
const observerOptions = {
    root: null,
    rootMargin: '0px',
    threshold: 0.1
};

const observer = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
            observer.unobserve(entry.target);
        }
    });
}, observerOptions);

// Generic Slide Switcher
function changeSlide(carouselId, direction) {
    const carousel = document.querySelector(`.framed-photo.carousel[data-carousel-id="${carouselId}"]`);
    if (!carousel) return;
    
    const slides = carousel.querySelectorAll('.carousel-slide');
    if (slides.length <= 1) return;
    
    let activeIndex = Array.from(slides).findIndex(slide => slide.classList.contains('active'));
    if (activeIndex === -1) activeIndex = 0;
    
    slides[activeIndex].classList.remove('active');
    
    activeIndex = (activeIndex + direction + slides.length) % slides.length;
    const nextSlide = slides[activeIndex];
    nextSlide.classList.add('active');
    
    // Update caption if data-caption is defined on the next slide
    const wrapper = carousel.closest('.framed-photo-gallery-wrapper');
    if (wrapper) {
        const captionElem = wrapper.querySelector('.photo-caption');
        if (captionElem) {
            const newCaption = nextSlide.getAttribute('data-caption');
            if (newCaption) {
                captionElem.textContent = newCaption;
            }
        }
    }
}

// Initialize elements
document.addEventListener('DOMContentLoaded', () => {
    // Scroll reveals
    const revealElements = document.querySelectorAll('.project-card, .project-row');
    revealElements.forEach(elem => {
        elem.style.opacity = '0';
        elem.style.transform = 'translateY(20px)';
        elem.style.transition = 'opacity 0.6s ease-out, transform 0.6s ease-out';
        observer.observe(elem);
    });

    // Setup photo click behavior to slide forward
    const carousels = document.querySelectorAll('.framed-photo.carousel');
    carousels.forEach(carousel => {
        const id = carousel.getAttribute('data-carousel-id');
        const slidesContainer = carousel.querySelector('.carousel-slides');
        if (slidesContainer) {
            slidesContainer.addEventListener('click', (e) => {
                // If they clicked an arrow button, let the inline onclick handler deal with it
                if (e.target.closest('.carousel-arrow')) return;
                changeSlide(id, 1);
            });
        }
    });

    // Check if form was submitted successfully (backend redirect)
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('status') === 'success') {
        alert('Thank you for reaching out! Your message has been sent successfully.');
        window.history.replaceState({}, document.title, window.location.pathname);
    }
});
