# KAYNEX — Manual de utilização

O **KAYNEX — Windows Utility Suite** é uma aplicação desktop desenvolvida para reunir ferramentas de monitoramento, manutenção, gerenciamento de arquivos e diagnóstico de rede em um único lugar.

Este manual apresenta os requisitos do computador, orientações de utilização, funcionalidades disponíveis e instruções para executar o projeto.

---

# 1. Requisitos do sistema

## Requisitos para utilizar o aplicativo

O KAYNEX foi desenvolvido para computadores com Windows.

**Requisitos recomendados para uma experiência adequada:**

| Componente | Requisito recomendado |
|---|---|
| Sistema operacional | Windows 11 64 bits |
| Processador | Intel ou AMD, 2 núcleos ou mais |
| Memória RAM | 8 GB |
| Armazenamento | 500 MB livres para a aplicação e seus dados |
| Arquitetura | x64 |
| Tela | Resolução de 1280 × 720 ou superior |

Essas são recomendações iniciais de uso, não requisitos mínimos oficialmente medidos. O consumo real depende das funcionalidades utilizadas e do tamanho das análises executadas.

**Observações:**
- Uma conexão com a internet não é necessária para utilizar as funcionalidades locais do aplicativo.
- Ferramentas de diagnóstico de rede precisam de conectividade para testar destinos externos.
- Algumas operações do Windows podem exigir privilégios administrativos.
- O espaço ocupado pelo aplicativo e pelo banco de dados pode variar conforme a utilização.

## Requisitos para desenvolvedores

Para executar, modificar ou compilar o código-fonte, é necessário instalar:

| Ferramenta | Finalidade |
|---|---|
| Windows 10 ou 11 64 bits | Ambiente de desenvolvimento |
| Flutter SDK | Framework da aplicação |
| Dart SDK | Linguagem utilizada pelo projeto, incluída no Flutter |
| Git | Clonagem e gerenciamento do repositório |
| Visual Studio | Ferramentas de compilação para Windows |
| Desktop development with C++ | Compilador e ferramentas nativas necessárias |

O Visual Studio Code é opcional e pode ser utilizado como editor.

---

# 2. Downloads e links úteis

Abaixo estão os links oficiais das ferramentas utilizadas no desenvolvimento.

| Ferramenta | Link |
|---|---|
| Flutter SDK | https://docs.flutter.dev/install |
| Flutter para Windows | https://docs.flutter.dev/platform-integration/windows/setup |
| Git | https://git-scm.com/install/win |
| Visual Studio | https://visualstudio.microsoft.com/ |
| Visual Studio Code | https://code.visualstudio.com/ |
| Documentação Dart | https://dart.dev/ |
| Repositório KAYNEX | https://github.com/Kaykedev01/kaynex |
| Releases | https://github.com/Kaykedev01/kaynex/releases |

**Importante:** na instalação do Visual Studio, selecione a carga de trabalho **Desenvolvimento para desktop com C++ (Desktop development with C++)**. O Visual Studio Code sozinho não substitui essas ferramentas de compilação.

---

# 3. Conhecendo a interface

Ao abrir o KAYNEX, você encontrará uma interface dividida em duas áreas principais:

**Barra lateral:** localizada à esquerda, permite acessar os módulos.

**Área principal:** apresenta as ferramentas e informações da seção selecionada.

A navegação está organizada em:

- **Visão geral:** painel com informações resumidas do computador.
- **Sistema:** monitoramento de recursos, processos, manutenção e atalhos.
- **Arquivos:** navegação e gerenciamento de arquivos e pastas.
- **Rede:** informações da conexão e ferramentas de diagnóstico.
- **Atividades:** histórico das operações realizadas.
- **Preferências:** configurações e personalização do aplicativo.

---

# 4. Visão geral

A Visão geral funciona como o painel inicial do KAYNEX.

Nela, você pode acompanhar informações importantes sobre o computador sem precisar abrir cada módulo individualmente.

Utilize essa página para consultar rapidamente o estado do sistema e identificar situações que merecem atenção.

---

# 5. Sistema

O módulo Sistema reúne ferramentas relacionadas ao hardware, desempenho e manutenção do Windows.

Na parte superior, você encontrará diferentes abas.

## Monitoramento

Essa seção permite acompanhar o comportamento dos recursos do computador.

**CPU:** apresenta informações sobre a utilização do processador.

