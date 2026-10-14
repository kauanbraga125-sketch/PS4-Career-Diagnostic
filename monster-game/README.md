# Noite da Horda — Android alpha 0.3

Corrida 2D de monstros para Kauan. Godot 4.5.1; funciona offline, em paisagem. Projeto separado de Porto Livre e dos arquivos FIFA/PS4.

## Esta versão

- Cemitério e Cidade em Caos liberados desde o início. Cada região mede 6.000 pixels de percurso (200 m do contador); um túnel com arco pintado, paredes e lanternas conduz à seguinte. A rota se repete continuamente.
- Zona Industrial: 700 moedas; Aeroporto: 1.200. As compras entram na próxima corrida, após as regiões iniciais. Cada cenário tem três camadas pintadas de parallax. Cidade com seis civis articulados fugindo, fogo, gritos e helicópteros caindo ao fundo; indústria com fumaça e aeroporto com luzes pulsantes.
- Quedas definitivas. Um membro abaixo do chão continua caindo mesmo se a borda passar ou houver um bônus/recruta perto. Perder todos leva à tela Fim da Horda. Um novo líder vem do grupo sobrevivente e fecha o espaço gradualmente. Não há respawn automático durante a corrida.
- Animações curtas de perda: zumbi retorna ao caixão, tampa fecha e se enterra; esqueleto desmonta em peças; mascarado perde a máscara em fumaça; mosca gira e solta fragmentos das asas.
- Mosca no estilo balão: sobe automaticamente a uma altura segura. Segure para mergulhar até o chão e coletar; solte para subir. Ao mergulhar, pode sofrer dano. Ao terminar o bônus, recupera sua forma anterior e os pulos normais.
- Bombas com pavio animado, helicópteros de ataque com rotor e soldados mirando/disparando projéteis. Saltos evitam tiros. Cada ameaça consumível causa uma perda; escudo absorve uma, máscara destrói obstáculos. Escudo e máscara não impedem queda em buracos.
- Velocidade e largura dos buracos crescem com o percurso. Uma horda grande aumenta a pressão e reduz recrutas; a partir do quinto túnel a pressão cresce mais. Três perdas recentes ou grupo pequeno ativam sete segundos de recuperação, suavizam velocidade/dificuldade e geram mais recrutas. Objetos já presentes continuam no percurso sem mudar de posição.

## Veículos

A quantidade conta criaturas vivas no chão. A máscara também consegue destruí-los. Todos tombam com animação, liberam criaturas e dão moedas; o indicador muda de cor conforme a força atual.

| Veículo | Criaturas | Moedas | Resgates |
|---|---:|---:|---:|
| Moto | 2 | 5 | 1 |
| Carro | 4 | 8 | 1 |
| Ônibus | 8 | 18 | 3 |
| Caminhão | 10 | 22 | 3 |
| Tanque | 12 | 28 | 4 |
| Avião | 16 | 40 | 5 |

A horda comporta 24 membros. Recrutamento além do limite rende duas moedas. São desafios da pista; veículos não são dirigíveis.

## Controles e progressão

Toque na pista ou em PULAR. Segure para saltar mais alto. Pulo Ágil nível 2 libera salto duplo. Durante o bônus Mosca, o botão vira MERGULHAR. II pausa, SOM liga/desliga; no computador, espaço e Esc. Android pausa automaticamente ao ir para o fundo.

Quatro melhorias permanentes, até três níveis: Primeira Horda (50 moedas × próximo nível), Pulo Ágil (65), Ímã de Moedas (70), Metamorfose (80). Carteira inicial: 120 moedas.

Só o visual de zumbi começa desbloqueado. Esqueleto 240, Mascarado 650 e Mosca 950 moedas. Os visuais compartilham a física normal; os bônus da pista dão poderes temporários mesmo sem comprar a skin.

Três missões por capítulo, doze modelos renováveis: recrutamento, moedas, distância, veículos, saltos, bônus, tamanho de horda, voo e frenesi. Quantidades crescem após os quatro primeiros capítulos. Recompensas pagas uma vez. Moedas e compras ficam após perder.

Save local com escrita atômica e backup. Migração das alphas 0.1/0.2 preserva carteira, recorde, melhorias, skins e recompensas; acrescenta os dois cenários grátis. Sem anúncios, pagamentos reais ou conexão obrigatória.

## Arte, som e Android

Quatro rigs de monstros e dois de NPCs, nove peças cada, com pernas alternadas, joelhos conectados, braços, corpo, cabeça, asas e compressão ao aterrissar. Poeira, ondas de transformação, brilhos, moedas girando/voando e rastros de velocidade. Limites: 240 partículas, oito rastros e 24 mortes transitórias.

Duas músicas originais e efeitos offline, incluindo vozes e mortes de cada monstro, sons de tiros, explosões e cidade. Amostras gratuitas CC0 e cue original do mascarado, com fontes em [ASSETS.md](ASSETS.md). Sem áudio extraído de Minecraft ou filmes.

Android 7+, OpenGL ES 3.0, ARMv7/ARM64; Compatibility. Meta de 60 FPS; ainda não há medição em telefone físico. Pacote `com.kauan.noitedahorda`, versionCode 3, APK de desenvolvimento com mesma chave mantida no workflow para permitir atualização.

## Verificação e reprodução

```sh
godot --headless --path monster-game --editor --import
godot --headless --path monster-game -- --self-test
```

Testes de queda/perda total, sobreviventes, máscara/escudo, retry, seis limiares de veículos, balão/mergulho, tiros e esquiva, dificuldade/recuperação real na geração, quatro rotas, compras, missões, save v1/v2/v3, animações, limites e simulação longa.

O workflow `.github/workflows/noite-da-horda-android.yml` valida testes, onze capturas do motor, vídeo de 480 quadros (16 s), exportação, assinatura e SHA-256 antes de publicar. O vídeo usa cenários preparados, entradas simuladas e a música original; não é benchmark de desempenho.

`prepare_rigs.py` e `prepare_worlds.py` medem regiões alpha sem editar os pixels das imagens. `compose_audio.py` sintetiza a trilha/efeitos originais. `compose_threat_audio.py` processa as amostras creditadas e gera os sons novos; para reprodução, prepare os fontes em `horde-audio-sources/` e o cue `masked-voice.wav` com o filtro flite do FFmpeg, conforme o próprio script. Os OGG prontos estão incluídos no projeto.
