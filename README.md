# PS4 Career Diagnostic

Diagnóstico de memória **executado no próprio PS4** para descobrir onde o jogo guarda a pontuação de titularidade do modo Carreira de Jogador.

> Esta versão substitui a primeira ideia de scanner no PC. O diagnóstico agora é um **plugin GoldHEN PRX carregado dentro do processo do jogo**.

## Por que plugin e não um PKG separado?

Um aplicativo normal aberto pelo menu do PS4 não é a arquitetura ideal para observar continuamente um jogo em execução. O GoldHEN permite carregar plugins PRX junto de um título; assim o diagnóstico roda no mesmo processo do jogo e pode observar suas regiões de memória enquanto você joga.

O sistema oficial de plugins GoldHEN suporta carregamento por Title ID em `/data/GoldHEN/plugins.ini`.

## V0.1 — Unknown-value scanner

Não precisamos digitar "titularidade = 83".

O plugin tira uma foto inicial de valores plausíveis (1 a 100). Depois você provoca mudanças reais no jogo e refina os candidatos:

```text
ANTES DA MUDANÇA
L3 + R3 + QUADRADO
→ snapshot

A titularidade caiu
L3 + R3 + BAIXO
→ mantém somente valores que diminuíram

A titularidade subiu
L3 + R3 + CIMA
→ mantém somente valores que aumentaram

Nada aconteceu com a titularidade
L3 + R3 + CÍRCULO
→ mantém somente valores que ficaram iguais
```

Repetimos até restarem poucos endereços.

## Atalhos

| Atalho | Ação |
|---|---|
| L3 + R3 + Quadrado | novo snapshot |
| L3 + R3 + Baixo | filtrar valores que diminuíram |
| L3 + R3 + Cima | filtrar valores que aumentaram |
| L3 + R3 + Triângulo | filtrar valores que mudaram |
| L3 + R3 + Círculo | filtrar valores que não mudaram |
| L3 + R3 + Options | salvar candidatos |
| L3 + R3 + X | zerar busca |
| L3 + R3 + Esquerda | modo INT32 |
| L3 + R3 + Direita | modo FLOAT |

O padrão é **INT32**. Se depois de vários testes não encontrarmos o valor correto, zeramos a busca, mudamos para FLOAT e repetimos.

## Arquivos gerados no PS4

```text
/data/GoldHEN/career_diag/diagnostic.log
/data/GoldHEN/career_diag/candidates.txt
```

Quando restarem 20 candidatos ou menos, o plugin solicita automaticamente o dump para `candidates.txt`.

## Instalação do PRX

Depois de compilar/baixar `career_diag.prx`:

```text
/data/GoldHEN/plugins/career_diag.prx
```

No `/data/GoldHEN/plugins.ini`, coloque o plugin **somente na seção do Title ID da sua versão do jogo**:

```ini
[CUSAxxxxx]
/data/GoldHEN/plugins/career_diag.prx
```

Não use `[default]`: o scanner foi feito para ser carregado apenas no jogo que estamos diagnosticando.

## Como o scanner trabalha

- enumera as regiões virtuais do processo com `sceKernelVirtualQuery`;
- considera apenas memória com leitura + escrita pela CPU;
- ignora stacks e a própria área interna do plugin;
- lê a memória por blocos usando a API de processo do GoldHEN;
- no modo INT32 guarda somente inteiros de 1 a 100;
- no modo FLOAT guarda somente floats de 1 a 100;
- cada filtro compara o valor atual com o valor anterior;
- a V0.1 é somente leitura: **não congela nem altera a titularidade**.

## Próxima fase

Quando identificarmos 1–poucos endereços confiáveis:

1. confirmar qual realmente controla a titularidade;
2. descobrir quem escreve nesse endereço;
3. localizar a rotina de perda;
4. criar o plugin final que permita ganhos e bloqueie somente reduções.

## Build

Requisitos locais:

- OpenOrbis PS4 Toolchain;
- GoldHEN Plugins SDK;
- LLVM/LLD.

```bash
export OO_PS4_TOOLCHAIN=/caminho/OpenOrbis/PS4Toolchain
export GOLDHEN_SDK=/caminho/GoldHEN_Plugins_SDK
make
```

O resultado é:

```text
bin/career_diag.prx
```

O GitHub Actions do repositório também compila o PRX automaticamente.
