# Noite da Horda — v0.8.9

Atualização sobre a v0.8.8. Android versionCode 27, pacote `com.kauan.noitedahorda.local` e mesma assinatura da edição Local. Instalar por cima da versão atual, sem desinstalar, para manter o progresso.

## Trânsito e superfícies

- Trânsito hostil usa carros de obstáculo, sem passageiros nem conversão. Há sequências de 2–4 carros e variações com helicópteros baixos e altos para alternar pular e correr por baixo.
- O teste “Veículos + helicóptero” usa esses carros hostis. “Infecção nos veículos” continua testando os veículos viráveis e seus passageiros.
- Helicópteros têm teto para pisar e parte inferior sólida. Bater a cabeça por baixo interrompe a subida sem causar dano; a frente causa dano.
- Tetos do ônibus e do avião foram alinhados à parte superior visível. O avião usa o topo da fuselagem como apoio, em vez do meio do sprite ou da altura da cauda.
- Soldados sinalizam a mira, alternam tiros baixos e altos e aumentam a cadência conforme a velocidade. Soldados, tanques e aviões têm controle de intervalo para reduzir períodos longos sem aparecer.

## Desafios e progressão

- Bombas 10% maiores, incluindo a colisão. Sequências terrestres, aéreas e mistas continuam usando as mesmas geometrias de grupos.
- Novas combinações: bomba → chão que cai → bomba; chão que cai antes de veículo virável; buraco → bombas → chão que cai; variações repetidas de desmoronamento.
- Buracos maiores exigem segurar o pulo. Hordas grandes encontram cadeias com pequenas ilhas de aterrissagem entre buracos longos; larguras acompanham velocidade e capacidade do salto.
- Intervalos normais entre encontros reduzidos suavemente, em cerca de 8%. Hordas com pelo menos 36 integrantes podem receber uma aceleração sinalizada de 6%, com transição suave e verificação de espaço livre.
- Oportunidades positivas reduzidas em 15%, com orçamento de encontros para controlar o excesso de almas. Limites cumulativos de oferta: 16, 25, 39, 49, 57 e 65 almas dos túneis 0 a 5; depois +12 por túnel. O orçamento considera NPCs e passageiros já reservados. Almas conquistadas continuam sendo entregues integralmente; veículos viráveis não aparecem vazios para contornar o limite.
- Quando o orçamento de almas se esgota, a geração continua com desafios em vez de tentar criar grupos de civis que não poderiam aparecer.
- A distância entre túneis mantém o acréscimo de 20% da v0.8.8; velocidade e dificuldade seguem o túnel e a horda. As áreas de aproximação dos túneis continuam sem subidas.
- Passageiros por veículo mantidos: moto 1; carro 1–2; ônibus 4; caminhão 3–4; tanque 2–3; avião 6–7. Conversão contabilizada uma vez por passageiro.

## Civil e apresentação

- O pacote aprovado substitui somente o civil de casaco azul, mochila laranja, antes ligado a `rig-civilian.png` e à variante 0. Chave explícita: `civil_casaco_azul_nerd`.
- Integração das seis folhas e dos 66 quadros originais, sem alterar os PNGs. Origem fixa (320, 560), escala comum ao zumbi e tempos individuais de animação.
- Parado e começo do susto olham à esquerda; o sétimo quadro do susto inicia a virada para fugir à direita; a captura vira para a esquerda. O espelhamento afeta somente a imagem.
- Captura lógica permanece em 0,62 s. A atuação preserva a ordem e as proporções dos tempos dos quadros, com espera final de 80 ms; o trecho intermediário é usado nas fases compatíveis da corrida. Recompensa, capturador e conversão continuam únicos.
- Mulher, trabalhador, policial, soldado e enquadramento dos passageiros nas janelas permanecem em seus caminhos próprios.
- Frases dos NPCs aparecem em uma caixa no alto da tela, com retrato e texto real. Balões ao lado dos personagens removidos. “Civis libertados” passa a “Almas convertidas”.
- Chão que cai usa pedra rachada, variações de largura, aviso visível e pedaços que descem girando. Bordas de buracos e de trechos elevados recebem novas peças de pedra e raízes.
- Moedas 20% maiores, com espessura mínima da rotação 20% maior. Espaçamento e margens foram ajustados. Mantido o orçamento 30% menor da v0.8.8 e a criação de formações completas fora da câmera.

## Horda, poderes e desempenho

- Atraso inicial de 3,2 ms adicionais por integrante na onda de pulo, limitado a 120 ms. Pode ser comparado com 0, 2 e 4,5 ms no modo de desenvolvedor; esse é um valor inicial para os próximos testes de jogabilidade.
- Com mais de 36 integrantes, desenhos encobertos são descartados, preservando silhuetas e ações visíveis. Todos os integrantes continuam físicos e continuam contando na horda. Na cena estática de 88 integrantes, o teste manteve 22 desenhos.
- Superfícies e buracos próximos são separados uma vez por passo de física; a contagem ativa é reutilizada; removida a revalidação completa das moedas a cada quadro. As novas folhas usam ETC2 e mipmaps no Android, sem reduzir a resolução dos PNGs aprovados.
- Super Fly e Mascarado começam com 11 s; Frenesi começa com 8 s: três segundos a mais. Melhorias de duração continuam somando seus valores.
- Aviso sonoro nos três segundos finais, em três pulsos. Removida a contagem numérica de término do bônus.
- Nova melhoria comprável “Frenesi Implacável”, por 900 moedas. Após comprada, o Frenesi protege de buracos, bombas e impactos e impede que a horda fique presa em veículos ou degraus durante o efeito. O Frenesi básico mantém seu efeito de velocidade.

## Desenvolvedor teste

Acesso: **Configurações → Desenvolvedor teste**. Quinze opções: bombas terrestres, aéreas e mistas; buracos; chão que cai; trânsito hostil; helicópteros; tanques; veículos + helicóptero; infecção nos veículos; desafios combinados; colisões e superfícies; sprites dos monstros; sprites dos NPCs; poderes e proteção.

Controle de horda, túnel e atraso de pulo; guias de colisão durante a corrida; inspeção de personagem e animação com pausa. No teste de poderes, botões para reaplicar Frenesi, Super Fly e Mascarado e alternar a melhoria de proteção. Os testes não alteram moedas, missões ou progresso e preservam a corrida pausada anterior.

## Verificação desta entrega

- Verificações focadas de tetos e contato inferior do helicóptero a 30/60 passos por segundo; frente danosa; captura do civil em fases diferentes; conversão única; poderes, avisos sonoros, orçamento de almas e trânsito sem passageiros.
- 108 combinações de planejamento: nove famílias, quatro variações e hordas de 16, 36 e 88. Todas passaram na versão final.
- Corridas com comandos simulados em 30/60 passos por segundo; combinações de carros/helicópteros também testadas com horda de 88. A física normal do jogo continua a 60 passos por segundo.
- Duas simulações de carga de 90 s mantendo 36 e 88 integrantes, com 431 verificações de criação fora da câmera: nenhuma criação visível, sequência recusada ou encontro sem colocação. Não são medições em um celular Android.
- Dezesseis capturas no renderizador real: civil, diálogos, desmoronamento, moedas, tetos, terreno elevado, mercado e telas de desenvolvedor. Compra da nova melhoria, leitura do save e isolamento dos testes verificados.
- APK conferido por integridade, versão, recursos e assinatura. Teste físico no aparelho e ajuste fino do balanceamento continuam dependendo das próximas partidas.

APK SHA-256: `9b887f02bce94d44a8fe0018b1357ec8e5d14ce4b8490e1de99795da666781b6`.
