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
- Dano da pistola é variável, sorteado a cada tiro em `Weapon.shoot()` (a base `Weapon` também aceita um `damage` fixo pra armas futuras que não quiserem variação); tiros também podem ser críticos (`crit_chance`, dobra o dano)
- `scripts/weapons/upgrades_pistola.gd` (`class_name UpgradesPistola`): sistema de upgrade da pistola vendido na loja — 4 trilhas (dano, tambor, reserva máxima, crítico), 3 níveis compráveis cada, persistidos em `GameState` (`nivel_dano`/`nivel_tambor`/`nivel_reserva`/`nivel_critico`). `pistol.gd` aplica os níveis atuais toda vez que a arma é recriada (`_ready()`), então um upgrade comprado já vale na próxima zona sem sincronização extra

### Projétil
- `scripts/weapons/bullet.gd`: `Area2D` criado 100% por código, viaja em linha reta, some após 2s ou ao colidir, emite ruído de impacto

### Ameaças (Inimigos)
- `scripts/enemies/ameaca.gd`: persegue o jogador por visão direta quando possível, senão usa `NavigationAgent2D`; separação suave entre ameaças próximas (`scripts/core/flocking_utils.gd`)
- Vida numérica e dano de projéteis; morte desativa colisão e movimento
- Dano de contato configurado em 8.0 a cada 1.0 s por Ameaca; a IA se aproxima até a distância de contato de 22 px e o jogador bloqueia golpes adicionais durante 0.2 s
- Vida (`max_health=24.0` por padrão), dano numérico e flash ao ser atingido; morte desativa colisão e movimento, mas não remove o nó — o corpo fica lootável
- Ataca o jogador corpo-a-corpo por `AttackArea`: quando chega a 22px, aplica 8.0 de dano a cada 1s, respeitando a invulnerabilidade de 0.2s do jogador
- Geme periodicamente (som "zombie_growl", intervalo aleatório sorteado por instância pra não gemerem juntas) — o jogador ouve com volume por distância (o sistema de ruído já faz isso automaticamente), mas outras `Ameaça` ignoram o gemido de propósito (não é estímulo de IA, senão os zumbis "investigariam" o gemido uns dos outros)
- `scripts/enemies/ameaca_debug_logger.gd`: diagnóstico opcional (`debug_logging`), desligado por padrão
- Loot: `AreaLoot`/`LootLabel` detectam o jogador por perto de um corpo morto; apertar `interact` (`E`) chama `_lootar()`, que credita `GameState.dinheiro` e remove o nó (idempotente via `_looteado`)
- `scripts/world/zona_populador.gd` (`class_name ZonaPopulador`) + `scripts/world/zona_mundo_sync.gd`: cada zona (Zona Norte, Zona Sul) espalha ~30 `Ameaca` em posições aleatórias na primeira visita (longe do spawn do jogador, fora de paredes — `PhysicsUtils.is_position_clear` — e fora do alcance de visão do jogador quando não há parede no meio — `PhysicsUtils.has_clear_line`, evita nascer já perseguindo sem o jogador andar/fazer barulho), e o estado de cada uma (viva/morta com corpo/já lootada) é salvo/restaurado a cada troca de fase e a cada save/load. Ao voltar pra uma zona já visitada, `Ameaca` vivas que ficaram a menos de 400px da `ZonaSaida` são reposicionadas pra não cercar o jogador assim que ele reentra — corpos mortos nunca são movidos, ficam exatamente onde morreram — ver "Menu Principal, Save e Pause" abaixo

