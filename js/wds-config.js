/*
 * WDS shared database — connection settings for every page of the website.
 *
 * One Supabase project is the single source of truth for events, fighters,
 * fights, results and rankings. ScoreHUB points at the same project.
 * The anon key is public by design; Row Level Security in the database
 * decides what each visitor or signed-in official may read or change.
 */
window.WDS_CONFIG = {
  supabaseUrl: 'https://zxqaolyckzgaqohpiwtk.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4cWFvbHlja3pnYXFvaHBpd3RrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMTY2ODEsImV4cCI6MjEwNTg5MjY4MX0.hVyih4Jwx4Zi4tpB-2_5Hu0u7ktKEO6KReQPME8tzoA',
  // Where officials score fights.
  scorehubUrl: 'https://candies-studios.github.io/scoreHUB/',
  // Event times are entered in this timezone.
  timezone: 'Asia/Kolkata',
};
