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
- Dano da pistola configurado em 8.0; cada `Ameaca` começa com 24.0 de Vida, portanto morre após três impactos

### Projétil
- `scripts/weapons/bullet.gd`: `Area2D` criado 100% por código, viaja em linha reta, some após 2s ou ao colidir, emite ruído de impacto

### Ameaças (Inimigos)
- `scripts/enemies/ameaca.gd`: persegue o jogador por visão direta quando possível, senão usa `NavigationAgent2D`; separação suave entre ameaças próximas (`scripts/core/flocking_utils.gd`)
- Vida numérica e dano de projéteis; morte desativa colisão e movimento
- Dano de contato configurado em 8.0 a cada 1.0 s por Ameaca; a IA se aproxima até a distância de contato de 22 px e o jogador bloqueia golpes adicionais durante 0.2 s
- `scripts/enemies/ameaca_debug_logger.gd`: diagnóstico opcional (`debug_logging`), desligado por padrão
- Área de loot já existe na cena (`AreaLoot`/`LootLabel`) mas a interação ainda não está conectada — ver Próximos Passos

### Sistema de Ruído
- `scripts/noise/noise_bus.gd`: bus de eventos de ruído (passos, tiro, impacto), consultável por posição/raio/idade
- `scripts/noise/noise_synthesizer.gd` + `noise_sfx_player.gd`: sons sintetizados por código (sem arquivos de áudio)
- `scripts/noise/noise_visualizer.gd`: visualização de depuração (tecla F3, desligado por padrão)

### HUD e Loja
- `scripts/world/hud.gd`: mostra munição atual/reserva, indicador de recarga e barra `Vida atual / Vida máxima` no canto inferior esquerdo, com cores por faixa de percentual
- `scripts/world/game_over.gd` + `scenes/ui/game_over.tscn`: pausa o jogo quando a Vida do jogador chega a zero e carrega o save mais recente ou retorna ao menu, sem salvar a morte
- `scripts/world/loja.gd` + `scenes/world/loja.tscn`: tela de loja para reabastecer munição, com confirmação ao tentar sair sem reabastecer
- `scripts/world/exit_zone.gd`: área que leva o jogador da cena principal para a loja

### Menu Principal, Save e Pause
- `scripts/world/game_state.gd` (autoload `GameState`, `class_name EstadoDoJogo`): estado da partida em memória (munição, dinheiro, cena atual, `vida` e `vida_maxima`), com `to_dict()`/`from_dict()`/`reset()` guiados por `PADROES` — fonte única dos valores de partida nova e do schema persistido
- `scripts/core/save_slots.gd` (`class_name SaveSlots`): mecanismo de 4 slots de save independentes em disco (`user://save_auto.cfg` + `save_slot_1/2/3.cfg`, formato `ConfigFile` com envelope `[meta]` versionado); não conhece o conteúdo da partida
- `scripts/world/save_jogo.gd` (`class_name SaveJogo`): fachada que monta/aplica o payload da partida, guarda o slot em uso (`slot_atual`, `static var`) e centraliza as trocas de fase (`trocar_fase`, `sair_para_o_menu`) — autossalva no slot de autosave a cada troca
- `scripts/world/menu_principal.gd` + `scenes/world/menu_principal.tscn`: primeira tela do jogo (`run/main_scene`), com título "FACULANDIA" e os botões Novo Jogo / Continuar / Sair
- `scripts/world/selecao_de_save.gd` + `scenes/ui/selecao_de_save.tscn`: painel reusável de escolha de slot, usado tanto por "Novo Jogo" (3 slots, com aviso de sobrescrita) quanto por "Continuar" (autosave + 3 slots, só os ocupados ficam clicáveis)
- `scripts/world/selecao_de_cenario.gd` + `scenes/world/selecao_de_cenario.tscn`: hub entre o menu e as zonas jogáveis (estilo Mega Man) — dois "cartões" (Zona Norte / Zona Sul) gerados em código a partir de `ZONAS`; escolher um chama `SaveJogo.trocar_fase`. A loja sempre devolve o jogador ao hub (`SaveJogo.CENA_SELECAO`), nunca direto para a zona jogada antes — o jogador escolhe de novo. Tem um atalho secreto de dev (tecla **F3**) que pula direto pra `cena_principal.tscn`, a cena de teste
- `scenes/world/zona_norte.tscn`: a zona completa, jogável desde o início — cópia exata de `cena_principal.tscn` (mesmo tileset, mesmas 2 Ameaças, mesma `ZonaSaida`). `cena_principal.tscn` **não** faz parte do fluxo do jogador: é a cena de teste/dev, usada por `scripts/tests/player_vision_test.gd` e pelo atalho F3 acima. As duas cenas começam idênticas e podem divergir com o tempo — corrigir uma não propaga pra outra automaticamente
- `scenes/world/zona_sul.tscn`: esqueleto da 2ª zona — toda a infraestrutura funcionando (Player, câmera, visão, HUD, menu de pause, `ZonaSaida` pra loja), mas sem tiles pintados nem Ameaças; label "Zona Sul (em construção)" fixo na tela. Pronta pra alguém desenhar o nível depois no editor
- `scripts/world/menu_pause.gd` + `scenes/ui/menu_pause.tscn`: menu de pause no ESC (`ui_cancel`), instanciado em toda cena jogável (`zona_norte.tscn`, `zona_sul.tscn`, `cena_principal.tscn`, `loja.tscn`); salva no slot da partida atual, sai para o menu ou fecha o jogo
- **Limitação conhecida**: voltar da loja recarrega a zona escolhida do zero, mesmo passando pelo hub — as `Ameaca` (instâncias fixas do editor) renascem com Vida cheia e o Vestígio de uma Ameaça morta some, mesmo com o autosave preservando dinheiro/munição/Vida do jogador. Corrigir isso depende do snapshot completo do mundo (ver Próximos Passos)