### Sistema de Ruído e Áudio
- `scripts/noise/noise_bus.gd`: bus de eventos de ruído (passos, tiro, impacto, gemido de zumbi), consultável por posição/raio/idade
- `scripts/noise/noise_synthesizer.gd` + `noise_sfx_player.gd`: sons sintetizados por código como base, mas `noise_sfx_player.gd` prefere um `.mp3` real se existir em `resources/sounds/sfx/{tiro,impacto,zumbi}.mp3` — sem o arquivo, cai no sintetizado. Tiro/zumbi já têm arquivo real; impacto de bala continua sintetizado (nunca foi pedido um arquivo pra esse)
- Som de passo (`resources/sounds/sfx/passo.mp3`) **não** passa por `noise_sfx_player.gd` — o arquivo real dura ~13s, incompatível com um `AudioStreamPlayer2D` novo por evento de ruído (que dispara a cada ~27px andados, sobreporia dezenas de instâncias). Em vez disso, `player_moviment.gd` toca ele em loop contínuo desde o `_ready()` e só liga/desliga o volume conforme anda ou fica parado — o evento de ruído `"footstep"` continua sendo emitido normalmente, só para a IA da `Ameaça` ouvir, sem tocar áudio nenhum por conta própria
- `scripts/audio/musica_tema.gd` (autoload `MusicaTema`): música-tema do menu/hub/loja (nunca toca dentro de fase — `parar()` roda no `_ready()` do player, que existe em toda zona). Já tem arquivo real (`resources/sounds/musica/tema.mp3`, com loop ativado no `.import`)
- `scripts/noise/noise_visualizer.gd`: visualização de depuração (tecla F3, desligado por padrão)

### Vida do Jogador e Morte
- `scripts/player/player_moviment.gd`: `take_damage(amount)` desconta a vida numérica persistida (começa em 100), aplica flash vermelho e bloqueia novos golpes por 0.2s; ao chegar a 0, emite o sinal de morte para o Game Over
- `SaveJogo.jogador_morreu()`: recarrega o save mais recente entre autosave e slots manuais (não salva o momento da morte por cima), força vida cheia de novo, e manda pro hub (`selecao_de_cenario.tscn`) — nunca de volta pra zona onde morreu
- Vida também enche ao entrar na loja (`loja.gd`), igual já reabastece munição

### HUD e Loja
- `scripts/world/hud.gd`: mostra munição atual/reserva, indicador de recarga e barra `Vida atual / Vida máxima` no canto inferior esquerdo, com cores por faixa de percentual
- `scripts/world/game_over.gd` + `scenes/ui/game_over.tscn`: pausa o jogo quando a Vida do jogador chega a zero e carrega o save mais recente ou retorna ao menu, sem salvar a morte
- `scripts/world/loja.gd` + `scenes/world/loja.tscn`: tela de loja para reabastecer munição, com confirmação ao tentar sair sem reabastecer
- `scripts/world/hud.gd`: mostra munição atual/reserva, indicador de recarga, barra numérica `Vida atual / Vida máxima` no canto inferior esquerdo e a densidade de `Ameaça` viva no canto superior esquerdo (contada direto na árvore em tempo real, não pelo snapshot de `ZonaPopulador`)
- `scripts/world/loja.gd` + `scenes/world/loja.tscn`: tela de loja para reabastecer munição, sem cura automática, com confirmação ao tentar sair sem reabastecer. Painel de upgrades da pistola (`%PainelUpgrades`): 4 linhas (dano/tambor/reserva/crítico), cada uma com o nível atual e um botão "Comprar" que chama `UpgradesPistola.comprar` — vira "MÁXIMO" desabilitado no nível 3. Primeiro lugar do jogo que gasta `GameState.dinheiro` (antes, só era incrementado ao lootar `Ameaça`)
- `scripts/world/exit_zone.gd`: área que leva o jogador da cena principal para a loja

