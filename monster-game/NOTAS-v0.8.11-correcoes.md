# Noite da Horda — fontes corrigidas 0.8.11 (base 0.8.10)

Esta entrega é o **projeto-fonte**, não um APK compilado. O repositório do GitHub estava atrasado; o ponto de partida é o backup completo **v0.8.10** obtido da Library. Os sprites, sons, terrenos, spawn, dificuldade e scripts não mencionados abaixo não foram modificados.

## Colisões individuais com aviões e veículos grandes

Arquivo `scripts/runner.gd`, função `update_vehicle`:

- A colisão frontal continua empurrando apenas o zumbi que efetivamente toca no para-choque, preservando a contagem dos membros que viram veículos.
- O interior de um veículo deixou de funcionar como uma zona de **teletransporte** que puxava para trás membros que tinham saltado parcialmente sobre ele.
- Quem pousar profundamente *dentro* do corpo do veículo sofre dano individual. Membros que pousaram no teto ou já ultrapassaram a traseira continuam correndo. O dano é aplicado depois da varredura do grupo para evitar índices incorretos quando membros desaparecem.
- Quem permanecer bloqueado no para-choque ainda pode ser abandonado e removido ao sair pelo limite esquerdo da câmera. Somente o último integrante perdido encerra a partida.

## Pulo segurado

Arquivo `scripts/balance.gd`:

- `HOLD_FALL_GRAVITY`: **1100** → **850** px/s².
- `MAX_HOLD`: **1.05** → **1.25** s.
- **Sem alterações** no impulso inicial, na gravidade do toque curto, na sequência de pulo por integrante, no buffer e no salto duplo.
- A duração extra é pequena (aproximadamente 0,08 s num salto completamente segurado). Aumenta a margem nos grandes veículos durante a fase lenta da corrida, sem criar voo.

## Regressão

Adicionado `tests/vehicle_survivors_test.gd` e incluído no `--self-test`, com cenários para caminhão e avião: pouso falho, sobrevivente adiante, contato superficial no teto, integrante bloqueado pela câmera e empurrão frontal preservado.

**Estado de verificação:** revisão de código e `git diff --check` realizados. Não foi possível executar os testes Godot nem gerar/assinar APK neste ambiente: não há Godot 4.5.1, modelos de exportação Android, SDK e chave Local original. Compilar com outra chave impede instalar por cima do aplicativo atual, portanto não é seguro forçar essa etapa.

## Para gerar o APK correto

Use **Godot 4.5.1** com os modelos Android e o ambiente de exportação do projeto, na pasta `monster-game`. Execute o autoteste primeiro:

```
godot --headless --path monster-game -- --self-test
```

Em seguida, exporte com a **mesma chave Local** do APK instalado, mantendo o identificador `com.kauan.noitedahorda.local` e o novo código de versão 29. A exportação definida em `export_presets.cfg` produz `NoiteDaHorda-v0.8.11.apk`.
