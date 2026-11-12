# EnterVehicle

Server: `actor:EnterVehicle(vehicle, animate)` requests boarding after a 0.5-second delay and returns the delay. With `animate` (used by `go_to_police_car`) the actor turns to the car and plays the first sequence the model has of `Idle_To_Sit_Chair` (citizens), `drive_jeep` (player models, held for 1 second) and `Stand_to_crouchpistol` (HL2 metrocops), or pauses for 1 second if it has none before disappearing; it does not board if it was moved more than 300 units from the car meanwhile. It requires DV, `use_vehicle`, a valid vehicle and an available allowed seat. Permission and availability are checked again when boarding; there is no synchronous success result.

Boarding preserves the actor object and UID, stores its body and equipment, removes the physical NPC/NextBot and binds the actor to the DV driver/passenger entity. `BGN_OnEnterVehicle(actor, provider)` fires after success. Only police actors may board designated police vehicles.

[Realm reference](../../../reference/server.md).
