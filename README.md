# FPGA-ELM-Image-Classifier
MI - Sistemas Digitais (PBL) 

# Introdução e Definição do Problema

Este relatório descreve o desenvolvimento da primeira etapa de um sistema embarcado voltado para a classificação de imagens de dígitos numéricos. O sistema completo será implementado em um SoC (System on Chip) heterogêneo, composto por um processador ARM integrado a uma FPGA, e será construído ao longo de múltiplos marcos de desenvolvimento.
No Marco 1, foco deste relatório, é apresentado o projeto e a implementação do núcleo classificador de imagens em FPGA, descrito na linguagem Verilog. Trata-se de um co-processador com conjunto próprio de instruções (ISA), responsável por realizar a inferência de uma rede neural baseada em Extreme Learning Machine (ELM), capaz de identificar dígitos numéricos a partir de imagens em escala de cinza.
O tema central do trabalho é a implementação de um algoritmo de classificação em um circuito especializado em FPGA, integrando conceitos de arquitetura de computadores, circuitos digitais e aceleração por hardware.

# Requisitos Principais

O objetivo central do projeto é desenvolver um sistema capaz de receber uma imagem e identificar automaticamente qual dígito numérico ela representa. Para isso, o sistema utiliza uma rede neural embarcada diretamente em hardware, eliminando a necessidade de um processador externo para realizar a classificação.

**Entrada e Saída**

A entrada do sistema é uma imagem em escala de cinza de 28×28 pixels, com 8 bits por pixel, no formato PNG, totalizando 784 bytes. Cada imagem contém apenas um dígito numérico. A saída é um número inteiro no intervalo de 0 a 9, correspondente ao dígito identificado.

**Co-processador — Núcleo ELM em Verilog**

O núcleo classificador foi descrito em Verilog com arquitetura sequencial, contendo FSM de controle, unidade MAC (Multiply-Accumulate) para as operações de multiplicação e acumulação das camadas da rede neural, função de ativação aproximada via LUT, bloco argmax, memórias dedicadas e banco de registradores. Os valores são representados em ponto fixo no formato Q4.12 e os pesos da rede (W_in, b e β) são armazenados em blocos de memória com estratégia definida de acesso.