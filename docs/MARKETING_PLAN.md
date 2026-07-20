# Turbo Race — Marketing Plan

**Goal:** Grow installs, ratings, and retention for Turbo Race on Google Play using only free channels.
**App:** https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot
**Site:** https://cpinan.github.io/turbo-race-godot/
**Status baseline:** v1.2.0 (code 6) live. Engineering complete. Marketing is the growth bottleneck.

---

## 0. Positioning

**One-liner:** *Ride a rocket sled, jump the walls, chase a high score — the endless runner you play in short bursts.*

**Genre tags:** Endless runner · Arcade · Casual · Offline · Single-player
**Hook features:** tilt OR joystick control · 3 difficulties · worldwide leaderboards · 20 achievements
**Unique dev story:** rewritten from Cocos2d-x/C++ into Godot 4.7 (fuels the devlog angle in §5).

**Target players:**
- Casual mobile gamers who like Flappy-Bird / Subway-Surfers-style "one more run" loops.
- The Godot / indie-dev community (secondary, via the migration story).

---

## 1. ASO — fix the store listing (HIGHEST PRIORITY)

The listing is the funnel everything else feeds. Fix it **before** promoting — traffic to a weak listing is wasted.

### 1.1 Critical problem: screenshots show no gameplay

Current 5 screenshots are: home menu ×2, control popup, GAME OVER (score 0), PAUSE popup. A browsing user never sees the fun, and one shot literally shows a loss with score 0. Screenshots are the single biggest install-conversion lever on Play. **This is the #1 fix.**

**New shotlist (capture 6–8 at full device resolution, 1080p+):**
1. Mid-jump over an obstacle, near-miss framing — action + tension.
2. HUD with a **high** score visible (never 0).
3. Dense obstacle field / a different obstacle type.
4. Bee character close-up on the sled — sell the character.
5. Leaderboard screen — "compete worldwide".
6. Achievements grid — "20 to unlock".
7. Control-options screen — tilt is a differentiator, keep it.
8. (Optional) Hard-mode moment.

**Rules:** consistent frame, no black bars / letterboxing, short burned-in caption on each (2–4 words: "JUMP THE WALLS", "TILT TO STEER", "BEAT THE LEADERBOARD"). First 2–3 screenshots matter most — lead with pure action.

**Capture commands (device connected via adb):**
```sh
# still
adb shell screencap -p /sdcard/s.png && adb pull /sdcard/s.png ./playstoreassets/

# 30s gameplay video for the promo slot
adb shell screenrecord --time-limit 30 /sdcard/v.mp4 && adb pull /sdcard/v.mp4
```

### 1.2 Promo video

Record 15–30s of pure gameplay, upload to YouTube (unlisted or public), paste the URL into Play Console. Listings with video convert better. Reuse clips for short-form (§4).

### 1.3 Text fields (ready to paste)

**Title** (30 char max — currently 10, wasting 20):
```
Turbo Race: Endless Runner
```

**Short description** (80 char max — most keyword-weighted field):
```
Jump, dodge & tilt through an endless obstacle run. Beat your high score!
```

**Full description** (4000 char max — Play indexes the body; front-load and repeat core terms naturally):
```
Turbo Race is a fast, addictive endless runner. Ride the rocket sled, jump
the walls, dodge the traps, and chase a new high score on every run.

▸ ENDLESS ACTION — the obstacles never stop. How far can you go?
▸ TWO WAYS TO PLAY — tilt your phone to steer, or use the on-screen joystick.
▸ THREE DIFFICULTIES — Easy, Medium, and Hard.
▸ GLOBAL LEADERBOARDS — compete with players worldwide via Google Play Games.
▸ 20 ACHIEVEMENTS — can you unlock them all?
▸ ONE MORE RUN — pick-up-and-play arcade fun, perfect for short breaks.

Simple to learn, hard to master. Time your jumps, react fast, survive longer,
and climb the leaderboard.

Free to play. Download Turbo Race and start the run!
```
Keyword targets to keep threaded through the body (no stuffing): *endless runner, arcade, jump, dodge, high score, leaderboard, offline, one-handed, casual.*

### 1.4 Category & tags

- **Category:** Arcade (not the generic "Games").
- **Tags in Console:** Arcade, Casual, Single player, Offline, Endless.

### 1.5 Localization (free, high leverage)

Translate title + short + full description into the top free-mobile-game markets: **Spanish (es), Portuguese-BR (pt-BR), Hindi (hi), Indonesian (id), Russian (ru).** Play indexes localized text separately → opens whole new search markets at zero cost. You (or the machine) can produce these; Spanish first (native).

### 1.6 ASO acceptance checklist

- [ ] 6–8 gameplay screenshots, 1080p+, captioned, no letterbox
- [ ] Promo video linked
- [ ] Title = "Turbo Race: Endless Runner"
- [ ] Short + full description updated
- [ ] Category = Arcade, tags set
- [ ] ≥1 localization live (es)
- [ ] Feature graphic still current (1024×500 ✓)

---

## 2. Ratings & reviews engine

Rating **count** + **average** + **freshness** all feed Play ranking and conversion. You have almost no reviews — this is a compounding lever.

- **In-app review prompt:** integrate Play In-App Review API, trigger after the ~3rd game-over (reuse the existing game-count hook that gates interstitials). Don't over-prompt — the API rate-limits itself.
- **Ask at a happy moment** (new high score / achievement unlock), never mid-fail.
- **Reply to every review** in Console — signals active dev, nudges ranking.
- **Seed the first ~10** honestly: friends, family, Godot/indie Discords who actually play it.

