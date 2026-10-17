# Arte e áudio

## Mercado 0.8.2

`market-art-v82.png`: atlas RGBA criado com o gerador integrado a partir do
mercado aprovado, com letreiro MERCADO, tênis, ímã, poção e igreja. Arquivo
original com alfa real preservado sem edição de pixels. Regiões e proveniência
em `market-art-v82-source.json`; recortes AtlasTexture no motor. Retratos do
zumbi e molduras existentes foram reutilizados. A interface escreve os textos,
preços e níveis e mantém as compras e animações independentes.

## Menu 0.8.1

`assets/art/menu-background-v81.png`: cenário original criado com a geração de
imagens integrada a partir da nova referência aprovada. PNG opaco preservado
sem edição de pixels; enquadramento proporcional em tempo de execução, sem
esticar a lua. Metadados em `menu-background-v81-source.json`. Lanternas têm
brilho animado nativo. Logo, painéis, ícones, personagens, ritual e textos
continuam recursos separados. Os atlas e o shader de animação do zumbi 0.8.0
foram preservados.

## Menu 0.7.9

`assets/art/zombie-menu-v79.png`: atlas RGBA de 4096 × 3072 pixels, 48 quadros completos aprovados pelo usuário. Arte gerada com imagegen e referências do próprio jogo. A preparação por `tools/normalize_menu_sprites.cjs` remove oscilações de escala, mantém o apoio dos pés e ajusta separadamente pele, cabelo, camisa e bermuda à paleta do primeiro quadro. Nenhum membro é separado ou articulado no novo personagem do menu. Metadados, referência da paleta e ajustes por quadro estão em `zombie-menu-v79.json`.

Os novos painéis, placa do título e acabamentos são desenhados pelo próprio Godot. O baú, os monstros, o caldeirão e as almas reutilizam os recursos existentes. A corrida e os estados de jogo usam os quadros completos recuperados da versão 0.7.8, com metadados `zombie-fluid-v73.json` e `zombie-run-drawn-v78.json`.

## Histórico da arte anterior

Arte bitmap criada para o projeto com o gerador de imagens integrado (modo built-in imagegen). Fontes e pixels preservados nos arquivos; recortes são regiões de AtlasTexture em tempo de execução.

## Arte nova

- `assets/art/rig-zombie.png`, `rig-skeleton.png`, `rig-masked.png` e `rig-fly.png`: quatro imagens RGBA de 1254 × 1254, com nove peças isoladas cada: cabeça, torso, braço, antebraço, mão, coxa, canela, pé e acessório.
- `assets/art/parallax-v2.png`: RGBA 1536 × 1024, três faixas independentes de cenário.
- `assets/art/rig-layout.json`: limites de transparência medidos por `tools/prepare_rigs.py`; não houve edição de imagem por Python.
- Prompts completos e modo de geração em `art-prompts-v2.json`. As imagens originais de criaturas e cenário foram usadas como referências de identidade e estilo para gerar arte nova.
- O motor articula as peças e cria as animações, poeira, brilhos, rastros e fragmentos. Os efeitos são desenho nativo do jogo.

## Recursos da alpha 0.1

`creatures.png` (folha antiga de poses), `items.png` (doze ícones/objetos) e `background.png` (cenário do menu e referência do céu). Prompts em `art-prompts.json`. A corrida agora usa os rigs novos.

Direção: cartoon de terror leve, contorno ameixa, volume suave, olhos grandes, menta, violeta, coral e dourado. Não foram extraídos sprites, música, código ou cenários dos jogos usados como referências de mecânicas.

Músicas `moon_menu.ogg` e `midnight_run.ogg`: composições originais em dó menor, sinos/sintetizador, baixo e percussão por `compose_audio.py`. Os onze efeitos foram sintetizados pelo mesmo programa. O vídeo de demonstração é uma captura do motor com entradas simuladas e a faixa `midnight_run` adicionada.

