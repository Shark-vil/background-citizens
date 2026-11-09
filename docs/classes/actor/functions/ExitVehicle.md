# ExitVehicle

Server: `actor:ExitVehicle(forced)` returns `true` after recreating and rebinding the original body, or `false` if it cannot exit. `forced` bypasses the police dismount policy, but still requires a valid vehicle and a safe position.

Position selection tries the nearest configured model exit, then positions beside the actor's seat and the opposite side. Ground, height, body clearance and overlap with standing actors are checked. If no spot is free, the actor stays aboard. Appearance, health, equipment and actor identity are preserved; `BGN_OnExitVehicle(actor, provider)` fires after success.
