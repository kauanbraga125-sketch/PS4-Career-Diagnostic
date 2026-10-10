# Recursos de terceiros — Porto Livre 0.2

Os recursos abaixo são redistribuídos sob CC0 1.0, exceto Car Concept, sob CC BY 4.0. As fontes, tamanhos e SHA-256 de cada download ficam no `assets/realism/sources.json` gerado durante o build. Não há recursos extraídos de GTA, Bully ou outros jogos comerciais.

| Recurso | Autor / projeto | Fonte e licença |
|---|---|---|
| Anatomia, pele, roupas, cabelo, olhos e sobrancelhas | MakeHuman Community; autores identificados nos arquivos `.mhmat` do pacote | [MakeHuman System Assets CC0](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html) |
| Car Concept | Eric Chadwick / Darmstadt Graphics Group GmbH, © 2024; base original Unity Fan | [Khronos glTF Sample Assets, CC BY 4.0](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/edc7c9e67c639d230715049ee31f9a96a6babbbe/Models/CarConcept) |
| Fancy motorcycle | Teh_Bucket | [OpenGameArt, CC0](https://opengameart.org/content/fancy-motorcycle) |
| Árvore texturizada | musdasch, Yughues e para | [OpenGameArt, CC0](https://opengameart.org/content/tree-24) |
| Asfalto, concreto, calçamento, grama, metal corrugado e madeira | Artistas da Poly Haven; asset IDs no script de preparação | [Poly Haven, CC0](https://polyhaven.com/license) |
| Wednesday Night — funk fusion | Zane Little Music | [OpenGameArt, CC0](https://opengameart.org/content/wednesday-night-funk-fusion) |
| 100 CC0 SFX #2 — passos, impactos, portas, ambiente | rubberduck | [OpenGameArt, CC0](https://opengameart.org/content/100-cc0-sfx-2) |
| Racing car engine sound loops | domasx2 | [OpenGameArt, CC0](https://opengameart.org/content/racing-car-engine-sound-loops) |

[Texto da CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode).

Blender 4.3.2 e MPFB (commit `d0a32e57a7f915cb2f2b95410e2117648c7bbb7e`) são ferramentas de criação/conversão sob GPL, executadas no build e não incluídas no APK. O uso dessas ferramentas não altera a licença dos recursos CC0 exportados. As animações de movimento foram criadas no script `tools/assets/build_models.py`; não são captura de movimento nem animações de GTA.

O disparo e os sinais de coleta/missão permanecem sintetizados pelo código do jogo. As armas e a arquitetura são criadas pelo projeto. Godot: [MIT, copyright dos colaboradores](https://godotengine.org/license/); o APK também inclui as licenças dos componentes da engine.

Car Concept foi adaptado para câmera externa: simplificação das malhas, remoção de interiores ocultos e placas/emblemas, escala de 4,3 m, textura limitada a 1K, vidro opaco e agrupamento das rodas. Licença: https://creativecommons.org/licenses/by/4.0/ . A licença original é preservada em `assets/realism/licenses/CarConcept-LICENSE.md`. Créditos também disponíveis no menu do jogo.
