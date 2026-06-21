# Faculandia — Revisão Geral do Projeto

## Sobre o Jogo

**Top-down shooter 2D** com visão limitada por um cone de névoa. O jogador se move por um mapa com tiles, mira com o mouse e atira em inimigos (futuro). O visual escuro com cone de visão cria um clima de tensão e exploração tática.

**Engine:** Godot 4.7 (GL Compatibility)  
**Linguagem:** GDScript  
**Perspectiva:** Top-down 2D

---

## O que já está implementado

### Movimento
- WASD e setas do teclado (mapeado como `ui_*`)
- Velocidade: 150 px/s
- Player preso aos limites da câmera (1152 × 648)

### Mira
- Mouse controla a direção da mira
- Sprite do player rotaciona na direção do mouse
- Crosshair customizado que segue o mouse (cursor do sistema oculto)

### Cone de Visão (Fog of War)
- Shader `visao_conica.gdshader` renderiza um cone iluminado na escuridão
- Tudo fora do cone fica escuro (alpha 0.7)
- Cone configurável: ângulo (75°) e alcance (600 px)
- Posição e ângulo atualizados a cada frame via `visibilidade.gd`

### Sistema de Armas (Herança)
| Arquivo | Classe | Função |
|---------|--------|--------|
| `scripts/weapon.gd` | `Weapon` (base) | Spawn de bala, cooldown, variáveis exportáveis |
| `scripts/pistol.gd` | `Pistol extends Weapon` | Stats da pistola (dano 8, cadência 0.2s) |

### Tiro
- Botão esquerdo do mouse (`Input Map: shoot`)
- Semi-automático (1 clique = 1 tiro)
- Cooldown entre tiros: 0.2s (pistola)

### Projétil
| Arquivo | Descrição |
|---------|-----------|
| `scripts/bullet.gd` | `Area2D` criado 100% por código |

A bala:
- Viaja a 600 px/s na direção da mira
- Tem lifetime de 2 segundos (autodestruição)
- Hitbox retangular (6×2 px) com `RectangleShape2D`
- Sprite definido pela arma (`bullet_texture`) com fallback visual via `_draw()` (círculo amarelo + halo laranja)
- Rotaciona automaticamente na direção da trajetória
- Destruída ao colidir com qualquer corpo ou área (`queue_free`)

---

## Estrutura de Arquivos

```
faculandia/
├── project.godot                    # Config + Input Map (shoot)
├── scripts/
│   ├── player_moviment.gd           # Player: movimento, mira, tiro
│   ├── crosshair.gd                 # Crosshair segue o mouse
│   ├── visibilidade.gd              # Atualiza shader do cone de visão
│   ├── weapon.gd                    # Classe base Weapon
│   ├── pistol.gd                    # Pistola (estende Weapon)
│   └── bullet.gd                    # Projétil
├── shaders/
│   └── visao_conica.gdshader        # Shader do cone de visão
├── scenes/
│   └── cena_principal.tscn          # Única cena do jogo
├── sprites/
│   ├── player_placeholder.png       # Sprite do jogador
│   ├── mira_placeholder.png         # Sprite da mira
│   ├── tileset_chao.png             # Tileset do chão
│   └── bala.png                     # Sprite da bala (Pistola)
└── resources/
    └── tileset_chao.tres            # Recurso do tileset
```

---

## Árvore da Cena

```
MainLoop (Node2D)
├── Mundo (Node2D)
│   ├── chao (TileMapLayer)
│   └── Player (CharacterBody2D) [player_moviment.gd]
│       ├── crosshair (Sprite2D) [crosshair.gd]
│       ├── player_sprite (Sprite2D)
│       ├── player_collision (CollisionShape2D 16×16)
│       ├── camera_player (Camera2D, zoom 1.8×)
│       └── Weapon (Node2D) [pistol.gd]
│           └── muzzle_marker (Marker2D, pos 12,0)
└── camada_ui (CanvasLayer)
    └── visibilidade (ColorRect) [visibilidade.gd]
```

---

## Fluxo de um Tiro

```
Clique esquerdo
  → Input.is_action_just_pressed("shoot")
  → player_moviment.gd: weapon.shoot(aim_direction, aim_angle)
  → weapon.gd: verifica can_fire → cria Area2D → gruda bullet.gd
  → preenche variáveis (dano, sprite, hitbox) → spawn no muzzle_marker
  → add_child na raiz → cooldown → libera
  → bullet.gd: _ready() → rotação + sprite + colisão
  → bullet.gd: _physics_process() → viaja + lifetime → colide → queue_free()
```

---

## Inputs Configurados

| Ação | Tecla/Botão |
|------|-------------|
| `ui_up` | W / ↑ / Gamepad |
| `ui_down` | S / ↓ / Gamepad |
| `ui_left` | A / ← / Gamepad |
| `ui_right` | D / → / Gamepad |
| `shoot` | Mouse Esquerdo |

---

## Próximos Passos Sugeridos

1. **Inimigos** — criar `enemy.gd`, comportamento básico (patrulha, perseguição, dano)
2. **Sistema de vida** — `health` no Player e inimigos, `take_damage()` na bala
3. **UI / HUD** — barra de vida, contador de kills, nome da arma equipada
4. **Mais armas** — Shotgun (múltiplas balas com dispersão), Rifle (mais rápido)
5. **Munição e recarga** — limite de balas, tecla R para recarregar
6. **Áudio** — som de tiro, impacto, passos
7. **Animação de tiro** — sprite de flash no cano (substitui o sistema de partículas removido)
8. **Mapa / level design** — expandir o tileset, adicionar obstáculos e paredes
