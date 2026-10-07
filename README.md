# CareerTrace v2110 — filtragem organizada da titularidade

Plugin GoldHEN para observar a memória do jogo na Carreira de Jogador. Esta atualização continua o **CareerTrace v2100**, mantendo as duas fases, os oito tipos numéricos e os atalhos de filtragem. O objetivo continua sendo descobrir o valor que acompanha a titularidade.

A coleta e o ranking são **somente leitura**. A identificação do endereço correto ainda depende de observar o efeito no jogo; esta versão não é um desbloqueio definitivo de titularidade.

## Instalação

Com o jogo fechado, substitua o arquivo existente:

```text
/data/GoldHEN/plugins/career_diag.prx
```

Mantenha a entrada do plugin na seção do Title ID do seu jogo em `/data/GoldHEN/plugins.ini`. Para o título usado neste projeto:

```ini
[CUSA57220]
/data/GoldHEN/plugins/career_diag.prx
```

Abra o jogo e entre na Carreira de Jogador. Aguarde a mensagem de conclusão de cada leitura antes de registrar outra mudança. A referência é criada na execução atual: após reiniciar o jogo, comece uma nova coleta.

## A mesma ideia, em duas fases

1. Na tela da carreira, pressione **R1 + cima** para criar a referência inicial da memória.
2. Na **fase 1 — regiões**, registre pelo menos **duas subidas, duas quedas e uma situação sem mudança** da titularidade, na ordem em que realmente acontecerem.
3. Use **R2 + esquerda** para fazer o FOCUS: o programa seleciona até 384 páginas promissoras e tira uma nova referência delas.
4. Na **fase 2 — valores**, registre novamente pelo menos **duas subidas, duas quedas e uma situação sem mudança**. O programa compara inteiros e números decimais e atualiza o ranking após cada evento.
5. Use **R1 + baixo** a qualquer momento para ver a fase, as contagens e o que falta. Envie `trace_rank.txt`, `trace_events.txt` e `diagnostic.log` para analisarmos o resultado.

Cada registro deve corresponder a uma nova observação: apertar o mesmo filtro duas vezes sem uma nova mudança não equivale a observar duas subidas. Para o controle “igual”, deixe ocorrer atividade normal de menus ou do jogo enquanto a titularidade permanece igual; isso ajuda a distinguir o valor procurado de mudanças sem relação com ele.

O FOCUS escolhe regiões por comportamento, não por endereços de sessões antigas. Pode ser necessário coletar mais eventos ou recomeçar: mudanças de memória não provam que uma região contém a titularidade.

## Atalhos

| Atalho | Ação |
|---|---|
| **R1 + cima** | Reiniciar a busca e criar a referência completa; reinicia também os arquivos da coleta |
| **R1 + baixo** | Mostrar fase, contagens e próximo passo |
| **R2 + cima** | Registrar que a titularidade **subiu** |
| **R2 + baixo** | Registrar que a titularidade **desceu** |
| **R2 + direita** | Registrar que a titularidade **ficou igual** |
| **R2 + esquerda** | Fase 1: FOCUS; fase 2: salvar o ranking |
| **L1 + R1** | Armar ou desarmar o teste individual, somente após a coleta detalhada |
| **R1 + esquerda** | Restaurar o teste anterior e testar o próximo candidato |
| **R1 + direita** | Solicitar a restauração do teste ativo |

## Melhorias da v2110

- Pontuação de 16 bits: resultados consistentes não perdem aderência por saturação após cerca de 15 mudanças. Há um limite explícito de 3.000 eventos detalhados por coleta.
- Comparações válidas contadas por página. Uma falha de leitura reinicia a evidência da página afetada; a primeira leitura recuperada cria uma nova referência, sem pontuar a mudança de um intervalo perdido.
- Valores vizinhos e interpretações distintas do mesmo endereço continuam disponíveis. Apenas interpretações equivalentes com/sem sinal da mesma largura são agrupadas na fila de testes.
- `trace_status.txt` e **R1 + baixo** informam o próximo passo. Comandos recebidos durante uma leitura são avisados como não registrados, em vez de sumirem silenciosamente.
- Gravação do ranking com tamanho verificado, corrigindo uma leitura além do buffer no cabeçalho da v2100.
- Fila de testes preservada enquanto estiver armada; salvar o ranking não reinicia a posição da fila.
- Testes individuais com releitura antes/depois da escrita, registro prévio dos bytes originais e tentativa automática de restauração após 10 segundos.
- Uma restauração só regrava o original se o valor ainda corresponder ao aplicado pelo plugin. Se o jogo mudou o valor, o plugin registra a divergência. Se a leitura ou escrita falhar, mantém a restauração pendente e bloqueia o próximo teste.
- Ao desarmar depois de escritas, renova a referência e a evidência da fase 2, para não aprender mudanças produzidas pelo próprio teste.

