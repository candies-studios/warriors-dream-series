/*
 * WDS Blog — all posts live in the POSTS list below.
 *
 * To add a post: copy one block, give it a new unique `slug` (lowercase, dashes),
 * set the date (YYYY-MM-DD), category, cover image and the article HTML in `body`.
 * Newest posts are shown first automatically. No other file needs to change.
 * The post opens at  pages/blog-post.html?p=<slug>
 */
(function () {
  var POSTS = [
    {
      slug: 'fight-night-19-fight-card',
      title: 'WDS Fight Night 19: The Fight Card',
      date: '2026-11-06',
      category: 'Announcements',
      author: 'WDS Team',
      cover: '../assets/images/footer-fight.jpg',
      excerpt: 'Fifteen professional MMA bouts land at CIDCO Exhibition Ground, Vashi on 12 December. Here is the full card.',
      body:
        '<p>Warriors Dream Series returns to Navi Mumbai for <strong>WDS Fight Night 19</strong> on <strong>Saturday, 12 December 2026</strong> at the CIDCO Exhibition Ground, Vashi. Doors open for a 5:00 PM start, with fifteen professional MMA bouts scheduled over three five-minute rounds.</p>' +
        '<h2>Main event and co-main event</h2>' +
        '<p>Light heavyweight <strong>Gaganpal Singh Dua</strong> (5-0-0) headlines the night at 93.0 kg; his opponent will be announced soon. In the co-main event, <strong>Adnan Khan</strong> meets <strong>Pratik Shetty</strong> at welterweight (77.1 kg).</p>' +
        '<h2>Full card</h2>' +
        '<ol class="blog-list">' +
          '<li>Main Event · Light Heavyweight 93.0 kg — Gaganpal Singh Dua vs TBA</li>' +
          '<li>Co-Main Event · Welterweight 77.1 kg — Adnan Khan vs Pratik Shetty</li>' +
          '<li>Bantamweight 61.2 kg — Nongmaithem Bonjovi vs Dzhavkharali Nuraliev</li>' +
          '<li>Flyweight 56.7 kg — Bishal Sahu vs Jake Bron</li>' +
          '<li>Flyweight 56.7 kg — Shoaib Khan vs TBA</li>' +
          '<li>Flyweight 56.7 kg — Ashish Rawat vs Safarov Yoqubjon</li>' +
          '<li>Catchweight 50 kg — Alena Ignateva vs Bebs Francisco</li>' +
          '<li>Catchweight 54 kg — Surbala Laishram vs Arofat Toirova</li>' +
          '<li>Flyweight 56.7 kg — Sangramsingh Godase vs Siddiqui Altamash Shahanawaz</li>' +
          '<li>Welterweight 77.1 kg — Kimson Tony vs Sohail Khan</li>' +
          '<li>Featherweight 65.8 kg — Edukondal vs Besii Ariijii</li>' +
          '<li>Featherweight 65.8 kg — Chhabi (Kapil) Gupta vs Shaheen Commando</li>' +
          '<li>Flyweight 56.7 kg — Sajal Choudhary vs Sagar Dange</li>' +
          '<li>Flyweight 56.7 kg — Thiaumuanlal Guite vs Sachin Singh</li>' +
          '<li>Bantamweight 61.2 kg — Rohit Raina vs Laxman Govekar</li>' +
        '</ol>' +
        '<p>Fighters from India, the Philippines, Tajikistan, Uzbekistan and Russia are on the card. Open the <a href="wds-fight-night-19.html">interactive fight card</a> to see every fighter\'s record, last result and height.</p>' +
        '<p class="blog-cta"><a class="blog-btn" href="wds-fight-night-19.html">View Fight Card</a></p>'
    },
    {
      slug: 'rising-star-8-results',
      title: 'WDS Rising Star 8: Results',
      date: '2026-10-26',
      category: 'Results',
      author: 'WDS Team',
      cover: '../assets/images/wds-rising-star-4.jpg',
      excerpt: 'Nikhil Thapa takes the main event and Qaazim Sheikh stops Nikhil Charan in the co-main. All eleven results from Wagholi, Pune.',
      body:
        '<p><strong>WDS Rising Star 8</strong> brought two days of amateur and pro MMA to Fit &amp; Fight Club in Wagholi, Pune on 24–25 October 2026. Eleven bouts made the main card.</p>' +
        '<h2>Main event and co-main event</h2>' +
        '<p><strong>Nikhil Thapa</strong> (Combat Fitness Clan) defeated <strong>Giftson Awungshi</strong> in the flyweight main event. In the co-main event, <strong>Qaazim Sheikh</strong> (Combat Fitness Center) stopped <strong>Nikhil Charan</strong> by TKO at featherweight.</p>' +
        '<h2>All results</h2>' +
        '<ol class="blog-list">' +
          '<li>Main Event · Pro MMA 56.7 kg — Nikhil Thapa def. Giftson Awungshi</li>' +
          '<li>Co-Main Event · Pro MMA 65.8 kg — Qaazim Sheikh def. Nikhil Charan (TKO)</li>' +
          '<li>Amateur MMA 52.2 kg — Nayan Mandlik def. Deekshitha R (Unanimous Decision)</li>' +
          '<li>Amateur MMA 56.7 kg — Vikas Banubakode def. Ahmed Raza (Submission)</li>' +
          '<li>Amateur MMA 61.2 kg — Bhuvan Rai def. Aryan Sawant</li>' +
          '<li>Final 56.7 kg — Chhewang Karma Lama def. Vijay Yadav</li>' +
          '<li>Final 65.8 kg — Md Sajid Khan def. Lanchenba</li>' +
          '<li>Pro MMA 65.8 kg — Sadaf Desai def. Ayman Shaikh (TKO)</li>' +
          '<li>Pro MMA 65.8 kg — Sujal Bhatt def. Stefan Dsouza (TKO)</li>' +
          '<li>Pro MMA 52.2 kg — Atharva Sanjay Katore def. Pratik Lambade (TKO)</li>' +
          '<li>Pro MMA 56.7 kg — Parth Sapkal def. Kushal Rao</li>' +
        '</ol>' +
        '<p>See every bout, with fighter photos and records, on the <a href="event.html?e=wds-rising-star-8">Rising Star 8 results page</a>.</p>' +
        '<p class="blog-cta"><a class="blog-btn" href="event.html?e=wds-rising-star-8">View Results</a></p>'
    },
    {
      slug: 'new-home-wdsmma-com',
      title: 'Warriors Dream Series Has a New Home: wdsmma.com',
      date: '2026-11-03',
      category: 'News',
      author: 'WDS Team',
      cover: '../assets/images/rankings-hero.jpg',
      excerpt: 'Our website now lives at wdsmma.com. Old links to warriorsdreamseries.com bring you here automatically.',
      body:
        '<p>The official Warriors Dream Series website has moved to <strong>wdsmma.com</strong>. Events, fight cards, results and fighter profiles are all here, in one place.</p>' +
        '<p>Bookmarks and links to warriorsdreamseries.com still work: they forward to the new address automatically.</p>' +
        '<p>Want fight results and event news the moment they land? Tap <strong>Warrior Community</strong> at the top of any page to join our WhatsApp updates and Instagram broadcast.</p>' +
        '<p class="blog-cta"><a class="blog-btn" href="events.html">See Upcoming Events</a></p>'
    }
  ];

  // ------------------------------------------------------------------ helpers
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  function fmtDate(iso) {
    var p = String(iso).split('-');
    return p.length === 3 ? (+p[2]) + ' ' + MONTHS[+p[1] - 1] + ' ' + p[0] : iso;
  }
  function sorted() {
    return POSTS.slice().sort(function (a, b) { return a.date < b.date ? 1 : a.date > b.date ? -1 : 0; });
  }
  function postUrl(p) { return 'blog-post.html?p=' + encodeURIComponent(p.slug); }

  function card(p) {
    return '<article class="blog-card">' +
      '<a class="blog-card-img" href="' + postUrl(p) + '" style="background-image:url(\'' + esc(p.cover) + '\')" aria-label="' + esc(p.title) + '"></a>' +
      '<div class="blog-card-body">' +
        '<div class="blog-meta"><span class="blog-tag">' + esc(p.category) + '</span><time datetime="' + esc(p.date) + '">' + fmtDate(p.date) + '</time></div>' +
        '<h2 class="blog-card-title"><a href="' + postUrl(p) + '">' + esc(p.title) + '</a></h2>' +
        '<p class="blog-card-excerpt">' + esc(p.excerpt) + '</p>' +
        '<a class="blog-more" href="' + postUrl(p) + '">Read more <span aria-hidden="true">›</span></a>' +
      '</div>' +
    '</article>';
  }

  function renderList() {
    var grid = document.getElementById('blog-grid');
    var filters = document.querySelector('.blog-filters');
    if (!grid) return;
    var posts = sorted();
    var cats = ['All'];
    posts.forEach(function (p) { if (cats.indexOf(p.category) === -1) cats.push(p.category); });
    function show(cat) {
      var list = posts.filter(function (p) { return cat === 'All' || p.category === cat; });
      grid.innerHTML = list.length ? list.map(card).join('') : '<p class="blog-empty">No posts yet.</p>';
      if (filters) [].forEach.call(filters.children, function (b) { b.classList.toggle('is-active', b.getAttribute('data-cat') === cat); });
    }
    if (filters) {
      filters.innerHTML = cats.map(function (c) {
        return '<button type="button" class="blog-filter" data-cat="' + esc(c) + '">' + esc(c) + '</button>';
      }).join('');
      filters.addEventListener('click', function (e) {
        var b = e.target.closest('.blog-filter');
        if (b) show(b.getAttribute('data-cat'));
      });
    }
    show('All');
  }

  function renderPost() {
    var box = document.getElementById('blog-article');
    if (!box) return;
    var slug = new URLSearchParams(location.search).get('p');
    var posts = sorted();
    var p = posts.filter(function (x) { return x.slug === slug; })[0];
    if (!p) {
      box.innerHTML = '<p class="blog-empty">This post could not be found.</p><p class="blog-cta"><a class="blog-btn" href="blog.html">Back to the blog</a></p>';
      return;
    }
    document.title = p.title + ' — Warriors Dream Series';
    var meta = document.querySelector('meta[name="description"]');
    if (meta) meta.setAttribute('content', p.excerpt);
    var more = posts.filter(function (x) { return x.slug !== p.slug; }).slice(0, 2);
    box.innerHTML =
      '<a class="blog-back" href="blog.html"><span aria-hidden="true">‹</span> All posts</a>' +
      '<div class="blog-meta"><span class="blog-tag">' + esc(p.category) + '</span><time datetime="' + esc(p.date) + '">' + fmtDate(p.date) + '</time><span>· ' + esc(p.author) + '</span></div>' +
      '<h1 class="blog-article-title">' + esc(p.title) + '</h1>' +
      '<div class="blog-article-cover" style="background-image:url(\'' + esc(p.cover) + '\')" role="img" aria-label="' + esc(p.title) + '"></div>' +
      '<div class="blog-article-body">' + p.body + '</div>' +
      (more.length ? '<section class="blog-related"><h2 class="blog-related-title">More from the blog</h2><div class="blog-grid">' + more.map(card).join('') + '</div></section>' : '');
  }

  window.WDSBlog = { posts: POSTS, renderList: renderList, renderPost: renderPost };
})();