Fontes: Bungee Regular, David Jonathan Ross, Google Fonts, SIL Open Font License 1.1 em `assets/fonts/Bungee-OFL.txt`, https://github.com/google/fonts/tree/main/ofl/bungee. DejaVu Sans, Bitstream Vera/DejaVu em `assets/fonts/DejaVu-LICENSE.txt`, https://dejavu-fonts.github.io/.

Motor Godot e colaboradores: MIT, https://godotengine.org/license/.

## Alpha 0.3: mundos, NPCs, veículos e ameaças

Gerador integrado, modo **built-in imagegen**. Prompts completos em [art-prompts-v3.json](art-prompts-v3.json).

- `parallax-city.png`, `parallax-industrial.png`, `parallax-airport.png`: 1536 × 1024 RGBA, três faixas cada.
- `rig-civilian.png`, `rig-soldier.png`: 1254 × 1254 RGBA, nove peças cada. Animação pelo motor; soldado tem pose de mira e rifle genérico separado.
- `vehicles-v3.png`: 1536 × 1024 RGBA, moto, ônibus, tanque, avião, caminhão e helicóptero. Carro preservado de `items.png`.
- `props-v3.png`: 1536 × 1024 RGBA, bomba, caixão aberto, tampa, arco de túnel, brasão de game over e explosão.
- `world-layout.json`: regiões medidas por `prepare_worlds.py`, inclusive limites por linha para objetos de larguras diferentes. As imagens geradas foram copiadas sem alteração; nenhuma edição de raster por Python. Recortes feitos em AtlasTexture durante execução.

Direção visual preserva o cartoon de terror leve das alphas anteriores. Chamas, rotores, projéteis, fumaça, luzes, poeira e articulações são efeitos/animações nativos.

## Fontes de áudio novas

Amostras **CC0** obtidas diretamente dos autores no OpenGameArt e adaptadas por `tools/compose_threat_audio.py`. Metadados e arquivos de origem em `assets/audio/SOURCES-v3.json`.

| Fonte | Autor/crédito | Uso | Link |
|---|---|---|---|
| Zombies Sound Pack | artisticdude | Groans e morte do zumbi (`zombie-1`, `zombie-5`, `zombie-13`) | https://opengameart.org/content/zombies-sound-pack |
| Bones rattle | congusbongus, fonte blukotek | Voz/fragmentos do esqueleto (`0`, `2`, `4`, `6`) | https://opengameart.org/content/bones-rattle |
| High pitch scream sounds(2) | pauliuw | Grito distante da cidade | https://opengameart.org/content/high-pitch-scream-sounds2 |
| Ghost breath | qubodup | Dissolução do mascarado | https://opengameart.org/content/ghost-breath |

Na alpha 0.3, `voice_masked` era uma frase sintética original “ki ki ma ma”, produzida pelo filtro flite/voz kal do FFmpeg e transformada em sussurro com ruído/eco. Não é gravação retirada de filme. O som de ossos é uma amostra livre de chocalho, não áudio do Minecraft.

`voice_fly`, `death_fly`, `gunshot`, `explosion`, `tunnel` e `city_ambience`: síntese original de ruído, osciladores e envelopes. Áudio normalizado com pico máximo 0,70 e fades; Ogg Vorbis. Vozes têm intervalo e mixagem limitada para não tocar 24 monstros simultaneamente. Ambiência da cidade para no menu/pausa.


## Alpha 0.4: túnel percorrível, civis, veículos, almas e ritual

Gerador integrado em modo **built-in imagegen**. Prompts e referências completos em [art-prompts-v4.json](art-prompts-v4.json). PNGs originais preservados; recorte por AtlasTexture no motor. `tools/prepare_atlas_v4.py` mede limites alpha sem editar raster e salva `assets/art/atlas-v4.json`.

