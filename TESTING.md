# Verification

Verified on 2026-11-04:

- All Lua scripts parse under Lua 5.4.
- Framework adapters, unavailable character data, numeric validation and identifier privacy.
- NUI startup handshake, focus lifecycle, native settings/map handoff and closing cleanup.
- Local cloned-ped headshots, cancellation and texture cleanup.
- Character-owned saved-place persistence and input validation; GPS sharing distance, routing buckets and rate limits.
- Independent map camera state, native GPS sample handling, invalid controls, switching 2D/3D and camera cleanup using native mocks.
- Headless Chromium integration: waypoint, route preview, saved places, safe text rendering, 2D/3D UI, zoom, pan, rotation and returning to the menu.
- RC.3 map redesign: branch cycling, independent place-type visibility, active waypoint controls, Explore/Nearby/Saved filtering and panel bounds at 1720×720, 900×650 and 650×600.
- Mocked native checks reject entity-attached/unknown/private blips, conceal all entity pools before camera activation and every frame, block street view and enforce camera bounds after repeated zoom/rotate inputs.

Live FiveM checks on this server confirmed the RC.3 aerial camera, public location list, selected-place card, waypoint pin and 2D texture loading. The route was unavailable in that session; the subsequent GPS/radar-calculation fix passes native-mock tests but has not yet been rechecked in game. Two-player concealment, custom overlays and full GPS route sampling still need the smoke test below. This is a release candidate, not a fully production-validated release.

Live smoke test:

1. Start only `sh_pauseMenu` after the framework; run `refresh` when the manifest changes.
2. Verify NUI callbacks with the requested mixed-case folder name on your server/client build.
3. Open and close the menu repeatedly; confirm face, balances and HUD restoration.
4. Open the aerial map; pan, rotate, zoom and recenter. Verify street view is unavailable and repeated zoom cannot reach ground level.
5. Switch to 2D and verify game tiles line up with the player and waypoint.
6. Set GPS nearby and far away; check native route points and route preview when available.
7. Save/delete places, reconnect and confirm character separation.
8. Check sharing with two players, then restart the resource while a map camera is active.

9. With a second player and vehicle in view, open the map and pan across them. Confirm entities and entity trackers are hidden, including while the camera moves; close/restart and confirm normal world visibility for both players. Check custom name tags, radar replacements and other resource overlays separately.
