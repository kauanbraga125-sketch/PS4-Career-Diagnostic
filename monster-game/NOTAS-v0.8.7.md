# Noite da Horda 0.8.7 — ritmo e geração

Atualização sobre as fontes exatas da v0.8.6. APK completo, código de versão 25, pacote `com.kauan.noitedahorda.local`, com a mesma assinatura da edição Local anterior. Instale por cima da 0.8.6, sem desinstalar, para preservar o progresso.

**O que mudou**

- Estrada entre túneis 30% menor: 18.000 → 12.600 px na velocidade inicial. O fator por velocidade continua; a largura visual das transições não foi reduzida.
- Geração em momentos de crescimento, desafio e recuperação, com sorteios ponderados e histórico dos últimos cinco trechos para diminuir repetições.
- Bombas isoladas, duplas para salto longo, sequências de saltos separados e combinações terrestres/aéreas. Até seis ameaças nos conjuntos avançados.
- Buracos de três tamanhos e conjuntos de até quatro buracos, respeitando o tempo de voo e a superfície para aterrissar e saltar novamente.
- Pressão adicional para hordas grandes, limitada pelo túnel e suavizada ao longo do tempo. Perdas recentes e hordas pequenas aumentam oportunidades de recuperação.
- Helicópteros raros no início, com intervalo mínimo e aviso visual/sonoro. Os seguidores calculam a aproximação relativa também para perigos aéreos baixos em movimento.
- Moedas em formações variadas e arcos derivados da trajetória real do salto. Trechos efetivamente vazios recebem moedas em corredores com caminho de corrida validado, incluindo o interior dos túneis.
- Agendamento separado dos bônus: espera mínima, sorteios por janelas de distância, chance crescente depois de falhas e prazo para procurar a próxima zona segura. Caixas oferecidas permanecem coletáveis durante o cooldown do próximo nascimento.
- Velocidade inicial mantida e crescimento posterior aproximando-se gradualmente de 680 px/s.
- Registro da seed, horda, velocidade, túnel e últimos 48 trechos em `user://last_run_generation.json`, ao encerrar a partida e nas saídas dos túneis.

**Parâmetros ajustáveis**

Valores experimentais deste jogo, não probabilidades oficiais de outros runners. Intensidades abaixo aplicam-se apenas aos trechos de desafio. Crescimento, elegibilidade e repetição ainda modificam a distribuição observada.

| Fase | Crescimento nominal | Leve / médio / intenso | Helicóptero por slot móvel elegível | Intervalo mínimo de helicóptero | Máximo bombas / buracos |
|---|---:|---|---:|---:|---|
| Início–T3 | 68% | 70 / 27 / 3% | 2% | 42 s | 2 / 1 |
| T4–6 | 56% | 52 / 38 / 10% | 6% | 30 s | 3 / 1 |
| T7–8 | 45% | 38 / 43 / 19% | 10% | 24 s | 3 / 2 |
| T9–10 | 36% | 25 / 47 / 28% | 10% | 21 s | 4 / 3 |
| T11+ | 30% | 18 / 44 / 38% | 14% | 18 s | 6 / 4 |

Os intervalos dos perigos móveis são convertidos em distância na velocidade de planejamento. Bônus: cooldown de 0,60–0,90 intervalo novo de túnel; prazo de 1,80–2,30 intervalos, seguido da primeira zona segura, sem sobrepor poderes ativos. Janela de 2,8 s de deslocamento; chance inicial de 14%, acrescida de 8,5 pontos percentuais por falha, até 90%.

Moedas: chance nominal de 70% dos chunks elegíveis, além do preenchimento de corredores vazios. Buracos pequenos/médios/grandes: 0,25–0,39 / 0,43–0,57 / 0,69–0,73 s de deslocamento. Recuperação entre saltos: 0,32 s mais pequena variação no espaçamento. Relevo: patamares de 80 px, retorno ao piso antes de outra subida, terreno plano predominante.

