# Dewdrop Plot

One tank, a clever little garden.

A bright irrigation and harvest-planning puzzle with sixty plots across six chapters. Route limited water to the crops in each harvest order, watch the garden bloom and grow your skills.

## Play

Plan channels, inspect crop demand and your water budget, then release a watering pulse. Meet the harvest order with the available supply. Undo/reset and normal retries are free; daily plots and grower progression add reasons to return.

Portrait touch/mouse controls and local offline saves. Native ads and Play Games are optional services; Web keeps gameplay and progress functional when they are unavailable. Optional ad benefits require the actual native earned-reward callback. No browser simulation grants an ad reward.

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

AdMob uses Google's official test app/unit IDs. Main menus offer a banner, every two completed rounds create a natural interstitial opportunity, and valuable optional hints require an earned native reward. Consent/error/unavailable paths preserve ordinary play. Play Games is wired with symbolic achievement/leaderboard mappings and production configuration disabled pending real owner IDs/backend credentials. All required owner configuration points are documented in platform/config.json and docs/PLATFORM_SETUP.md.

## Source and delivery

Original code is Apache-2.0. Developer: [EthannYakabuski](https://github.com/EthannYakabuski). Third-party assets/plugins retain their supplied licenses and required notices. Hosted CI is intended to run meaningful game/service tests, export Android/Web and deploy Web to Pages. Build artifacts, caches and keys are excluded from source. See HANDOFF.txt for actual results and blockers; file/workflow presence alone does not establish verification.

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

This repository publishes the existing local-test source package. The recorded HANDOFF and docs describe their dated local verification; they do not establish production service, physical-device, audio, browser or human acceptance.

GitHub-hosted build/test/artifact CI is configured. The Pages deployment job is explicitly skipped pending separate authorization; no live Pages site is claimed. No real saves, private coordinator evidence, credentials, signing identities or prebuilt APK/Web exports are committed. Build outputs remain CI artifacts.

Apache-2.0 covers original project work. Third-party assets, fonts, engine and plugins retain their own terms in LICENSES and source notices; where present, Creature Mixer custom terms exclude NFT/blockchain projects and are not CC0.
