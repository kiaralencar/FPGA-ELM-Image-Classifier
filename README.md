# FPGA-ELM-Image-Classifier

## Introdução e Definição do Problema

Este relatório descreve o desenvolvimento da primeira etapa de um sistema embarcado voltado para a classificação de imagens de dígitos numéricos. O sistema completo será implementado em um SoC (System on Chip) heterogêneo, composto por um processador ARM integrado a uma FPGA, e será construído ao longo de três marcos de desenvolvimento.
No Marco 1, foco deste relatório, é apresentado o projeto e a implementação do núcleo classificador de imagens em FPGA, descrito na linguagem Verilog e sintetizado utilizando o Quartus Prime 23.1 para a placa DE1-SoC. Trata-se de um co-processador com conjunto próprio de instruções (ISA), responsável por realizar a inferência de uma rede neural baseada em Extreme Learning Machine (ELM), capaz de identificar dígitos numéricos a partir de imagens em escala de cinza de 28×28 pixels.
O sistema foi desenvolvido de forma autossuficiente na FPGA, permitindo o carregamento dos dados, a execução da inferência e a visualização do resultado diretamente na placa, através dos botões, chaves e displays de sete segmentos disponíveis na DE1-SoC. O tema central do trabalho é a implementação de um algoritmo de classificação em um circuito especializado em FPGA, integrando conceitos de arquitetura de computadores, circuitos digitais e aceleração por hardware.
## Requisitos Principais

### Entrada e Saída

O sistema recebe como entrada uma imagem em escala de cinza com resolução de 28×28 pixels, onde cada pixel é representado por 8 bits, assumindo valores no intervalo de 0 a 255, totalizando 784 bytes. A saída é um número inteiro pred correspondente ao dígito identificado, no intervalo de 0 a 9. 

### Co-processador

O núcleo classificador foi implementado em Verilog com arquitetura sequencial, contendo uma FSM de controle com 12 estados para gerenciar o fluxo de execução, uma unidade MAC dual-mode para as operações de multiplicação e acumulação das duas camadas da rede neural, uma função de ativação aproximada da tangente hiperbólica por 20 segmentos lineares em Q4.12, e um bloco argmax combinacional embutido diretamente na FSM para determinar o dígito com maior valor de saída. Os valores são representados em ponto fixo no formato Q4.12. 

### Sistema de Memórias

O sistema utiliza cinco blocos de memória M10K da FPGA Cyclone V: MEM_IMG para armazenar os 784 pixels da imagem de entrada, MEM_WIN para os pesos W_in, MEM_BIAS para o bias b, MEM_BETA para os pesos β, e MEM_H para as saídas da camada oculta. Os pesos são inicializados via arquivos .mif gerados a partir do modelo treinado. O acesso às memórias é gerenciado por um multiplexador de endereços que prioriza a escrita quando necessário.

### Conjunto de Instruções (ISA)

O co-processador possui um conjunto próprio de instruções de 32 bits. As instruções disponíveis são STORE_IMG para carregar a imagem, STORE_WEIGHTS para carregar os pesos W_in e β, STORE_BIAS para carregar o bias, START para disparar a inferência, e STATUS para consultar o estado atual, retornando BUSY, DONE ou ERROR.

### Interface com a Placa

A interface com a placa DE1-SoC foi implementada no módulo top_de1soc, utilizando os botões KEY, chaves SW e displays de sete segmentos. O KEY[0] realiza o reset do sistema, o KEY[1] envia instruções pelo fluxo normal, o KEY[2] captura e exibe o estado nos displays, e o KEY[3] permite escrita manual nas memórias. Os displays HEX0 a HEX4 exibem o estado atual do sistema em texto (READY, BUSY, DONE, ERROR) e o HEX5 exibe o dígito predito. Os LEDs indicam o estado das flags img_ready, w_ready e b_ready, além do status geral do processamento.


## Fundamentação Teórica

### Representação Digital da Imagem