**Memória:** mostra o percentual de utilização da memória RAM.

**E/S de disco:** apresenta informações sobre a atividade de leitura e escrita dos discos.

**Alerta de memória:** permite definir um limite de utilização da RAM para receber avisos quando o consumo ultrapassar o valor configurado.

Para alterar o limite, clique no seletor de porcentagem e escolha o valor desejado.

**Atualizar hardware:** utilize esse botão para solicitar uma nova consulta das informações de hardware disponíveis.

Os gráficos permitem acompanhar as amostras coletadas pelo aplicativo.

## Processos

Utilize essa aba para consultar os programas e processos em execução no Windows.

Você pode identificar processos pelo nome e consultar informações como PID e utilização de recursos.

Ao encontrar um processo que deseja encerrar:

1. Localize o processo na lista.
2. Selecione a opção de encerramento correspondente.
3. Confira as informações apresentadas.
4. Confirme a operação somente se tiver certeza.

Tenha cuidado ao encerrar processos desconhecidos ou relacionados ao funcionamento do Windows.

## Manutenção

Essa seção reúne ferramentas relacionadas à manutenção do computador.

Utilize os recursos disponíveis para analisar arquivos temporários e identificar possíveis oportunidades de liberar espaço.

Antes de executar uma limpeza:

1. Escolha as categorias que deseja analisar.
2. Confira os itens identificados.
3. Verifique a estimativa de espaço que poderá ser liberado.
4. Selecione o que deseja remover.
5. Revise a seleção e confirme a operação.

Não remova arquivos cuja finalidade você desconheça.

## Atalhos

Essa aba reúne acessos rápidos a ferramentas e recursos do próprio Windows.

Utilize os atalhos para abrir ferramentas do sistema sem precisar procurá-las manualmente pelo menu Iniciar.

---

# 6. Arquivos

O módulo Arquivos permite navegar pelo armazenamento do computador e realizar operações com arquivos e pastas.

## Navegando pelos diretórios

1. Abra a seção Arquivos pela barra lateral.
2. Selecione a unidade ou diretório desejado.
3. Navegue pelas pastas disponíveis.
4. Selecione um arquivo para visualizar suas informações ou utilizar as ações disponíveis.

## Abrindo arquivos

Localize o arquivo desejado e utilize a opção de abertura para executá-lo com o aplicativo padrão associado ao seu tipo no Windows.

## Gerenciando arquivos e pastas

Quando disponíveis, utilize as ferramentas de gerenciamento para:

- Criar pastas.
- Renomear arquivos.
- Copiar arquivos.
- Mover arquivos.
- Excluir arquivos e pastas.

Sempre confira o destino e os itens selecionados antes de confirmar uma operação.

## Análise de armazenamento

Utilize as ferramentas de análise disponíveis para identificar quais arquivos e diretórios ocupam mais espaço.

Essa análise ajuda a descobrir o que está consumindo o armazenamento do computador e onde vale a pena realizar uma organização.

## Arquivos duplicados

Quando utilizar a ferramenta de identificação de duplicados, confira os grupos encontrados e compare os caminhos dos arquivos.

Antes de excluir qualquer ocorrência, certifique-se de que está mantendo a cópia correta.

---

# 7. Rede

O módulo Rede reúne informações sobre a conexão e ferramentas para investigar problemas de conectividade.

## Informações da conexão

Utilize essa seção para consultar os dados disponíveis sobre os adaptadores de rede e a conexão atual.

Entre as informações apresentadas podem estar os endereços IP, gateway, DNS e estado dos adaptadores.

## Ping

O Ping permite verificar se um destino responde pela rede e medir o tempo de resposta.

Para utilizar:

1. Informe o endereço IP ou domínio desejado.
2. Configure a quantidade de pacotes, quando disponível.
3. Execute o teste.
4. Analise a latência e possíveis perdas de pacotes.

Exemplo de destino:

```text
google.com
```

## Consulta DNS

Utilize a consulta DNS para verificar como um domínio está sendo resolvido e quais informações de endereço são retornadas.

Informe o domínio desejado e execute a consulta.

## Traceroute

O Traceroute permite observar o caminho percorrido pelos pacotes até determinado destino.

Informe o endereço desejado e execute o diagnóstico.

Essa ferramenta pode ajudar a identificar em qual trecho do caminho existem atrasos ou falhas de resposta.

---

# 8. Atividades

