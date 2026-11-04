# Verification

Updated: 2026-11-05. Release: 1.0.0.

## Automated checks

- Lua 5.4 parsing for all resource scripts.
- Framework selection and profile handling for ESX, QBCore, Qbox, standalone and custom adapters.
- Numeric validation, identifier privacy, request limits and server-origin event guards.
- NUI startup, focus lifecycle, native menu handoff, settings and resource-stop cleanup.
- Local character headshots, cancellation, fallback and texture cleanup.
- Character-owned saved places, persistence, GPS sharing distance, routing buckets and rate limits.
- Map camera bounds, entity concealment and exclusion of private/entity-attached blips using native mocks.
- GPS fallback when normal waypoint points are absent, curved path sampling, preview cleanup and shared-channel opt-out.
- Browser integration for location filtering, branch cycling, per-type visibility, waypoints, saved places, route preview, zoom, pan, rotation and map/menu closing.
- Responsive panel bounds at 1720×720, 900×650 and 650×600.

## In-game acceptance

The server owner confirmed the current version on 2026-11-05. Earlier live checks also covered aerial rendering, public location selection, destination cards, waypoint pins and 2D texture loading. Automated native mocks complement these checks; they do not simulate every FiveM build or third-party resource.

## Checks for your server

1. Start only one pause-menu resource and start your framework first.
2. Open/close the menu and verify character data, headshots, controls, HUD and camera restoration.
3. Check 2D/3D map alignment and GPS for nearby and distant destinations, on foot and in a vehicle.
4. Test saved-place ownership across characters and sharing between two players in the intended routing bucket.
5. Verify other players, vehicles and tracking blips are concealed in the aerial view, including during camera movement. Check custom name tags and overlays separately.
6. Restart the resource while the map is open and verify camera, weather, focus and HUD recovery.
7. If a mission/racing resource reserves the shared native multi-route channel during map use, disable `Config.Map.nativeRouteFallback`.
