# Projecao de Sombras e Camadas de Bloqueadores de Visao

## Contexto e Decisao
Para garantir uma renderizacao de iluminacao e sombras 2D precisa, sem artefatos ou vazamento de luz atraves de paredes e garantindo que Bloqueadores de Visao expostos a luz tenham cor e iluminacao plena:

- **Fusao de Bloqueadores Contiguos (Paredes e Caixas)**: Blocos modulares adjacentes da mesma camada (ex: sequencias de paredes 32x32 ou caixas lado a lado) sao tratados como um unico corpo continuo. O raycasting realiza travessia continua atraves de colisores adjacentes conectados ate a verdadeira saida em espaco livre (ar/chao desobstruido). Isso garante que nao haja vazamento ou dentes em costuras internas e que o objeto inteiro fique dentro da malha iluminada.
- **Camada 1 (Paredes / Bloqueadores Altos)**: Bloqueia movimento, projeteis, Visao Direta, Fontes de Luz e Percepcao Periferica. Nas extremidades de silhueta (onde a parede encontra o chao livre), a sombra e projetada a partir da quina externa, isolando comodos e o exterior.
- **Camada 8 (Obstaculos Baixos - Caixas, Barris)**: Bloqueia movimento, projeteis, Visao Direta e Fontes de Luz, porem permite Percepcao Periferica a curta distancia.
- **Shader de Visibilidade**: Aplica atenuacao radial por distancia a partir da origem da luz e suavizacao angular nas bordas laterais do feixe de luz, operando de forma limpa sobre os poligonos geometricos de visao e luz.