| Arquivo em assets/art/ | Uso |
|---|---|
| tunnel-interior-v4.png | Interior lateral contínuo do túnel, 1536 × 1024, opaco |
| tunnel-mouths-v4.png | Entrada e saída na encosta, 2172 × 724, RGBA |
| rig-civilian-woman-v4.png | Civil de cardigan coral, nove peças, 1254 × 1254 |
| rig-civilian-worker-v4.png | Civil operário com capacete, nove peças, 1254 × 1254 |
| vehicles-v4.png | Moto, carro, ônibus, caminhão, tanque e avião, 1536 × 1024 |
| ritual-v4.png | Alma, altar, baú de moedas e bomba aérea, 1536 × 1024 |
| vfx-v4.png | Três chamas de pavio e três quadros de captura, 1536 × 1024 |

Os veículos novos apontam à esquerda; a moto é espelhada em tempo de execução. O helicóptero continua usando a folha v3. Rigs v2 dos monstros recebem animações novas de captura/empurrar e corrida mais expressiva. Passageiros acenam com a parte superior dos rigs humanos. Rodas, chamas, rotores, poeira, almas em voo e barra do ritual são animados no motor.

### Áudio da alpha 0.4

**Ki Ki Ki Ma Ma Ma — alexander / Orange Free Sounds**, publicado em 11/01/2019. A página disponibiliza a amostra sob **Creative Commons Attribution 4.0**, inclusive para uso comercial. Usada como `voice_masked_v4.ogg`, substituindo o cue sintético anterior. Conversão para mono, normalização e fades; nenhuma alegação de gravação original do projeto.

- Página: https://orangefreesounds.com/ki-ki-ki-ma-ma-ma/
- Fonte: https://www.orangefreesounds.com/wp-content/uploads/2019/01/Ki-ki-ki-ma-ma-ma.mp3
- Licença: https://creativecommons.org/licenses/by/4.0/
- Crédito apresentado também no menu **Como jogar → Créditos**.

`soul_capture.ogg`, `level_up.ogg` e `ritual_fill.ogg`: composições originais com osciladores e envelopes. Processamento por `tools/compose_progress_audio.py`; hashes, origem, atribuição e modificações em `assets/audio/SOURCES-v4.json`. As fontes CC0 da versão anterior permanecem creditadas acima; a amostra nova do mascarado usa CC BY 4.0.

## Alpha 0.5: animações, metamorfose, policiais e destroços

Seis imagens geradas com **built-in imagegen**, mantendo a identidade cartoon. Prompts completos, referências e nomes originais em [art-prompts-v5.json](art-prompts-v5.json). Os PNGs foram copiados sem alterar pixels. `tools/prepare_atlas_v5.py` mede os limites das peças e escreve `assets/art/atlas-v5.json`; almas, poderes e fogo usam células fixas para evitar saltos de pivô.

| Arquivo em assets/art/ | Uso | Formato |
|---|---|---|
| rig-police-v5.png | Nove partes do policial, incluindo placa STOP | 1254 × 1254 RGBA, 3 × 3 |
| soul-frames-v5.png | Seis quadros de alma/chama | 1536 × 1024 RGBA, 3 × 2 |
| power-pickups-v5.png | Três estados do casulo e três da máscara | 1536 × 1024 RGBA, 3 × 2 |
| vehicles-damaged-v5.png | Moto, carro, ônibus, caminhão, tanque e avião amassados | 1536 × 1024 RGBA, 3 × 2 |
| vehicles-wrecks-v5.png | Mesmos seis veículos capotados | 1536 × 1024 RGBA, 3 × 2 |
| fire-frames-v5.png | Dois ciclos de três quadros de fogo/fumaça | 1536 × 1024 RGBA, 3 × 2 |

Corrida usa apoio do pé e retorno Hermite contínuo; pernas são articuladas com duas juntas. Empurrar, capturar, saltar, pousar e voar são poses combinadas com as peças. Transformação de 2,8 s usa mistura progressiva das criaturas, casulo/máscara, partículas e lettering; não é vídeo. Destroços completam uma rotação no motor e recebem emissores próprios de fogo. A placa STOP mantém a leitura ao inverter a direção do policial.