## Como interpretar o resultado

`match` é a pontuação dividida pela melhor pontuação possível nas comparações válidas daquela página. **Não é uma probabilidade de o endereço estar correto.** `U`, `D` e `S` mostram quantas comparações válidas de cada tipo existem; `ready=1` indica que aquela página tem pelo menos 2 subidas, 2 quedas e 1 controle igual.

O programa mantém até 300 entradas no ranking e até 64 na fila de testes, exigindo aderência de pelo menos 55% e pontuação mínima de 8. Coletar mais mudanças naturais continua útil depois do mínimo de cinco eventos.

São analisados `u8`, `u16`, `i16`, `u32`, `i32`, `i64`, `f32` e `f64`, inclusive em posições não alinhadas. A busca de regiões cobre até 720.000 páginas de 4 KiB; o log informa quando esse limite é atingido. Isso não garante cobertura de toda a memória do jogo. A versão usa aproximadamente 43 MiB de buffers estáticos, cerca de 12 MiB a mais que a v2100 para evitar a saturação da pontuação.

## Teste individual opcional

Depois do ranking detalhado, **L1 + R1** arma os testes sem escrever. **R1 + esquerda** aplica uma pequena alteração em um candidato, por até 10 segundos, ou até **R1 + direita**.

Inteiros recebem +1, ou -1 no limite dos tipos pequenos. Decimais próximos de 0–1 recebem uma alteração de 0,01; os demais, 1. Valores muito grandes e decimais quase nulos ficam apenas no ranking. Um candidato cujo valor mudou desde a medição é ignorado pelo teste.

Não salve a carreira durante testes de escrita. A memória do jogo pode mudar entre verificações; mesmo um teste pequeno pode causar falhas, e restaurar bytes não desfaz efeitos que o jogo já tenha calculado. A coleta por filtros pode ser usada sem armar esses testes.

## Arquivos no PS4

Todos ficam em `/data/GoldHEN/career_diag/`:

| Arquivo | Conteúdo |
|---|---|
| `trace_status.txt` | Fase e próximo passo |
| `trace_events.txt` | Histórico de medições rotuladas e reinícios da evidência |
| `trace_pages.txt` | Ranking de regiões antes do FOCUS |
| `trace_rank.txt` | Ranking detalhado com tipo, endereço, valor e evidência |
| `trace_test.txt` | Valores originais/aplicados e resultado das restaurações |
| `diagnostic.log` | Diagnóstico geral e mensagens |

## Compilação e verificação

Requisitos: OpenOrbis PS4 Toolchain, GoldHEN Plugins SDK, LLVM/LLD.

```bash
export OO_PS4_TOOLCHAIN=/caminho/OpenOrbis/PS4Toolchain
export GOLDHEN_SDK=/caminho/GoldHEN_Plugins_SDK
make
```

Saída: `bin/career_diag.prx`. O workflow do GitHub compila o plugin e o plugin mínimo de diagnóstico de carregamento.

```bash
make check
```

Os testes executam o código real do scanner com memória simulada e AddressSanitizer/UndefinedBehaviorSanitizer. Cobrem o fluxo completo sem escrita, pontuação longa, candidatos vizinhos, falhas de leitura, valores desatualizados, restauração, limite de tempo e comandos concorrentes. Em ambientes sem suporte ao LeakSanitizer por restrições de `/proc`, use `ASAN_OPTIONS=detect_leaks=0 make check`; as verificações de acesso à memória e comportamento indefinido permanecem ativas.

Esses testes e a compilação não substituem o teste de carregamento e comportamento no PS4.