Neste projeto, as imagens são tratadas em escala de cinza com resolução de 28×28 pixels, totalizando 784 pixels por imagem. Cada pixel é representado por um número inteiro de 8 bits, podendo assumir 2⁸ = 256 tonalidades de cinza, variando de 0 (preto) a 255 (branco). Cada imagem representa um único dígito numérico entre 0 e 9.

### Representação em Ponto Fixo (Q4.12)

Por se tratar de uma implementação em hardware, os valores da rede neural são representados no formato de ponto fixo Q4.12. Nesse formato, cada valor é armazenado em 16 bits, sendo 1 bit de sinal, 4 bits para a parte inteira e 12 bits para a parte fracionária. Essa representação permite realizar operações aritméticas de forma eficiente em FPGA, sem a necessidade de unidades de ponto flutuante, que demandariam muito mais recursos de hardware. O acumulador da unidade MAC utiliza 34 bits para evitar overflow durante as somas sucessivas.

### Extreme Learning Machine (ELM)

A Extreme Learning Machine é um tipo de rede neural de camada única cujos pesos da camada oculta (W_in e b) são fixos e não são ajustados durante o treinamento — apenas os pesos da camada de saída (β) são aprendidos. Isso torna a ELM especialmente adequada para implementação em hardware, pois todos os pesos podem ser armazenados diretamente em blocos de memória da FPGA e carregados via arquivos .mif.

O processo de inferência é dividido em quatro etapas sequenciais. Primeiro, o vetor de entrada x composto pelos 784 pixels é carregado na memória. Em seguida é processada a camada oculta, onde para cada um dos 128 neurônios é calculado h = tanh(W_in · x + b). Depois é processada a camada de saída, calculando y = β · h para cada um dos 10 dígitos possíveis. Por fim, a predição é obtida através da operação argmax(y), que retorna o índice do maior valor entre os 10 resultados, correspondendo ao dígito identificado.

### Operação MAC (Multiply-Accumulate)

A operação MAC é o núcleo computacional da rede neural, realizando sucessivas multiplicações entre dois valores e acumulando os resultados em um registrador. No projeto, a mesma unidade MAC é reutilizada nas duas camadas da rede: na camada oculta, multiplica pixels de 8 bits pelos pesos W_in de 16 bits em Q4.12; na camada de saída, multiplica os valores h pelos pesos β, ambos em Q4.12. A seleção entre os dois modos é feita pelo sinal use_h. O acumulador possui 34 bits para garantir precisão durante as somas sucessivas em ponto fixo.

### Máquina de Estados Finita (FSM)

A FSM é o componente responsável por coordenar e sequenciar todas as operações do co-processador. A FSM de inferência percorre 12 estados: READY, MAC_H, MAC_H_W, MAC_H_LAST, ACTIV, SAVE_H, MAC_Y, MAC_Y_W, MAC_Y_LAST, SAVE_Y, DO_ARGMAX e DONE. Os estados intermediários de espera MAC_H_W e MAC_Y_W foram introduzidos para lidar com a latência de leitura das BRAMs, garantindo que os dados estejam disponíveis no momento correto para a operação MAC. Há ainda um estado WAIT que mantém o resultado visível nos displays por 3 segundos antes de retornar ao estado READY.

### Argmax

O argmax é a operação final da inferência, responsável por identificar o índice do maior valor entre os 10 resultados da camada de saída, correspondendo ao dígito previsto. No projeto, o argmax foi implementado de forma combinacional diretamente dentro da FSM, operando sobre um banco de 10 registradores internos y_reg[0..9] ao invés de uma memória externa, o que simplifica o circuito e reduz a latência desta etapa

## Descrição da Solução

### Arquitetura Geral do Co-processador