*Code task — I can wire the In-App Review prompt on request.*

---

## 3. Web build + itch.io (shareable demo)

Export a **Godot HTML5 build** → a single link anyone can play in-browser, no install.

- Host on itch.io (free) **and** embed on cpinan.github.io/turbo-race-godot.
- itch.io is its own discovery channel + community.
- A playable link converts far better than "go install an APK" when shared in threads/DMs.
- Keep the mobile Play version as the primary CTA; web build is the top-of-funnel try-before-install.

*Note:* AdMob/GPGS won't run on web — guard those (AdManager already has an Android-only guard; verify LeaderboardService/AchievementChecker degrade gracefully on the `web` platform).

*Code task — I can set up the HTML5 export preset + platform guards.*

---

## 4. Distribution channels (where to share — all free)

Read each community's self-promo rules first. Post as a developer sharing work, not as an ad.

### Reddit
- r/AndroidGaming, r/IndieGaming, r/IndieDev, r/playmygame, r/gamedev (**Feedback Friday** thread), r/godot.
- Lead with a GIF/clip, not a link. Mention it's free, ask for feedback.

### Godot community (you have a native on-topic angle)
- Godot **Discord** #showcase, r/godot, Godot forum.
- Angle: *"Cocos2d-x C++ game rewritten in Godot 4.7 — here's the result + what I learned."* On-topic, genuinely interesting, and doubles as devlog content (§5).

### Short-form video (algorithmic free reach)
- **TikTok, YouTube Shorts, Instagram Reels.** Post near-miss / high-score / "rage" clips. Gameplay loops perform well. Repurpose the promo-video footage. Post consistently (§6 cadence).

### Game listing / directory sites
- itch.io (from §3), IndieDB, "free Android game" roundup submissions, r/incremental_games-style adjacent communities.
- Submit to indie-game newsletter roundups and mobile-game blogs that accept dev submissions.

### Discord servers
- Indie-game, mobile-game, and Godot servers with #self-promo / #showcase channels.

### Your own surfaces
- GitHub repo README: Play badge + gameplay GIF up top (partly done — add GIF).
- Site: gameplay GIF above the fold, Play badge, embed web build.

---

## 5. Content / devlog angle (free, compounding)

You have a story most games don't: **"I rewrote my C++ mobile game in Godot 4.7."** Dev-audience gold.

- Write it up: dev.to / Hashnode / personal blog + a Twitter/X or Bluesky thread.
- Topics that travel: the Y-up coord-flip parity trick, pure-function collision design + GUT testing, porting Cocos2d-x actions (JumpBy) to Godot, GPGS + AdMob + UMP integration gotchas.
- Every post links the Play page. Engineering content pulls a *different* audience than game-marketing content — free reach into indie-dev circles, some of whom install and review.

---

## 6. Cadence

**Launch week (the relaunch of the fixed listing):**
- Day 1: ship fixed listing (screenshots, video, copy).
- Day 2: Reddit posts (r/godot with migration story, r/AndroidGaming, r/playmygame).
- Day 3: Godot Discord #showcase + itch.io web build live.
- Day 4: first devlog post + thread.
- Day 5: first short-form clip.

**Ongoing weekly:**
- 2–3 short-form clips (TikTok/Shorts/Reels).
- 1 community post OR 1 devlog entry.
- Reply to all new reviews.
- Check metrics (§7).

---

## 7. Metrics to track (Play Console, free)

- **Store listing conversion rate** (visitors → installs) — the ASO scoreboard; watch it move after §1.
- Install count & sources (organic search vs. explore vs. third-party referral).
- **Rating average + count** trend.
- **D1 / D7 retention** — if low, retention work (not marketing) is the real bottleneck.
- Uninstall rate.
- Search-term impressions (which keywords surface you).

Decision rule: if conversion is low → keep iterating screenshots/copy. If installs are fine but retention is low → gameplay/onboarding problem, pause paid-attention efforts and fix the game loop.

---

## 8. 30 / 60 / 90 day roadmap

**0–30 days — fix the funnel**
- New screenshots + video + full copy rewrite live.
- Category/tags corrected.
- In-app review prompt shipped.
- Spanish localization live.
- HTML5 web build on itch.io + site.
- Launch-week community posts done.

**30–60 days — organic reach**
- Weekly short-form clips running.
- 2–3 devlog posts published + shared.
- 2 more localizations (pt-BR, id).
- Seed + respond to reviews; hit first ratings milestone.

**60–90 days — iterate on data**
- A/B test screenshot order / first-frame (Play Console experiments — free).
- Double down on whichever channel drove the most installs.
- Evaluate retention metrics; feed findings back into gameplay.
- Consider a small content update (new obstacle/vehicle already in the extensibility design) as a "what's new" re-engagement + fresh-listing signal.

---

## 9. Priority order (do in this sequence)

1. **Gameplay screenshots + promo video** → update listing. *(unblocks everything; do first)*
2. **Rewrite title / short / full description**, fix category + tags.
3. **In-app review prompt** (code).
4. **HTML5 web build** → itch.io + site embed (code).
5. **Spanish localization** of listing.
6. **Launch-week community posts** (Reddit, Godot Discord) with the migration story.
7. **Weekly short-form clips + devlog** cadence.

---

## Open code tasks (I can do these in-repo)

- [ ] Wire Play **In-App Review API** prompt (trigger on ~3rd game-over via existing game-count hook).
- [ ] Add **HTML5 export preset** + verify AdMob/GPGS platform guards degrade on `web`.
- [ ] Add gameplay **GIF to README** + site above-the-fold.
- [ ] Generate localized store-copy strings (es first).
```
