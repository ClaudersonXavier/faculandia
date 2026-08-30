# Faculandia — Revisão Geral do Projeto

## Sobre o Jogo

**Top-down shooter/stealth 2D** com visão limitada por um cone de percepção direta, percepção periférica curta e fontes de luz no cenário. O jogador se move por um mapa com tiles, mira com o mouse, atira e precisa gerenciar munição — inclusive voltando a uma loja para reabastecer. Ameaças (inimigos) perseguem o jogador por visão direta ou navegação, e existe um sistema de ruído que faz as ameaças perceberem passos, tiros e impactos.

**Engine:** Godot 4.7 (GL Compatibility)
**Linguagem:** GDScript
**Perspectiva:** Top-down 2D

---

## O que já está implementado

### Movimento
- WASD e setas do teclado (mapeado como `ui_*`), com suporte a gamepad
- Velocidade base 135 px/s, com aceleração/atrito e penalidade de 15% ao andar de costas (*backpedal*)
- Player preso aos limites da câmera (configurados por nível via override de instância)
- Emite ruído de passos periodicamente (a cada ~27px andados)

### Mira e Câmera
- Mouse controla a direção da mira; sprite do player rotaciona de acordo
- Crosshair customizado que segue o mouse (cursor do sistema oculto)
- Câmera com zoom 1.8× e limites configuráveis por cena

### Percepção do Jogador (Fog of War)
Sistema de raycast físico (não é iluminação nativa do Godot) com três camadas de percepção:
- **Visão Direta**: cone à frente do jogador (ângulo e alcance configuráveis), bloqueado por paredes e por obstáculos baixos (caixas/barris)
- **Percepção Periférica**: raio curto ao redor do jogador, bloqueado só por paredes (obstáculos baixos não bloqueiam)
- **Fontes de Luz**: iluminam área própria independente da mira do jogador
- Objetos fora de qualquer uma dessas três áreas são ocultados de verdade (`discard` no shader), não apenas escurecidos
- Ver `docs/adr/0001-projecao-de-sombras-e-camadas-de-bloqueadores.md` para a decisão de arquitetura completa

### Sistema de Armas (Herança) e Munição
| Arquivo | Classe | Função |
|---------|--------|--------|
| `scripts/weapons/weapon.gd` | `Weapon` (base) | Spawn de bala, cooldown, recarga, munição |
| `scripts/weapons/pistol.gd` | `Pistol extends Weapon` | Stats da pistola |

- Tiro semi-automático (botão esquerdo do mouse), recarga com tecla própria (`reload`)
- Munição (pente atual / reserva) persistida em `GameState` (autoload), inclusive ao trocar de cena

### Projétil
- `scripts/weapons/bullet.gd`: `Area2D` criado 100% por código, viaja em linha reta, some após 2s ou ao colidir, emite ruído de impacto

### Ameaças (Inimigos)
- `scripts/enemies/ameaca.gd`: persegue o jogador por visão direta quando possível, senão usa `NavigationAgent2D`; separação suave entre ameaças próximas (`scripts/core/flocking_utils.gd`)
- Vida, dano e flash ao ser atingido; morte desativa colisão e movimento
- `scripts/enemies/ameaca_debug_logger.gd`: diagnóstico opcional (`debug_logging`), desligado por padrão
- Área de loot já existe na cena (`AreaLoot`/`LootLabel`) mas a interação ainda não está conectada — ver Próximos Passos

### Sistema de Ruído
- `scripts/noise/noise_bus.gd`: bus de eventos de ruído (passos, tiro, impacto), consultável por posição/raio/idade
- `scripts/noise/noise_synthesizer.gd` + `noise_sfx_player.gd`: sons sintetizados por código (sem arquivos de áudio)
- `scripts/noise/noise_visualizer.gd`: visualização de depuração (tecla F3, desligado por padrão)

### HUD e Loja
- `scripts/world/hud.gd`: mostra munição atual/reserva e indicador de recarga
- `scripts/world/loja.gd` + `scenes/world/loja.tscn`: tela de loja para reabastecer munição, com confirmação ao tentar sair sem reabastecer
- `scripts/world/exit_zone.gd`: área que leva o jogador da cena principal para a loja

---

## Estrutura de Arquivos

