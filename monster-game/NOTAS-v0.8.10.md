# Noite da Horda — v0.8.10

Atualização sobre a v0.8.9. Android versionCode 28, pacote `com.kauan.noitedahorda.local`, mesma assinatura da edição Local. Instale por cima da versão atual, sem desinstalar, para manter o progresso.

## Pulo e hordas grandes

- Um integrante que já tem apoio pode iniciar o próximo salto imediatamente, mesmo com o primeiro ainda no ar. O toque feito até 140 ms antes de um pouso fica guardado para esse pouso.
- O pulo se propaga por tempo entre integrantes, com 8 ms adicionais por posição na fila lógica, sem o limite antigo de 120 ms. Exemplos do atraso adicional: posição 36, 280 ms; posição 88, 696 ms.
- A distância física entre integrantes ainda participa da antecipação, mas essa coordenação diminui conforme a horda cresce. As fileiras também ficam um pouco mais abertas em hordas grandes.
- Soltar o toque afeta os seguidores atrasados. Eles recebem uma continuidade parcial do gesto, em vez de repetir integralmente o salto do primeiro no mesmo ponto da pista. Acertar o primeiro já não garante pousar todos na mesma ilha.
- Comandos de seguidores vencem rapidamente se não houver apoio. Um comando antigo não fica esperando para disparar em outra plataforma muito depois.
- O laboratório permite comparar atrasos de 0, 4, 8, 12 e 16 ms por integrante. O valor inicial desta versão é 8 ms; o ajuste fino continua pelas partidas.

## Trânsito, tiros e sequências

- Carros hostis já se movem na velocidade completa desde a criação fora da câmera. A velocidade de aproximação aumentou, sem aceleração disparada pela proximidade do jogador.
- Oito variações de trânsito, incluindo pares de carros próximos, saltos curtos sucessivos, helicópteros baixos e helicópteros altos sobrepostos à passagem dos carros.
- Recuperações e intervalos dos desafios combinados ficaram menores. A geometria continua conferindo uma rota possível para quem responde ao comando, sem ampliar toda aterrissagem para garantir a passagem da horda inteira.
- Novas cadeias de chão que cede com comprimentos alternados e pequenas ilhas entre trechos. Entram tanto na geração normal quanto nas combinações com bombas. O teste “Chão que cai” passa a exercitar essas sequências.
- Veículos abaixo da força necessária perderam a penalidade quase total no sorteio, quando há uma rota de salto possível. Veículos viráveis também podem aparecer em variante blindada, com força exigida acima da horda presente. O número fica indicado no veículo; motos mantêm a exigência original.
- Soldados são colocados mais longe, começam a disparar antes e usam cadência maior com a velocidade. Tiros mais rápidos alternam mira e altura. A colisão verifica o percurso da bala entre quadros para evitar atravessar um zumbi sem registrar contato.

## Avisos e continuidade

- Textos de instrução sobre chão que cai, buracos, bombas, carros e helicópteros aparecem somente no trecho inicial da primeira partida. O chão mantém suas rachaduras e animação de desmoronamento para o jogador observar.
- A primeira partida fica registrada no progresso. Saves com partidas anteriores já são reconhecidos como jogadores que concluíram essa etapa. Testes de desenvolvedor não ativam os avisos nem alteram a progressão.
- Mantidos os sprites aprovados do civil, tetos físicos, diálogo com retrato, moedas maiores e mais grossas, redução da oferta de almas, intervalo entre túneis, poderes e otimizações da v0.8.9. Consulte as [notas anteriores](NOTAS-v0.8.9.md) para esses detalhes.

## Verificação

- Resposta ao pouso de outro integrante, toque antecipado, atraso cumulativo, soltura do gesto e vencimento de comandos verificados na física do jogo.
- 32 variações planejadas de trânsito, carros com helicópteros, chão que cai e desafios combinados passaram. Corridas com comandos simulados confirmaram rotas sobrevivíveis e perdas individuais em hordas grandes.
- Encontro com soldado a 2.400 px de distância: quatro disparos durante a aproximação; velocidade e colisão das balas verificadas.
- Duas simulações de 90 s mantendo 36 e 88 integrantes: 423 verificações de criação fora da câmera, sem criação visível, sequência recusada ou encontro sem colocação. Médias de física de 0,81 e 1,68 ms neste computador, sem equivalência garantida a desempenho no celular.
- Cinco capturas no renderizador real conferiram tutorial, partida sem instruções, desmoronamento, diálogo, onda de pulo, veículo blindado e controles do laboratório. Leitura e gravação do marcador de tutorial verificadas.
- APK conferido por versão, integridade, recursos compilados e assinatura. Não houve teste em aparelho Android físico nesta entrega.

APK SHA-256: `70ff7f4531784ce787b4039a3f48ac110dc5bd131c473426add9c778d3256222`.