---

## Estrutura de Arquivos

```
faculandia/
├── project.godot
├── AGENTS.md / CLAUDE.md / GEMINI.md   # instruções para agentes (CLAUDE.md e GEMINI.md são symlinks)
├── scripts/
│   ├── core/            # utilitários compartilhados (physics_layers, physics_utils, animation_utils,
│   │                     # texture_utils, noise_type_config, sprite_conventions, flocking_utils,
│   │                     # save_slots — mecanismo de slots de save, sem conhecer o conteúdo da partida)
│   ├── player/           # player_moviment, player_vision, player_vision_raycaster, crosshair
│   ├── weapons/          # weapon, pistol, bullet
│   ├── enemies/          # ameaca, ameaca_debug_logger
│   ├── noise/            # noise_bus, noise_event, noise_synthesizer, noise_sfx_player, noise_visualizer
│   ├── world/            # hud, game_over, loja, game_state, exit_zone, navegacao_cenario,
│   │                     # save_jogo, menu_principal, menu_pause, selecao_de_save,
│   │                     # selecao_de_cenario (hub de zonas)
│   ├── testing/          # test_spawner, test_entity (ferramentas de debug em runtime)
│   └── tests/            # scripts de teste automatizado (rodados via `make test`)
├── shaders/
│   ├── visao_conica.gdshader              # escurece/dessatura a tela fora da percepção
│   ├── fragmento_perceptivel.gdshader      # discard de entidades fora da percepção
│   └── visibility_polygon.gdshaderinc      # funções de teste ponto-em-polígono, compartilhadas pelos dois shaders acima
├── scenes/
│   ├── world/            # menu_principal.tscn (primeira tela), selecao_de_cenario.tscn (hub),
│   │                     # zona_norte.tscn, zona_sul.tscn (zonas jogáveis), loja.tscn,
│   │                     # cena_principal.tscn (cena de teste/dev, fora do fluxo do jogador)
│   ├── objects/          # ameaca.tscn, barril.tscn, caixa.tscn, player.tscn (instanciáveis)
│   └── ui/               # camada_ui.tscn (overlay de escuridão + HUD + barra de Vida),
│                          # game_over.tscn (overlay de derrota), menu_pause.tscn (overlay de pause),
│                          # selecao_de_save.tscn (painel de slots)
├── resources/
│   ├── sprites/          # characters/, environment/, items/, test/
│   ├── tilesets/         # tileset_chao.tres, tileset_parede.tres
│   └── sounds/           # reservado para áudio futuro
└── docs/adr/             # registros de decisão de arquitetura
```

---

