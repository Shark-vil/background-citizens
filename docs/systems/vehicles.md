# Vehicles and Decent Vehicle

DV is optional. Install Decent Vehicle, the car content used by your actor config, and DV waypoints for the map. Pedestrian navigation and DV roads are separate. Server providers own boarding and driving; clients render seated actors.

## Character identity and damage

Boarding preserves Actor/UID but replaces its entity; exit restores the saved body at a free seat-specific position. A blocked exit keeps the actor aboard. Use actor health accessors and BGN_ActorEntityChanged for integrations. Actor-on-actor seated hits roll triple damage (20%), double (50%) or unchanged damage (30%); player/foreign NPC hits do not receive this multiplier.

## Driving and verification

[Emergency routing](navigation.md#emergency-cars-decent-vehicle), [traffic recovery and developer fixtures](testing.md#dv-traffic-developer-checks), [arrest in a car](arrest.md#car-break-in).

Police keep pursuing driving suspects, use ranged weapons against enemies in cars and avoid boarding loops. An officer steps out when a live enemy is within 800 units of the car and is not driving away (its car moved within the last 6 s), or the car is at 20% health or less. A seated officer has no NPC senses: once a second the server makes a hostile NPC (hostile to players) or a NextBot hunting a player/actor within 1000 units and in sight of the car its enemy, unless `bgn_ignore_another_npc` is on. Siren control has one owner and tolerates brief target loss. Native DV sensor timing is preserved; bounded local recovery handles blocked vehicles without replacing DV globally. Vehicle spawn distance and hidden cleanup have separate settings from pedestrians.

Steep ramps and unusual axle layouts require separate live calibration. Stub regressions do not prove every vehicle model or map.
