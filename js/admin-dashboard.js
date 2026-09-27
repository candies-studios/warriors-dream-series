// Supabase Configuration
const SUPABASE_URL = 'https://qjqpquwcfarvyjzfzjcb.supabase.co';
const SUPABASE_ANON_KEY = 'evJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.evJpc3MiOiJzdXJhYmFzZSIsInJlZiI6InFqcXBxdXdjZmFydnlqemZ6amNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMTY0MDksImV4cCI6MjEwNTg5MjQwOX0.ZLFN4fA';

const { createClient } = supabase;
const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Tab switching
function switchTab(tabName) {
    document.querySelectorAll('.tab-content').forEach(tab => tab.classList.remove('active'));
    document.querySelectorAll('.tab-button').forEach(btn => btn.classList.remove('active'));
    document.getElementById(tabName).classList.add('active');
    event.target.classList.add('active');

    if (tabName === 'fighters') loadFighters();
    else if (tabName === 'events') loadEvents();
    else if (tabName === 'bouts') { loadEvents(); loadFighters(); loadBouts(); }
    else if (tabName === 'judges') loadJudges();
    else if (tabName === 'scorecards') { loadBouts(); loadJudges(); loadScorecards(); }
    else if (tabName === 'rankings') loadRankings();
}

// Auth
async function loginUser() {
    const email = document.getElementById('loginEmail').value;
    const password = document.getElementById('loginPassword').value;

    if (!email || !password) {
        showMessage('loginMessage', 'Please enter email and password', 'error');
        return;
    }

    try {
        const { data, error } = await db.auth.signInWithPassword({ email, password });
        if (error) {
            showMessage('loginMessage', 'Login failed: ' + error.message, 'error');
            return;
        }
        closeLoginModal();
        updateAuthUI();
        loadFighters();
    } catch (err) {
        showMessage('loginMessage', 'Error: ' + err.message, 'error');
    }
}

async function logoutUser() {
    try {
        await db.auth.signOut();
        updateAuthUI();
        ['fightersList', 'eventsList', 'boutsList', 'judgesList', 'scorecardsList', 'rankingsList'].forEach(id => document.getElementById(id).innerHTML = '');
    } catch (err) {
        console.error('Logout error:', err);
    }
}

async function updateAuthUI() {
    const { data: { user } } = await db.auth.getUser();
    const userEmail = document.getElementById('currentUser');
    const userRole = document.getElementById('userRole');

    if (user) {
        userEmail.textContent = user.email;
        userRole.textContent = user.user_metadata?.role || 'Unknown';
    } else {
        userEmail.textContent = 'Not logged in';
        userRole.textContent = '-';
    }
}

function openLoginModal() {
    document.getElementById('loginModal').style.display = 'flex';
}

function closeLoginModal() {
    document.getElementById('loginModal').style.display = 'none';
    document.getElementById('loginEmail').value = '';
    document.getElementById('loginPassword').value = '';
    document.getElementById('loginMessage').innerHTML = '';
}

function showMessage(elementId, message, type) {
    const element = document.getElementById(elementId);
    element.innerHTML = `<div class="message ${type}">${message}</div>`;
    setTimeout(() => element.innerHTML = '', 5000);
}

// Fighters
async function addFighter() {
    const firstName = document.getElementById('fighterFirstName').value;
    const lastName = document.getElementById('fighterLastName').value;
    const nickname = document.getElementById('fighterNickname').value;
    const country = document.getElementById('fighterCountry').value;
    const weightClass = document.getElementById('fighterWeightClass').value;
    const bornYear = document.getElementById('fighterBornYear').value;

    if (!firstName || !lastName || !country || !weightClass || !bornYear) {
        showMessage('fighterMessage', 'Please fill all required fields', 'error');
        return;
    }

    try {
        const { data, error } = await db
            .from('fighters')
            .insert([{
                first_name: firstName,
                last_name: lastName,
                nickname: nickname,
                country: country,
                weight_class: weightClass,
                born_year: parseInt(bornYear),
                public_id: 'FTR-' + Math.random().toString(36).substr(2, 9).toUpperCase()
            }])
            .select();

        if (error) {
            showMessage('fighterMessage', 'Error: ' + error.message, 'error');
            return;
        }

        showMessage('fighterMessage', 'Fighter added successfully!', 'success');
        document.getElementById('fighterFirstName').value = '';
        document.getElementById('fighterLastName').value = '';
        document.getElementById('fighterNickname').value = '';
        document.getElementById('fighterCountry').value = '';
        document.getElementById('fighterWeightClass').value = '';
        document.getElementById('fighterBornYear').value = '';
        loadFighters();
    } catch (err) {
        showMessage('fighterMessage', 'Error: ' + err.message, 'error');
    }
}

