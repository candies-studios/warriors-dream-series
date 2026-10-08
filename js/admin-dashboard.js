/*
 * WDS Admin Dashboard — management tool for the shared WDS database.
 *
 * Same Supabase project as the website and ScoreHUB (js/wds-config.js).
 * What management can do here is enforced by Row Level Security in the
 * database, not by this page: only Admin/Promoter accounts can write.
 */
const { createClient } = supabase;
const db = createClient(WDS_CONFIG.supabaseUrl, WDS_CONFIG.supabaseAnonKey, {
    auth: { persistSession: true, autoRefreshToken: true, storageKey: 'wds-admin-auth' },
});

let me = null;              // { id, name, email, role } of the signed-in official
let editingEventId = null;  // event being edited in the Events form

// ---------------------------------------------------------------- utilities
function esc(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function val(id) { const el = document.getElementById(id); return el ? el.value.trim() : ''; }
function setVal(id, v) { const el = document.getElementById(id); if (el) el.value = v == null ? '' : v; }
function orNull(v) { return v === '' ? null : v; }

function showMessage(elementId, message, type) {
    const element = document.getElementById(elementId);
    if (!element) return;
    element.innerHTML = `<div class="message ${type}">${esc(message)}</div>`;
    clearTimeout(element.__timer);
    element.__timer = setTimeout(() => element.innerHTML = '', 6000);
}

function spinner(id) {
    const el = document.getElementById(id);
    if (el) el.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
    return el;
}

function friendly(error) {
    const msg = (error && error.message) || String(error);
    if (/row-level security|permission denied/i.test(msg)) return 'Your account does not have permission for that. Sign in as Admin or Promoter.';
    return msg;
}

function formatDate(d) {
    if (!d) return 'TBA';
    const [y, m, day] = d.split('-').map(Number);
    return new Date(Date.UTC(y, m - 1, day)).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' });
}
function formatTime(t) {
    if (!t) return 'TBA';
    const [h, m] = t.split(':').map(Number);
    return `${(h % 12) || 12}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`;
}
function pill(text, kind) { return `<span class="pill ${esc(kind || text)}">${esc(text)}</span>`; }

function updateDropdown(elementId, data, valueKey = 'id', label = item => item.name) {
    const select = document.getElementById(elementId);
    if (!select) return;
    const current = select.value;
    select.querySelectorAll('option:not(:first-child)').forEach(opt => opt.remove());
    data.forEach(item => {
        const option = document.createElement('option');
        option.value = item[valueKey];
        option.textContent = label(item) || 'Unknown';
        select.appendChild(option);
    });
    if ([...select.options].some(o => o.value === current)) select.value = current;
}

// ---------------------------------------------------------------- tabs
function switchTab(tabName) {
    document.querySelectorAll('.tab-content').forEach(tab => tab.classList.remove('active'));
    document.querySelectorAll('.tab-button').forEach(btn => btn.classList.remove('active'));
    document.getElementById(tabName).classList.add('active');
    if (window.event && window.event.target) window.event.target.classList.add('active');

    if (tabName === 'fighters') loadFighters();
    else if (tabName === 'events') loadEvents();
    else if (tabName === 'bouts') { loadEvents(); loadFighters(); loadBouts(); }
    else if (tabName === 'judges') loadJudges();
    else if (tabName === 'scorecards') { loadBouts(); loadScorecards(); }
    else if (tabName === 'rankings') loadRankings();
}

// ---------------------------------------------------------------- auth
async function loginUser() {
    const email = val('loginEmail').toLowerCase();
    const password = document.getElementById('loginPassword').value;
    if (!email || !password) {
        showMessage('loginMessage', 'Please enter email and password', 'error');
        return;
    }
    try {
        let { error } = await db.auth.signInWithPassword({ email, password });
        if (error) {
            // Invited but never signed in: the password entered now becomes theirs.
            const { data: officials } = await db.rpc('list_officials');
            const invited = (officials || []).find(o => (o.login_email || '').toLowerCase() === email && !o.registered);
            if (!invited) {
                showMessage('loginMessage', 'Login failed: ' + error.message, 'error');
                return;
            }
            if (password.length < 6) {
                showMessage('loginMessage', 'Choose a password of at least 6 characters.', 'error');
                return;
            }
            const up = await db.auth.signUp({ email, password, options: { data: { name: invited.name } } });
            if (up.error) { showMessage('loginMessage', 'Login failed: ' + up.error.message, 'error'); return; }
            if (!up.data.session) {
                showMessage('loginMessage', 'Account created. Confirm the email we sent, then log in again.', 'info');
                return;
            }
        }
        closeLoginModal();
        await updateAuthUI();
        loadFighters();
    } catch (err) {
        showMessage('loginMessage', 'Error: ' + err.message, 'error');
    }
}

async function logoutUser() {
    try {
        await db.auth.signOut();
    } catch (err) {
        console.error('Logout error:', err);
    }
    await updateAuthUI();
}

async function updateAuthUI() {
    const { data: { session } } = await db.auth.getSession();
    me = null;
    if (session) {
        const { data } = await db.from('profiles').select('id,name,email,role,active').eq('id', session.user.id).maybeSingle();
        if (data && data.active && data.role) me = data;
    }
    document.getElementById('currentUser').textContent = session ? (me ? `${me.name} (${session.user.email})` : session.user.email) : 'Not logged in';
    document.getElementById('userRole').textContent = me ? me.role : (session ? 'No role — ask an admin' : '-');
}

function isStaff() { return me && (me.role === 'ADMIN' || me.role === 'PROMOTER'); }
function requireStaff(messageId) {
    if (isStaff()) return true;
    showMessage(messageId, 'Log in with an Admin or Promoter account to make changes.', 'error');
    return false;
}

function openLoginModal() {
    document.getElementById('loginModal').style.display = 'flex';
}

function closeLoginModal() {
    document.getElementById('loginModal').style.display = 'none';
    setVal('loginEmail', '');
    setVal('loginPassword', '');
    document.getElementById('loginMessage').innerHTML = '';
}

// ---------------------------------------------------------------- fighters
async function addFighter() {
    if (!requireStaff('fighterMessage')) return;
    const firstName = val('fighterFirstName');
    const lastName = val('fighterLastName');
    const bornYear = val('fighterBornYear');
    if (!firstName || !lastName) {
        showMessage('fighterMessage', 'Please enter the first and last name', 'error');
        return;
    }
    const { error } = await db.from('fighters').insert([{
        name: `${firstName} ${lastName}`,
        first_name: firstName,
        last_name: lastName,
        nickname: orNull(val('fighterNickname')),
        country: orNull(val('fighterCountry')),
        weight_class: orNull(val('fighterWeightClass')),
        born_year: bornYear ? parseInt(bornYear, 10) : null,
    }]);
    if (error) { showMessage('fighterMessage', 'Error: ' + friendly(error), 'error'); return; }
    showMessage('fighterMessage', 'Fighter added successfully!', 'success');
    ['fighterFirstName', 'fighterLastName', 'fighterNickname', 'fighterCountry', 'fighterWeightClass', 'fighterBornYear'].forEach(id => setVal(id, ''));
    loadFighters();
}

async function loadFighters() {
    const container = spinner('fightersList');
    const { data, error } = await db.from('fighters')
        .select('id,public_id,name,nickname,country,weight_class,born_year,team')
        .order('name');
    if (error) { container.innerHTML = `<div class="message error">Error: ${esc(error.message)}</div>`; return; }
    updateDropdown('boutFighter1Id', data);
    updateDropdown('boutFighter2Id', data);
    if (!data.length) {
        container.innerHTML = '<div class="empty-state"><p>No fighters found</p><p>Add your first fighter above</p></div>';
        return;
    }
    container.innerHTML = '<table class="data-table"><thead><tr><th>Name</th><th>Nickname</th><th>Country</th><th>Weight Class</th><th>Born</th><th>ID</th></tr></thead><tbody>' +
        data.map(f => `<tr><td>${esc(f.name)}</td><td>${esc(f.nickname || '-')}</td><td>${esc(f.country || '-')}</td><td>${esc(f.weight_class || '-')}</td><td>${esc(f.born_year || '-')}</td><td>${esc(f.public_id)}</td></tr>`).join('') +
        '</tbody></table>';
}

// ---------------------------------------------------------------- events
function eventFormValues() {
    return {
        title: val('eventTitle'),
        series: val('eventSeries') || 'rising-star',
        status: val('eventStatus') || 'draft',
        event_date: orNull(val('eventDate')),
        end_date: orNull(val('eventEndDate')),
        start_time: orNull(val('eventTime')),
        venue: orNull(val('eventLocation')),
        city: orNull(val('eventCity')),
        poster_url: orNull(val('eventPoster')),
        description: orNull(val('eventDescription')),
        page_url: orNull(val('eventPageUrl')),
        series_label: orNull(val('eventSeriesLabel')),
    };
}

async function saveEvent() {
    if (!requireStaff('eventMessage')) return;
    const row = eventFormValues();
    if (!row.title) {
        showMessage('eventMessage', 'Please enter the event title', 'error');
        return;
    }
    const query = editingEventId
        ? db.from('events').update(row).eq('id', editingEventId).select('status')
        : db.from('events').insert([{ ...row, created_by: me.id }]).select('status');
    const { data, error } = await query;
    if (error) { showMessage('eventMessage', 'Error: ' + friendly(error), 'error'); return; }
    const status = data && data[0] ? data[0].status : row.status;
    const note = status !== row.status ? ` Status is now "${status}".` : '';
    showMessage('eventMessage', (editingEventId ? 'Event updated — the website and ScoreHUB show it now.' : 'Event created!') + note, 'success');
    resetEventForm();
    loadEvents();
}

async function editEvent(id) {
    const { data: ev, error } = await db.from('events').select('*').eq('id', id).single();
    if (error) { showMessage('eventMessage', 'Error: ' + error.message, 'error'); return; }
    editingEventId = id;
    setVal('eventTitle', ev.title);
    setVal('eventSeries', ev.series);
    setVal('eventStatus', ev.status);
    setVal('eventDate', ev.event_date);
    setVal('eventEndDate', ev.end_date);
    setVal('eventTime', ev.start_time ? ev.start_time.slice(0, 5) : '');
    setVal('eventLocation', ev.venue);
    setVal('eventCity', ev.city);
    setVal('eventPoster', ev.poster_url);
    setVal('eventDescription', ev.description);
    setVal('eventPageUrl', ev.page_url);
    setVal('eventSeriesLabel', ev.series_label);
    document.getElementById('eventSubmit').textContent = 'Update Event';
    document.getElementById('eventCancel').style.display = '';
    document.getElementById('eventTitle').scrollIntoView({ behavior: 'smooth', block: 'center' });
}

function resetEventForm() {
    editingEventId = null;
    ['eventTitle', 'eventDate', 'eventEndDate', 'eventTime', 'eventLocation', 'eventCity', 'eventPoster', 'eventDescription', 'eventPageUrl', 'eventSeriesLabel'].forEach(id => setVal(id, ''));
    setVal('eventStatus', 'draft');
    setVal('eventSeries', 'rising-star');
    document.getElementById('eventSubmit').textContent = 'Create Event';
    document.getElementById('eventCancel').style.display = 'none';
}

async function finalizeEvent(id) {
    if (!requireStaff('eventMessage')) return;
    if (!confirm('Publish all provisional results of this event and update the rankings?')) return;
    const { data, error } = await db.rpc('finalize_event_results', { p_event: id });
    if (error) { showMessage('eventMessage', 'Error: ' + friendly(error), 'error'); return; }
    showMessage('eventMessage', `${data} result(s) finalized. Rankings recalculated.`, 'success');
    loadEvents();
}

async function loadEvents() {
    const container = document.getElementById('eventsList');
    const { data, error } = await db.from('events')
        .select('id,public_id,title,status,event_date,start_time,venue,city,is_listed,bouts(count)')
        .order('event_date', { ascending: false, nullsFirst: true });
    if (error) { if (container) container.innerHTML = `<div class="message error">Error: ${esc(error.message)}</div>`; return; }
    const listed = data.filter(e => e.is_listed);
    updateDropdown('boutEventId', listed, 'id', e => `${e.title} (${e.status})`);
    if (!container) return;
    if (!listed.length) {
        container.innerHTML = '<div class="empty-state"><p>No events found</p></div>';
        return;
    }
    container.innerHTML = '<table class="data-table"><thead><tr><th>Title</th><th>Date</th><th>Time</th><th>Venue</th><th>Status</th><th>Bouts</th><th></th></tr></thead><tbody>' +
        listed.map(e => {
            const bouts = e.bouts && e.bouts[0] ? e.bouts[0].count : 0;
            return `<tr><td>${esc(e.title)}</td><td>${esc(formatDate(e.event_date))}</td><td>${esc(formatTime(e.start_time))}</td>` +
                `<td>${esc([e.venue, e.city].filter(Boolean).join(', ') || 'TBA')}</td><td>${pill(e.status)}</td><td>${bouts}</td>` +
                `<td><button class="btn-secondary" onclick="editEvent('${e.id}')">Edit</button>` +
                (bouts ? `<button class="btn-secondary" onclick="finalizeEvent('${e.id}')">Finalize results</button>` : '') + '</td></tr>';
        }).join('') + '</tbody></table>';
}

// ---------------------------------------------------------------- bouts
async function addBout() {
    if (!requireStaff('boutMessage')) return;
    const eventId = val('boutEventId');
    const blue = val('boutFighter1Id');
    const red = val('boutFighter2Id');
    const weightClass = orNull(val('boutWeightClass'));
    if (!eventId || !blue || !red) {
        showMessage('boutMessage', 'Please select the event and both fighters', 'error');
        return;
    }
    if (blue === red) {
        showMessage('boutMessage', 'Fighters must be different', 'error');
        return;
    }
    const roster = [blue, red].map(fighter_id => ({ event_id: eventId, fighter_id, weight_class: weightClass }));
    let { error } = await db.from('event_fighters').upsert(roster);
    if (!error) {
        ({ error } = await db.from('bouts').insert([{
            event_id: eventId,
            bout_number: parseInt(val('boutNumber') || '1', 10),
            blue_fighter_id: blue,
            red_fighter_id: red,
            weight_class: weightClass,
            bout_name: weightClass,
            total_rounds: parseInt(val('boutRounds') || '3', 10),
            bout_type: val('boutType') || 'AMATEUR',
        }]));
    }
    if (error) { showMessage('boutMessage', 'Error: ' + friendly(error), 'error'); return; }
    showMessage('boutMessage', 'Bout created — it appears in ScoreHUB now. Seat the judges there.', 'success');
    setVal('boutNumber', String(parseInt(val('boutNumber') || '1', 10) + 1));
    setVal('boutFighter1Id', '');
    setVal('boutFighter2Id', '');
    loadBouts();
}

function boutLabel(b) {
    return `${b.event ? b.event.title : 'Event'} · #${b.bout_number}: ${b.blue ? b.blue.name : 'TBA'} vs ${b.red ? b.red.name : 'TBA'}`;
}

async function loadBouts() {
    const container = spinner('boutsList');
    const eventId = val('boutEventId');
    let query = db.from('bouts')
        .select('id,public_id,bout_number,status,result_status,result_note,event:events(title),blue:fighters!bouts_blue_fighter_id_fkey(name),red:fighters!bouts_red_fighter_id_fkey(name)')
        .order('created_at', { ascending: false })
        .limit(200);
    if (eventId) query = query.eq('event_id', eventId).order('bout_number');
    const { data, error } = await query;
    if (error) { if (container) container.innerHTML = `<div class="message error">Error: ${esc(error.message)}</div>`; return; }
    updateDropdown('scorecardBoutId', data, 'id', boutLabel);
    if (!container) return;
    if (!data.length) {
        container.innerHTML = '<div class="empty-state"><p>No bouts found</p></div>';
        return;
    }
    const isAdmin = me && me.role === 'ADMIN';
    container.innerHTML = '<table class="data-table"><thead><tr><th>Event</th><th>#</th><th>Blue</th><th>Red</th><th>Status</th><th>Result</th><th></th></tr></thead><tbody>' +
        data.map(b => {
            const actions = [];
            if (b.result_status === 'provisional') actions.push(`<button onclick="finalizeBout('${b.id}')">Finalize</button>`);
            if (b.result_status === 'final' && isAdmin) actions.push(`<button class="btn-secondary" onclick="reopenBout('${b.id}')">Reopen</button>`);
            if (b.result_status !== 'final') actions.push(`<button class="btn-secondary" onclick="deleteBout('${b.id}')">Delete</button>`);
            return `<tr><td>${esc(b.event ? b.event.title : '')}</td><td>${b.bout_number}</td><td>${esc(b.blue ? b.blue.name : 'TBA')}</td><td>${esc(b.red ? b.red.name : 'TBA')}</td>` +
                `<td>${pill(b.status.toLowerCase(), b.status === 'LIVE' ? 'live' : '')}</td>` +
                `<td>${b.result_note ? esc(b.result_note) + ' ' : ''}${b.result_status !== 'none' ? pill(b.result_status) : ''}</td><td>${actions.join('')}</td></tr>`;
        }).join('') + '</tbody></table>';
}

async function finalizeBout(id) {
    if (!requireStaff('boutMessage')) return;
    const { error } = await db.rpc('finalize_bout_result', { p_bout: id });
    if (error) { showMessage('boutMessage', 'Error: ' + friendly(error), 'error'); return; }
    showMessage('boutMessage', 'Result finalized — published on the website and rankings updated.', 'success');
    loadBouts();
}

async function finalizeSelectedEvent() {
    const eventId = val('boutEventId');
    if (!eventId) { showMessage('boutMessage', 'Select the event first', 'error'); return; }
    if (!requireStaff('boutMessage')) return;
    if (!confirm('Publish all provisional results of this event and update the rankings?')) return;
    const { data, error } = await db.rpc('finalize_event_results', { p_event: eventId });
    if (error) { showMessage('boutMessage', 'Error: ' + friendly(error), 'error'); return; }
    showMessage('boutMessage', `${data} result(s) finalized. Rankings recalculated.`, 'success');
    loadBouts();
}

async function reopenBout(id) {
    if (!confirm('Reopen this finalized result? It will be removed from the website and the rankings until finalized again.')) return;
    const { error } = await db.rpc('reopen_bout_result', { p_bout: id });
    if (error) { showMessage('boutMessage', 'Error: ' + friendly(error), 'error'); return; }
    showMessage('boutMessage', 'Result reopened.', 'success');
    loadBouts();
}

async function deleteBout(id) {
    if (!requireStaff('boutMessage')) return;
    if (!confirm('Delete this bout and any scorecards entered for it?')) return;
    const { data, error } = await db.from('bouts').delete().eq('id', id).select('id');
    if (error || !data.length) { showMessage('boutMessage', 'Error: ' + friendly(error || { message: 'Bout could not be deleted' }), 'error'); return; }
    showMessage('boutMessage', 'Bout deleted.', 'success');
    loadBouts();
}

// ---------------------------------------------------------------- officials
async function addJudge() {
    if (!requireStaff('judgeMessage')) return;
    const name = val('judgeName');
    const email = val('judgeEmail').toLowerCase();
    const role = val('judgeRole') || 'JUDGE';
    if (!name || !email || !email.includes('@')) {
        showMessage('judgeMessage', 'Please enter a name and a valid email', 'error');
        return;
    }
    const { error } = await db.from('official_invites').upsert([{ email, name, role, phone: orNull(val('judgePhone')), invited_by: me.id }]);
    if (error) { showMessage('judgeMessage', 'Error: ' + friendly(error), 'error'); return; }
    showMessage('judgeMessage', `${name} added. They sign in to ScoreHUB with their name, role and a PIN they choose.`, 'success');
    ['judgeName', 'judgeEmail', 'judgePhone'].forEach(id => setVal(id, ''));
    loadJudges();
}

async function deactivateOfficial(id) {
    if (!confirm('Deactivate this official? They will no longer be able to sign in to ScoreHUB.')) return;
    const { data, error } = await db.from('profiles').update({ active: false }).eq('id', id).select('id');
    if (error || !data.length) { showMessage('judgeMessage', 'Only an admin can deactivate officials.', 'error'); return; }
    loadJudges();
}

async function removeInvite(email) {
    const { error } = await db.from('official_invites').delete().eq('email', email);
    if (error) { showMessage('judgeMessage', 'Error: ' + friendly(error), 'error'); return; }
    loadJudges();
}

async function loadJudges() {
    const container = spinner('judgesList');
    const [{ data: people, error }, { data: invites }] = await Promise.all([
        db.from('profiles').select('id,name,email,role,phone,active').not('role', 'is', null).order('name'),
        db.from('official_invites').select('email,name,role,phone').order('name'),
    ]);
    if (error) { container.innerHTML = `<div class="message error">Error: ${esc(error.message)}</div>`; return; }
    const known = new Set((people || []).map(p => (p.email || '').toLowerCase()));
    const rows = (people || []).map(p => ({ ...p, state: p.active ? 'registered' : 'inactive' }))
        .concat((invites || []).filter(i => !known.has(i.email)).map(i => ({ ...i, state: 'invited' })));
    if (!rows.length) {
        container.innerHTML = '<div class="empty-state"><p>No officials yet</p><p>Log in as management to see and add officials</p></div>';
        return;
    }
    container.innerHTML = '<table class="data-table"><thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Phone</th><th>Status</th><th></th></tr></thead><tbody>' +
        rows.map(o => `<tr><td>${esc(o.name)}</td><td>${esc(o.email || '-')}</td><td>${esc(o.role)}</td><td>${esc(o.phone || '-')}</td>` +
            `<td>${pill(o.state === 'invited' ? 'invited — first sign-in sets PIN' : o.state, o.state)}</td>` +
            `<td>${o.state === 'registered' ? `<button class="btn-secondary" onclick="deactivateOfficial('${o.id}')">Deactivate</button>` : ''}` +
            `${o.state === 'invited' ? `<button class="btn-secondary" onclick="removeInvite('${esc(o.email)}')">Remove</button>` : ''}</td></tr>`).join('') +
        '</tbody></table>';
}

// ---------------------------------------------------------------- scorecards (read-only)
async function loadScorecards() {
    const container = document.getElementById('scorecardsList');
    const boutId = val('scorecardBoutId');
    if (!boutId) {
        container.innerHTML = '<div class="empty-state"><p>Select a bout to see the judges\' cards</p></div>';
        return;
    }
    spinner('scorecardsList');
    const { data, error } = await db.from('round_scores')
        .select('round_number,blue_score,red_score,submitted_at,judge:profiles(name)')
        .eq('bout_id', boutId)
        .order('round_number');
    if (error) { container.innerHTML = `<div class="message error">Error: ${esc(friendly(error))}</div>`; return; }
    if (!data.length) {
        container.innerHTML = '<div class="empty-state"><p>No scorecards submitted yet</p></div>';
        return;
    }
    const byJudge = {};
    data.forEach(s => {
        const name = s.judge ? s.judge.name : 'Judge';
        (byJudge[name] = byJudge[name] || []).push(s);
    });
    container.innerHTML = '<table class="data-table"><thead><tr><th>Judge</th><th>Rounds (Blue – Red)</th><th>Total</th></tr></thead><tbody>' +
        Object.keys(byJudge).sort().map(name => {
            const rounds = byJudge[name];
            const blue = rounds.reduce((t, r) => t + r.blue_score, 0);
            const red = rounds.reduce((t, r) => t + r.red_score, 0);
            return `<tr><td>${esc(name)}</td><td>${rounds.map(r => `R${r.round_number}: ${r.blue_score}–${r.red_score}`).join(' · ')}</td><td><strong>${blue}–${red}</strong></td></tr>`;
        }).join('') + '</tbody></table>';
}

// ---------------------------------------------------------------- rankings
async function loadRankings() {
    const container = spinner('rankingsList');
    const weightClass = val('rankingWeightClass');
    let query = db.from('public_rankings').select('name,nickname,division_name,score,win_pct,method_points,wins,losses,draws,division_rank,overall_rank');
    query = weightClass ? query.eq('division_name', weightClass).order('division_rank') : query.order('overall_rank');
    const { data, error } = await query;
    loadWeights();
    if (error) { container.innerHTML = `<div class="message error">Error: ${esc(error.message)}</div>`; return; }
    if (!data.length) {
        container.innerHTML = '<div class="empty-state"><p>No rankings yet</p><p>Finalize some results to see rankings</p></div>';
        return;
    }
    container.innerHTML = '<table class="data-table"><thead><tr><th>Rank</th><th>Fighter</th><th>Weight Class</th><th>Score</th><th>Win %</th><th>Method pts</th><th>Record</th></tr></thead><tbody>' +
        data.map(r => `<tr><td>#${weightClass ? r.division_rank : r.overall_rank}</td><td>${esc(r.name)}${r.nickname ? ' (' + esc(r.nickname) + ')' : ''}</td>` +
            `<td>${esc(r.division_name)}</td><td><strong>${Number(r.score).toFixed(2)}</strong></td><td>${Number(r.win_pct).toFixed(1)}%</td>` +
            `<td>${Number(r.method_points).toFixed(2)}</td><td>${r.wins}W - ${r.losses}L${r.draws ? ' - ' + r.draws + 'D' : ''}</td></tr>`).join('') +
        '</tbody></table>';
}

const METHOD_LABELS = {
    KO_HEAD: 'KO (head)', KO_BODY: 'KO (body)', TKO: 'TKO / referee stoppage', DOCTOR_STOPPAGE: 'Doctor stoppage',
    CORNER_STOPPAGE: 'Corner stoppage', SUBMISSION: 'Submission', RNC: 'Verbal submission',
    DECISION_UNANIMOUS: 'Unanimous decision', DECISION_SPLIT: 'Split decision', DECISION_MAJORITY: 'Majority decision',
    DQ: 'Disqualification',
};
const METHOD_ORDER = Object.keys(METHOD_LABELS);

async function loadWeights() {
    const container = document.getElementById('weightsList');
    if (!container) return;
    const { data, error } = await db.from('ranking_method_weights').select('result_type,round_no,weight,confirmed,note');
    if (error) { container.innerHTML = `<div class="message error">Error: ${esc(error.message)}</div>`; return; }
    data.sort((a, b) => METHOD_ORDER.indexOf(a.result_type) - METHOD_ORDER.indexOf(b.result_type) || a.round_no - b.round_no);
    const editable = isStaff();
    container.innerHTML = '<table class="data-table"><thead><tr><th>Win method</th><th>Round</th><th>Weight</th><th>Status</th><th></th></tr></thead><tbody>' +
        data.map(w => {
            const key = `${w.result_type}:${w.round_no}`;
            const input = editable
                ? `<input type="number" step="0.01" min="0" max="10" value="${Number(w.weight)}" data-weight="${esc(key)}" style="width: 90px">`
                : Number(w.weight).toFixed(2);
            return `<tr><td>${esc(METHOD_LABELS[w.result_type] || w.result_type)}</td><td>${w.round_no ? 'R' + w.round_no : 'Any'}</td>` +
                `<td>${input}</td><td>${w.confirmed ? pill('committee', 'final') : pill('to confirm', 'provisional')}</td>` +
                `<td>${editable ? `<button class="btn-secondary" onclick="saveWeight('${esc(key)}')">${w.confirmed ? 'Save' : 'Save &amp; confirm'}</button>` : ''}</td></tr>`;
        }).join('') + '</tbody></table>';
}

async function saveWeight(key) {
    if (!requireStaff('weightsMessage')) return;
    const [resultType, roundNo] = key.split(':');
    const input = document.querySelector(`[data-weight="${key}"]`);
    const weight = Number(input && input.value);
    if (!(weight >= 0 && weight <= 10)) { showMessage('weightsMessage', 'Enter a weight between 0 and 10', 'error'); return; }
    const { data, error } = await db.from('ranking_method_weights')
        .update({ weight, confirmed: true })
        .eq('result_type', resultType).eq('round_no', Number(roundNo)).select('result_type');
    if (error || !data.length) { showMessage('weightsMessage', 'Error: ' + friendly(error || { message: 'permission denied' }), 'error'); return; }
    showMessage('weightsMessage', `${METHOD_LABELS[resultType] || resultType}${Number(roundNo) ? ' R' + roundNo : ''} = ${weight}. Rankings recalculated.`, 'success');
    loadRankings();
}

async function recalculateRankings() {
    const { data, error } = await db.rpc('admin_recompute_rankings');
    if (error) { alert(friendly(error)); return; }
    loadRankings();
    alert(`Rankings recalculated: ${data} fighters ranked.`);
}

// ---------------------------------------------------------------- init
window.addEventListener('load', async () => {
    await updateAuthUI();
    loadFighters();
    // Deferred: supabase-js must not be called inside its own auth callback.
    db.auth.onAuthStateChange(() => setTimeout(updateAuthUI, 0));
});