### Menu Principal, Save e Pause
- `scripts/world/game_state.gd` (autoload `GameState`, `class_name EstadoDoJogo`): estado da partida em memória (munição, dinheiro, cena atual, `vida` e `vida_maxima`), com `to_dict()`/`from_dict()`/`reset()` guiados por `PADROES` — fonte única dos valores de partida nova e do schema persistido
- `scripts/core/save_slots.gd` (`class_name SaveSlots`): mecanismo de 4 slots de save independentes em disco (`user://save_auto.cfg` + `save_slot_1/2/3.cfg`, formato `ConfigFile` com envelope `[meta]` versionado); não conhece o conteúdo da partida
- `scripts/world/save_jogo.gd` (`class_name SaveJogo`): fachada que monta/aplica o payload da partida, guarda o slot em uso (`slot_atual`, `static var`) e centraliza as trocas de fase (`trocar_fase`, `sair_para_o_menu`) — autossalva no slot de autosave a cada troca. O payload tem duas seções: `"estado"` (`EstadoDoJogo`, campos flat) e `"mundo"` (`ZonaPopulador`, snapshot de `Ameaca` por zona, capturado da árvore viva antes de trocar de cena)
- `scripts/world/menu_principal.gd` + `scenes/world/menu_principal.tscn`: primeira tela do jogo (`run/main_scene`), com título "FACULANDIA" e os botões Novo Jogo / Continuar / Sair
- `scripts/world/selecao_de_save.gd` + `scenes/ui/selecao_de_save.tscn`: painel reusável de escolha de slot, usado tanto por "Novo Jogo" (3 slots, com aviso de sobrescrita) quanto por "Continuar" (autosave + 3 slots, só os ocupados ficam clicáveis)
- `scripts/world/selecao_de_cenario.gd` + `scenes/world/selecao_de_cenario.tscn`: hub entre o menu e as zonas jogáveis (estilo Mega Man) — dois "cartões" (Zona Norte / Zona Sul) gerados em código a partir de `ZONAS`; escolher um chama `SaveJogo.trocar_fase`. A loja sempre devolve o jogador ao hub (`SaveJogo.CENA_SELECAO`), nunca direto para a zona jogada antes — o jogador escolhe de novo. Tem um atalho secreto de dev (tecla **F3**) que pula direto pra `cena_principal.tscn`, a cena de teste
- `scenes/world/zona_norte.tscn`: a zona completa, jogável desde o início — cópia exata de `cena_principal.tscn` (mesmo tileset, mesmas 2 Ameaças, mesma `ZonaSaida`). `cena_principal.tscn` **não** faz parte do fluxo do jogador: é a cena de teste/dev, usada por `scripts/tests/player_vision_test.gd` e pelo atalho F3 acima. As duas cenas começam idênticas e podem divergir com o tempo — corrigir uma não propaga pra outra automaticamente
- `scenes/world/zona_sul.tscn`: esqueleto da 2ª zona — toda a infraestrutura funcionando (Player, câmera, visão, HUD, menu de pause, `ZonaSaida` pra loja, `ZonaMundoSync`), mas sem tiles pintados; label "Zona Sul (em construção)" fixo na tela. Já popula ~30 `Ameaca` proceduralmente, igual à Zona Norte — falta só pintar `chao`/`paredes` com o tileset
- `scripts/world/menu_pause.gd` + `scenes/ui/menu_pause.tscn`: menu de pause no ESC (`ui_cancel`), instanciado em toda cena jogável (`zona_norte.tscn`, `zona_sul.tscn`, `cena_principal.tscn`, `loja.tscn`); salva no slot da partida atual, sai para o menu ou fecha o jogo
- **Limitação conhecida**: a vida de uma `Ameaca` viva é reiniciada ao recarregar o snapshot; a persistência atual registra viva/morta/lootada, não a vida parcial de uma ameaça viva.
- Voltar da loja (ou fechar/reabrir o jogo) recarrega a zona do zero visualmente, mas `ZonaPopulador` restaura o estado de cada `Ameaca` exatamente como estava: mortas continuam mortas, corpos não-lootados continuam no lugar, corpos já lootados não voltam — resolvido pelo mecanismo descrito acima (era a limitação conhecida anterior, ver histórico do item 7 de Próximos Passos)

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
│   │                     # selecao_de_cenario (hub de zonas), zona_populador,
│   │                     # zona_mundo_sync (populacao/persistencia de Ameaca por zona)
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

`zona_norte.tscn` e `cena_principal.tscn` começaram como cópias exatas uma da
outra (ver "Menu Principal, Save e Pause" acima) e têm a mesma árvore-base,
mas já divergem: só `zona_norte.tscn` tem `ZonaMundoSync` (a Ameaca vira
procedural ali) e só `cena_principal.tscn` mantém `Ameaca`/`Ameaca2` fixas
(cena de teste, estável de propósito). Árvore combinada abaixo, com a
diferença anotada em cada linha que muda:

