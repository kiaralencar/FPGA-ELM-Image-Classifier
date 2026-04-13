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