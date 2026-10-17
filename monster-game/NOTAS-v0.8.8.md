# Noite da Horda 0.8.8 — desafios, moedas e testes

APK completo sobre a v0.8.7, versão Android 26, pacote `com.kauan.noitedahorda.local`, com a assinatura Local anterior. Instale por cima da versão instalada para manter seu progresso.

## Ajustes de gameplay

- Formações e obstáculos são planejados fora da maior área que a câmera pode revelar, incluindo a abertura durante o salto. Removido o preenchimento de moedas perto do jogador. Bônus e civis de recuperação seguem a mesma margem.
- Orçamento de moedas físicas reduzido em 30% em relação à densidade de referência da v0.8.7. As formações permanecem inteiras: linhas, rampas, arcos, blocos 3×3, colunas 2×4 e desenho em ponta. Cada moeda tem uma trajetória de coleta possível; os blocos podem exigir escolhas ou mais de uma passada de salto. Quantidades variam com a pista e as zonas seguras. Recompensas por virar veículos continuam separadas.
- Moedas com largura mínima maior durante a rotação e corpo 10% mais largo, evitando o aspecto de lâmina.
- Visão do mundo aproximadamente 5% menor nos dois eixos, por zoom uniforme. Os menus e o HUD mantêm seu tamanho.
- Bombas compactas em grupos, usando as referências 1–2–3, 3–4–2 e 2–3–2–4–3, além de variações. Grupos terrestres, aéreos baixos/altos e mistos. Quantidade e espaçamento se adaptam à velocidade e ao salto disponível. Bombas superiores acompanham alguns grupos terrestres; outros alternam salto, passagem por baixo e novo salto. Não é preciso um poder para passar.
- Buracos encadeados com saltos de durações diferentes e aterrissagens mais próximas. Até quatro buracos nas combinações maiores. A largura e a quantidade aumentam com túnel e horda.
- Chão que cede, com rachaduras, aviso e sinal sonoro antes de abrir. Pular evita a queda; membros atrasados continuam sujeitos ao buraco.
- Hordas a partir de 36 liberam combinações mais cedo, inclusive no T3; acima de 50 a pressão aumenta. Diminuiu a proporção de trechos gratuitos para hordas grandes. Perdas recentes ainda dão recuperação e oportunidades de recrutar.
- Carros em conjunto com helicóptero baixo, além dos encontros móveis. Helicópteros em movimento aguardam o fim do desafio anterior antes de avançar sobre ele. Tempo de reação, pouso e início do próximo desafio são reservados.
- Tanques e aviões têm mais peso e proteção contra longas ausências quando a horda já consegue virá-los.
- Cada bomba explode uma única vez. Proteção após impacto comum reduzida para permitir que bombas independentes da sequência causem novas perdas. Proteção especial de transformação/ressurreição preservada.
- Zumbis pousam sobre o teto físico de veículos, correm por ele e caem ao sair pela traseira. A saída não os puxa de volta para a frente do carro.
- Resgate imediato e garantido ao virar veículos; os passageiros não ficam presos na arte nem fogem antes de aumentar a horda.

| Veículo virado | Passageiros adicionados |
|---|---:|
| Moto | 1 |
| Carro | 1–2 |
| Ônibus | 4 |
| Tanque | 2–3 |
| Caminhão | 3–4 |
| Avião | 6–7 |

A capacidade continua em 96 integrantes. Resgates quando ela já está cheia mantêm a conversão de excedentes em moedas.

## Túneis e progressão

O intervalo-base da v0.8.7 passou de **12.600 para 15.120 px (+20%)**, ainda abaixo dos 18.000 px antigos. Intervalos posteriores usam a velocidade prevista para cada túnel; aceleração temporária não muda esse planejamento. A dificuldade continua dependendo do número do túnel e do tamanho da horda.

Os incrementos existentes de velocidade por túnel foram multiplicados por **1,10**. A velocidade inicial foi mantida. Túneis futuros são agendados antes de gerar o relevo; entrada, interior, saída e aproximação ficam sobre pista plana.

## Desenvolvedor teste

Abra **Configurações → Desenvolvedor teste**. Toque na horda ou no túnel para alterar os valores; depois escolha o grupo de obstáculos. A corrida usa somente esse grupo em diferentes variações. Há bombas terrestres, aéreas, mistas, buracos, chão que cai, trânsito, helicópteros, tanques, veículos com helicóptero e resgate dos seis veículos.

O teste usa o salto básico, não concede progresso, não grava moedas ou missões e preserva uma corrida normal que estava pausada. Ao morrer, retorna à seleção. Pausa permite repetir ou escolher outro grupo.

## Verificações

- 1.536 trechos gerados com hordas 1/16/36/88 e fases 0/3/8/14, incluindo câmera de planejamento larga. Sem falhas nas verificações de geração fora da câmera e posição das moedas.
- 102 cenários completos no simulador real, a 30/60 FPS, com hordas de 1/36/88. Bombas terrestres/aéreas/mistas, buracos, colapso e carros com helicóptero: nenhuma perda ao executar os comandos previstos.
- 576 combinações de sequências com os quatro níveis de salto e seis receitas, em quatro fases. Todas aceitas pela verificação física. Um buraco deliberadamente impossível foi rejeitado.
- 120 verificações de passageiros/resgate dos seis veículos; chamar a virada duas vezes não duplica o resgate. Apoio no teto, corrida e descida da traseira verificados no simulador.
- Oito simulações de partidas normais com duas seeds, iniciadas em T3/36 e T8/88, sem invencibilidade. Sem reação, todas as hordas foram eliminadas; com um controlador que conhece os comandos planejados, todas sobreviveram 120 s e puderam crescer. Isso verifica existência de ameaça e de uma saída possível; não mede habilidade humana.
- Calibração de moedas contra as fontes da v0.8.7: em duas observações de 120 s com a mesma seed e horda de 36, a média das densidades por distância ficou cerca de 29% menor. A contagem bruta inclui formações futuras já planejadas e varia entre partidas.
- Interface renderizada em 16:9, tela larga e tablet 4:3. Teste não alterou carteira, missões ou arquivo de progresso e restaurou a corrida pausada.
- APK compilado com Godot 4.5.1, integridade ZIP, versão, pacote e assinatura verificados. Artes, áudio e bibliotecas nativas anteriores preservados por comparação byte a byte.

Não houve teste em um aparelho Android físico. Resposta ao toque, desempenho no celular e equilíbrio final continuam sendo ajustados pelas suas partidas.

## Fontes e reprodução

Parâmetros: `scripts/tuning.gd` e `director.gd`. Geração: `course.gd`, `terrain.gd` e `sequence_validator.gd`. Física, resgate e modo de teste: `runner.gd`. Interface/câmera: `game.gd` e `gameplay_ui.gd`. Verificações em `tools/*v88*.gd` e relatórios em `validation/v088-*.json`.

O arquivo `NoiteDaHorda-v0.8.8-fontes.bundle` preserva esta atualização e as anteriores desde o commit público `fca6490f1641cd5da018e8d4ee878a5ce00c6492` de `kauanbraga125-sketch/horda-zumbi`. Para restaurar, obtenha esse commit, execute `git fetch CAMINHO_DO_BUNDLE HEAD` e crie uma branch em `FETCH_HEAD`. A chave de assinatura permanece separada e não está no código nem no bundle.