### Áudio novo e atribuição

Metadados, modificações e hashes dos arquivos de origem em `assets/audio/SOURCES-v5.json`. Notas de licença dos pacotes em `assets/audio/NPC-LICENSES-v5.txt`. Os pacotes de gritos têm licenças mistas: o jogo usa **somente as três amostras CC0 indicadas abaixo**. As demais gravações não foram incluídas.

| Uso | Autor e amostra | Licença / fonte |
|---|---|---|
| Seis colisões e esforço de metal | qubodup, Crash Collision, com novas camadas/tempos/timbres por veículo | CC0 — https://opengameart.org/content/crash-collision |
| Rotor de helicóptero | WuxiaScrub, Helicopter SFX; trecho de 3,8 s com crossfade e normalização | CC0 — https://opengameart.org/content/helicopter-sfx |
| Hélice de avião | Mish7913, Propeller (Cartoon) Loop | CC0 — https://opengameart.org/content/propeller-cartoon-loop |
| Gritos masculinos / operário | JohnsonBrandEditing, human male scream multi; `aargh3.ogg` / `aargh5.ogg`, adaptação por congusbongus | CC0 — https://opengameart.org/content/aargh-male-screams ; https://freesound.org/people/JohnsonBrandEditing/sounds/173944/ |
| Grito feminino | tcrocker68, Girl_Scream.wav; `female/2.ogg`, adaptação por congusbongus | CC0 — https://opengameart.org/content/female-screams ; https://www.freesound.org/people/tcrocker68/sounds/235592/ |

Comandos “Stop! Stop! Police!” e “Contact! Move! Hold the line!” são síntese flite kal16/rms, filtrada como voz/rádio; não são amostras retiradas de um filme ou jogo. Vidro, motor, fogo, metamorfoses e resgate são sínteses originais com osciladores, ruído e envelopes. Processamento em `tools/compose_scene_audio_v5.py`, Ogg Vorbis mono normalizado. Sons de veículos variam timbre, duração, impactos e camadas. Sons contínuos param na pausa/menu e respeitam SOM: OFF. As fontes das versões anteriores permanecem creditadas acima, incluindo o sussurro CC BY 4.0 do Mascarado.


## Menu e ícone 0.5.1

O menu usa a imagem aprovada apenas como referência de organização; todos os textos, botões, contadores, personagens, asas, almas e ritual são renderizados de forma independente pelo motor. Nenhuma imagem do menu completo é carregada.

- Luckiest Guy: Astigmatic / Brian J. Bonislawsky, Apache 2.0. Origem: https://github.com/google/fonts/tree/main/apache/luckiestguy; licença em assets/fonts/Luckiest-LICENSE.txt.
- Lilita One: Juan Montoreano, SIL OFL 1.1. Origem: https://github.com/google/fonts/tree/main/ofl/lilitaone; licença em assets/fonts/Lilita-OFL.txt.
- assets/icon-monsters-v51.png: ícone gerado com imagegen usando os sprites originais como referência de identidade; zumbi manchado, esqueleto com olhos azuis, mosca de olhos compostos magenta e máscara de hóquei. Aprovado pelo usuário.


## Atualização 0.6 — áudios fornecidos e integração

Kauan forneceu os dezesseis efeitos do pacote de 14/10/2026 e os MP3 Mischief Under Moonlight, Clockwork Ghoul’s Dash e Midnight Sprint. As gravações foram tratadas com filtros, compressão suave, normalização de energia/loudness, proteção de picos, fades e emendas de loop. O runtime faz a mixagem, atenuação musical durante vozes/impactos e crossfades. O borbulhar de fundo do ritual é síntese original. SOURCES-v6.json registra nomes originais, hashes e processamento; a autoria das gravações fornecidas não é reivindicada pelo projeto.

