# PS4 Career Diagnostic

Ferramenta de diagnóstico **read-only** para localizar, no processo de um jogo de PS4, valores que acompanham a pontuação de titularidade do modo Carreira de Jogador.

## Objetivo da V0.1

A V0.1 não escreve nem congela memória. Ela:

1. conecta a um PS4 executando um payload `ps4debug` compatível;
2. lista os processos ativos;
3. permite selecionar o processo do jogo;
4. faz uma busca inicial por um valor numérico;
5. refina a mesma busca depois que o valor muda no jogo;
6. mostra quantos endereços candidatos restaram e uma pequena amostra deles;
7. registra a sessão em JSON para comparação posterior.

Exemplo de uso:

```text
Titularidade no jogo: 83
> first 83
Candidatos: 281453

Depois de uma mudança no jogo:
Titularidade: 79
> refine 79
Candidatos: 417

Depois:
Titularidade: 76
> refine 76
Candidatos: 5
```

O scanner reutiliza a sessão anterior; portanto cada `refine` verifica apenas os candidatos sobreviventes.

## Requisitos

- PS4 desbloqueado/homebrew;
- payload `ps4debug` compatível em execução;
- PC e PS4 na mesma rede;
- Python 3.13 ou superior.

A comunicação usa a biblioteca Python `ps4debug` (PyPS4debug).

## Instalação

No Windows PowerShell:

```powershell
git clone https://github.com/kauanbraga125-sketch/PS4-Career-Diagnostic.git
cd PS4-Career-Diagnostic
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e .
```

## Executar

Se souber o IP do PS4:

```powershell
career-diag --host 192.168.0.20
```

Ou tente descoberta automática:

```powershell
career-diag --discover
```

O programa lista os processos e pede qual processo deve ser analisado.

## Comandos da sessão

```text
first <valor>       inicia uma nova busca exata
refine <valor>      refina usando somente os candidatos anteriores
show                mostra amostra dos candidatos atuais
reset               apaga a busca atual
save                grava o estado/resumo da sessão
help                mostra os comandos
quit                encerra
```

O tipo inicial é `int32`, que é uma primeira hipótese razoável para uma pontuação inteira. Suporte a `float` pode ser adicionado se o valor não aparecer como inteiro.

## Estratégia

A identificação não termina quando encontramos um endereço com o mesmo número mostrado na interface. O processo correto é:

- reduzir os candidatos por várias mudanças reais;
- confirmar que o endereço acompanha tanto aumentos quanto reduções;
- só depois criar uma fase separada de teste de escrita;
- posteriormente usar watchpoint/breakpoint para descobrir a rotina que escreve o valor;
- apenas no projeto final bloquear reduções mantendo ganhos normais.

## Segurança do projeto

A V0.1 é propositalmente somente leitura. Nenhuma função de escrita em memória está exposta pelo programa.

Use apenas em jogos/modos offline e em hardware/software sob seu controle.
