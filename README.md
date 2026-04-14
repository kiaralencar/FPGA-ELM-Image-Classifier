# FPGA-ELM-Image-Classifier

## Introdução e Definição do Problema

Este relatório descreve o desenvolvimento da primeira etapa de um sistema embarcado voltado para a classificação de imagens de dígitos numéricos. O sistema completo será implementado em um SoC (System on Chip) heterogêneo, composto por um processador ARM integrado a uma FPGA, e será construído ao longo de três marcos de desenvolvimento.
No Marco 1, foco deste relatório, é apresentado o projeto e a implementação do núcleo classificador de imagens em FPGA, descrito na linguagem Verilog e sintetizado utilizando o Quartus Prime 23.1 para a placa DE1-SoC. Trata-se de um co-processador com conjunto próprio de instruções (ISA), responsável por realizar a inferência de uma rede neural baseada em Extreme Learning Machine (ELM), capaz de identificar dígitos numéricos a partir de imagens em escala de cinza de 28×28 pixels.
O sistema foi desenvolvido de forma autossuficiente na FPGA, permitindo o carregamento dos dados, a execução da inferência e a visualização do resultado diretamente na placa, através dos botões, chaves e displays de sete segmentos disponíveis na DE1-SoC. O tema central do trabalho é a implementação de um algoritmo de classificação em um circuito especializado em FPGA, integrando conceitos de arquitetura de computadores, circuitos digitais e aceleração por hardware.
## Requisitos Principais

### Entrada e Saída

O sistema recebe como entrada uma imagem em escala de cinza com resolução de 28×28 pixels, onde cada pixel é representado por 8 bits, assumindo valores no intervalo de 0 a 255, totalizando 784 bytes. A saída é um número inteiro pred correspondente ao dígito identificado, no intervalo de 0 a 9, exibido no display de sete segmentos HEX5 da placa.

### Co-processador

O núcleo classificador foi implementado em Verilog com arquitetura sequencial, contendo uma FSM de controle com 12 estados para gerenciar o fluxo de execução, uma unidade MAC dual-mode para as operações de multiplicação e acumulação das duas camadas da rede neural, uma função de ativação aproximada da tanh por 20 segmentos lineares em Q4.12, e um bloco argmax combinacional embutido diretamente na FSM para determinar o dígito com maior valor de saída. Os valores são representados em ponto fixo no formato Q4.12. 

### Sistema de Memórias

O sistema utiliza cinco blocos de memória M10K da FPGA Cyclone V: MEM_IMG para armazenar os 784 pixels da imagem de entrada, MEM_WIN para os pesos W_in, MEM_BIAS para o bias b, MEM_BETA para os pesos β, e MEM_H para as saídas da camada oculta. Os pesos são inicializados via arquivos .mif gerados a partir do modelo treinado. O acesso às memórias é gerenciado por um multiplexador de endereços que prioriza a escrita quando necessário.

### Conjunto de Instruções (ISA)

O co-processador possui um conjunto próprio de instruções de 32 bits. As instruções disponíveis são STORE_IMG para carregar a imagem, STORE_WEIGHTS para carregar os pesos W_in e β, STORE_BIAS para carregar o bias, START para disparar a inferência, e STATUS para consultar o estado atual, retornando BUSY, DONE ou ERROR.

### Interface com a Placa

A interface com a placa DE1-SoC foi implementada no módulo top_de1soc, utilizando os botões KEY, chaves SW e displays de sete segmentos. O KEY[0] realiza o reset do sistema, o KEY[1] envia instruções pelo fluxo normal, o KEY[2] captura e exibe o estado nos displays, e o KEY[3] permite escrita manual nas memórias. Os displays HEX0 a HEX4 exibem o estado atual do sistema em texto ( BUSY, DONE, ERROR) e o HEX5 exibe o dígito predito. Os LEDs indicam o estado das flags img_ready, w_ready e b_ready, além do status geral do processamento.


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

O acelerador ELM (elm_accel) é organizado em uma hierarquia de módulos interconectados por barramentos de fios agrupados em três categorias: fios de escrita, que partem da UC em direção às memórias; fios de leitura, que partem da FSM em direção às memórias; e fios de controle, que conectam a FSM às unidades de processamento MAC e Ativação. Essa separação garante que escrita e leitura nas memórias nunca ocorram simultaneamente, evitando conflitos de acesso.
O fluxo de operação do sistema segue três fases distintas. Na primeira fase, a UC recebe as instruções de carregamento e escreve os dados nas memórias correspondentes, ativando as flags de controle conforme cada memória é preenchida. Na segunda fase, após o recebimento da instrução START com todas as flags ativas, a FSM assume o controle e executa sequencialmente os cálculos das duas camadas da rede neural. Na terceira fase, o resultado da inferência é disponibilizado no registrador pred e exibido no display HEX5 da placa.

### Unidade de Controle (UC)

