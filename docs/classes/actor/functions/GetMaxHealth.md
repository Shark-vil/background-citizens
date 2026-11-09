# GetMaxHealth

Shared: `actor:GetMaxHealth()` returns the attached entity's maximum health if the entity is valid and its `GetMaxHealth` method exists. Otherwise it returns the stored vehicle character maximum health, or `0` when unavailable.

The current entity's method takes priority over stored vehicle data, as with [Health](Health.md).