A seção Atividades apresenta o histórico das operações registradas pelo KAYNEX.

Utilize essa página para acompanhar o que foi realizado anteriormente.

Você pode consultar os registros disponíveis e utilizar os recursos de pesquisa e filtragem para localizar atividades específicas.

Os registros podem ajudar a identificar quando determinada operação foi executada e qual foi seu resultado.

---

# 9. Preferências

A seção Preferências permite personalizar o comportamento e a aparência do KAYNEX.

## Aparência

Escolha entre os temas disponíveis e personalize a cor de destaque.

A alteração da aparência modifica a apresentação visual dos componentes do aplicativo.

## Monitoramento

Configure o intervalo de atualização das informações, quando disponível.

Um intervalo menor permite atualizações mais frequentes, mas pode aumentar o consumo de recursos do próprio aplicativo.

## Página inicial

Selecione qual seção deseja visualizar automaticamente ao abrir o KAYNEX.

## Outras configurações

Consulte as demais opções disponíveis para ajustar o comportamento do aplicativo e gerenciar suas preferências.

As configurações persistentes são armazenadas localmente.

---

# 10. Executando o KAYNEX pelo código-fonte

Esta seção é destinada a desenvolvedores ou usuários que desejam executar o projeto diretamente.

## 10.1. Verificar as ferramentas

Após instalar Flutter, Git e Visual Studio com as ferramentas C++, abra o PowerShell e execute:

```powershell
flutter doctor -v
```

Esse comando verifica se o ambiente de desenvolvimento está configurado corretamente.

Para verificar os dispositivos disponíveis:

```powershell
flutter devices
```

O Windows deve aparecer como uma plataforma disponível.

## 10.2. Clonar o repositório

Execute:

```powershell
git clone https://github.com/Kaykedev01/kaynex.git
```

Entre na pasta do projeto:

```powershell
cd kaynex
```

## 10.3. Instalar dependências

Execute:

```powershell
flutter pub get
```

Esse comando baixa as dependências necessárias para o funcionamento do projeto.

## 10.4. Executar o aplicativo

Para iniciar o KAYNEX em modo de desenvolvimento:

```powershell
flutter run -d windows
```

## 10.5. Verificar o código

Para analisar possíveis problemas:

```powershell
flutter analyze
```

Para executar os testes automatizados:

```powershell
flutter test
```

## 10.6. Compilar uma versão de produção

Para gerar a versão Release:

```powershell
flutter build windows --release
```

Após a compilação, os arquivos gerados estarão normalmente em:

```text
build/windows/x64/runner/Release/
```

Execute `kaynex.exe` para abrir o aplicativo.

Para distribuir a aplicação, compacte a pasta Release inteira, preservando o executável, as bibliotecas e os demais arquivos necessários.

---

# 11. Banco de dados e armazenamento

O KAYNEX utiliza SQLite para persistência local.

O banco é utilizado para armazenar informações como:

- Preferências do usuário.
- Histórico de atividades.
- Registros de operações.
- Informações persistentes dos módulos.

O banco é criado em um diretório local de suporte do usuário no Windows.

Os dados são mantidos localmente e não exigem serviços externos.

---

# 12. Recomendações de uso

- Consulte o monitoramento antes de iniciar uma manutenção.
- Utilize a análise de armazenamento para identificar arquivos que ocupam muito espaço.
- Confira cuidadosamente os arquivos antes de removê-los.
- Evite encerrar processos que você não reconhece.
- Utilize o Ping e o Traceroute para investigar problemas de conexão.
- Consulte o histórico para acompanhar operações anteriores.
- Ajuste o intervalo de monitoramento de acordo com sua necessidade.
- Mantenha cópias de segurança dos arquivos importantes.

---

# 13. Suporte e contribuições

O KAYNEX é um projeto em desenvolvimento.

Sugestões, melhorias e identificação de problemas são bem-vindas.

Para relatar um problema, acesse:

[GitHub Issues — KAYNEX](https://github.com/Kaykedev01/kaynex/issues)

Para acompanhar o desenvolvimento e consultar o código-fonte:

[Repositório oficial — KAYNEX](https://github.com/Kaykedev01/kaynex)

---

# 14. Licença

Este projeto está licenciado sob a licença MIT.

Consulte o arquivo [LICENSE](LICENSE) para obter mais informações.

---

**KAYNEX — Suas ferramentas do Windows em um só lugar.**