O acelerador ELM (elm_accel) é organizado em uma hierarquia de módulos interconectados por barramentos de fios agrupados em três categorias: fios de escrita, que partem da unidade de controle em direção às memórias; fios de leitura, que partem da FSM em direção às memórias; e fios de controle, que conectam a FSM às unidades de processamento MAC e Ativação. Essa separação garante que escrita e leitura nas memórias nunca ocorram simultaneamente, evitando conflitos de acesso.
O fluxo de operação do sistema segue três fases distintas. Na primeira fase, a UC recebe as instruções de carregamento e escreve os dados nas memórias correspondentes, ativando as flags de controle conforme cada memória é preenchida. Na segunda fase, após o recebimento da instrução START com todas as flags ativas, a FSM assume o controle e executa sequencialmente os cálculos das duas camadas da rede neural. Na terceira fase, o resultado da inferência é disponibilizado no registrador pred e exibido no display HEX5 da placa.

### Unidade de Controle (UC)

A UC recebe como entrada as instruções de 32 bits no formato ISA, o sinal instr_valid indicando que uma instrução está disponível, e os sinais infer_done e infer_busy vindos da FSM. Como saída, gera os sinais de escrita para cada memória (endereço, dado e enable de escrita), as flags img_ready, w_ready e b_ready, o sinal start_infer para disparar a FSM, e o status atual do sistema.
A UC opera em dois modos independentes. No fluxo normal, acionado pelo KEY[1], ela decodifica o opcode nos bits [31:28] da instrução e direciona o dado para a memória correta: opcode 0001 escreve na MEM_IMG, opcode 0010 escreve na MEM_WIN, opcode 0011 escreve na MEM_BIAS, e opcode 0100 dispara a inferência. No modo de escrita manual, acionado pelo KEY[3] e isolado do fluxo normal, é possível escrever diretamente em qualquer memória durante testes, sendo bloqueado automaticamente enquanto a inferência estiver em andamento. Um multiplexador de saída prioriza a escrita manual quando ativa, garantindo que os dois modos nunca conflitem.

### Bloco de Memórias

O bloco de memórias instancia cinco RAMs de porta única do tipo M10K, geradas pelo Quartus Prime 23.1 para a FPGA Cyclone V. Cada memória possui uma interface de escrita vinda da UC e uma interface de leitura vinda da FSM, com um multiplexador de endereços que prioriza a escrita quando o sinal de write enable está ativo.
A MEM_IMG armazena 784 posições de 16 bits representando os pixels da imagem de entrada. A MEM_WIN armazena 100.352 posições de 16 bits com os pesos W_in em Q4.12, inicializada com W_in_q.mif. A MEM_BIAS armazena 128 posições de 16 bits com os valores de bias em Q4.12, inicializada com b_q.mif. A MEM_BETA armazena 1.280 posições de 16 bits com os pesos β em Q4.12, inicializada com beta_q.mif. A MEM_H armazena 128 posições de 16 bits com as saídas da camada oculta, sendo escrita pela FSM durante a inferência e lida na camada de saída.

### Unidade MAC

A unidade MAC recebe como entradas os sinais de controle enable, clear_acc, add_bias e use_h, além dos dados pixel, peso, h_in, beta e bias. Como saída, produz o acumulador de 34 bits em Q4.12. Ela opera em dois modos selecionados pelo sinal use_h: no modo camada oculta, multiplica um pixel de 8 bits não-sinalizado pelo peso W_in de 16 bits sinalizado em Q4.12, produzindo um produto de 24 bits; no modo camada de saída, multiplica h de 16 bits sinalizado pelo peso β de 16 bits sinalizado, produzindo um produto de 32 bits. Em ambos os casos o resultado é estendido em sinal e acumulado nos 34 bits do registrador. O sinal add_bias soma o bias diretamente ao acumulador ao final do cálculo de cada neurônio, e o sinal clear_acc zera o acumulador antes de iniciar um novo neurônio ou dígito.

### Função de Ativação (tanh aproximada)

