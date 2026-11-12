# EnterVehicle

Server: `actor:EnterVehicle(vehicle, animate)` requests boarding after a 0.5-second delay and returns the delay. With `animate` (used by `go_to_police_car`) the actor stops and turns to the car (no sit animation; the state `go_to_police_car` first walks it to within about 70 units of the car's hull) before disappearing; it does not board if it was moved more than 300 units from the car meanwhile. It requires DV, `use_vehicle`, a valid vehicle and an available allowed seat. Permission and availability are checked again when boarding; there is no synchronous success result.

Boarding preserves the actor object and UID, stores its body and equipment, removes the physical NPC/NextBot and binds the actor to the DV driver/passenger entity. `BGN_OnEnterVehicle(actor, provider)` fires after success. Only police actors may board designated police vehicles.

[Realm reference](../../../reference/server.md).
