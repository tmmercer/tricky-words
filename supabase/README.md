# Database

Player data lives in the Supabase project `otoypxqbgtqyhgzryfpu`, in three tables:
`tw_players`, `tw_rounds`, `tw_word_stats`. They have row-level security on and no
policies, so the public key can't read or change them directly. The game only calls two
functions, `tw_login(p_name)` and `tw_save_round(...)`, which check their inputs.

Players are identified by name only (no password), so anyone who knows a name can play as
that player. That's fine for a family game, but don't put anything private in these tables.
The migration that created them is `migrations/tricky_words_players.sql`.