O pulo da 0.8.6 já tinha a extensão solicitada e foi preservado depois de medido: toque de 0,04 s → cerca de 82 px e 0,635 s de voo; segurar → cerca de 198 px e 1,268 s. Os limites dos buracos grandes já estavam ligeiramente reduzidos na versão-base.

**Verificações realizadas**

- 15.000 trechos gerados. com 200 seeds por combinação de fase/horda. Início/T1/T3 com 16 membros; T5/T8/T11 com 16. 25. 36 e 50. Sem falhas detectadas nos casos verificados.
- 121.018 verificações de posições de moedas livres de terreno e obstáculos.
- 252 cenários de conjuntos completos no simulador real, a 30/60/120 FPS, com hordas de 1/16/36/50. Nenhuma perda ao executar as trajetórias previstas.
- Coleta de bônus durante o cooldown seguinte, determinismo dos sorteios e redução exata de 30% dos intervalos de túnel verificados novamente após a recuperação do ambiente. Um buraco deliberadamente impossível foi rejeitado pelo validador.
- Na etapa anterior desta mesma atualização, foram executados mais 54 cenários de perigos aéreos móveis a 30/60/120 FPS e com hordas de 1/16/50, sem perdas nos saltos testados. Também foram renderizados menu, veículos, horda de 60, pulo e pausa, e verificados os controles e compras do mercado.

| Seed de observação | Fase inicial | Bônus coletados em 240 s | Maior vazio visível | Tempo em relevo elevado |
| 877000 | T0 | 6 | 1.17 s | 5.56% |
| 877008 | T8 | 5 | 1.10 s | 5.54% |
| 877011 | T11 | 5 | 1.47 s | 5.68% |

Essas três observações mantêm os integrantes vivos para medir a distribuição do cenário; não representam uma partida humana. A física é testada separadamente, sem esse auxílio. Antes da pausa, três partidas com um bot que apenas acionava o toque, sem invencibilidade, teletransporte ou integrantes injetados, atingiram T11: seeds 8711, 8712 e 8713, com hordas de 80, 77 e 70 e perdas de 2, 3 e 1. Isso demonstra alcance possível com essa política, sem medir a dificuldade para uma pessoa.

O APK teve os recursos compilados com Godot 4.5.1, assinatura v2/v3 e integridade ZIP conferidas. Artes, áudio e bibliotecas ARMv7/ARM64 foram preservados por comparação byte a byte. Não houve instalação em um celular Android físico; sensação do toque, fluidez no aparelho e dificuldade ainda dependem das suas partidas.

**Fontes**

- `scripts/tuning.gd`: parâmetros por fase.
- `scripts/course.gd`, `director.gd`: padrões, probabilidades, moedas e ritmo.
- `scripts/sequence_validator.gd`: validação de conjuntos.
- `scripts/bonus_director.gd`: bônus e zonas seguras.
- `scripts/runner.gd`: túneis, coleta, seguidores, avisos e diagnóstico.
- `scripts/terrain.gd`: RNG de terreno; `game.gd`: aviso de helicóptero.
- `project.godot`, `export_presets.cfg`: versão e distribuição.
- `tools/*v87*.gd`, `validation/v087-*.json`: testes e relatórios.

As fontes completas estão preservadas no arquivo `NoiteDaHorda-v0.8.7-fontes.bundle`. Para recuperar esse bundle incremental, obtenha antes o commit público `fca6490f1641cd5da018e8d4ee878a5ce00c6492` do repositório `kauanbraga125-sketch/horda-zumbi`, importe o bundle com `git fetch CAMINHO_DO_BUNDLE HEAD` e crie uma branch a partir de FETCH_HEAD. A chave privada de assinatura fica separada.

O envio da branch pelo Git foi impedido pela conexão de rede (HTTP 403). Portanto, o repositório remoto ainda não deve ser tratado como fonte desta v0.8.7; use o backup de fontes entregue com ela.