async function loadFighters() {
    const container = document.getElementById('fightersList');
    container.innerHTML = '<div class="loading"><div class="spinner"></div></div>';

    try {
        const { data, error } = await db
            .from('fighters')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) {
            container.innerHTML = `<div class="message error">Error: ${error.message}</div>`;
            return;
        }

        if (!data || data.length === 0) {
            container.innerHTML = '<div class="empty-state"><p>No fighters found</p><p>Add your first fighter above</p></div>';
            return;
        }

        let html = '<table class="data-table"><thead><tr><th>Name</th><th>Nickname</th><th>Country</th><th>Weight Class</th><th>Born</th><th>ID</th></tr></thead><tbody>';
        data.forEach(fighter => {
            html += `
                <tr>
                    <td>${fighter.first_name} ${fighter.last_name}</td>
                    <td>${fighter.nickname || '-'}</td>
                    <td>${fighter.country}</td>
                    <td>${fighter.weight_class}</td>
                    <td>${fighter.born_year}</td>
                    <td>${fighter.public_id}</td>
                </tr>
            `;
        });
        html += '</tbody></table>';
        container.innerHTML = html;

        updateDropdown('boutFighter1Id', data);
        updateDropdown('boutFighter2Id', data);
    } catch (err) {
        container.innerHTML = `<div class="message error">Error: ${err.message}</div>`;
    }
}

// Events
async function addEvent() {
    const title = document.getElementById('eventTitle').value;
    const date = document.getElementById('eventDate').value;
    const location = document.getElementById('eventLocation').value;
    const status = document.getElementById('eventStatus').value;

    if (!title || !date || !location) {
        showMessage('eventMessage', 'Please fill all required fields', 'error');
        return;
    }

    try {
        const { data, error } = await db
            .from('events')
            .insert([{
                title: title,
                event_date: date,
                location: location,
                status: status,
                public_id: 'EVT-' + Math.random().toString(36).substr(2, 9).toUpperCase()
            }])
            .select();

        if (error) {
            showMessage('eventMessage', 'Error: ' + error.message, 'error');
            return;
        }

        showMessage('eventMessage', 'Event created successfully!', 'success');
        document.getElementById('eventTitle').value = '';
        document.getElementById('eventDate').value = '';
        document.getElementById('eventLocation').value = '';
        loadEvents();
    } catch (err) {
        showMessage('eventMessage', 'Error: ' + err.message, 'error');
    }
}

async function loadEvents() {
    try {
        const { data, error } = await db
            .from('events')
            .select('*')
            .order('event_date', { ascending: false });

        if (error) return;

        const container = document.getElementById('eventsList');
        if (!data || data.length === 0) {
            container.innerHTML = '<div class="empty-state"><p>No events found</p></div>';
            return;
        }

        let html = '<table class="data-table"><thead><tr><th>Title</th><th>Date</th><th>Location</th><th>Status</th><th>ID</th></tr></thead><tbody>';
        data.forEach(event => {
            html += `
                <tr>
                    <td>${event.title}</td>
                    <td>${new Date(event.event_date).toLocaleDateString()}</td>
                    <td>${event.location}</td>
                    <td>${event.status}</td>
                    <td>${event.public_id}</td>
                </tr>
            `;
        });
        html += '</tbody></table>';
        container.innerHTML = html;

        updateDropdown('boutEventId', data, 'id', 'title');
    } catch (err) {
        console.error('Error:', err);
    }
}

// Bouts
async function addBout() {
    const eventId = document.getElementById('boutEventId').value;
    const fighter1Id = document.getElementById('boutFighter1Id').value;
    const fighter2Id = document.getElementById('boutFighter2Id').value;
    const status = document.getElementById('boutStatus').value;

    if (!eventId || !fighter1Id || !fighter2Id) {
        showMessage('boutMessage', 'Please select all required fields', 'error');
        return;
    }

    if (fighter1Id === fighter2Id) {
        showMessage('boutMessage', 'Fighters must be different', 'error');
        return;
    }

    try {
        const { data, error } = await db
            .from('bouts')
            .insert([{
                event_id: eventId,
                fighter_1_id: fighter1Id,
                fighter_2_id: fighter2Id,
                status: status,
                public_id: 'BOU-' + Math.random().toString(36).substr(2, 9).toUpperCase()
            }])
            .select();

        if (error) {
            showMessage('boutMessage', 'Error: ' + error.message, 'error');
            return;
        }

        showMessage('boutMessage', 'Bout created successfully!', 'success');
        document.getElementById('boutEventId').value = '';
        document.getElementById('boutFighter1Id').value = '';
        document.getElementById('boutFighter2Id').value = '';
        loadBouts();
    } catch (err) {
        showMessage('boutMessage', 'Error: ' + err.message, 'error');
    }
}

