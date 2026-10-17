# Noite da Horda 0.8.3

A gameplay e a pausa seguem as duas referências aprovadas. O HUD usa placas
roxas com bordas douradas, ícones animados e números maiores; os indicadores,
o botão de pausa e os efeitos de coleta se alinham às bordas de cada tela.
A moeda do HUD permanece de frente para facilitar a leitura. Poderes ativos
e o aviso dos carros continuam visíveis sem ocupar o caminho da horda.

A pausa reúne três missões em um painel com acabamento igual ao menu e ao
mercado. Cada missão mostra objetivo, conclusão, progresso numérico e almas.
Frenesi usa o próprio zumbi correndo como ícone. Continuar recebe o botão
dourado; Recomeçar, Menu e Configurações mantêm controles independentes.
As almas e os ícones continuam animados com a corrida congelada ao fundo.

## Câmera e percurso

- Zoom normal de 1,26 para 1,32; a transformação mantém seu limite de 1,42.
- A câmera conserva a âncora horizontal da horda e enquadra os saltos normais.
  Somente saltos muito altos recebem espaço adicional abaixo do HUD: o
  enquadramento antecipa a subida, afasta suavemente quando necessário e
  retorna após a descida de todos os seguidores. A superfície continua visível.
- Pausar congela o enquadramento, e recomeçar limpa o zoom da transformação.
  O cálculo da câmera ocorre antes do desenho e da conversão dos efeitos.
- A física, o ponto de contato do chão e as colisões continuam em coordenadas
  do percurso. O chão ilustrado é repetido sob a mesma superfície e recortado
  normalmente pelos buracos.
- Os arcos de moedas param antes da silhueta dos obstáculos, considerando
  também a largura de cada veículo.

## Arte, validação e pacote

`assets/art/gameplay-ground-v83.png` é uma textura original gerada para o chão
de pedra do cemitério. O PNG original fica intacto; `AtlasTexture` recorta suas
margens no motor. Os demais personagens e cenários usam as artes aprovadas.

`tools/gameplay_v83_check.gd` confere três proporções de tela, os controles por
toque, câmera e física pausadas, configurações, retorno, reinício, salto normal
sobre buraco, salto duplo, enquadramento suave, cobertura das bordas e espaço
entre moedas e obstáculos. As capturas são produzidas pelo jogo renderizado.
Ainda é necessária uma conferência no aparelho físico.

Pacote Local `com.kauan.noitedahorda.local`, versão 0.8.3, código 21, ARMv7 e
ARM64, com a mesma chave da 0.8.2. A sobreposição preserva os recursos do menu,
mercado, sons e personagens do APK anterior, além das bibliotecas nativas.