```
faculandia/
├── project.godot
├── AGENTS.md / CLAUDE.md / GEMINI.md   # instruções para agentes (CLAUDE.md e GEMINI.md são symlinks)
├── scripts/
│   ├── core/            # utilitários compartilhados (physics_layers, physics_utils, animation_utils,
│   │                     # texture_utils, noise_type_config, sprite_conventions, flocking_utils)
│   ├── player/           # player_moviment, player_vision, player_vision_raycaster, crosshair
│   ├── weapons/          # weapon, pistol, bullet
│   ├── enemies/          # ameaca, ameaca_debug_logger
│   ├── noise/            # noise_bus, noise_event, noise_synthesizer, noise_sfx_player, noise_visualizer
│   ├── world/            # hud, loja, game_state, exit_zone, navegacao_cenario
│   ├── testing/          # test_spawner, test_entity (ferramentas de debug em runtime)
│   └── tests/            # scripts de teste automatizado (rodados via `make test`)
├── shaders/
│   ├── visao_conica.gdshader              # escurece/dessatura a tela fora da percepção
│   ├── fragmento_perceptivel.gdshader      # discard de entidades fora da percepção
│   └── visibility_polygon.gdshaderinc      # funções de teste ponto-em-polígono, compartilhadas pelos dois shaders acima
├── scenes/
│   ├── world/            # cena_principal.tscn (nível principal), loja.tscn
│   ├── objects/          # ameaca.tscn, barril.tscn, caixa.tscn, player.tscn (instanciáveis)
│   └── ui/               # camada_ui.tscn (overlay de escuridão + HUD, reusável entre cenas)
├── resources/
│   ├── sprites/          # characters/, environment/, items/, test/
│   ├── tilesets/         # tileset_chao.tres, tileset_parede.tres
│   └── sounds/           # reservado para áudio futuro
└── docs/adr/             # registros de decisão de arquitetura
```

---

## Árvore da Cena Principal (resumida)

```
MainLoop (Node2D)
├── NoiseBus (Node) [noise_bus.gd]
├── TestSpawner (Node) [test_spawner.gd]
├── Mundo (Node2D)
│   ├── NoiseVisualizer (Node2D) [noise_visualizer.gd]
│   ├── NavigationRegion2D [navegacao_cenario.gd]
│   ├── Ameaca, Ameaca2 (instâncias de ameaca.tscn)
│   ├── chao (TileMapLayer)
│   ├── paredes (TileMapLayer, bloqueia movimento e visão)
│   ├── Player (instância de player.tscn — ver árvore própria abaixo)
│   ├── Barril1/2, Caixa1/2 (instâncias, bloqueiam visão direta mas não periférica)
│   └── ZonaSaida (Area2D) [exit_zone.gd] → leva para a loja
└── camada_ui (instância de camada_ui.tscn)
    ├── visibilidade (ColorRect, shader de escuridão)
    ├── HUD (Control) [hud.gd]
    └── ConfirmationDialog (específico desta cena, confirma saída sem reabastecer)
```

### Árvore do Player (`scenes/objects/player.tscn`)

```
Player (CharacterBody2D) [player_moviment.gd]
├── crosshair (Sprite2D) [crosshair.gd]
├── player_collision (CollisionShape2D)
├── camera_player (Camera2D) — limites de câmera definidos por cada cena que instancia
├── AudioListener2D
├── Weapon (Node2D) [pistol.gd]
│   ├── Sprite2D
│   └── muzzle_marker (Marker2D)
├── PlayerVision (Node2D) [player_vision.gd] — overlay de escuridão definido por cada cena que instancia
└── player_sprite (AnimatedSprite2D)
```

---

## Inputs Configurados

| Ação | Tecla/Botão |
|------|-------------|
| `ui_up` / `ui_down` / `ui_left` / `ui_right` | WASD / Setas / Gamepad |
| `shoot` | Mouse Esquerdo |
| `reload` | R |
| `debug_vision` | F1 (alterna visão de debug, revela tudo) |

Teclas adicionais de debug (via `test_spawner.gd`, sem action própria): `Z` spawna ameaça, `L` spawna fonte de luz de teste, `Delete`/`Backspace` remove o objeto de teste mais próximo do mouse. `F3` alterna o visualizador de ruído.

---

## Próximos Passos Sugeridos

1. **Loot ao matar ameaça** — conectar `AreaLoot`/`LootLabel` (já existem na cena) a uma interação real (tecla, ex. `E`) que credite `GameState.dinheiro`
2. **Loja funcional** — hoje só reabastece munição; falta usar `GameState.dinheiro` para de fato comprar algo
3. **Mais armas** — Shotgun (dispersão), Rifle (cadência maior), usando a herança de `Weapon` já existente
4. **Animação de tiro** — flash no cano da arma
5. **Áudio ambiente/música** — `resources/sounds/` já está reservado para isso
6. **Mais tipos de ameaça** — a estrutura de `scripts/enemies/` já separa IA de debug logging, facilitando compor novos comportamentos a partir de `ameaca.gd`
