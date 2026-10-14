# Arte e áudio — alpha 0.4

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
