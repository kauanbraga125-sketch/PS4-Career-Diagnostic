# Noite da Horda 0.8.5 — variedade da fase

Corrige o problema em que a pista ficava dominada por elevações e civis, enquanto veículos e outros obstáculos quase não apareciam.

## O que mudou

- **Elevações mais espaçadas:** longos trechos planos entre plataformas. O intervalo usa o deslocamento de aproximadamente 22–30 segundos, com ajustes para velocidade, segurança e túneis. As plataformas duram aproximadamente 3–4 segundos de deslocamento e sempre retornam ao nível original. A altura continua em 80 pixels.
- **Variedade distribuída por sequência:** abertura gradual, seguida por um conjunto embaralhado de motos, carros, ônibus, caminhões, bombas, helicópteros, bombas aéreas, buracos, policiais, soldados e carros em sentido contrário. Tanques e aviões entram depois do primeiro túnel. A sequência evita repetições consecutivas quando há alternativas.
- **Espaço reservado para o desafio:** quando um obstáculo não cabe perto de uma plataforma ou túnel, ele é deslocado para o próximo trecho plano adequado. A prioridade permanente de buracos foi removida; ela impedia os outros padrões de entrar.
- **Veículos continuam aparecendo mesmo sem passageiros disponíveis:** o limite de almas da etapa não transforma mais todo veículo em outro objeto. Resgates continuam respeitando os limites existentes; a mensagem de recompensa informa a quantidade real de passageiros.
- **Carros em sentido contrário restaurados:** há eventos reservados para eles. Um carro reservado longe da tela começa a se aproximar na distância de aviso, evitando atravessar outros trechos antes de o jogador chegar. O salto dos seguidores considera a velocidade de aproximação do carro, para a parte de trás de uma horda grande não ser atingida apesar de um salto correto.
- **Bombas preservadas também na velocidade inicial:** o tamanho visual foi ajustado para caber numa trajetória segura, em vez de o gerador descartar todas por uma área de exclusão excessiva.
- Moedas continuam sendo validadas contra terreno e obstáculos. Plataformas podem receber fileiras de moedas e funcionam como pequenas pausas entre desafios.

Menu, mercado, coleção, missões, tutorial, recursos de áudio e artes existentes foram preservados. Os métodos de atualização da câmera e de enquadramento permanecem idênticos aos da 0.8.4. Não foram gerados novos sprites nesta atualização.

## O que foi testado

| Verificação | Resultado |
|---|---|
| Reprodução da 0.8.4 | A varredura reproduziu os desafios sendo descartados enquanto as plataformas continuavam presentes. |
| Distribuição nova | 720 eventos em 9 seeds; todos receberam um desafio. Todos os tipos de veículo, bombas, helicópteros e carros em sentido contrário apareceram em cada seed. |
| Veículos estacionados | 31–34 a cada 80 eventos na varredura; carros em sentido contrário contados separadamente. |
| Fase realmente avançando | 3 simulações de 3 minutos, com renderização no Godot e registro de objetos que efetivamente entraram na tela. Todos os tipos solicitados apareceram nas três execuções. |
| Terreno elevado nessas execuções | Aproximadamente 9–11% do tempo de percurso; 6–7 plataformas em 3 minutos. |
| Física e geometria | 840 trechos, 8.874 checagens de moedas e 121 plataformas; sem falhas nos cenários testados. Pulos e aterrissagens a 30/60/120 FPS, com hordas de 1/5/20 e velocidades de 305/500/780 px/s. |
| Carros em sentido contrário | 27 combinações de FPS, velocidade e tamanho de horda, além de início da aproximação e aviso; sem perdas nos saltos testados. |
| Câmera | Comparação do código confirmou os métodos de câmera e enquadramento inalterados. |
| APK | Compilação dos recursos e verificação da assinatura, integridade e preservação das bibliotecas ARMv7/ARM64. |

As simulações de distribuição usam um observador que mantém a horda viva para medir a fase inteira; não são uma partida jogada por uma pessoa. A física de saltos e colisões foi verificada separadamente sem esse auxílio. Não houve teste em celular Android físico nesta sessão.

## Instalação

APK completo, versão 0.8.5, código de versão 23, com a mesma identidade e assinatura da versão local anterior. Instale por cima da 0.8.4, sem desinstalar, para preservar o progresso.
