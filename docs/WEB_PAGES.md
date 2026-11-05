# Playable Web deployment

Stable game URL: [https://ethannyakabuski.github.io/dewdrop-plot/](https://ethannyakabuski.github.io/dewdrop-plot/)

The `main` GitHub Actions workflow imports Godot 4.5.1 resources, retains strict
service/game checks, exports single-threaded Web and builds/validates the Android
debug AAB before the dependent `github-pages` environment deploys `build/web`.
The Pages site must use GitHub Actions (`build_type=workflow`). Setup, the exact
commit's Actions result and public availability are separate verification gates.
`build-info.json` contains only the source commit and public repository name;
compare `source_commit` with the deployment's Actions SHA. It contains no keys,
machine paths, save data or raw logs. Complete accompanying `LICENSES` notices
remain next to the game. Existing Android releases and genuine saves are untouched.

## Later iframe integration

The website is not changed by this update. A future embed can use:

```html
<iframe src="https://ethannyakabuski.github.io/dewdrop-plot/"
        title="Dewdrop Plot" width="540" height="960"
        loading="lazy" allow="autoplay; fullscreen" allowfullscreen></iframe>
```

Resize the portrait container responsively. Click/tap inside the frame before
keyboard input or audio; browser autoplay rules can require a player gesture.
The parent site's CSP must permit this origin in `frame-src`. Restrictive iframe
sandbox flags can block scripts or local persistence; evaluate them on the actual
website rather than assuming this example proves compatibility. Browser/private
mode and third-party storage policies can affect IndexedDB saves in an iframe.

The export has Web extensions and thread support disabled, so it does not rely
on SharedArrayBuffer/cross-origin-isolation response headers. WebGL 2 and
WebAssembly support are still needed. HTTP/header and load-only checks do not
prove gameplay, audible output or cross-browser/mobile acceptance. Record actual browser and iframe observations separately for each deployed commit.
See the [Godot 4.5 Web export guidance](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html).

Native Android AdMob/Play Games are unavailable in Web. Normal local play remains
available; unavailable ads never grant pretend earned rewards. Saved Web progress
is browser/origin-local and is not the Android save or cloud synchronization.
Google Play publication, production signing and unrelated website/account changes
remain outside this Web deployment task.
