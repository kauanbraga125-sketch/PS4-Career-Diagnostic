# PROMPT ÚNICO PARA O CHATGPT — HORDA ZUMBI

## Contexto
Trabalhe sobre a VERSÃO MAIS RECENTE do projeto Android **Horda Zumbi**. Ele é um endless runner 2D com horda de monstros, inspirado em certas mecânicas de *Zombie Tsunami*, mas deve manter identidade e recursos próprios.

Receba como referências o arquivo `VISUALIZACAO_GERAL.png`, as nove imagens em `diagramas/` e o arquivo `referencias_externas/FONTES_E_REFERENCIAS.md`.

**Já corrigidos — NÃO refazer:** (1) personagem flutuando no menu inicial; (7) mercado sem permitir clicar/comprar. Preserve essas correções e teste regressões.

**Escopo desta rodada — SOMENTE PROGRAMAÇÃO:** pulo, tamanho/colisões de veículos, moedas, terreno elevado, comentários de NPCs e testes. Não redesenhe sprites, não altere a câmera sem necessidade. Guarde para outra atualização os sprites de civis, motoqueiro, NPCs em veículos, animação especial de captura e piscadas/expressões/roupas do zumbi.

## 1. Pulo variável baseado no toque (alta prioridade)
Queremos sensação de controle semelhante ao Zombie Tsunami: toque rápido = pulo curto; pressionar por mais tempo = pulo mais alto, mais lento e de maior alcance; soltar = interromper sustentação e descer naturalmente.

1. Localize a física real (posição/velocidade/gravidade e input) e mexa nela, não apenas na animação.
2. Mantenha impulso inicial e grave três fases: subida/sustentação limitada/descida. Reduza gravidade APENAS durante a subida e enquanto botão pressionado (ou aplique sustentação limitada equivalente).
3. Imponha tempo máximo de sustentação; quando soltar, retire força de sustentação e, se necessário, use um corte SUAVE da velocidade positiva de subida. NÃO teletransporte nem force velocidade descendente instantânea.
4. A queda deve continuar natural e a curva de toque longo claramente mais ampla que a de toque curto, sem permitir voo infinito. Pode partir de aumento moderado de 8–12% na altura máxima se testes mostrarem necessidade, mas primeiro ajuste veículos.
5. Preserve aterrissagens, coordenadas de solo variáveis, sistema de horda e frame rate independence (deltaTime). Não permitir múltiplos saltos aéreos acidentais, travamento ou atravessar terreno.
6. Instrumente medição do tempo de voo, altura e distância máxima para pulo curto e longo nas velocidades principais de jogo.

Referência visual: `diagramas/01_pulos_curto_longo.png`, `02_fisica_pressao_soltar.png`.

## 2. Spawn e geometria de moedas (alta prioridade)
Não quero moedas dentro de bombas, veículos, chão, obstáculos ou buracos. Quero padrões planejados e COLETÁVEIS, inspirados nas imagens de gameplay real:
- Linha horizontal baixa: 3–6 moedas, coletáveis correndo.
- Linha horizontal alta: 3–5, exige salto.
- Diagonal crescente e decrescente: 3–6, acompanha subida/descida.
- Arco de salto: 4–7, respeita curva real de toque curto ou longo.
- Pequena grade: 2×2 ou 2×3, somente se todas puderem ser alcançadas por trajetória válida.
- Formações sobre chão elevado.

**Parâmetros experimentais e configuráveis (não são valores oficiais):** distância centro-a-centro de moedas adjacentes ~1,35 a 1,7 vezes o diâmetro visual; início de grupos separado pelo deslocamento equivalente a cerca de 1,8–3,5 s na velocidade de referência. Recalibre por dificuldade, velocidade, colisão e alcance real. Evite grupos tão colados que exijam dois saltos antes de aterrissar.

**Procedimento obrigatório de geração:** (a) gere/reserve trechos de terreno; (b) gere/reserve obstáculos e veículos; (c) compute zonas de exclusão (hitboxes + margem); (d) proponha formação de moedas; (e) teste cada moeda contra geometria e área de exclusão em coordenadas DE MUNDO, antes de materializar; (f) valide que a formação tem trajetória coletável a partir de situação de entrada plausível; (g) se inválida, reposicione/troque padrão ou descarte.

Evite validação baseada apenas na imagem desenhada, pois hitboxes e áreas de coleta podem diferir. Reserve espaço tanto para obstáculos estáticos quanto objetos em movimento ou recém-gerados. Eventos/despawn não devem produzir duplicação de moedas.

Referências: `03_formacoes_moedas.png`, `04_moedas_colisoes.png`, `09_espacamento_moedas.png`.

