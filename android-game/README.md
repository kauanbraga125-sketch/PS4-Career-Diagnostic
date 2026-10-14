# Porto Livre — Android alpha 0.4

Jogo original de exploração urbana criado para Kauan, em Godot 4.5.1. Esta alpha continua o projeto da 0.3, na pasta `android-game`; o plugin FIFA/PS4 permanece separado.

## Novidades da 0.4

- Botões **MIRAR** e **ATIRAR** independentes. Mira em terceira pessoa sobre o ombro, transição de câmera/FOV, arraste do próprio botão para apontar no celular e bloqueio do tiro por cobertura próxima.
- Quatro armas **Quaternius CC0 importadas em GLB**. Mãos posicionadas com IK e cano orientado ao ponto de mira; inventário e 12 locais de coleta continuam offline.
- Caminhada, corrida, espera, salto, queda e aterrissagem da biblioteca **KayKit 1.1 CC0**, adaptadas ao esqueleto humano MakeHuman. Mistura entre clipes e velocidade ajustada ao deslocamento; não são alegadas captura de movimentos ou IK dos pés.
- **Ragdoll físico com 12 corpos e juntas 6DOF limitadas**, ativado em NPCs abatidos e na morte do jogador. Colisão com terreno e veículos, impulso inicial e recuperação do jogador após 3 segundos. Sistema experimental.
- Céus texturizados Kenney, ciclo de **24 minutos por dia**, amanhecer, noite, nuvens/tempo limpo ou coberto e postes iluminados perto do jogador. O perfil Alto usa um shader com amostragem de ruído 3D para as nuvens; Leve/Equilibrado preservam as panorâmicas com custo menor.
- Prédios de fachada variada importados do **Kenney City Kit Commercial**, além das oito casas da 0.3. Geometria exterior agrupada em MultiMesh por modelo/bloco.
- Avião biplano e helicóptero **importados de fontes CC0**, com voo assistido. O avião precisa ganhar velocidade para subir; o helicóptero pode pairar. Modelos de arcade, sem aerodinâmica profissional.
- **Salto livre e abertura manual de paraquedas**, vela curvada, cordas, controle de direção e descida limitada. O botão aparece no ar; pousar recolhe a vela.
- Aceleração e ré por botões próprios; analógico usado para virar. Motor gravado convertido para Ogg com loop e volume audível, variação de tom conforme velocidade/aceleração. Materiais de pneus sem mapas de microdetalhe que cintilavam.

## Mundo e campanha

Mapa de 1.440 × 1.440 m (2,0736 km² delimitados), com seis regiões, montanhas esculpidas e colisão, pequenos morros acessíveis, campus, praia, área arenosa com cactos, porto e farol. Esse tamanho é geométrico; não afirma equivalência exata com a área de Bully.

Esta é uma alpha jogável com física simplificada, IA limitada, repetição de cenários e missões narradas por texto. Não há interiores, multiplayer, cutscenes dubladas, deformação de carro ou equivalência visual/tecnológica a GTA V. Não contém assets de outros jogos comerciais.

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

Celular em paisagem: analógico esquerdo move o personagem ou vira o veículo. Arraste à direita para olhar; também pode arrastar enquanto segura MIRAR/ATIRAR. Armas são recolhidas automaticamente a pé. Segure ACELERAR para dirigir, FREIO para parar ou RÉ para recuar. Aproxime-se e use ENTRAR/SAIR. Nos veículos terrestres, freie abaixo de 18 km/h antes de sair.

As aeronaves estão no porto: helicóptero em (532,629), avião em (572,658), sinalizados no mapa. ACELERAR ganha velocidade; SUBIR/DESCER mudam altitude. Use SALTAR em altitude e ABRIR PARAQUEDAS no ar. Guie a descida pelo analógico. A oficina (60,18) restaura saúde, munição e veículos próximos.

PC: WASD/setas; mouse para olhar; botão direito mira, esquerdo dispara; E entra/sai/salta; espaço pula/freia; Shift corre/sobe; Ctrl desce; P abre/recolhe paraquedas; R recarrega; Tab troca arma; M mapa; Esc pausa. Na pausa, HORÁRIO e CLIMA permitem alternar para testar as condições.

## Compatibilidade e otimização

Android 7+ (API 24), ARMv7/ARM64, OpenGL ES 3.0. O projeto prioriza celulares potentes. Ainda não foi medido em aparelho físico; FPS, memória mínima e estabilidade por modelo de celular precisam de teste real.

| Perfil | Alvo configurado | Blocos | Pedestres | Trânsito | Sombras | Nuvens |
| --- | --- | --- | --- | --- | --- | --- |
| Leve | 30 FPS | até 9 | 10 | 2 | desligadas | panorama |
| Equilibrado | 60 FPS | até 25 | 18 | 4 | sol, 75 m | panorama |
| Alto | 60 FPS | até 49 | 28 | 6 | sol, 120 m | ruído 3D |

Malhas/materiais compartilhados, MultiMesh estático, streaming de blocos, IA distante suspensa, resolução 3D adaptativa sem reduzir a interface, mipmaps e texturas humanas de 1K/skyboxes de 2K. Sombras dos postes desligadas; apenas oito luzes próximas. Ragdolls são criados ao serem necessários. Alvo de FPS não é resultado de benchmark.

## Salvamento e compilação

O save da 0.2/0.3 é preservado, acrescido de horário e clima. Persistem campanha, dinheiro, armas, munição, itens coletados e preferências; a missão incompleta recomeça na primeira etapa. Veículos e NPCs individuais não persistem. Save local com arquivo temporário e backup.

O workflow `.github/workflows/porto-livre-android.yml` converte as fontes com Blender 4.3.2, importa em Godot 4.5.1, roda a suíte integrada, renderiza capturas reais, exporta `PortoLivre-v0.4.0.apk` e verifica assinatura, manifesto e SHA-256. Artefato: `PortoLivre-Android-v0.4.0`. Assinatura de desenvolvimento; a chave é preservada no cache do GitHub Actions, cujo vencimento pode exigir reinstalação.

```sh
PORTO_BLENDER=/caminho/blender python3 android-game/tools/assets/prepare.py
godot --headless --path android-game --editor --import
python3 android-game/tools/configure_imports.py
godot --headless --path android-game --editor --import
godot --headless --path android-game -- --self-test
godot --headless --path android-game --script res://tests/pose_audit.gd
```

A auditoria física também simula impactos no chão e mortes repetidas nos quatro modelos de NPC, partindo de poses diferentes. Testes injetam entradas e posições para verificar os sistemas; não substituem jogar a campanha completa nem testar toque e desempenho no Android físico.

## Licenças

Arte/áudio e adaptações documentados em [THIRD_PARTY.md](THIRD_PARTY.md), com fontes e hashes no pacote de recursos. CarConcept: CC BY 4.0; demais assets artísticos listados: CC0. Godot e seus colaboradores: MIT, https://godotengine.org/license/.
