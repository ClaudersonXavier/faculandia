# Faculandia

Glossario do contexto de jogo para manter linguagem consistente sobre mapa, movimento e combate.

## Language

**Obstaculo**:
Elemento do cenario que bloqueia movimento do jogador e projeteis.
_Avoid_: Parede, bloqueio, colisao

**Bloqueador de Visao**:
Elemento do cenario que impede o jogador de perceber o que esta atras dele.
_Avoid_: Obstaculo, parede, bloqueio

**Cenario**:
Ambiente fisico do jogo que permanece parcialmente perceptivel mesmo fora da Visao Direta.
_Avoid_: Mapa, fundo, mundo

**Ameaca**:
Entidade que pode ferir ou pressionar o jogador. Sua capacidade de agir nao depende de estar perceptivel para o jogador.
_Avoid_: Inimigo, monstro, zumbi

**Percepcao da Ameaca**:
Capacidade de uma Ameaca notar o jogador por sinais como presenca, ruido ou luz.
_Avoid_: Visao do jogador, agro automatico, alerta garantido

**Interativo**:
Elemento que o jogador pode examinar, coletar ou acionar quando esta ao alcance e perceptivel.
_Avoid_: Item, objeto clicavel, loot

**Vestigio**:
Rastro visual de uma acao recente ou passada que pode permanecer parcialmente perceptivel fora da visao direta.
_Avoid_: Efeito, decalque, marca

**Visao Direta**:
Area a frente do jogador onde ameacas e interativos podem ser percebidos claramente.
_Avoid_: Lanterna, cone de luz, campo de visao

**Mira**:
Direcao apontada pelo mouse que orienta a Visao Direta do jogador.
_Avoid_: Direcao de movimento, rotacao, olhar

**Fonte de Luz**:
Elemento do cenario que torna uma area mais perceptivel sem depender da Mira do jogador.
_Avoid_: Lampada, vela, luz teste

**Percepcao Periferica**:
Area curta ao redor do jogador onde ameacas e interativos muito proximos podem ser percebidos claramente.
Bloqueadores de Visao impedem essa percepcao.
_Avoid_: Luz interna, circulo de luz, visao circular

**Andavel**:
Area do cenario onde o jogador pode se mover livremente.
_Avoid_: Chao livre, passavel
