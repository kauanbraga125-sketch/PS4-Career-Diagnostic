# Noite da Horda 0.8.4

Esta versão reúne as três telas aprovadas e os ajustes de programação pedidos no ZIP `Horda_Zumbi_Prompt_e_Referencias_Visuais.zip`. Mantém o menu inicial, sua animação e as compras do mercado. O algoritmo e as constantes da câmera permanecem os mesmos da versão 0.8.3.

## Gameplay

- Pulo com impulso inicial, sustentação limitada durante a subida e soltura suave por aceleração, sem teletransporte ou velocidade descendente instantânea. Cada integrante repete a duração do toque no mesmo ponto do mundo. Toques duplicados no mesmo quadro não enfileiram saltos extras; o salto duplo continua exigindo a melhoria de nível 2.
- Plataformas físicas com degrau de 80 pixels, topo caminhável e retorno ao chão original. Uma máquina de estados persistente entre trechos impede subir novamente antes de descer. O degrau bloqueia a passagem de quem não pula; a saída inicia uma queda natural. O chão usa recortes do tile existente, na mesma escala.
- Geração na ordem terreno → obstáculos e corredores de movimento → trajetórias livres → moedas → NPCs/eventos. Moedas passam por validação em coordenadas de mundo contra solo, bordas, buracos, veículos, bombas e ameaças móveis. Formações inválidas recebem uma alternativa ou são descartadas.
- Sete padrões: fileira baixa, fileira alta, subida, descida, arco, pequena grade e fileira sobre plataforma. Cada grupo tem uma trajetória de coleta validada com o raio básico de coleta, sem depender do ímã. Novos perigos reservam espaço antes de aparecer; há nova checagem quando se movimentam.
- Veículos grandes menores e geometria ajustada ao alcance do pulo sem melhorias, com margem para variação de velocidade. O desenho, as rodas, os contatos, os colisores e os destroços usam as mesmas dimensões. Força necessária, recompensas e resgates foram preservados. Obstáculos sem um caminho completo de aproximação, passagem e recuperação são reposicionados ou omitidos.
- Falas mais frequentes, com cooldown variável, uma fala por vez e antirrepetição das últimas três frases. NPCs do cenário da cidade também fazem comentários; não foram alterados seus sprites.

## Telas aprovadas

Missões: três cartões, progresso numérico, conclusão, recompensas animadas do ritual e acesso direto a Jogar.

Como jogar: demonstrações animadas com os personagens existentes, controles de toque, força dos seis veículos e explicação dos poderes.

Coleção: prévia animada, personagem completo mesmo bloqueado, estados de desbloqueio, poderes temporários e acesso ao mercado. Selecionar uma prévia não compra nem equipa nada. Voltar do mercado preserva a seleção e mostra compras imediatamente.

## Valores adotados

Valores do próprio jogo; não são medidas oficiais de Zombie Tsunami.

| Parâmetro | Valor |
|---|---:|
| Impulso inicial | 580 px/s |
| Gravidade normal | 1.500 px/s² |
| Gravidade durante sustentação | 950 px/s² |
| Tempo máximo de sustentação | 0,50 s |
| Transição após soltar | até 0,10 s, com gravidade de 3.000 px/s² |
| Pulo curto, toque de 0,04 s, sem melhorias | cerca de 81 px de altura e 0,63–0,64 s de voo |
| Pulo longo, toque de 0,50 s, sem melhorias | cerca de 173 px de altura e 1,02–1,03 s de voo |
| Alcance inicial aproximado, a 305 px/s | 193–195 px curto; 311–316 px longo |
| Degrau | 80 px, cerca de 46% da altura do pulo longo |
| Diâmetro visual da moeda | 45 px |
| Espaçamento de moedas | 68 px, cerca de 1,51 diâmetro |
| Intervalo alvo entre grupos | 1,8–3,5 s de deslocamento; grupos inseguros são omitidos |
| Duração da fala de NPC | 2,5 s |
| Pausa após a fala | 2,5–4,5 s |

## Validação

- Simulações a 30, 60 e 120 FPS, velocidades de 305, 500 e 780 px/s, e hordas de 1, 5 e 20: pulos curto/longo, chegada de todos os integrantes ao topo, retorno ao solo e impossibilidade de simplesmente caminhar sobre o degrau.
- Travessias físicas dos seis veículos com hordas de 1, 5 e 20 nas três velocidades; travessias de buracos longos; teste de novos perigos e corredores de projéteis sobre moedas.
- Varredura de 840 trechos em 12 seeds, incluindo 223 plataformas e 6.461 checagens de moedas, sem falhas nos cenários testados. Resultado final e medidas individuais acompanham o código em `tools/balance_v84_check.gd` e no relatório de validação.
- Renderização real no Godot em 1600×720, 1280×720 e 1280×960. Controles por toque, animação facial da coleção, estados bloqueado/liberado, compra de monstro, navegação de poderes, retorno dos créditos, Jogar, pausa e retomada.
- Regressão completa do mercado: compras e débitos exatos, quatro melhorias, limite de nível, saldo insuficiente, multitoque, arrastar sem comprar, rolagem, desbloqueios de monstros/poderes/cenários, persistência do save e bônus de duração.
- APK com as bibliotecas Android ARMv7 e ARM64 preservadas, mesma identidade do aplicativo e mesma assinatura da versão local anterior. Verificação de assinatura e integridade do pacote.

Os testes foram feitos no motor e por simulação automatizada. Não houve teste em um celular Android físico nesta sessão. O encerramento do Godot no ambiente de teste ainda informa recursos em uso; os fluxos testados terminam sem erros de execução.

## Instalação e pendências

Instale por cima do APK local 0.8.3 para manter o progresso; não desinstale a versão anterior. O APK é completo, não exige instalar um pacote separado de recursos.

Conforme o ZIP, a revisão de artes de NPCs, motoqueiro, passageiros, captura e novas expressões fica registrada em `BACKLOG-SPRITES.md` para outra atualização. Nenhum sprite foi redesenhado nesta rodada.
