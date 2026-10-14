# Arte e áudio — alpha 0.2

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
