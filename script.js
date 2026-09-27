// Make Rankings tab visible on ALL pages
document.addEventListener('DOMContentLoaded', function() {
    const rankingsTab = document.querySelector('a[href="rankings.html"]');
    if (rankingsTab) {
        rankingsTab.style.display = 'block';
        rankingsTab.style.visibility = 'visible';
    }
    
    // Set active page in navigation
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    document.querySelectorAll('nav a').forEach(link => {
        if (link.getAttribute('href') === currentPage) {
            link.classList.add('active');
        }
    });
});

// Ensure Rankings tab stays visible (runs every 500ms)
setInterval(() => {
    const rankingsTab = document.querySelector('a[href="rankings.html"]');
    if (rankingsTab) {
        rankingsTab.style.display = 'block';
        rankingsTab.style.visibility = 'visible';
    }
}, 500);

// Mobile menu toggle
const mobileMenuToggle = document.querySelector('.mobile-menu-toggle');
if (mobileMenuToggle) {
    mobileMenuToggle.addEventListener('click', function() {
        const navMenu = document.querySelector('nav ul');
        if (navMenu) {
            navMenu.classList.toggle('active');
        }
    });
}

// Close mobile menu when a link is clicked
document.querySelectorAll('nav a').forEach(link => {
    link.addEventListener('click', function() {
        const navMenu = document.querySelector('nav ul');
        if (navMenu && navMenu.classList.contains('active')) {
            navMenu.classList.remove('active');
        }
    });
});

// Contact form handler
const contactForm = document.querySelector('.contact-form');
if (contactForm) {
    contactForm.addEventListener('submit', function(e) {
        e.preventDefault();
        alert('Thank you for your message! We will get back to you soon.');
        this.reset();
    });
}