A função de ativação recebe como entrada os bits [27:12] do acumulador MAC, correspondendo à parte inteira e fracionária do resultado em Q4.12, e produz como saída o valor tanh aproximado em Q4.12 no intervalo de -1 a +1. A implementação utiliza 20 segmentos lineares cobrindo o intervalo de -8,0 a +8,0, explorando a simetria tanh(-x) = -tanh(x) para operar sempre sobre o valor absoluto da entrada e aplicar o sinal ao final. Para cada segmento, são definidos um breakpoint x0, um valor y0 e uma inclinação slope, e o resultado é calculado como y = y0 + (x - x0) × slope >> 12. Valores com |x| ≥ 4,5 são saturados diretamente em ±4095 (≈ ±1 em Q4.12).

### Interface com a Placa (top_de1soc)

O módulo top_de1soc realiza a interface entre o acelerador ELM e os periféricos da placa DE1-SoC. Ele implementa detecção de borda para os quatro botões KEY, garantindo que cada pressionamento gere um pulso de exatamente um ciclo de clock. O KEY[0] realiza o reset geral do sistema, o KEY[1] envia uma instrução pelo fluxo normal, o KEY[2] captura e exibe o estado atual nos displays, e o KEY[3] aciona a escrita manual nas memórias.
A instrução enviada pelo KEY[1] é montada a partir das chaves SW, onde SW[3:0] define o opcode e SW[9:4] define o endereço parcial. Os displays HEX0 a HEX4 exibem o estado do sistema em texto — rEAdY, bUSY, donE ou Erro — capturado no momento do pressionamento do KEY[2]. O display HEX5 exibe o dígito predito após a primeira inferência concluída, permanecendo apagado até que o sistema atinja o estado DONE pela primeira vez. Os LEDs LEDR[0], LEDR[1] e LEDR[2] indicam respectivamente se a imagem, os pesos e o bias foram carregados, enquanto LEDR[6] a LEDR[9] refletem o estado atual do sistema.

## Modo de Uso

### Configuração Inicial no Quartus Prime

Antes de operar o sistema na placa, é necessário abrir o In-System Memory Content Editor no Quartus Prime. Nessa ferramenta é possível verificar que as memórias MEM_WIN, MEM_BIAS e MEM_BETA já estão carregadas com os pesos da rede neural através dos arquivos .mif gerados a partir do modelo treinado. O único dado que precisa ser carregado pelo usuário é a imagem de entrada, selecionando o arquivo .mif correspondente diretamente na ferramenta e escrevendo na memória MEM_IMG.

### Operação na Placa

Após carregar a imagem, o sistema já está pronto para operar. Ao ligar a placa, o sistema inicia no estado rEAdY, exibido nos displays de sete segmentos HEX0 a HEX4. Os LEDs LEDR[0], LEDR[1] e LEDR[2] indicam respectivamente se a imagem, os pesos e o bias estão carregados nas memórias.

Os botões e chaves operam da seguinte forma:
* KEY[0] — Reset geral do sistema, retornando ao estado READY
* KEY[1] — Envia a instrução montada pelas chaves SW pelo fluxo normal
* KEY[2] — Captura e exibe o estado atual do sistema nos displays HEX0 a HEX4
* KEY[3] — Grava na memória usando a instrução de escrita manual

As chaves SW controlam as instruções enviadas:
* SW[3:0] — Define o opcode da instrução (0001 = STORE_IMG, 0010 = STORE_WEIGHTS, 0011 = STORE_BIAS, 0100 = START)


Para iniciar a inferência, configure SW[3:0] = 0100 e pressione KEY[1]. O display passará a mostrar bUSY durante o processamento e donE ao término, exibindo o dígito predito no display HEX5.

### Escrita Manual nas Memórias

O sistema possui um mecanismo de escrita manual nas memórias acionado pelo KEY[3], projetado para permitir testes e para servir de base para a integração com o processador ARM nos próximos marcos. Nesse modo, a instrução é montada a partir das chaves SW da seguinte forma:

* SW[3:0] — Define o opcode 
* SW[6:4] — Define os 3 bits de endereço
* SW[9:7] — Define os 3 bits do dado a ser escrito

