# Porto Livre — Android alpha 0.2

Jogo original de exploração urbana em terceira pessoa, desenvolvido para Kauan. Projeto Godot **4.5.1**, separado dos arquivos do plugin FIFA/PS4 nesta mesma branch. Não usa mapas, personagens, marcas, sons ou assets de GTA ou Bully.

## Estado real desta entrega

Esta é uma **alpha jogável**, não um jogo comercial finalizado nem um equivalente visual a GTA. Há um ciclo completo de dez missões, exploração livre, carros e motos dirigíveis, armas, NPCs e salvamento. A versão 0.2 usa quatro personagens MakeHuman vestidos e animados por esqueleto, carro/moto importados, árvores com folhas texturizadas e materiais PBR fotográficos de 2K. A arquitetura ainda é gerada por blocos, agora com textura, frisos e detalhes de cobertura; ainda há repetição visual. As missões usam instruções de texto, sem dublagem/cutscenes. Não há interiores exploráveis, multiplayer, ragdolls, deformação de carro ou sistema avançado de tráfego. O comportamento de pedestres é simples e pode precisar de ajustes ao redor de construções.

O mapa mede **1.440 × 1.440 metros (2,0736 km² de área delimitada)**. Essa é a escala geométrica do projeto; não foi verificada uma equivalência exata com a área de Bully. Edifícios ocupam parte do terreno, com circulação pelas ruas, calçadas, praças e pátios. Não confundir área com quantidade de conteúdo.

## Sistemas implementados

- Seis regiões: Serra Verde, Centro Financeiro, Distrito Industrial, Campus/Parque, Vila Antiga e Porto/Orla; ruas contínuas, morro no oeste, farol, prédios, casas, armazéns, contêineres, calçadas, faixa de pedestres, árvores e mobiliário.
- Personagem em terceira pessoa: andar, correr com stamina, pular, olhar livremente, colisões e câmera que evita atravessar paredes.
- Carros e motos com modelos diferentes, aceleração gradual, freios, arrasto proporcional ao quadrado da velocidade, direção conforme velocidade, aderência lateral, gravidade, inclinação visual e dano por colisão. São **modelos de condução simplificados**, não simulação validada de pneus/suspensão; a moto usa equilíbrio assistido.
- Quatro modelos humanos com anatomia, pele, cabelo e roupas diferentes. Nove clipes por esqueleto: espera, andar, correr, saltar, cair, aterrissar, ser abatido, pilotar e mirar. Transições com mistura entre clipes; a mão animada carrega a arma. São animações autorais, sem mocap, IK dos pés ou ragdoll. Civis, hostis, patrulhas e um personagem de resgate têm comportamentos próprios.
- Pistola, SMG, escopeta e carabina em 12 posições exploráveis; inventário, munição, carregador, recarga, dispersão e consulta de linha de tiro. Sem violência gráfica.
- Trânsito limitado, alerta policial, perseguição a pé e perda do alerta por distância/ocultação.
- HUD, minimapa, mapa completo, marcador pessoal, velocímetro, missão, saúde, stamina, dinheiro, toque simultâneo e controles de teclado/mouse.
- Música de fundo, ambiente urbano, passos alternados, impacto, aterrissagem, porta e recarga gravados; loop de motor com mudança de tom. Música e efeitos têm controles independentes. Disparos, coleta e missão ainda são sintetizados.
- Save local com escrita temporária e backup; campanha concluída, armas, munição, itens coletados, dinheiro e preferências persistem. Ao carregar, **a missão incompleta recomeça na primeira etapa**. Estado individual de veículos e NPCs não persiste.

## Campanha

| # | Missão | Regras |
|---|---|---|
| 1 | De volta ao porto | Chegar à esquina da oficina |
| 2 | Primeiro frete | Recolher peças e entregar usando carro |
| 3 | Entrega expressa | Passar por quatro checkpoints de moto em 180 s |
| 4 | Depois da tempestade | Buscar três caixas a pé |
| 5 | Mira responsável | Encontrar uma arma e acertar três alvos físicos |
| 6 | Ninguém fica para trás | Vencer três guardas, resgatar Rafa e chegar à clínica |
| 7 | Curvas da serra | Completar quatro checkpoints de moto em 210 s |
| 8 | Rastro de papel | Recolher documentos em três pontos vigiados |
| 9 | Sem deixar rastro | Despistar a patrulha e voltar à oficina sem alerta |
| 10 | A última entrega | Percorrer a rota de carro, vencer a emboscada e entregar em 300 s |

