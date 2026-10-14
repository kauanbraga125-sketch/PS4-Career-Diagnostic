# Noite da Horda — Android alpha 0.4

Corrida 2D de monstros para Kauan, em Godot 4.5.1. Offline, em paisagem, com arte cartoon. Projeto separado de Porto Livre e dos arquivos FIFA/PS4.

## Fuga, civis e túneis

Cemitério e Cidade em Caos são gratuitos. A horda captura **civis vivos**: três modelos, corridas, saltos, pânico e grupos. Cada monstro tem uma animação de captura; a conversão ocorre após 0,62 s e rende uma alma. Qualquer membro pode capturar. Soldados disparam de longe e, quando capturados, tornam-se um dos quatro monstros aleatoriamente. Um capturador morto não termina a conversão nem ressuscita a horda.

O primeiro túnel começa em **600 m**. É um corredor de aproximadamente seis segundos, com entrada na encosta, interior lateral, canos, lanternas, água e saída para o próximo cenário. A região só muda na saída. Após sair, o intervalo até o seguinte é `600 m × max(1, velocidade / 275)`. Isso mantém tempo de percurso entre transições quando o jogo acelera. O número do túnel aumenta a dificuldade; o nível do jogador é uma progressão separada.

Zona Industrial custa 2.200 moedas; Aeroporto, 3.800. As compras entram na próxima corrida. Cada região tem três camadas de parallax. Na cidade, civis correm ao fundo, incêndios se movem, há gritos e helicópteros caindo; a indústria tem fumaça, e o aeroporto tem balizas animadas.

Bombas terrestres e aéreas têm pavios acesos, três quadros de chama e faíscas. Helicópteros maiores aparecem em duas alturas: pule sobre os baixos ou passe sob os altos. Soldados atiram projéteis que podem ser evitados com saltos. Grupos de ameaças aumentam a cada dois túneis, até cinco; veículos grandes mantêm aproximação livre. Cada ameaça consumível causa uma perda. Máscara e escudo não impedem quedas.

Velocidade, buracos e pressão crescem com o percurso e o túnel. Uma horda grande reduz a frequência de civis; três perdas recentes ou grupo pequeno ativam sete segundos de recuperação, com mais civis e grupos menores de obstáculos. Objetos existentes continuam no percurso sem teletransporte.

## Veículos e passageiros

Todos apontam para a horda, com proporções distintas: o avião tem 680 px de largura, o carro, 246. A contagem é de **membros diferentes que realmente encostaram**: 1/4, 2/4, 3/4. O veículo inclina aos poucos e só completa a virada após alcançar o requisito. Se o grupo empurrar por 1,35 s sem força suficiente, o veículo não vira e causa uma perda, uma única vez. Saltar permite evitar o contato.

| Veículo | Contatos necessários | Moedas | Civis libertados |
|---|---:|---:|---:|
| Moto | 2 | 2 | 1 |
| Carro | 4 | 3 | 1 |
| Ônibus | 8 | 8 | 4 |
| Caminhão | 10 | 10 | 4 |
| Tanque | 12 | 12 | 4 |
| Avião | 16 | 18 | 6 |

Passageiros acenam assustados pelas janelas. Depois da virada, saem como humanos animados e precisam ser capturados; não viram monstros instantaneamente. A horda comporta 24 membros; capturas além do limite continuam rendendo almas e duas moedas. Os veículos são obstáculos, não são dirigíveis.

## Almas, níveis, missões e economia

Recordes separados de almas e distância. No fim da partida, as almas preenchem uma tabela animada. O nível 1 precisa de 20 almas, o 2 de 36, o 3 de 60; a fórmula é `20 + 12n + 4n²`, com `n = nível − 1`. Excedentes passam para o nível seguinte. Cada tabela completa rende moedas aleatórias: 140–260, mais um acréscimo pelo nível.

Três missões simultâneas, visíveis na pausa, em seis conjuntos renováveis: civis/almas, moedas, distância, viradas, pulos, bônus, horda, voo, frenesi, soldados, túneis, grupos e passageiros. As metas aumentam a cada seis capítulos. Missões completas guardam pontos para o **Ritual da Madrugada**. Ao encerrar a partida e voltar ao menu, almas voam para o altar e enchem sua barra. Cada 100 pontos rende 250–500 moedas, mais um acréscimo pelo nível; o excedente permanece. Os prêmios não se repetem ao reabrir a tela.