Ao pressionar KEY[3], a instrução montada é enviada para a UC pelo barramento de escrita manual, que é completamente separado do fluxo normal. Essa escrita é bloqueada automaticamente enquanto a inferência estiver em andamento, evitando corrupção dos dados nas memórias. Esse mecanismo representa o embrião da interface MMIO que será utilizada pelo driver Linux no próximo marco, onde o processador ARM poderá escrever diretamente nas memórias do co-processador via mapeamento de memória.

## Evolução dos Módulos

#### fsm_infer.v
A versão inicial da FSM possuía apenas 8 estados simples: READY, MAC_H, ACTIV, SAVE_H, MAC_Y, SAVE_Y, DO_ARG e DONE. Nessa versão, a FSM avançava diretamente de MAC_H para ACTIV sem aguardar a latência da BRAM, o que causava leitura de dados incorretos nas memórias.
A versão final expandiu para 13 estados, adicionando os estados intermediários MAC_H_W e MAC_H_LAST para a camada oculta, e MAC_Y_W e MAC_Y_LAST para a camada de saída. Esses estados de espera foram introduzidos especificamente para absorver a latência de leitura das BRAMs M10K, garantindo que os dados estejam estáveis antes de serem consumidos pela MAC. Além disso, foi adicionado o estado WAIT, que mantém o resultado visível nos displays por 3 segundos antes de retornar ao READY.
Outra mudança importante foi a remoção da MEM_Y como memória externa — os resultados da camada de saída passaram a ser armazenados em um banco de 10 registradores internos y_reg[0..9], e o argmax passou a ser implementado de forma combinacional diretamente dentro da FSM, eliminando a dependência do módulo externo argmax.v.

### mac.v
A versão inicial da MAC operava apenas no modo camada oculta, multiplicando pixels de 8 bits pelos pesos W_in de 16 bits. O produto era de 24 bits e acumulado em 34 bits.
A versão final adicionou o modo camada de saída, controlado pelo novo sinal use_h. Quando use_h = 1, a MAC multiplica os valores h de 16 bits pelos pesos β de 16 bits, gerando um produto de 32 bits com precisão completa. Isso permitiu reutilizar a mesma unidade MAC nas duas camadas da rede, reduzindo o uso de recursos de hardware.

### uc.v

A versão inicial da UC possuía apenas um barramento de instruções, decodificando os opcodes STORE_IMG, STORE_WEIGHTS, STORE_BIAS, START e STATUS pelo sinal instr_valid. As flags img_ready, w_ready e b_ready eram verificadas internamente antes de disparar a inferência.
A versão final adicionou um segundo barramento completamente independente, o mem_write_instr, acionado pelo sinal mem_write_valid e pelo KEY[3] da placa. Esse modo de escrita manual permite escrever diretamente em qualquer memória durante os testes, sendo bloqueado automaticamente quando a inferência está em andamento via sinal infer_busy. Um multiplexador de saída foi adicionado para priorizar a escrita manual quando ativa, garantindo que os dois modos nunca conflitem.

### mem_block.v

A versão inicial do bloco de memórias utilizava arrays Verilog simples com $readmemh para inicialização, sem instanciar módulos de BRAM dedicados. Essa abordagem funcionava em simulação mas não gerava BRAMs M10K reais na síntese do Quartus.
A versão final substituiu todos os arrays por instâncias dos módulos ram_img, ram_win, ram_bias, ram_beta e ram_h, gerados pelo wizard do Quartus Prime como RAMs de porta única do tipo M10K, inicializadas via arquivos .mif. Essa mudança foi fundamental para que os pesos da rede fossem corretamente armazenados nas BRAMs da FPGA Cyclone V, garantindo o funcionamento real do sistema na placa.

### activation.v

A versão inicial implementava uma aproximação simples da sigmoid dividida em apenas 4 regiões lineares, com breakpoints em 1.0, 2.5 e 4.5 em Q4.12.
A versão final substituiu a sigmoid pela função tanh, muito mais adequada para redes ELM, com uma aproximação por 20 segmentos lineares cobrindo o intervalo de -8.0 a +8.0 em Q4.12. A precisão aumentou significativamente com a adição de 13 breakpoints e slopes calculados para cada segmento, e a saturação passou a ser aplicada em ±4095 (≈ ±1 em Q4.12).

