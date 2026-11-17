# KAYNEX — Windows Utility Suite

Aplicativo desktop Flutter/Dart para monitoramento local do Windows, análise e organização de arquivos, manutenção seletiva e diagnóstico de rede. As funções principais não dependem de conta, servidor ou internet. Dados persistentes ficam em SQLite no perfil local do usuário.

## Executar

Requisitos: Windows 10/11 x64, Flutter/Dart compatíveis com `pubspec.yaml` e Visual Studio com **Desktop development with C++**.

```powershell
flutter pub get
flutter run -d windows
```

O banco `kaynex.sqlite` é criado em Application Support/KAYNEX. Para build local: `flutter build windows --debug`.

## Implementado

- **Visão geral:** identificação do dispositivo, Windows, hardware, recursos e rede; séries em memória limitadas para CPU e RAM e atividades recentes.
- **Sistema:** inventário obtido via Windows/CIM, CPU, RAM, discos e I/O de disco quando fornecido pelo Windows; processos com memória, estimativa de CPU entre amostras, pesquisa, ordenação e encerramento confirmado com proteção de processos críticos. Análise e limpeza seletiva de arquivos temporários conhecidos, com prévia e confirmação.
- **Arquivos:** navegação, pesquisa, ordenação, seleção e operações confirmadas; análise recursiva de pastas com progresso/cancelamento, maiores itens e distribuição por categoria; duplicados confirmados por SHA-256; regras de organização e renomeação em lote com prévia.
- **Rede:** adaptadores, ping com estatísticas, consulta DNS, traceroute e teste TCP de porta, com resultados registrados localmente.
- **Atividades:** histórico SQLite, busca, filtros por módulo e período, ordenação, detalhes e limpeza de registros.
- **Preferências:** tema, cor de destaque, intervalo de atualização, página inicial, limite do histórico, confirmação de operações e backup/restauração validada do banco.

## Arquitetura e persistência

`lib/features` contém páginas por módulo; `lib/core/services` contém serviços Windows, análise de armazenamento, operações de arquivos e manutenção; `lib/core/database/local_store.dart` gerencia SQLite e migrações. Os arquivos usam `part` para compartilhar tipos privados do app sem concentrar páginas e serviços em `main.dart`.

SQLite versionado guarda preferências, atividades, diagnósticos de rede, operações de arquivos, regras de organização e operações de manutenção. Métricas rápidas de CPU/RAM permanecem apenas em buffers de tamanho limitado na memória. O backup é uma cópia local; a restauração verifica integridade e esquema antes de substituir o banco.

## Limites conhecidos

- A integração de inventário e processos depende do PowerShell/CIM local; políticas corporativas, provedores ausentes e permissões podem limitar campos. A CPU por processo é uma estimativa calculada entre amostras e pode não estar disponível no primeiro ciclo.
- O Windows não oferece uma leitura térmica universal confiável para CPU/GPU. Temperaturas não são inventadas nem exibidas sem fonte confiável.
- Gateway/DNS por interface podem variar conforme provedor e configuração do Windows; campos sem fonte disponível permanecem indisponíveis.
- A limpeza limita-se a arquivos conhecidos por extensão/localização e idade; não inclui lixeira, Downloads ou limpeza genérica de caches. Arquivos em uso ou inacessíveis são ignorados e relatados.
- Operações de arquivos não implementam uma lixeira própria nem desfazer universal; alterações feitas fora do app não são revertidas. A análise recursiva pode levar tempo em volumes grandes e está sujeita a permissões e arquivos que mudem durante a leitura.
- Inicialização automática com Windows, atividade real de rede por processo e monitoramento térmico estão pendentes. Não há varredura de rede; os testes são executados somente contra os destinos informados pelo usuário.

## Dependências diretas

- `sqflite_common_ffi`: SQLite local desktop com FFI.
- `path_provider`: diretório local de suporte para o banco e backups.
- `crypto`: SHA-256 para confirmação de duplicados.
- `fl_chart`: gráficos de séries e distribuição de armazenamento.