```
MainLoop (Node2D)
├── NoiseBus (Node) [noise_bus.gd]
├── TestSpawner (Node) [test_spawner.gd] — só em cena_principal.tscn; removido de zona_norte.tscn/zona_sul.tscn (redundante agora que ZonaMundoSync popula de verdade)
├── ZonaMundoSync (Node) [zona_mundo_sync.gd] — só em zona_norte.tscn/zona_sul.tscn, gera/restaura ~30 Ameaca (não existe em cena_principal.tscn)
├── Mundo (Node2D)
│   ├── NoiseVisualizer (Node2D) [noise_visualizer.gd]
│   ├── NavigationRegion2D [navegacao_cenario.gd]
│   ├── Ameaca, Ameaca2 (instâncias fixas de ameaca.tscn, só em cena_principal.tscn — nas zonas jogáveis quem popula é o ZonaMundoSync acima)
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

`zona_sul.tscn` tem a mesma árvore-base (com `ZonaMundoSync`, igual `zona_norte.tscn`),
**menos** `Ameaca`/`Ameaca2`/`Barril1-2`/`Caixa1-2` fixas e com `chao`/`paredes` sem
tiles pintados (`NavigationRegion2D` faz bake a partir só dos limites da câmera do
`Player`, sem paredes) — **mais** um `EmConstrucao` (Label, filho de `camada_ui`,
"Zona Sul (em construção)").

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

Teclas adicionais de debug (via `test_spawner.gd`, sem action própria, só em `cena_principal.tscn` — removido de `zona_norte.tscn`/`zona_sul.tscn`): `Z` spawna ameaça, `L` spawna fonte de luz de teste, `Delete`/`Backspace` remove o objeto de teste mais próximo do mouse. `F3` alterna o visualizador de ruído dentro de uma zona jogável — mas no hub (`selecao_de_cenario.tscn`) `F3` é um atalho secreto de dev que pula direto pra `cena_principal.tscn` (a cena de teste), sem relação com o visualizador de ruído.

---

## Próximos Passos Sugeridos

1. ~~**Loot ao matar ameaça**~~ — implementado: `AreaLoot`/`LootLabel` + `_lootar()` em `ameaca.gd`
2. **Loja funcional** — hoje só reabastece munição; falta usar `GameState.dinheiro` para de fato comprar algo
3. **Mais armas** — Shotgun (dispersão), Rifle (cadência maior), usando a herança de `Weapon` já existente
4. **Animação de tiro** — flash no cano da arma
5. ~~**Áudio ambiente/música**~~ — implementado: música-tema + tiro/passo/zumbi já usam arquivo `.mp3` real (`musica_tema.gd` + `noise_sfx_player.gd`); só o impacto de bala continua sintetizado, sem pedido de arquivo pra ele
6. **Mais tipos de ameaça** — a estrutura de `scripts/enemies/` já separa IA de debug logging, facilitando compor novos comportamentos a partir de `ameaca.gd`
7. **Progresso por zona e snapshot do mundo** — a navegação hub → zona → loja → hub já existe (`selecao_de_cenario.tscn`); falta o rastreio de Ameaças mortas/regeneração/conclusão de zona ao voltar. Cada zona com uma quantidade de Ameaças, mortas permanentemente mortas e vivas regenerando vida até limpar a zona; o save já tem o gancho para isso (`versao` no envelope, `cena` já aponta para qual zona/tela o jogador está, `SaveJogo` como ponto único de montagem/aplicação do payload), falta a seção de conteúdo do mundo em si. Resolve de quebra a limitação de "voltar da loja ressuscita as Ameaças" — alternativa menor no meio-tempo: transformar a loja num overlay pausado em vez de trocar de cena
8. **Cura do jogador** — a Vida já é persistida e exibida, mas nesta versão só diminui; adicionar loja/item de cura quando houver economia de itens
9. **Desenhar a Zona Sul** — `zona_sul.tscn` já tem toda a infraestrutura (Player, câmera, visão, HUD, `ZonaSaida`, menu de pause); falta pintar `chao`/`paredes` com o tileset e posicionar Ameaças/objetos
7. ~~**Progresso por zona e snapshot do mundo**~~ — implementado via `ZonaPopulador` + `ZonaMundoSync` (`scripts/world/zona_populador.gd`, `scripts/world/zona_mundo_sync.gd`) e a seção `"mundo"` do save. Cada zona gera ~30 `Ameaca` na primeira visita e persiste viva/morta/lootada em todo `trocar_fase`/`autosalvar`. Não implementado: vida regenerando em Ameaça viva até "limpar" a zona (a ideia original mencionava isso; hoje uma Ameaça viva sempre recarrega com vida cheia, sem regeneração incremental)
8. **Desenhar a Zona Sul** — `zona_sul.tscn` já tem toda a infraestrutura (Player, câmera, visão, HUD, `ZonaSaida`, menu de pause, `ZonaMundoSync` já populando ~30 Ameaça); falta só pintar `chao`/`paredes` com o tileset
