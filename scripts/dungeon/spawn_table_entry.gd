class_name SpawnTableEntry
extends Resource

## Une entrée d'une SpawnTable (Phase 6.3) : un chemin de ressource/scène
## chargeable à la volée, et son poids relatif dans le tirage pondéré.
## Nommé item_path (pas resource_path) pour ne pas masquer la propriété
## native Resource.resource_path (chemin du .tres de CETTE entrée sur le
## disque, sans rapport avec l'objet qu'elle référence).
@export var item_path: String = ""
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
## Phase 8.2 : si vrai, cette entrée n'est tirable que si MetaProgression
## rapporte l'item comme débloqué par au moins un joueur de la partie
## (cf. SpawnTable._available_entries).
@export var requires_unlock: bool = false