Carteira inicial: 120 moedas. Só o zumbi começa comprado. Esqueleto: 1.000; Mascarado: 2.800; Mosca: 4.500. Bônus temporários da pista funcionam independentemente da skin comprada.

| Melhoria | Nível 1 | Nível 2 | Nível 3 |
|---|---:|---:|---:|
| Primeira Horda | 350 | 1.400 | 3.150 |
| Pulo Ágil | 420 | 1.680 | 3.780 |
| Ímã de Moedas | 360 | 1.440 | 3.240 |
| Metamorfose | 500 | 2.000 | 4.500 |

Preços são uma primeira calibração; novas compras exigem várias partidas. Compras anteriores permanecem válidas.

## Controles, animações e save

Toque na pista ou em PULAR; segure para saltar mais alto, especialmente nos buracos maiores. Pulo Ágil nível 2 libera salto duplo. A transformação Mosca sobe sozinha: segure para mergulhar, solte para subir. II pausa; SOM liga/desliga; espaço e Esc no computador. Android pausa ao ir para o fundo.

Corrida articulada, balanço de corpo e braços, poses de empurrar/capturar, poeira de passos/salto/pouso, brilhos, rastros e almas voando. Quedas são definitivas: todos caindo levam ao game over. Cada criatura tem uma perda curta própria: caixão, ossos desmontando, máscara em fumaça, asas em fragmentos. Limites: 240 partículas, oito rastros e 24 mortes transitórias.

Save local com escrita atômica e backup. Migração das alphas 0.1/0.2/0.3 preserva carteira, recorde de distância, melhorias, skins e cenários comprados. Almas capturadas são gravadas durante a partida e recuperadas se o aplicativo for fechado. Sem anúncios, pagamentos reais ou conexão obrigatória.

## Arte, som e Android

Oito rigs: quatro monstros, três civis e um soldado. Arte criada com **built-in imagegen**, com animação no motor. Sete novas folhas/imagens nesta versão; fontes e prompts em [ASSETS.md](ASSETS.md) e [art-prompts-v4.json](art-prompts-v4.json). `prepare_atlas_v4.py` mede transparência e cria metadados; não altera pixels.

Duas músicas originais, sons de monstros, passos, tiros, explosões, capturas, almas e ritual. O sussurro característico “Ki Ki Ki Ma Ma Ma” usa a amostra publicada por alexander / Orange Free Sounds sob CC BY 4.0, convertida e normalizada. Créditos no jogo e em ASSETS.md. Os sons do esqueleto são amostras livres de ossos; não são áudio do Minecraft.

Android 7+, OpenGL ES 3.0, ARMv7/ARM64; Compatibility. Meta de 60 FPS; desempenho em telefone físico ainda não foi medido. Pacote `com.kauan.noitedahorda`, versionCode 4, APK de desenvolvimento com a mesma chave mantida no workflow das alphas anteriores.

## Verificação e reprodução

```sh
godot --headless --path monster-game --editor --import
godot --headless --path monster-game -- --self-test
```

228 verificações de contatos individuais/viradas parciais, passageiros, capturas de todos os monstros, conversão de soldados, túneis a 600 m, alturas/grupos de ameaças, almas/níveis, ritual sem pagamento duplicado, preços, migração de save, buracos, voo e simulação longa.

O workflow `.github/workflows/noite-da-horda-android.yml` roda os testes, gera 22 capturas reais do motor e vídeo de 720 quadros (24 s), exporta o APK, verifica assinatura e SHA-256 e publica a release. As prévias usam cenários preparados, entradas simuladas e a música original; não são benchmark nem uma partida contínua completa. `--capture` e `--motion-preview` não usam nem alteram o save pessoal.

Os OGG prontos são incluídos. Para recriar os novos sons, coloque o MP3 creditado em `horde-audio-sources/jason-ki.mp3` e execute `tools/compose_progress_audio.py`; metadados e hashes em `assets/audio/SOURCES-v4.json`.
