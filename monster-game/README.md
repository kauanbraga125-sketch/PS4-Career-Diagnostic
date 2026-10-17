# Atualização 0.8.10

Pulo iniciado por qualquer integrante que tenha pousado, atraso cumulativo sem o limite antigo, menor coordenação nas hordas grandes, carros mais rápidos, trânsito compacto, chão que cai em sequência, veículos de força insuficiente e instruções somente na primeira partida. [Mudanças e verificações](NOTAS-v0.8.10.md).

# Atualização 0.8.9

Trânsito hostil e helicópteros, tetos corrigidos, civil de casaco azul com 66 quadros, desmoronamento animado, desafios combinados, otimização da horda e laboratório de testes ampliado. [Mudanças e verificações](NOTAS-v0.8.9.md).

# Atualização 0.8.8

Bombas em grupos terrestres/aéreos/mistos, pressão antecipada sobre hordas grandes, chão que cede, tetos físicos e resgate garantido dos veículos. Moedas planejadas fora da câmera, com orçamento 30% menor e novas geometrias. Intervalo-base entre túneis +20%; zoom reduz o espaço visível em 5%. Testes específicos em **Configurações → Desenvolvedor teste**. Detalhes, limites e validação em [NOTAS-v0.8.8.md](NOTAS-v0.8.8.md).

# Atualização 0.8.5

Variedade da fase e elevações menos frequentes: veja [UPDATE-v0.8.5.md](UPDATE-v0.8.5.md).

# Atualização 0.8.4

Gameplay, missões, tutorial e coleção: veja [UPDATE-v0.8.4.md](UPDATE-v0.8.4.md).

## Gameplay e pausa 0.8.3

HUD e pausa seguindo as referências aprovadas, chão de pedra, moedas separadas dos obstáculos e enquadramento suave para saltos altos. Detalhes em [UPDATE-v0.8.3.md](UPDATE-v0.8.3.md).

# Noite da Horda — Android 0.8.2

Mercado seguindo a referência aprovada, com quatro melhorias visíveis, ícones maiores, benefícios e preços claros. Compras por toque, rolagem e persistência de desbloqueios corrigidas. Detalhes em [UPDATE-v0.8.2.md](UPDATE-v0.8.2.md). O menu mantém o cenário 0.8.1 e a animação contínua aprovada de 32 segundos; a corrida usa os sprites completos da base 0.7.8.

Jogo offline de corrida 2D para Kauan. Godot 4.5.1, Android 7+, OpenGL ES 3.0, ARMv7 e ARM64. Atualização do pacote Local mantém a assinatura e migra o progresso das versões 0.1–0.5.1 para o save 6.

Correção dos encaixes do zumbi: [UPDATE-v0.7.1.md](UPDATE-v0.7.1.md).

Detalhes da atualização 0.7 e pendência de ambientes: [UPDATE-v0.7.md](UPDATE-v0.7.md).

## Atualização 0.7

Pulo em ondas, correções dos membros e das colisões, percurso variado com dificuldade gradual, almas mais raras, mercado com rolagem, coleção animada, novo frasco de almas com 61 estados e passageiros animados. Os detalhes e a validação estão em [UPDATE-v0.7.md](UPDATE-v0.7.md).

## Base 0.6 preservada

- O menu apresenta o zumbi animado em destaque e o companheiro Super Fly disponível. Esqueleto, Mascarado e os demais recursos continuam disponíveis pela coleção e pelos poderes.
- Mercado único, quatro categorias, ilustrações individuais e linhas que expandem com descrição, preço e COMPRAR. Coleção e missões têm atalhos próprios.
- Líquido do caldeirão ondula com bolhas, estouros, vapor e luz. Almas recebidas reforçam sua reação.
- Metamorfose de 2,8 segundos com título, aproximação suave da câmera, eletricidade, impacto e voz. Pista continua em movimento a 22% do ritmo; voo recupera até 86%; término volta progressivamente a 100%.
- Coletar um poder no túnel N impede todos os poderes nos túneis N+1 e N+2. N+3 volta ao sorteio de 22% por oportunidade; nenhum padrão garante o aparecimento. O trecho inicial conta como túnel 1.
- Civis sozinhos ou em grupos de três; pelo menos 100 metros entre grupos de três. Proteção de posicionamento e de percurso nos dois lados dos buracos. Grupos tornam-se mais raros com o avanço; perdas recentes favorecem recuperação.
- Toque curto dá salto curto; segurar prolonga subida e descida. Seguidores antecipam seu salto diante de carros em movimento.
- Bombas maiores e grupos tardios; carros vindo em sentido contrário com aviso e buzina. Cada carro causa no máximo uma perda e quebra no primeiro contato. Seu para-choque é a superfície de colisão; saltar no momento correto evita o impacto. Sequências aparecem nas etapas avançadas.
- Contraste de primeiro plano, borda no shader, cenário levemente escurecido, fontes do jogo e um balão persistente por vez com antecipação em alta velocidade.
- Dezesseis efeitos fornecidos por Kauan, três músicas e efeitos anteriores recebem tratamento comum. Filtros, compressão leve, normalização, limitação de picos e emendas de loops. Mixer separado de música, efeitos e vozes; impactos/vozes baixam a música; transições e repetições musicais usam crossfade. Limitador final protege a soma dos canais.

| Momento | Faixa |
|---|---|
| Menu | Mischief Under Moonlight |
| Início até o túnel 5 | Clockwork Ghoul’s Dash |
| Túnel 6 em diante | Midnight Sprint |

## Verificação e compilação

```sh
godot --headless --path monster-game --editor --import
godot --headless --path monster-game -- --self-test
godot --path monster-game -- --menu-preview
```

Testes verificam progressão, migração, economia, capturas, túneis, salto, veículos, intervalo e sorteio de poderes, percurso dos civis, mixagem e estabilidade em simulação. A suíte visual usa toques e arrastos em três proporções e captura uma metamorfose em movimento. Desempenho em celular físico não foi medido.

As opções de importação com mipmaps evitam serrilhado ao reduzir sprites. A atualização 0.7 adiciona arte de passageiros e do frasco de almas. Créditos e proveniência em ASSETS.md, assets/art/prompts-v7.json e nos manifestos de áudio assets/audio/SOURCES-v6.json e assets/audio/v7/manifest.json. Para reproduzir o tratamento: HORDE_AUDIO_SOURCE aponta para os MP3 originais enviados e HORDE_AUDIO_BASE para os OGG anteriores; executar tools/prepare_audio_v6.py (NumPy, SciPy e FFmpeg).

O APK Local usa com.kauan.noitedahorda.local, versionCode 28 e versionName 0.8.10, com a chave Local existente. Não requer internet, anúncios ou pagamentos reais.
