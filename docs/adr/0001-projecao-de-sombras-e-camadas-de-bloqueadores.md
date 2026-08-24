# Projecao de Sombras e Camadas de Bloqueadores de Visao

## Contexto e Decisao
Para evitar que objetos expostos a Visao Direta ou Fontes de Luz (como caixas, barris e paredes) fiquem desaturados na penumbra do cenario por estarem dentro do seu proprio ponto de colisao frontal, decidimos calcular a projecao de sombras a partir da silhueta/face traseira dos colisores.

Adicionalmente, separamos os bloqueadores em camadas fisicas dedicadas:
- **Camada 1 (Paredes / Bloqueadores Altos)**: Bloqueia movimento, projeteis, Visao Direta, Fontes de Luz e Percepcao Periferica (visao circular a curta distancia).
- **Camada 8 (Obstaculos Baixos - Caixas, Barris)**: Bloqueia movimento, projeteis, Visao Direta e Fontes de Luz, porem permite Percepcao Periferica a curta distancia.