A UC recebe como entrada as instruções de 32 bits no formato ISA, o sinal instr_valid indicando que uma instrução está disponível, e os sinais infer_done e infer_busy vindos da FSM. Como saída, gera os sinais de escrita para cada memória (endereço, dado e enable de escrita), as flags img_ready, w_ready e b_ready, o sinal start_infer para disparar a FSM, e o status atual do sistema.
A UC opera em dois modos independentes. No fluxo normal, acionado pelo KEY[1], ela decodifica o opcode nos bits [31:28] da instrução e direciona o dado para a memória correta: opcode 0001 escreve na MEM_IMG, opcode 0010 escreve na MEM_WIN, opcode 0011 escreve na MEM_BIAS, e opcode 0100 dispara a inferência. No modo de escrita manual, acionado pelo KEY[3] e isolado do fluxo normal, é possível escrever diretamente em qualquer memória durante testes, sendo bloqueado automaticamente enquanto a inferência estiver em andamento. Um multiplexador de saída prioriza a escrita manual quando ativa, garantindo que os dois modos nunca conflitem.

### Bloco de Memórias

O bloco de memórias instancia cinco RAMs de porta única do tipo M10K, geradas pelo Quartus Prime 23.1 para a FPGA Cyclone V. Cada memória possui uma interface de escrita vinda da UC e uma interface de leitura vinda da FSM, com um multiplexador de endereços que prioriza a escrita quando o sinal de write enable está ativo.
A MEM_IMG armazena 784 posições de 16 bits representando os pixels da imagem de entrada, inicializada com o arquivo 2.mif. A MEM_WIN armazena 100.352 posições de 16 bits com os pesos W_in em Q4.12, inicializada com W_in_q.mif. A MEM_BIAS armazena 128 posições de 16 bits com os valores de bias em Q4.12, inicializada com b_q.mif. A MEM_BETA armazena 1.280 posições de 16 bits com os pesos β em Q4.12, inicializada com beta_q.mif. A MEM_H armazena 128 posições de 16 bits com as saídas da camada oculta, sendo escrita pela FSM durante a inferência e lida na camada de saída.

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

Após carregar a imagem, o sistema já está pronto para operar. Ao ligar a placa, o sistema inicia no estado rEAdY, exibido nos displays de sete segmentos HEX0 a HEX4. Os LEDs LEDR[0], LEDR[1] e LEDR[2] indicam respectivamente se a imagem, os pesos W_in e o bias estão carregados nas memórias.
Os botões e chaves operam da seguinte forma:

KEY[0] — Reset geral do sistema, retornando ao estado READY
KEY[1] — Envia a instrução montada pelas chaves SW pelo fluxo normal
KEY[2] — Captura e exibe o estado atual do sistema nos displays HEX0 a HEX4
KEY[3] — Grava na memória usando a instrução de escrita manual

As chaves SW controlam as instruções enviadas:

SW[3:0] — Define o opcode da instrução (0001 = STORE_IMG, 0010 = STORE_WEIGHTS, 0011 = STORE_BIAS, 0100 = START)
SW[9:4] — Define o endereço parcial no fluxo normal

Para iniciar a inferência, configure SW[3:0] = 0100 e pressione KEY[1]. O display passará a mostrar bUSY durante o processamento e donE ao término, exibindo o dígito predito no display HEX5.

### Escrita Manual nas Memórias

O sistema possui um mecanismo de escrita manual nas memórias acionado pelo KEY[3], projetado para permitir testes e para servir de base para a integração com o processador ARM nos próximos marcos. Nesse modo, a instrução é montada a partir das chaves SW da seguinte forma:

SW[3:0] — Define o opcode (1 = MEM_IMG, 2 = MEM_WIN, 3 = MEM_BIAS, 6 = MEM_BETA)
SW[6:4] — Define os 3 bits de endereço
SW[9:7] — Define os 3 bits do dado a ser escrito

Ao pressionar KEY[3], a instrução montada é enviada para a UC pelo barramento de escrita manual, que é completamente separado do fluxo normal. Essa escrita é bloqueada automaticamente enquanto a inferência estiver em andamento, evitando corrupção dos dados nas memórias. Esse mecanismo representa o embrião da interface MMIO que será utilizada pelo driver Linux no próximo marco, onde o processador ARM poderá escrever diretamente nas memórias do co-processador via mapeamento de memória.

## Conclusão

O desenvolvimento do projeto de classificação de imagens em FPGA permitiu colocar em prática conceitos fundamentais de sistemas digitais e arquitetura de computadores, resultando em um co-processador funcional capaz de identificar dígitos numéricos através de uma rede neural ELM implementada inteiramente em hardware.

Todos os requisitos propostos foram atendidos. O sistema realiza corretamente a inferência da rede neural, exibindo o dígito predito nos displays da placa DE1-SoC, com o conjunto de instruções ISA funcionando conforme especificado e a interface com a placa respondendo adequadamente aos botões e chaves.

Ao longo do desenvolvimento, a equipe aprofundou seus conhecimentos em diversas áreas. A implementação do conjunto de instruções ISA trouxe uma compreensão prática de como um co-processador se comunica com o mundo externo. O estudo da rede neural ELM permitiu entender como algoritmos de aprendizado de máquina podem ser traduzidos para hardware. A representação em ponto fixo Q4.12, o uso de arquivos .mif para inicialização das memórias e a utilização das BRAMs M10K da FPGA foram aspectos que exigiram aprendizado específico e contribuíram para um entendimento mais profundo do funcionamento das memórias em hardware. O projeto também contribuiu para o aperfeiçoamento do conhecimento em Verilog, máquinas de estados finitas e na utilização dos recursos da placa DE1-SoC.