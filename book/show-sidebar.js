// mdBook hides the sidebar below 1080px wide. Keep the chapter tree visible
// down to 640px unless the reader has toggled it themselves. mdBook's script
// hides a collapsed sidebar with display:none, so undo that along with the
// checkbox and class that the toggle button maintains.
window.addEventListener('load', function () {
    var toggle = document.getElementById('mdbook-sidebar-toggle-anchor');
    var sidebar = document.getElementById('mdbook-sidebar');
    var chosen = null;
    try { chosen = localStorage.getItem('mdbook-sidebar'); } catch (e) {}
    if (toggle && sidebar && !chosen && window.innerWidth >= 640 && !toggle.checked) {
        toggle.checked = true;
        sidebar.style.display = '';
        document.documentElement.classList.add('sidebar-visible');
    }
});
