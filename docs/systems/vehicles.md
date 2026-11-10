# Vehicles and Decent Vehicle

DV is optional. Install Decent Vehicle, the car content used by your actor config, and DV waypoints for the map. Pedestrian navigation and DV roads are separate. Server providers own boarding and driving; clients render seated actors.

## Character identity and damage

Boarding preserves Actor/UID but replaces its entity; exit restores the saved body at a free seat-specific position. A blocked exit keeps the actor aboard. Use actor health accessors and BGN_ActorEntityChanged for integrations. Actor-on-actor seated hits roll triple damage (20%), double (50%) or unchanged damage (30%); player/foreign NPC hits do not receive this multiplier.

## Driving and verification

[Emergency routing](navigation.md#emergency-cars-decent-vehicle), [traffic recovery and developer fixtures](testing.md#dv-traffic-developer-checks), [arrest in a car](arrest.md#car-break-in).

Police keep pursuing driving suspects, use ranged weapons against enemies in cars and avoid boarding loops. Siren control has one owner and tolerates brief target loss. Native DV sensor timing is preserved; bounded local recovery handles blocked vehicles without replacing DV globally. Vehicle spawn distance and hidden cleanup have separate settings from pedestrians.

Steep ramps and unusual axle layouts require separate live calibration. Stub regressions do not prove every vehicle model or map.