async function loadBouts() {
    const container = document.getElementById('boutsList');
    container.innerHTML = '<div class="loading"><div class="spinner"></div></div>';

    try {
        const { data, error } = await db
            .from('bouts')
            .select(`id, public_id, status, created_at, events(title), fighters!bouts_fighter_1_id_fkey(first_name, last_name), fighters!bouts_fighter_2_id_fkey(first_name, last_name)`)
            .order('created_at', { ascending: false });

        if (error) {
            container.innerHTML = `<div class="message error">Error: ${error.message}</div>`;
            return;
        }

        if (!data || data.length === 0) {
            container.innerHTML = '<div class="empty-state"><p>No bouts found</p></div>';
            return;
        }

        let html = '<table class="data-table"><thead><tr><th>Event</th><th>Fighter 1</th><th>Fighter 2</th><th>Status</th><th>ID</th></tr></thead><tbody>';
        data.forEach(bout => {
            const event = bout.events?.title || 'Unknown';
            const f1 = bout.fighters ? bout.fighters[0]?.first_name + ' ' + bout.fighters[0]?.last_name : 'Unknown';
            const f2 = bout.fighters ? bout.fighters[1]?.first_name + ' ' + bout.fighters[1]?.last_name : 'Unknown';
            html += `<tr><td>${event}</td><td>${f1}</td><td>${f2}</td><td>${bout.status}</td><td>${bout.public_id}</td></tr>`;
        });
        html += '</tbody></table>';
        container.innerHTML = html;

        updateDropdown('scorecardBoutId', data, 'id', 'public_id');
    } catch (err) {
        container.innerHTML = `<div class="message error">Error: ${err.message}</div>`;
    }
}

// Judges
async function addJudge() {
    const name = document.getElementById('judgeName').value;
    const country = document.getElementById('judgeCountry').value;
    const experience = document.getElementById('judgeExperience').value;

    if (!name || !country || !experience) {
        showMessage('judgeMessage', 'Please fill all required fields', 'error');
        return;
    }

    try {
        const { data, error } = await db
            .from('judges')
            .insert([{
                name: name,
                country: country,
                experience_years: parseInt(experience),
                public_id: 'JUD-' + Math.random().toString(36).substr(2, 9).toUpperCase()
            }])
            .select();

        if (error) {
            showMessage('judgeMessage', 'Error: ' + error.message, 'error');
            return;
        }

        showMessage('judgeMessage', 'Judge added successfully!', 'success');
        document.getElementById('judgeName').value = '';
        document.getElementById('judgeCountry').value = '';
        document.getElementById('judgeExperience').value = '';
        loadJudges();
    } catch (err) {
        showMessage('judgeMessage', 'Error: ' + err.message, 'error');
    }
}

async function loadJudges() {
    const container = document.getElementById('judgesList');
    container.innerHTML = '<div class="loading"><div class="spinner"></div></div>';

    try {
        const { data, error } = await db
            .from('judges')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) {
            container.innerHTML = `<div class="message error">Error: ${error.message}</div>`;
            return;
        }

        if (!data || data.length === 0) {
            container.innerHTML = '<div class="empty-state"><p>No judges found</p></div>';
            return;
        }

        let html = '<table class="data-table"><thead><tr><th>Name</th><th>Country</th><th>Experience</th><th>ID</th></tr></thead><tbody>';
        data.forEach(judge => {
            html += `<tr><td>${judge.name}</td><td>${judge.country}</td><td>${judge.experience_years} years</td><td>${judge.public_id}</td></tr>`;
        });
        html += '</tbody></table>';
        container.innerHTML = html;

        updateDropdown('scorecardJudgeId', data, 'id', 'name');
    } catch (err) {
        container.innerHTML = `<div class="message error">Error: ${err.message}</div>`;
    }
}