O sussurro existente do Mascarado e os créditos das amostras anteriores foram preservados. Artes existentes continuam intactas; mipmaps e o shader do primeiro plano ajustam sua apresentação sem alterar os pixels dos arquivos PNG.

## Atualização 0.7

Artes originais feitas com a ferramenta integrada image_gen: assets/art/passengers-v7.png (12 poses) e assets/art/soul-jar-frame-v7.png (vidro vazio). O motor compõe o líquido em assets/art/soul-jar-states-v7.png (61 níveis). Os menus mantêm controles e textos independentes. Prompts em assets/art/prompts-v7.json. Os 60 sons fornecidos por Kauan, hashes e tratamento estão em assets/audio/v7/manifest.json; sete ambiências provisórias aguardam identificação.

## Menu 0.8.0

`menu-logo-v80.png`, `menu-panel-v80.png`, `menu-play-v80.png` e `menu-missions-v80.png` são peças independentes geradas pela ferramenta integrada de imagem a partir da referência de menu aprovada pelo usuário: logo de madeira NOITE DA HORDA, moldura de pedra violeta com cantos dourados, botão dourado vazio e pergaminho com selo de missão. O motor escreve os rótulos dos botões e os contadores; a tela completa não é uma imagem estática.

`menu-zombie-source.png` preserva a arte aprovada do personagem; os renderizadores em `tools/menu_face_renderer.cjs` e `tools/bake_menu_animation.cjs` produzem a base e os atlas faciais da prévia revisada. As poses, a paleta e as proporções foram mantidas. O runtime faz a respiração e o movimento contínuo do corpo por shader. `menu-zombie-animation.json` registra os 1.920 instantes do ciclo e os 607 recortes únicos.

## Correção de articulação 0.7.1

`assets/art/rig-zombie-v71.png` foi editado pela ferramenta de geração de imagens integrada a partir de `rig-zombie.png`, preservando a aparência do personagem. Só as regiões dos membros e da mão são usadas; cabeça, camisa, short e pés continuam vindo da arte original. O arquivo mantém transparência real. O prompt completo está em `assets/art/rig-zombie-v71-source.json`; as regiões alpha medidas estão em `assets/art/zombie-rig-v71.json`.

## Gameplay 0.8.3

- `assets/art/gameplay-ground-v83.png`: textura original gerada com ImageGen para o chão de pedra das referências aprovadas de gameplay. PNG original sem edição de pixels. O recorte AtlasTexture, a repetição e o alinhamento à superfície física são feitos no motor; proveniência e região em `gameplay-ground-v83-source.json`.
- O HUD e a pausa reutilizam as fontes, molduras, almas, retratos e artes existentes. Bandeira, pausa, confirmação e navegação usam desenho vetorial nativo; o ícone de Frenesi reutiliza a animação de corrida do zumbi.


## Versão 0.8.4
Nenhuma imagem ou folha de sprites nova. As três telas reutilizam os painéis, personagens e animações aprovados. As plataformas usam recortes do chão v0.8.3; moedas e veículos mantêm suas artes e recebem apenas geometria de programação.


## Atualização 0.8.9

- `assets/art/civil-azul-v089/`: seis folhas alinhadas e 66 quadros fornecidos pelo usuário em `Civil_Casaco_Azul_Pacote_Integracao(1).zip`. Pixels dos PNGs aprovados preservados; orientação, origem e tempos seguem o prompt do pacote. Referências, prévias e quadros individuais não são incluídos no APK.
- `assets/art/terrain-v089.png`: folha original gerada pela ferramenta integrada imagegen para pedra intacta, rachaduras, desmoronamento, margens de buracos e pontas de elevações, no estilo do chão v0.8.3. Recortes e animação são feitos pelo motor.
- `assets/audio/power-warning-v089.ogg`: sinal original sintetizado com senoides, ataque curto e decaimento, para os três segundos finais dos poderes.
