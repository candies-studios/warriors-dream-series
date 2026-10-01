/*
 * WDS shared database — connection settings for every page of the website.
 *
 * One Supabase project is the single source of truth for events, fighters,
 * fights, results and rankings. ScoreHUB points at the same project.
 * The anon key is public by design; Row Level Security in the database
 * decides what each visitor or signed-in official may read or change.
 */
window.WDS_CONFIG = {
  supabaseUrl: 'https://qjqpquwcfarvyjzfzjcb.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqcXBxdXdjZmFydnlqemZ6amNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMTE0NDIsImV4cCI6MjEwNTg4NzQ0Mn0.V747d27nDgWroNv2gafQborcxNhAIKpv4d6iZLFN4fA',
  // Where officials score fights.
  scorehubUrl: 'https://candies-studios.github.io/scoreHUB/',
  // Event times are entered in this timezone.
  timezone: 'Asia/Kolkata',
};
