# Dewdrop Plot

One tank, a clever little garden.

A bright irrigation and harvest-planning puzzle with sixty plots across six chapters. Route limited water to the crops in each harvest order, watch the garden bloom and grow your skills.

## Play

Plan channels, inspect crop demand and your water budget, then release a watering pulse. Meet the harvest order with the available supply. Undo/reset and normal retries are free; daily plots and grower progression add reasons to return.

Portrait touch/mouse controls and local offline saves. Native ads and Play Games are optional services; Web keeps gameplay and progress functional when they are unavailable. Optional ad benefits require the actual native earned-reward callback. No browser simulation grants an ad reward.

## Continue this project

This game folder is the canonical Git working copy for [Dewdrop Plot](https://github.com/EthannYakabuski/dewdrop-plot). Open this folder as its own Codex project and use one focused task per update. Read `AGENTS.md`, `HANDOFF.txt` and `docs/PLATFORM_SETUP.md` first; a new task must recover context from these files rather than assume access to an earlier chat. Check existing user changes before editing.

Verified pre-consolidation public baseline: `2788003b300c0bf8ff400c39f50a33466b4a412d`.
[Hosted build/test run](https://github.com/EthannYakabuski/dewdrop-plot/actions/runs/39527047278): **PASS** on that exact commit.
Later documentation commits require their own CI result; this dated result does not verify later binaries.

`game/catalog.json` defines 18 achievements and 4 leaderboards. `platform/config.json` maps their symbolic keys to owner-supplied console IDs; the numeric Play Games game ID must also match `export_presets.cfg`. See native setup for the separate AdMob manifest setting and the development test-ID rules.

## Build and test

Use Godot **4.5.1 Compatibility**, matching export templates, Java17 and the Android SDK. Android test package: `com.ethannyakabuski.dewdropplot`, minimumAPI24/targetAPI35. Android texture import is enabled; the initial Android shader-cache guard avoids an observed old-emulator driver fault. Android remote-run is disabled in the preset so headless exports do not shut down the ADB server; command-line export still works. See [native setup](docs/PLATFORM_SETUP.md) and the game/tests reports for exact test entrypoints.

```sh
godot --headless --editor --path . --import
godot --headless --path . --script platform/tests/services_smoke.gd
godot --headless --path . --export-release Web build/web/index.html
godot --headless --path . --install-android-build-template --export-debug Android build/android/game-debug.apk
```

Create the build/web and build/android output folders first. These commands assume a `godot` executable on PATH; on Windows substitute the installed Godot executable, using PowerShell's `&` call operator for a quoted path. No Windows desktop build is supplied.

## Native services

AdMob uses Google's official test app/unit IDs. Main menus offer a banner, every two completed rounds create a natural interstitial opportunity, and valuable optional hints require an earned native reward. Consent/error/unavailable paths preserve ordinary play. Play Games is wired with symbolic achievement/leaderboard mappings and production configuration disabled pending owner console IDs and configuration. All required owner configuration points are documented in platform/config.json and docs/PLATFORM_SETUP.md.

## Source and delivery

Original code is Apache-2.0. Developer: [EthannYakabuski](https://github.com/EthannYakabuski). Third-party assets/plugins retain their supplied licenses and required notices. Hosted CI runs game/service tests and exports Android/Web; Pages deployment remains explicitly disabled. Build artifacts, caches and keys are excluded from source. See HANDOFF.txt for actual results and blockers; file/workflow presence alone does not establish verification.

Marketing assets, store/web copy, icons and screenshot provenance belong under marketing/. Human-owned next steps include final backend IDs/account setup, release signing, current Play eligibility checks, production service tests, human playtesting and Play publication. The first package is test-configured and must not be treated as Play-ready.

## Future content

Greenhouse Seasons: greenhouse plots, phased watering and cosmetic crop families.

## Licenses

See [the complete accompanying notices](LICENSES/INDEX.txt) for the engine,
fonts, plugins and assets. Keep the `LICENSES` directory with every redistributed
Android or Web build; original-code Apache licensing does not replace third-party
terms. CI copies these notices beside both exports and includes them with the
Android artifact.

## Public source and deployment status

The public repository contains source, assets, notices and sanitized verification summaries. Original local QA APKs, raw SDK logs, real saves, signing material and private evidence stay outside tracked public content. Local restored build outputs remain ignored. Hosted export artifacts are separate binaries from the APK named in HANDOFF.txt and have not received that original native QA.

Pages remains disabled; no live deployment, Library action or Google Play publication is part of this handoff. Keep the complete third-party notices with redistributed source and builds.

## Service configuration caution

`admob.app_id` in JSON is a reference value: the Android manifest uses Godot Project Settings `admob/general/android/app_id`. The Services `test_mode` flag changes status wording; it does not turn production ad unit IDs into test requests. Keep Google sample IDs for development, or configure real test devices separately before production-ID testing.

## Round Three screenshot supplement

Eighteen genuine Android images now provide six distinct views per logical phone, 7-inch and 10-inch profile. Nine original Home/planning/Journal images are retained byte-for-byte; nine ordinary roster/daily/palette views expand the same unchanged APK. See [the screenshot scope](docs/SCREENSHOTS_ROUND_THREE.md) and marketing/screenshots-round-three/capture-manifest.json. No rebuild or renewed gameplay/ad/offline acceptance is claimed. The original complete APK/source commit is unknown; source matching is limited to nine recorded runtime inputs.