### top_de1soc.v

A versão inicial era bastante simples, com apenas um display HEX0 mostrando o pred e 3 LEDs de status. O reset era direto, sem detecção de borda nos botões.
A versão final expandiu significativamente a interface, adicionando detecção de borda para todos os 4 botões KEY, 6 displays de sete segmentos exibindo o estado em texto e o dígito predito, 10 LEDs com informações detalhadas de status e flags, e suporte ao segundo barramento de escrita manual pelo KEY[3].

## Testes e Validação

### Metodologia de Testes

Os testes do sistema foram realizados em duas etapas principais: validação funcional dos módulos e testes diretos em hardware na placa DE1-SoC.

Inicialmente, foram verificados os sinais de controle e o fluxo de execução utilizando os LEDs e displays da placa, permitindo acompanhar o estado do sistema em tempo real. Em seguida, foram realizados testes completos de inferência, envolvendo o carregamento da imagem, ativação das flags e execução da FSM até a obtenção do resultado final.

A validação foi feita observando o comportamento do sistema durante a execução, verificando se as transições de estado ocorriam corretamente, se os dados eram lidos das memórias de forma adequada e se o valor predito final correspondia ao esperado.

---

### Testes Funcionais

Os testes funcionais foram realizados para garantir o correto funcionamento de cada etapa do sistema.

Inicialmente, foi validado o processo de carregamento dos dados, verificando se as memórias MEM_IMG, MEM_WIN e MEM_BIAS eram corretamente escritas e se as flags img_ready, w_ready e b_ready eram ativadas após a conclusão da escrita.

Em seguida, foi testado o disparo da inferência por meio da instrução START, garantindo que o sistema só iniciasse o processamento quando todas as flags estivessem ativas. Durante a execução, foi possível observar a mudança do estado READY para BUSY e, posteriormente, para DONE.

Também foi validado o funcionamento da FSM ao longo dos estados de execução, verificando se os ciclos de leitura, cálculo na unidade MAC e armazenamento dos resultados ocorriam corretamente. Por fim, foi verificada a exibição do resultado final no display HEX5, confirmando a correta execução da operação de argmax.

---

### Problemas Encontrados e Correções

Durante a fase de testes, alguns problemas foram identificados e corrigidos ao longo do desenvolvimento.

Inicialmente, foi observado que a saída da unidade MAC permanecia constantemente em zero, mesmo com os dados corretamente carregados nas memórias. Esse comportamento indicava que a operação de multiplicação e acumulação não estava sendo executada corretamente. Após análise, verificou-se que o sinal de controle MAC enable não estava sendo ativado nos momentos corretos pela FSM, impedindo a realização dos cálculos. A correção foi realizada ajustando a lógica de controle da FSM para garantir que o sinal MAC enable fosse ativado durante os ciclos de processamento.

Outro problema identificado foi a leitura incorreta de dados das memórias, causada pela não consideração da latência das BRAMs M10K. Como consequência, valores inválidos eram utilizados nas operações. Esse problema foi resolvido com a introdução de estados intermediários de espera, como MAC_H_W e MAC_Y_W, garantindo que os dados estivessem estáveis antes de serem utilizados pela unidade MAC.

Também foi observado comportamento incorreto no acumulador da MAC quando o sinal de limpeza (clear_acc) não era acionado corretamente entre os neurônios. Isso fazia com que valores de execuções anteriores fossem acumulados, gerando resultados incorretos. A solução foi garantir que a FSM sempre ativasse o sinal clear_acc antes do início do cálculo de um novo neurônio.

---

### Validação Final

Após a correção dos problemas identificados, o sistema passou a apresentar comportamento estável e consistente. A inferência é iniciada corretamente apenas quando todas as condições são satisfeitas, os dados são processados conforme esperado e o resultado final é exibido corretamente nos displays da placa.

