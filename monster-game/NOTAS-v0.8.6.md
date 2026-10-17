# Noite da Horda 0.8.6 — proporções e progressão

Versão Android 0.8.6, código 24. Reequilibra o tamanho dos veículos, o pulo segurado e a geração probabilística dos encontros.

## Veículos e passageiros

Todos os veículos usam 84% de suas dimensões de referência, independentemente da velocidade. A redução individual para caber no pulo foi removida.

| Veículo | Largura × altura no mundo | Zumbis para virar |
|---|---:|---:|
| Moto | 126 × 81 px | 2 |
| Carro | 207 × 102 px | 4 |
| Ônibus | 395 × 197 px | 8 |
| Caminhão | 386 × 190 px | 10 |
| Tanque | 311 × 155 px | 12 |
| Avião | 571 × 272 px | 16 |

O avião tem 2,76 vezes a largura do carro. Silhueta, colisão, dano e destroços acompanham o veículo. Os passageiros são desenhados dentro das janelas e somente nas posições ocupadas. Motos vazias deixam de mostrar um piloto fictício. A ocupação de cada assento é sorteada: começa em 78% e diminui gradualmente até 42% nas etapas avançadas.

Veículos grandes entram quando há força suficiente para virá-los, com uma pequena margem de membros, ou quando o salto foi validado para aquele veículo e velocidade. Isso permite manter seus tamanhos sem gerar uma parede impossível para uma horda pequena. A margem considera a horda no momento da geração; perder membros depois ainda pode mudar a decisão do jogador.

## Pulo, buracos e elevações

- O pulo segurado ganhou sustentação também no começo da descida. Na física base, o tempo de voo passou de aproximadamente 1,02 s para 1,27 s, com pico de cerca de 198 px. A sustentação termina após 1,05 s de toque; depois a gravidade normal prevalece. O toque curto continua próximo de 82 px e 0,64 s.
- Os seguidores repetem a duração do toque a partir do próprio lançamento. O ajuste de aproximação contra carros vindo na direção da horda foi preservado.
- Buracos pequenos ocupam 0,25–0,39 s de deslocamento; médios, 0,43–0,57 s; grandes, 0,69–0,73 s. Antes, os grandes usavam 0,77 s. A chance de um buraco sorteado ser grande aumenta de 10% até 30% com o avanço.
- Elevações mantêm 80 px de altura e precisam de um salto real. Depois de cada elevação, há um trecho plano equivalente a 45–65 s de deslocamento, respeitando um mínimo de 13.000 px e as áreas dos túneis. A primeira só pode começar depois de 14.500 px.
- O planejamento de helicópteros baixos usa a mesma colisão do jogo, incluindo o movimento vertical. O gerador deixa de levantar todos para compensar uma caixa visual excessiva. As moedas continuam excluídas da arte completa dos perigos; novos buracos e perigos reposicionados invalidam moedas incompatíveis imediatamente.

## Sorteios e dificuldade

A antiga abertura de 12 eventos e o baralho com cotas fixas foram substituídos por sorteios com pesos. A introdução continua com um civil e moedas; os encontros seguintes variam entre partidas. Repetições recebem uma redução de peso, sem obrigar uma quantidade exata de cada objeto.

No início há mais civis, oportunidades de resgate e trechos de moedas. Conforme os túneis avançam, diminuem os pesos dessas oportunidades e aumentam os de buracos, bombas, helicópteros, carros em sentido contrário e soldados. Hordas pequenas ou recém atingidas recebem um reforço moderado na chance de recuperação. Carros em sentido contrário mantêm o aviso de aproximação e um intervalo mínimo entre eventos; deixam de ser adicionados por um segundo temporizador independente do sorteio.

| Túneis alcançados | Velocidade base |
|---|---:|
| 0 | 305 px/s |
| 1 | 316 px/s |
| 3 | 338 px/s |
| 5 | 360 px/s |
| 6 | 377 px/s |
| 10 | 445 px/s |
| 15 | 550 px/s |
| Avançado | Até 680 px/s |

A influência adicional do tamanho da horda foi reduzida: começa em até 3 px/s e chega a até 12 px/s nas etapas avançadas. Frenesi continua sendo uma aceleração temporária. O espaçamento entre encontros diminui gradualmente de aproximadamente 3,0–4,1 s para 2,1–2,9 s, com espaço extra para obstáculos largos, plataformas, aproximações e túneis.

O limite técnico da horda subiu de 24 para 96. A cota de almas nos primeiros túneis foi removida. A formação fica mais compacta nas hordas grandes, e o desenho e o cálculo de enquadramento usam a mesma profundidade. Hordas de 60 permanecem no enquadramento normal em solo; a câmera mantém sua âncora, limites e suavização.

## Validação

| Verificação | Resultado |
|---|---|
| Pulos e carros em sentido contrário | 72 cenários, a 30/60/120 FPS, com 1/20/60 membros e velocidades de etapas iniciais a avançadas; sem perdas nos saltos testados. |
| Veículos com tamanho novo | Os seis tipos foram virados pela física real, com contagem correta dos passageiros resgatados. Moto e carro também foram ultrapassados por um único zumbi em salto longo. |
| Sorteios | 16.000 decisões em 32 sequências distintas. Com 40 membros e todos os tipos elegíveis, as oportunidades favoráveis caíram de 72,3% no início para 47,2% na etapa 14. São proporções da amostra, sujeitas a elegibilidade, recuperação, repetições e intervalos. |
| Percursos gerados | 800 eventos em oito sementes, com todos os tipos solicitados, três tamanhos de buraco, 27 helicópteros baixos e 23 altos. Elevações ocuparam 5,83% do comprimento analisado. |
| Moedas | 11.275 verificações de posições livres de terreno e obstáculos, sem falhas. |
| Corridas completas até o sexto túnel | Seis corridas na simulação real, controladas por um bot que apenas aciona o toque, sem invencibilidade, reposicionamento ou zumbis injetados. No túnel 5 as hordas tiveram 48, 53, 78, 65, 81 e 68 membros. Todas chegaram ao sexto túnel. |
| Arte e câmera | Capturas pelo renderizador do Godot: seis veículos com passageiros, horda de 60, pulo longo e pausa. Horda grande em solo manteve o zoom e a posição vertical normais. |
| Distribuição Android | Recursos compilados para a mesma versão do Godot do APK, assinatura e integridade conferidas, bibliotecas ARMv7/ARM64 preservadas. |

As quantidades do bot são resultados dessa política de controle e dessas sementes, sem promessa de uma população específica para jogadores. As chances permitem outras combinações de população e perdas. A validação foi feita no Godot; não houve teste de instalação em um celular Android físico nesta sessão.

## Instalação e fontes

APK completo com o pacote `com.kauan.noitedahorda.local` e a mesma assinatura da edição Local 0.8.5. Instale por cima, sem desinstalar, para manter o progresso.

O backup de fontes é um Git bundle com as alterações até esta versão. Seu pré-requisito público é o commit `fca6490f1641cd5da018e8d4ee878a5ce00c6492` do repositório `kauanbraga125-sketch/horda-zumbi`; a chave privada de assinatura fica separada das fontes.