## Árvore da Zona Norte / cena de teste (resumida)

`zona_norte.tscn` e `cena_principal.tscn` são cópias exatas uma da outra (ver
"Menu Principal, Save e Pause" acima) e por isso têm a mesma árvore:

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
├── camada_ui (instância de camada_ui.tscn)
│   ├── visibilidade (ColorRect, shader de escuridão)
│   ├── HUD (Control) [hud.gd]
│   │   ├── HealthBar / HealthLabel (barra de Vida do jogador)
│   │   └── GameOver (overlay de derrota)
│   └── ConfirmationDialog (específico desta cena, confirma saída sem reabastecer)
└── menu_pause (instância de scenes/ui/menu_pause.tscn) → abre no ESC (`ui_cancel`)
```

`zona_sul.tscn` tem a mesma árvore, **menos** `Ameaca`/`Ameaca2`/`Barril1-2`/`Caixa1-2`
e com `chao`/`paredes` sem tiles pintados (`NavigationRegion2D` faz bake a partir só
dos limites da câmera do `Player`, sem paredes) — **mais** um `EmConstrucao` (Label,
filho de `camada_ui`, "Zona Sul (em construção)").

`selecao_de_cenario.tscn` (o hub) é bem mais simples — um `Control` de tela cheia
com `Fundo` (TextureRect), `Veu` (ColorRect escuro), `Titulo`, `Cartoes`
(HBoxContainer preenchido em código a partir de `ZONAS`, mesmo padrão de
`selecao_de_save.tscn`) e `Voltar`.

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
| `debug_zombie` | F2 (alterna visão de debug da IA: visão, linha de visada, destino e caminho) |
| `ui_cancel` (built-in) | ESC — abre/fecha o menu de pause (`scenes/ui/menu_pause.tscn`) em qualquer zona e na loja |

Teclas adicionais de debug (via `test_spawner.gd`, sem action própria): `Z` spawna ameaça, `L` spawna fonte de luz de teste, `Delete`/`Backspace` remove o objeto de teste mais próximo do mouse. `F3` alterna o visualizador de ruído dentro de uma zona jogável — mas no hub (`selecao_de_cenario.tscn`) `F3` é um atalho secreto de dev que pula direto pra `cena_principal.tscn` (a cena de teste), sem relação com o visualizador de ruído.

---

## Próximos Passos Sugeridos

1. **Loot ao matar ameaça** — conectar `AreaLoot`/`LootLabel` (já existem na cena) a uma interação real (tecla, ex. `E`) que credite `GameState.dinheiro`
2. **Loja funcional** — hoje só reabastece munição; falta usar `GameState.dinheiro` para de fato comprar algo
3. **Mais armas** — Shotgun (dispersão), Rifle (cadência maior), usando a herança de `Weapon` já existente
4. **Animação de tiro** — flash no cano da arma
5. **Áudio ambiente/música** — `resources/sounds/` já está reservado para isso
6. **Mais tipos de ameaça** — a estrutura de `scripts/enemies/` já separa IA de debug logging, facilitando compor novos comportamentos a partir de `ameaca.gd`
7. **Progresso por zona e snapshot do mundo** — a navegação hub → zona → loja → hub já existe (`selecao_de_cenario.tscn`); falta o rastreio de Ameaças mortas/regeneração/conclusão de zona ao voltar. Cada zona com uma quantidade de Ameaças, mortas permanentemente mortas e vivas regenerando vida até limpar a zona; o save já tem o gancho para isso (`versao` no envelope, `cena` já aponta para qual zona/tela o jogador está, `SaveJogo` como ponto único de montagem/aplicação do payload), falta a seção de conteúdo do mundo em si. Resolve de quebra a limitação de "voltar da loja ressuscita as Ameaças" — alternativa menor no meio-tempo: transformar a loja num overlay pausado em vez de trocar de cena
8. **Cura do jogador** — a Vida já é persistida e exibida, mas nesta versão só diminui; adicionar loja/item de cura quando houver economia de itens
9. **Desenhar a Zona Sul** — `zona_sul.tscn` já tem toda a infraestrutura (Player, câmera, visão, HUD, `ZonaSaida`, menu de pause); falta pintar `chao`/`paredes` com o tileset e posicionar Ameaças/objetos
