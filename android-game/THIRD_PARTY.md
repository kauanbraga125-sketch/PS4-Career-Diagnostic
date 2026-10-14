# Recursos de terceiros — Porto Livre 0.2

Os recursos abaixo são redistribuídos sob CC0 1.0, exceto Car Concept, sob CC BY 4.0. As fontes, tamanhos e SHA-256 de cada download ficam no `assets/realism/sources.json` gerado durante o build. Não há recursos extraídos de GTA, Bully ou outros jogos comerciais.

| Recurso | Autor / projeto | Fonte e licença |
|---|---|---|
| Anatomia, pele, roupas, cabelo, olhos e sobrancelhas | MakeHuman Community; autores identificados nos arquivos `.mhmat` do pacote | [MakeHuman System Assets CC0](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html) |
| Car Concept | Eric Chadwick / Darmstadt Graphics Group GmbH, © 2024; base original Unity Fan | [Khronos glTF Sample Assets, CC BY 4.0](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/edc7c9e67c639d230715049ee31f9a96a6babbbe/Models/CarConcept) |
| 8 casas suburbanas distintas, glTF | Kenney; cópia de distribuição do catálogo Hidencod/tge-assets, revisão 08f0c913f6783cc81f9f6105a7cdda8562b1c192 | [Kenney City Kit Suburban, CC0](https://kenney.nl/assets/city-kit-suburban) · [arquivos-fonte](https://github.com/Hidencod/tge-assets) |
| Fancy motorcycle | Teh_Bucket | [OpenGameArt, CC0](https://opengameart.org/content/fancy-motorcycle) |
| Árvore texturizada | musdasch, Yughues e para | [OpenGameArt, CC0](https://opengameart.org/content/tree-24) |
| Asfalto, concreto, calçamento, grama, metal corrugado e madeira | Artistas da Poly Haven; asset IDs no script de preparação | [Poly Haven, CC0](https://polyhaven.com/license) |
| Wednesday Night — funk fusion | Zane Little Music | [OpenGameArt, CC0](https://opengameart.org/content/wednesday-night-funk-fusion) |
| 100 CC0 SFX #2 — passos, impactos, portas, ambiente | rubberduck | [OpenGameArt, CC0](https://opengameart.org/content/100-cc0-sfx-2) |
| Racing car engine sound loops | domasx2 | [OpenGameArt, CC0](https://opengameart.org/content/racing-car-engine-sound-loops) |

[Texto da CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode).

Blender 4.3.2 e MPFB (commit `d0a32e57a7f915cb2f2b95410e2117648c7bbb7e`) são ferramentas de criação/conversão sob GPL, executadas no build e não incluídas no APK. O uso dessas ferramentas não altera a licença dos recursos CC0 exportados. A pose de pilotagem é autoral; os clipes de movimento da 0.4 são adaptados da biblioteca KayKit CC0 em `tools/assets/retarget.py`. Não são alegados como captura de movimento nem animações de GTA.

O disparo e os sinais de coleta/missão permanecem sintetizados pelo código do jogo. Os modelos de armas, casas e prédios são importados das fontes CC0 identificadas nesta página; o projeto cria a distribuição, colisões e comportamento. Godot: [MIT, copyright dos colaboradores](https://godotengine.org/license/); o APK também inclui as licenças dos componentes da engine.

Car Concept foi adaptado para câmera externa: simplificação das malhas, remoção de interiores ocultos e placas/emblemas, escala de 4,3 m, textura limitada a 1K, vidro opaco e agrupamento das rodas. Licença: https://creativecommons.org/licenses/by/4.0/ . A licença original é preservada em `assets/realism/licenses/CarConcept-LICENSE.md`. Créditos também disponíveis no menu do jogo.


## Alpha 0.4 — additional CC0 assets

| Asset | Creator | Primary source | Adaptation |
| --- | --- | --- | --- |
| City Kit Commercial 2.1 | Kenney | https://kenney.nl/assets/city-kit-commercial | GLB exterior buildings, plot scaling, shared MultiMesh batches |
| Skyboxes | Kenney | https://kenney.nl/assets/skyboxes | 2K day, morning and night panoramas blended in a custom sky shader |
| Ultimate Gun Pack | Quaternius | https://opengameart.org/content/low-poly-guns-pack | Four Blender models converted to GLB, scaled, oriented and fitted to character grips |
| Cartoon Helicopter | z11z11 | https://opengameart.org/content/cartoon-helicopter-0 | Textured mirrored mesh converted to GLB; rotor separated, orientation and scale adjusted |
| Low Poly Biplane Airplane Model | mujtaba-io | https://opengameart.org/content/low-poly-biplane-airplane-model | Blender scene converted to GLB; mobile scale, paint materials and orientation adjusted |
| KayKit Character Animations 1.1 | Kay Lousberg | https://kaylousberg.itch.io/kaykit-character-animations | Full humanoid walk, run, idle, jump, fall, land and aiming clips retargeted to MakeHuman CMU skeletons; translation limited to body compression |

All additional rows above are CC0-1.0. KayKit source GLBs are retrieved from the public GeorgeQLe/assets-kaykit-3d-characters mirror at fixed revision `af08a62d3669370ec4636ae6314b38cdcd5dd759`; the original creator's page establishes the license. These clips are not described as motion capture.

The previous CarConcept CC BY 4.0 attribution continues to apply. Sources and downloaded SHA-256 values are bundled in `assets/realism/sources.json`. The runtime uses original game code for physics, ragdoll, cameras, sky rendering and parachute geometry. No Rockstar/Capcom game assets are included.