## 3. Terrenos elevados REAIS, sem morrinhos (prioridade máxima)
Não crie lombadas arredondadas. Quero segmentos de pista com altura superior e topo caminhável, que o jogador só alcance PULANDO. Depois de algum tempo, a pista deve DESCER de volta ao nível inicial.

Sequência permitida: NORMAL → SUBIDA → ELEVADO → DESCIDA → NORMAL.
Regra inflexível: NUNCA duas subidas seguidas antes de descer. Não é permitido NORMAL → ALTO → MAIS ALTO. Garantir que o estado persista através das chunks carregadas.

Implemente máquina de estados:
- NORMAL: pode continuar normal ou iniciar uma subida.
- ELEVADO: pode continuar no alto ou descer, mas NÃO pode gerar outra subida.
- DESCENDO/RETORNO: finalize transição, atualize altura do chão para baseline, volte a NORMAL.

A plataforma superior deve ter área física caminhável, comprimento para aterrissar, borda reconhecível e alinhamento visual. Use inicialmente como teste um degrau ~35–55% da altura efetiva do pulo LONGO, ajustando conforme colisões, velocidade, espaço de reação e tamanho da horda. Estabeleça comprimento mínimo de entrada e de plataforma com base no alcance real do salto. Salto no fim do degrau/queda não deve atravessar o chão. Câmera permanece estável como hoje; não recentralize verticalmente a cada degrau. Use tiles/recortes do chão existente de modo coerente, sem texturas esticadas.

Nunca gere obstáculo inevitável logo após subir, nem moedas dentro da borda do degrau. Inicie próximo segmento em NORMAL somente depois que DESCIDA ocorreu. Varie comprimentos, mas garanta retorno.

Referências: `05_terreno_elevado_correto.png`, `06_proibido_dupla_subida.png`.

## 4. Veículos e obstáculos
Revise escala e hitboxes dos veículos grandes que parecem impossíveis de saltar quando se aproxima. Antes de superdimensionar pulo, REDUZA somente veículos desproporcionais, juntamente com seus colisores. Mantenha rodas no chão e alinhe hitboxes ao visual. Determine tamanho aceitável pela altura/alcance reais dos pulos nas diferentes velocidades. Preserve lógica atual de destruição/resgate da horda. Não deixe veículo alto bloquear uma plataforma elevada sem espaço para reação.

Referência: `07_veiculos_hitbox.png`.

## 5. Falas e comentários de NPCs
Aumente moderadamente a frequência das falas de civis e NPCs (inclusive os do cenário), sem sobreposição excessiva. Use cooldown variável, limite de concorrência e antirrepetição. Podem ocorrer eventos contextuais (horda crescente, carro, salto, civil próximo). Respeite áudio atual e não altere artes/sprites nesta etapa.

## 6. Arquitetura do spawn
Adote sequência lógica que evite geradores cegos: TERRENO → VEÍCULOS/OBSTÁCULOS → ZONAS LIVRES/TRAJETÓRIAS → MOEDAS → NPCs/EVENTOS, ou equivalente compatível com arquitetura atual. Use o MESMO sistema de coordenadas e evite misturar posições de mundo e de tela. Centralize constantes de balanceamento.

Referência: `08_pipeline_geracao.png`.

## 7. Testes necessários, sem verificações intermináveis
- Toque rápido: pulo curto. Hold: ganho claro de altura e distância. Release: queda natural.
- Testes em 30, 60 e 120 FPS, ou simulação com dt apropriado.
- 1, 5 e 20 zumbis: colisões/aterrissagem corretas conforme arquitetura.
- Varredura automatizada de pelo menos centenas de trechos e várias seeds: ZERO moedas dentro de colisores; ZERO segunda subida sem descida; ZERO trechos críticos sem trajetória jogável.
- Conferir moedinhas perto de veículos, bombas, bordas, terrenos elevados e durante velocidades rápidas.
- Conferir escala/collider de veículos, falas e regressões do mercado e do menu.
- Evite alteração da câmera e de sprites.

## 8. Entrega
Aplique no código da versão MAIS RECENTE; compile APK somente após testes essenciais se houver ambiente de build. Forneça APK, alterações resumidas, valores adotados e o que realmente foi testado. Se o repositório ou compilador não estiver disponível, peça acesso ou indique limitação em vez de inventar entrega ou links. Não reinicie projeto, não perca recursos já implementados.

**Importante:** o design dos diagramas é original e conceitual; não trate curvas/dimensões desenhadas como medidas oficiais do Zombie Tsunami. Base factual: tap/hold/release descrito em guias e controles com um toque oficialmente descritos; distribuição, frequências e regras do nosso gerador são decisões de implementação.
