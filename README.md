# Faculandia

Jogo 2D top-down shooter desenvolvido em Godot 4 (GDScript).

---

## 🎮 Controles de Jogabilidade

| Ação | Tecla / Entrada | Descrição |
| :--- | :--- | :--- |
| **Movimentação** | `W`, `A`, `S`, `D` ou `Setas` / Gamepad | Move o jogador pelo cenário (redução de 15% de velocidade ao andar de costas / backpedal). |
| **Mirar** | `Movimento do Mouse` | Direciona o corpo do jogador e a arma para o cursor. |
| **Atirar** | `Botão Esquerdo do Mouse` | Dispara um projétil na direção da mira, gerando ruído sonoro e impacto com colisões. |
| **Recarregar** | `R` | Recarrega o pente da arma equipada usando munição da reserva. |

---

## 🛠️ Controles de Debug

O jogo conta com ferramentas e atalhos de depuração em tempo real para testes de visão, áudio, iluminação e inteligência artificial de inimigos:

| Tecla | Função | O que faz |
| :--- | :--- | :--- |
| <kbd>F1</kbd> | **Alternar Visão de Debug** | Ativa/desativa a névoa de guerra (*Fog of War*) e a escuridão do mapa, revelando todos os elementos e inimigos sem restrição de campo de visão. |
| <kbd>F3</kbd> | **Alternar Debug de Som** *(Desativado por padrão)* | Ativa/desativa a exibição visual das ondas sonoras (*Noise Visualizer*) emitidas pelo sistema de áudio no cenário. |
| <kbd>Z</kbd> | **Spawnar Ameaça / Inimigo** | Instancia uma nova Ameaça/Zumbi (`ameaca.tscn`) exatamente na posição atual do cursor do mouse. A ameaça começará a navegar e perseguir o jogador. |
| <kbd>L</kbd> | **Spawnar Fonte de Luz** | Cria uma nova fonte de luz dinâmica de teste na posição do mouse (raio de 280px com sombras e oclusão de obstáculos). |
| <kbd>Delete</kbd> ou <kbd>Backspace</kbd> | **Remover Objeto de Teste** | Remove o objeto de teste gerado mais próximo do cursor do mouse (dentro de um raio de 80px). |

### 🔊 Visualizador de Ruído (<kbd>F3</kbd>)
Quando ativado via <kbd>F3</kbd>, o sistema de som desenha anéis expansivos coloridos indicando o alcance e intensidade acústica de cada evento:
- 🔵 **Azul Claro**: Ruído de passos do jogador (*raio ~120px*).
- 🔴 **Vermelho / Laranja**: Ruído de disparo de arma de fogo (*raio ~600px*).
- 🟡 **Amarelo Ouro**: Ruído de impacto do projétil em paredes ou alvos (*raio ~250px*).

---

## 🚀 Como Executar

### Comandos Make

- **Rodar o jogo:**
  ```bash
  make run
  ```

- **Abrir o Godot Editor:**
  ```bash
  make editor
  ```

- **Rodar os testes automatizados:**
  ```bash
  make test
  ```

### Executar com GPU Dedicada (NVIDIA PRIME)

- **Rodar o jogo via NVIDIA:**
  ```bash
  make run-nvidia
  ```

- **Abrir o editor via NVIDIA:**
  ```bash
  make editor-nvidia
  ```

### Especificar executável do Godot

Caso o executável `godot` não esteja no seu `PATH`:

```bash
make run GODOT=/caminho/para/godot
```
