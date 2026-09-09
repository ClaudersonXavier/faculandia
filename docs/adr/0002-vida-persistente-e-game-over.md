# Vida persistente e Game Over como retorno ao checkpoint

Decidimos persistir `vida` e `vida_maxima` no estado da partida e, ao chegar a zero, pausar o jogo em uma tela de Game Over. O botão de retorno carrega o save mais recente entre autosave e slot manual, sem gravar a morte; isso preserva um checkpoint jogável e evita que uma derrota sobrescreva o progresso recuperável.

## Considered Options

- **Autosave fixo ou slot manual fixo**: rejeitados porque cada um pode estar mais antigo que o outro.
- **Salvar Vida zero ao morrer**: rejeitado porque transforma a derrota em um estado persistente que exige uma restauração especial.
- **Vida não persistente**: rejeitada porque as transições de cena e o Continue perderiam o Estado de Vida acordado para a partida.