// Scorecards
async function addScorecard() {
    const boutId = document.getElementById('scorecardBoutId').value;
    const judgeId = document.getElementById('scorecardJudgeId').value;
    const fighter1Scores = document.getElementById('scorecardFighter1Scores').value;
    const fighter2Scores = document.getElementById('scorecardFighter2Scores').value;

    if (!boutId || !judgeId || !fighter1Scores || !fighter2Scores) {
        showMessage('scorecardMessage', 'Please fill all required fields', 'error');
        return;
    }

    try {
        const { data, error } = await db
            .from('scorecards')
            .insert([{
                bout_id: boutId,
                judge_id: judgeId,
                fighter_1_scores: fighter1Scores.split(',').map(s => parseInt(s.trim())),
                fighter_2_scores: fighter2Scores.split(',').map(s => parseInt(s.trim())),
                public_id: 'SCD-' + Math.random().toString(36).substr(2, 9).toUpperCase()
            }])
            .select();

        if (error) {
            showMessage('scorecardMessage', 'Error: ' + error.message, 'error');
            return;
        }

        showMessage('scorecardMessage', 'Scorecard created successfully!', 'success');
        document.getElementById('scorecardBoutId').value = '';
        document.getElementById('scorecardJudgeId').value = '';
        document.getElementById('scorecardFighter1Scores').value = '';
        document.getElementById('scorecardFighter2Scores').value = '';
        loadScorecards();
    } catch (err) {
        showMessage('scorecardMessage', 'Error: ' + err.message, 'error');
    }
}

async function loadScorecards() {
    const container = document.getElementById('scorecardsList');
    container.innerHTML = '<div class="loading"><div class="spinner"></div></div>';

    try {
        const { data, error } = await db
            .from('scorecards')
            .select(`id, public_id, fighter_1_scores, fighter_2_scores, created_at, bouts(public_id), judges(name)`)
            .order('created_at', { ascending: false });

        if (error) {
            container.innerHTML = `<div class="message error">Error: ${error.message}</div>`;
            return;
        }

        if (!data || data.length === 0) {
            container.innerHTML = '<div class="empty-state"><p>No scorecards found</p></div>';
            return;
        }

        let html = '<table class="data-table"><thead><tr><th>Bout</th><th>Judge</th><th>Fighter 1 Scores</th><th>Fighter 2 Scores</th><th>ID</th></tr></thead><tbody>';
        data.forEach(scorecard => {
            const bout = scorecard.bouts?.public_id || 'Unknown';
            const judge = scorecard.judges?.name || 'Unknown';
            const f1 = scorecard.fighter_1_scores?.join(', ') || '-';
            const f2 = scorecard.fighter_2_scores?.join(', ') || '-';
            html += `<tr><td>${bout}</td><td>${judge}</td><td>${f1}</td><td>${f2}</td><td>${scorecard.public_id}</td></tr>`;
        });
        html += '</tbody></table>';
        container.innerHTML = html;
    } catch (err) {
        container.innerHTML = `<div class="message error">Error: ${err.message}</div>`;
    }
}

// Rankings
async function loadRankings() {
    const container = document.getElementById('rankingsList');
    const weightClass = document.getElementById('rankingWeightClass').value;

    container.innerHTML = '<div class="loading"><div class="spinner"></div></div>';

    try {
        let query = db
            .from('rankings')
            .select(`rank_position, points, wins, losses, weight_class, fighters(first_name, last_name, nickname), public_id`)
            .order('rank_position', { ascending: true });

        if (weightClass) {
            query = query.eq('weight_class', weightClass);
        }

        const { data, error } = await query;

        if (error) {
            container.innerHTML = `<div class="message error">Error: ${error.message}</div>`;
            return;
        }

        if (!data || data.length === 0) {
            container.innerHTML = '<div class="empty-state"><p>No rankings yet</p><p>Complete some bouts to see rankings</p></div>';
            return;
        }

        let html = '<table class="data-table"><thead><tr><th>Rank</th><th>Fighter</th><th>Weight Class</th><th>Points</th><th>Record</th></tr></thead><tbody>';
        data.forEach((ranking) => {
            const fighter = ranking.fighters;
            const name = fighter ? `${fighter.first_name} ${fighter.last_name}` : 'Unknown';
            const nickname = fighter?.nickname ? ` (${fighter.nickname})` : '';
            const record = `${ranking.wins}W - ${ranking.losses}L`;

            html += `<tr><td>#${ranking.rank_position}</td><td>${name}${nickname}</td><td>${ranking.weight_class}</td><td>${ranking.points} pts</td><td>${record}</td></tr>`;
        });

        html += '</tbody></table>';
        container.innerHTML = html;
    } catch (err) {
        container.innerHTML = `<div class="message error">Error: ${err.message}</div>`;
    }
}

// Utility
function updateDropdown(elementId, data, valueKey = 'id', labelKey = 'first_name') {
    const select = document.getElementById(elementId);
    if (!select) return;

    const options = select.querySelectorAll('option:not(:first-child)');
    options.forEach(opt => opt.remove());

    data.forEach(item => {
        const option = document.createElement('option');
        option.value = item[valueKey];
        option.textContent = item[labelKey] || 'Unknown';
        select.appendChild(option);
    });
}

// Init
window.addEventListener('load', updateAuthUI);
