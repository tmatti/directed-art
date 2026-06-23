# Accounts hold multiple child Profiles; Profiles own Drawings

An Account (the adult-owned email/password login) has many Profiles, one per child. A Directed Drawing and its progress belong to a Profile, not directly to the Account. A session begins by choosing which Profile is drawing ("who's drawing today?"), so each child gets their own gallery and progress.

We chose this over a flat account-owns-drawings model despite the added complexity, because the realistic users are parents with several children and teachers with a classroom — a shared, mixed gallery would degrade the core "revisit my past drawings" experience for exactly the common case. The Account owns identity and billing concerns; Profiles own the creative content. Classroom-scale management features (rosters, bulk profiles) remain deferred — Profiles give us the data shape without committing to that surface yet.