As etapas avançam por posição e condições concretas de veículo/alvos/combate. Falhas de tempo e morte permitem repetir. Ao terminar, a cidade permanece aberta.

## Controles

Celular em paisagem: analógico esquerdo para mover/dirigir; arraste em região livre à direita para câmera. Botões: correr, pular, entrar/sair, atirar, recarga, trocar arma, freio, pausa. Toque no minimapa abre o mapa. Armas são coletadas automaticamente ao passar perto **a pé**. É preciso frear abaixo de 18 km/h para sair do veículo. Interagir perto da oficina (60,18) restaura saúde, munição de armas encontradas e veículos próximos.

PC: WASD ou setas; mouse para olhar; clique esquerdo dispara; E entra/sai/interage; espaço pula/freia; Shift corre; R recarrega; Tab troca arma; M abre mapa; Esc pausa. Na pausa, clique em Continuar captura o mouse.

## Otimização e compatibilidade

Renderizador OpenGL de compatibilidade; Android 7+ (API 24), GPU com OpenGL ES 3.0. APK universal ARMv7/ARM64. O projeto **não foi medido em celular físico**, portanto não há FPS mínimo garantido. Esta versão prioriza celulares mais potentes. A memória mínima e os modelos de aparelho suportados ainda precisam de teste físico; a versão do Android por si só não garante bom desempenho.

| Perfil | Alvo | Blocos simultâneos | Pedestres comuns | Trânsito | Sombras |
|---|---|---|---|---|---|
| Leve | 30 FPS | até 9 | 10 | 2 | desligadas |
| Equilibrado | 60 FPS | até 25 | 18 | 4 | sol, 75 m, MSAA 2× |
| Alto (padrão) | 60 FPS | até 49 | 28 | 6 | sol, 120 m, MSAA 4× |

Geometria estática agrupada em MultiMesh por material e bloco; malhas compartilhadas; geração determinística e descarregamento de blocos; um bloco novo por frame; IA distante suspensa; distância de visão 235/350/470 m; texturas PBR 2K com mipmaps e normais, texturas humanas limitadas a 1K, malhas e materiais compartilhados, árvores agrupadas em MultiMesh e esqueletos com quatro influências por vértice. Escala 3D adaptativa com piso de 60/70/80% conforme perfil; interface preserva a resolução. O alvo de FPS é uma configuração, não uma medição em hardware real.

## Reproduzir o APK no GitHub

Workflow: `.github/workflows/porto-livre-android.yml`, disparado por alterações desta pasta na branch `game/porto-livre-android`. Primeiro executa o workflow reutilizável de recursos: baixa as fontes CC0 e converte os modelos com Blender 4.3.2 e MPFB fixado por commit. Depois instala Java 17, SDK Android 35 e templates oficiais Godot 4.5.1, importa recursos, executa validação integrada, renderiza uma captura e exporta um APK assinado para testes. O artefato `PortoLivre-Android-v0.2.0` contém APK, imagem, hash e metadados. A chave de desenvolvimento fica no cache do Actions; se esse cache expirar, uma nova chave pode exigir reinstalação (faça backup do save antes de desinstalar). Não é uma assinatura de publicação na Play Store.

Validação local:

```sh
PORTO_BLENDER=/caminho/para/blender python3 android-game/tools/assets/prepare.py
godot --headless --path android-game --editor --import
godot --headless --path android-game -- --self-test
```

A suíte verifica a inicialização do mundo, entrada/saída de veículo, restauração de colisões, recarga, condições e conclusão das dez missões, rejeição de veículo errado, repetição por tempo, serialização e respawn. Esses testes injetam estados e posições: **não substituem jogar toda a campanha, testar o toque num Android real ou medir fluidez**.

## Licenças

Código e elementos autorais foram criados para este projeto. As fontes, autores e licenças da arte e do áudio importados estão em [THIRD_PARTY.md](THIRD_PARTY.md). Engine Godot: MIT, copyright dos colaboradores, https://godotengine.org/license/. O APK inclui componentes da engine sujeitos às suas respectivas licenças. Não há assets extraídos de outros jogos.