Dessa forma, foi possível validar o funcionamento completo do co-processador, desde o carregamento dos dados até a obtenção da predição final. 

### Uso de Recursos

O relatório de síntese gerado pelo Quartus Prime 23.1 apresenta o seguinte consumo de recursos da FPGA Cyclone V (DE1-SoC) após a implementação completa do sistema:

img

O uso de ALMs e registradores é bastante reduzido, representando apenas 4% e 2% do dispositivo respectivamente, o que demonstra que a lógica de controle e o datapath do co-processador são eficientes em termos de área.
Os 5 DSP Blocks correspondem aos multiplicadores utilizados pela unidade MAC, que realiza as operações de multiplicação entre pixels e pesos na camada oculta, e entre os valores h e os pesos β na camada de saída.
O uso de 204 blocos M10K representa 51% da memória disponível no dispositivo, acima do limite de referência de 100 blocos indicado no barema. Esse consumo elevado é justificado pelo tamanho da memória MEM_WIN, que armazena os 100.352 pesos W_in da camada oculta da rede ELM — resultado direto da arquitetura da rede, que possui 128 neurônios ocultos operando sobre 784 pixels de entrada. Trata-se de uma limitação inerente ao modelo ELM utilizado, e não de um problema de implementação. As demais memórias (MEM_BIAS, MEM_BETA, MEM_H e MEM_IMG) consomem uma quantidade significativamente menor de blocos M10K.


## Conclusão

O desenvolvimento do projeto de classificação de imagens em FPGA permitiu colocar em prática conceitos fundamentais de sistemas digitais e arquitetura de computadores, resultando em um co-processador funcional capaz de identificar dígitos numéricos através de uma rede neural ELM implementada inteiramente em hardware.

Todos os requisitos propostos foram atendidos. O sistema realiza corretamente a inferência da rede neural, exibindo o dígito predito nos displays da placa DE1-SoC, com o conjunto de instruções ISA funcionando conforme especificado e a interface com a placa respondendo adequadamente aos botões e chaves.

Ao longo do desenvolvimento, a equipe aprofundou seus conhecimentos em diversas áreas. A implementação do conjunto de instruções ISA trouxe uma compreensão prática de como um co-processador se comunica com o mundo externo. O estudo da rede neural ELM permitiu entender como algoritmos de aprendizado de máquina podem ser traduzidos para hardware. A representação em ponto fixo Q4.12, o uso de arquivos .mif para inicialização das memórias e a utilização das BRAMs M10K da FPGA foram aspectos que exigiram aprendizado específico e contribuíram para um entendimento mais profundo do funcionamento das memórias em hardware. O projeto também contribuiu para o aperfeiçoamento do conhecimento em Verilog, máquinas de estados finitas e na utilização dos recursos da placa DE1-SoC.

Apesar dos resultados obtidos, alguns pontos de melhoria foram identificados durante o desenvolvimento do projeto.Um dos principais aspectos a ser aprimorado está relacionado ao fluxo de carregamento de dados. Atualmente, o sistema exige um reset completo para a execução de uma nova inferência, o que implica no recarregamento de todos os parâmetros da rede, incluindo pesos e bias. Em uma arquitetura mais eficiente, esses dados deveriam ser carregados apenas uma vez, permitindo que múltiplas inferências fossem realizadas apenas com a atualização da imagem de entrada. Essa melhoria reduziria o tempo de operação e tornaria o sistema mais próximo de aplicações reais.

Outro ponto importante é a limitação da interface atual, que depende exclusivamente de botões da placa para envio de instruções. Essa abordagem dificulta a integração com o processador ARM presente no SoC. Como evolução do projeto, seria ideal implementar uma interface baseada em mapeamento de memória (MMIO), permitindo que o processador controle o co-processador diretamente por meio de leitura e escrita em registradores, eliminando a dependência de interação manual.

Por fim, melhorias na organização da arquitetura de controle também poderiam ser exploradas, como uma separação mais clara entre os estados de carregamento e inferência, garantindo maior flexibilidade e escalabilidade para futuras expansões do sistema.