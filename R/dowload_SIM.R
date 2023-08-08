#' Criar base de dados do Sistema de Informação de Mortalidade (SIM) do Sistema Único de Saúde (SUS)
#'
#' Esta função baixa arquivos .dbc do Sistema de Informação de Mortalidade da página de microdados do Sistema Único de Saúde.
#'
#' @param uf Uma string indicando a Unidade Federativa (estado) de interesse, utilizando a abreviatura de duas letras (exemplo: "SP").
#' @param periodo Um vetor com dois ou um valor(es): São string indicando o periodo do início do intervalo das publicações requeridas no formato "AAAA".
#' @param dir Uma string indicando o diretório de saída em que os arquivos serão armazenados (o padrão é o diretório criado dentro da pasta Documentos do Usuário).
#' @param filename Uma string indicando o nome do arquivo para o arquivo baixado (o padrão é construído com base nos parâmetros de entrada do diretório da pasta Documentos do usuário).
#'
#' @return Um banco de dados no environment do RStudio
#'
#' @examples
#' \dontrun{
#' download_SIM (uf = "CE", periodo = c(1996, 2021), dir = ".", filename = NULL),
#' download_SIM (uf = c("AL", "BA", "CE", "MA", "PB", "PE", "PI", "RN", "SE"), periodo = 2021, dir = ".", filename = NULL),
#' download_SIM (uf = "CE", periodo = c(1996:2021), dir = ".", filename = NULL)
#' }
#'
#' @export

download_SIM <- function(uf, periodo, dir = ".", filename = NULL) {
  
  # Carrega pacotes ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  # Carrega o pacote pacman
  if (!require(pacman)) {
    install.packages("pacman")
    library(pacman)
  }
  
  pacman::p_load(furrr, fs, curl, httr, foreign, data.table, tibble,
                 stringi, stringr, progressr, writexl, dplyr, openxlsx, readxl)

  # Move a pasta read.dbc para o library do usuário ++++++++++++++++++++++++++++
  
  if (file.exists(file.path(system.file(package = "read.dbc")))) {
  cat("O arquivo 'read.dbc' Já existe no diretório")
} else {
  # Caminho completo da pasta "read.dbc"
  caminho_pasta <- system.file("Arquivos_externos", package = "PAINELSIMDATASUS")
  caminho_completo <- file.path(caminho_pasta, "read.dbc")
  
  # Diretório de destino
  dest_dir <- file.path(system.file(package = "stats"))
  dest_dir <- gsub('stats','', dest_dir)
  
  # Move o arquivo para o diretório de destino
  novo_caminho_completo <- file.path(dest_dir, "read.dbc")
  file.rename(caminho_completo, novo_caminho_completo)
  cat("O arquivo 'read.dbc' foi movido com sucesso para:", novo_caminho_completo)
}
  
  # Transformacao dos parametros ++++++++++++++++++++++++++++++++++++
  
  # Transforma a entrada de uf em um vetor, se necessário
  if (!is.vector(uf)) uf <- as.vector(uf)
  
  # Transforma a entrada de periodo em um vetor, se necessário
  if (!is.vector(periodo)) periodo <- as.vector(periodo)
  
  # Diretorio e arquivos +++++++++++++++++++++++++++++++++++++++++++++++++++++++
  
  # Define o diretório de destino dos arquivos baixados
  dir_destino <- file.path(dir, "SIM")
  
  # Verifica se o diretório de destino existe, caso contrário, cria o diretório
  if (!dir.exists(dir_destino)) {
    dir.create(dir_destino, recursive = TRUE)
    cat(paste0("O direório ", dir_destino, " foi criado.\n"))
  }
  
  # Informa o diretório de sada ao usuário
  cat(paste0("Os arquivos serão salvos em: ", dir_destino, "\n"))
  
  # Verificar se os arquivos .DBC correspondentes já existem
  arquivos_existentes <- FALSE
  for (i in 1:length(uf)) {
    for (j in 1:length(periodo)) {
      file_name <- paste0("DO", uf[i], periodo[j], ".DBC")
      file_path <- file.path(dir_destino, file_name)
      if (file.exists(file_path)) {
        arquivos_existentes <- TRUE
        break
      }
    }
  }
  
  # Iniciar o processo somente se os arquivos .DBC não existirem
  if (!arquivos_existentes) {
    # Transformacao dos parametros
    if (!is.vector(uf)) uf <- as.vector(uf)
    if (!is.vector(periodo)) periodo <- as.vector(periodo)
  
    # URL base para o site do DATASUS
    base_url <- "ftp://ftp.datasus.gov.br/dissemin/publicos/SIM/CID10/DORES/"
    
    # Baixa arquivo(os) ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    # Define as colunas do dataframe SIM
    SIM = data.frame(UF = character(),
                      ANO = integer(),
                      stringsAsFactors = FALSE)
    
    # Loop pelos valores de uf e periodo para baixar os arquivos correspondentes
    for (i in 1:length(uf)) {
      for (j in 1:length(periodo)) {
        
        # Verifica se a extensão está como .dbc ou .DBC na URL
        file_name <- stri_c("DO", uf[i], periodo[j], ".dbc")
        url <- stri_paste(base_url, file_name)
        if (identical(httr::status_code(httr::GET(url)), 200L)) {
          file_name <- file_name
        } else {
          file_name <- stri_c("DO", uf[i], periodo[j], ".DBC")
          url <- stri_paste(base_url, file_name)
          if (identical(httr::status_code(httr::GET(url)), 200L)) {
            file_name <- file_name
          }
        }
        
        # Cria conexão com a URL e baixa o arquivo
        url <- stri_paste(base_url, file_name)
        file_name_local <- stri_replace_last_fixed(file_name, ".dbc", ".DBC")
        curl_download(url, file.path(dir_destino, file_name_local))
        
        # Lê o arquivo e salva em um dataframe
        cat(paste0("Lendo o arquivo ", file_name, "\n"))
        file_path <- file.path(dir_destino, file_name)
        file_ext <- tools::file_ext(file_path)
        
        if (file_ext == "dbf") {
          file_df <- foreign::read.dbf(gzfile(file_path))
        } else if (file_ext == "dbc" | file_ext == "DBC") {
          file_df <- read.dbc::read.dbc(file_path)
        } else {
          stop(paste0("O arquivo ", file_name, " não está no formato DBC ou DBF."))
        }
        
        # Adiciona as colunas UF e período
        file_df$UF <- uf[i]
        file_df$ANO <- periodo[j]
        
        # Adiciona os dados ao dataframe SIM
        SIM <- rbind(SIM, file_df)
      }
    }
    
  } else {
    mensagem_aviso <- "Os arquivos .DBC correspondentes já existem. O download não será iniciado."
    print(mensagem_aviso)
    
    # Ler os arquivos .DBC existentes em dir_destino
    if (arquivos_existentes) {
      for (i in 1:length(uf)) {
        for (j in 1:length(periodo)) {
          file_name <- paste0("DO", uf[i], periodo[j], ".DBC")
          file_path <- file.path(dir_destino, file_name)
          if (file.exists(file_path)) {
            # Lê o arquivo e salva em um dataframe
            cat(paste0("Lendo o arquivo ", file_name, "\n"))
            file_ext <- tools::file_ext(file_path)
            
            if (file_ext == "dbf") {
              file_df <- foreign::read.dbf(gzfile(file_path))
            } else if (file_ext == "dbc" | file_ext == "DBC") {
              file_df <- read.dbc::read.dbc(file_path)
            } else {
              stop(paste0("O arquivo ", file_name, " não está no formato DBC ou DBF."))
            }
            
            # Adiciona as colunas UF e período
            file_df$UF <- uf[i]
            file_df$ANO <- periodo[j]
            
            # Adiciona os dados ao dataframe SIM
            SIM <- rbind(file_df)
          }
        }
      }
    }
  }
  
  # Tratamento dos dados +++++++++++++++++++++++++++++++++++++++++++++++++++++++
  
  # Removendo coluna contador
  SIM =
    SIM %>%
    select(-CONTADOR)
  
  # Criando coluna Óbito fetal e até 11 meses
  SIM$`Obito fetal e até 11 meses` <- NA
  
  
  # Substituir somente o segundo "*" por "|"
  for (coluna in colnames(SIM)) {
    if (grepl("^LINHA", coluna)) {
      SIM[[coluna]] <- gsub("^(.*?\\*.*?\\*)", "\\1|", SIM[[coluna]])
    }
  }
  
  # Substituir o restante dos "*"
  for (coluna in colnames(SIM)) {
    SIM[[coluna]] <- gsub("\\*", "", SIM[[coluna]])
  }
  
  # Inserindo arquivos externos para descodificação ++++++++++++++++++++++++++++
  
  # Importar os arquivos XLSX para juntar ao SIM
  # Identifica o caminho do pacote
  # Adiciona a pasta de arquivos que contém CBO, CID e Municipios
  caminho_pasta <- system.file("Arquivos_externos", package = "PaineisPublicos")
  
  # Obtém a lista de arquivos na pasta
  arquivos <- list.files(caminho_pasta)
  
  # Criar uma lista para armazenar os dados dos arquivos XLSX
  dados_xlsx <- list()
  
  # Itera sobre cada arquivo e realiza a leitura dos arquivos .xlsx
  for (arquivo in arquivos) {
    caminho_arquivo <- file.path(caminho_pasta, arquivo)
    
    # Verifica se o arquivo possui a extensão .xlsx e não começa com ~$
    
    if (grepl("\\.xlsx$", arquivo, ignore.case = TRUE)) {
      # Realiza a leitura do arquivo usando read_excel
      dados_xlsx[[arquivo]] <- readxl::read_excel(caminho_arquivo)
    }
  }
  
  # Os dataframes CBO, CID e municipio serão usados somente no Power BI,
  #já que o merge utiliza mais do que o disponível de memória do R
  CBO = dados_xlsx$CBO.xlsx
  CID = dados_xlsx$CID.xlsx
  Municipio = dados_xlsx$Municipios
  Descricao = dados_xlsx$Descricao.xlsx
  rm(dados_xlsx)
  
  # Remover duplicatas da coluna COD_OCUPACAO
  CBO = subset(CBO, !duplicated(COD_OCUPACAO))
  
  # Convertendo todas as colunas de Descricao para caracteres
  Descricao = dplyr::mutate_all(Descricao, as.character)
  
  # Identificar colunas do SIM e Descricao que não possuem prefixo IDADE ou PESO
  colunas_substituir <- colnames(SIM)[!(grepl("^IDADE", colnames(SIM)) | grepl("^PESO", colnames(SIM)))]
  colunas_descricao <- paste0(colunas_substituir, "_DESC")
  
  for (coluna in colunas_substituir) {
    coluna_descricao <- paste0(coluna, "_DESC")
    if (coluna_descricao %in% colnames(Descricao)) {
      if (coluna %in% c("IDADE", "IDADEF", "IDADEMAE", "PESO")) {
        next  # Ignorar as colunas IDADE, IDADEMAE e PESO
      } else {
        indices <- tryCatch(
          match(SIM[[coluna]], Descricao[[coluna]]),
          error = function(e) NULL
        )
        
        if (!is.null(indices)) {
          indices <- indices[!is.na(indices) & !is.na(SIM[[coluna]])]  # Remover NA
          
          if (length(indices) > 0) {
            suppressWarnings({
              SIM[[coluna]][!is.na(SIM[[coluna]])] <- Descricao[[coluna_descricao]][indices]
            })
          }
        }
      }
    }
  }
  
  # Transformar as colunas de IDADE, IDADEMAE e PESO de acordo com os intervalos definidos em Descricao
  tryCatch({
    # Substituir os valores da coluna SIM$`Obito fetal e até 11 meses` pelos valores de Descricao$DESC_IDADEF
    suppressWarnings({
      for (i in 1:nrow(Descricao)) {
        intervalo <- Descricao[i, c("IDADE3", "IDADE4")]
        substituicao <- Descricao[i, "DESC_IDADEF"]
        SIM$`Obito fetal e até 11 meses`[as.numeric(SIM$IDADE) >= as.numeric(intervalo[1]) & as.numeric(SIM$IDADE) <= as.numeric(intervalo[2])] <- substituicao
      }
    })
    
    # Substituir os valores da coluna SIM$IDADE pelos valores de Descricao$Desc_IDADE
    suppressWarnings({
      for (i in 1:nrow(Descricao)) {
        intervalo <- Descricao[i, c("IDADE1", "IDADE2")]
        substituicao <- Descricao[i, "Desc_IDADE"]
        SIM$IDADE[as.numeric(SIM$IDADE) >= as.numeric(intervalo[1]) & as.numeric(SIM$IDADE) <= as.numeric(intervalo[2])] <- substituicao
      }
    })
    
    # Substituir os valores da coluna SIM$IDADEMAE pelos valores de Descricao$IDADEMAE_DESC
    suppressWarnings({
      for (i in 1:nrow(Descricao)) {
        intervalo <- Descricao[i, c("IDADEMAE1", "IDADEMAE2")]
        substituicao <- Descricao[i, "IDADEMAE_DESC"]
        SIM$IDADEMAE[as.numeric(SIM$IDADEMAE) >= as.numeric(intervalo[1]) & as.numeric(SIM$IDADEMAE) <= as.numeric(intervalo[2])] <- substituicao
      }
    })
    
    # Substituir os valores da coluna SIM$PESO pelos valores de Descricao$PESO_DESC
    suppressWarnings({
      for (i in 1:nrow(Descricao)) {
        intervalo <- Descricao[i, c("PESO1", "PESO2")]
        substituicao <- Descricao[i, "PESO_DESC"]
        SIM$PESO[as.numeric(SIM$PESO) >= as.numeric(intervalo[1]) & as.numeric(SIM$PESO) <= as.numeric(intervalo[2])] <- substituicao
      }
    })
  }, error = function(e) {
    # Ação a ser executada caso ocorra um erro
    # Por exemplo, imprimir uma mensagem de erro
    mensagem_erro <- "Ocorreu um erro ao realizar o tratamento dos dados"
    print(mensagem_erro)
  })
  
  # Converter os resultados das colunas de lista para caracteres
  SIM$`Obito fetal e até 11 meses` <- as.character(unlist(SIM$`Obito fetal e até 11 meses`))
  SIM$IDADE <- as.character(unlist(SIM$IDADE))
  SIM$IDADEMAE <- as.character(unlist(SIM$IDADEMAE))
  SIM$PESO <- as.character(unlist(SIM$PESO))
  
  # adicionando coluna de ID
  SIM =
    SIM %>%
    mutate(ID = row_number())
  
  # adicionando coluna para contar a quantidade de óbitos
  SIM =
    SIM %>%
    mutate(`Obitos` = 1)
  
  # Seção óbitos em mulher fértil: Situação gestacional ou pósgestacional em que ocorreu o óbito
  SIM = 
    SIM %>%
    mutate(
      `Obito na gravidez`= case_when(
        TPMORTEOCO %in% c("Durante a gestação", "Durante o abortamento", "Após o abortamento") ~ "Sim",
        TPMORTEOCO %in% c("Entre 43 dias e até 1 ano após o parto", "A investigação não identificou o momento do óbito" ,"Mais de um ano após o parto") ~ "Não",
        TPMORTEOCO %in% c("O óbito não ocorreu nas circunstâncias anteriores") ~ "Ignorado",
        TRUE ~ "Não informado"),
      
      `Obito no puerpério`= case_when(
        TPMORTEOCO == "No parto ou até 1 hora após o parto" ~ "Sim, até 42 dias após o parto",
        TPMORTEOCO ==  "No puerpério - até 42 dias após o parto" ~ "Sim, de 43 dias a 1 ano",
        TPMORTEOCO %in% c("Durante a gestação", "Durante o abortamento", "Após o abortamento") ~ "Não",
        TPMORTEOCO == "O óbito não ocorreu nas circunstâncias anteriores" ~ "Ignorado",
        TRUE ~ "Não informado")
    )
  
  # Computar os casos não preenchidos em TPMORTEOCO
  # Mulheres Elegíveis
  SIM = 
    SIM %>%
    mutate(
      MULHERES_ELEGIVEIS = if_else(
        SEXO == "Feminino" & 
          IDADE %in% c("10-14", "15-19", "20-24","25-29","30-34","35-39","40-44","45-49"), 1, 0 ),
      MULHERES_ELEGIVEIS_SEM_PREEN = if_else(MULHERES_ELEGIVEIS == 1 & TPMORTEOCO == "Não informado", 1, 0)
    )
  
  # Criando tabela Razão de óbito para classificar os CID's do médico e sistema ++
  
  # Separando CAUSABAS e CAUSABAS_O, LINHAA e LINHAA_O
  # Variável derivada
  # CAUSABAS_O e CAUSABAS
  OBITO_M <- SIM %>%
    select(ID, CAUSABAS_O)
  
  OBITO_S <- SIM %>%
    select(ID, CAUSABAS)
  
  # Criar coluna para identificar médico e sistema e substituir a LINHA e LINHA_O por LINHA
  OBITO_S <- OBITO_S %>%
    mutate(Identif = "Após Codificação e Investigação")  # Sistema
  
  OBITO_M <- OBITO_M %>%
    mutate(Identif = "Atestado pelo Médico") %>%  # Médico
    rename(CAUSABAS = CAUSABAS_O)
  
  # Juntando os dois bancos
  Razao_de_obito <- full_join(OBITO_S, OBITO_M, by = c("ID", "CAUSABAS", "Identif"))
  rm(OBITO_M, OBITO_S)
  
  # Tramsformar colunas de data e de hora para formato YYY-mm-dd e HH:MM +++++++++
  
  # Identificar e transformar colunas com prefixo DT em formato YYY-mm-dd
  for (coluna in colnames(SIM)) {
    if (grepl("^DT", coluna)) {
      SIM[[coluna]] <- as.Date(SIM[[coluna]], format = "%d%m%Y")
      SIM[[coluna]] <- format(SIM[[coluna]], "%Y-%m-%d")
    }
  }
  
  # Transformar a coluna HORAOBITO em formato HH:MM
  SIM$HORAOBITO <- format(as.POSIXct(SIM$HORAOBITO, format = "%H%M"), "%H:%M")
  
  # Transformar todos os NA do SIM em "Sem Informação", exceto nas linhas em que TIPOBITO for "Óbito fetal"
  SIM = SIM %>%
    mutate(across(everything(), ~ ifelse(is.na(.) & TIPOBITO != "Óbito fetal", "Sem Informação", .)))

  # Código auxiliar para organizar e classificar as variáveis ++++++++++++++++++++
  SIM =
    SIM %>%
    mutate(
      IDADE_COD = case_when(
        IDADE == "0-4" ~ 1,
        IDADE == "5-9" ~ 2,
        IDADE == "10-14" ~ 3,
        IDADE == "15-19" ~ 4,
        IDADE == "20-24" ~ 5,
        IDADE == "25-29" ~ 6,
        IDADE == "30-34" ~ 7,
        IDADE == "35-39" ~ 8,
        IDADE == "40-44" ~ 9,
        IDADE == "45-49" ~ 10,
        IDADE == "50-54" ~ 11,
        IDADE == "55-59" ~ 12,
        IDADE == "60-64" ~ 13,
        IDADE == "65-69" ~ 14,
        IDADE == "70-74" ~ 15,
        IDADE == "75-79" ~ 16,
        IDADE == "80-84" ~ 17,
        IDADE == "85-89" ~ 18,
        IDADE == "90+" ~ 19
      ),
      ESC2010_COD = case_when(
        ESC2010 == "Sem escolaridade" ~ 1,
        ESC2010 == "Fundamental I (1ª a 4ª série)" ~ 2,
        ESC2010 == "Fundamental II (5ª a 8ª série)" ~ 3,
        ESC2010 == "Médio (antigo 2º Grau)" ~ 4,
        ESC2010 == "Superior incompleto" ~ 5,
        ESC2010 == "Superior completo" ~ 6,
        ESC2010 == "Ignorado" ~ 7,
        ESC2010 == "Sem Informação" ~ 8
      ),
      TPMORTEOCO_COD = case_when(
        TPMORTEOCO == "Gravidez" ~ 1,
        TPMORTEOCO == "Abortamento" ~ 2,
        TPMORTEOCO == "Parto" ~ 3,
        TPMORTEOCO == "Até 42 dias após o término do parto" ~ 4,
        TPMORTEOCO == "De 43 dias a 1 ano após o término da gestação" ~ 5,
        TPMORTEOCO == "Não ocorreu nestes períodos" ~ 6,
        TPMORTEOCO == "Ignorad" ~ 7,
        TPMORTEOCO == "Sem Informação" ~ 8
      ),
      IDADEMAE_COD = case_when(
        IDADEMAE == "10-14" ~ 1,
        IDADEMAE == "15-19" ~ 2,
        IDADEMAE == "20-24" ~ 3,
        IDADEMAE == "25-29" ~ 4,
        IDADEMAE == "30-34" ~ 5,
        IDADEMAE == "35-39" ~ 6,
        IDADEMAE == "40-44" ~ 7,
        IDADEMAE == "45-49" ~ 8,
        IDADEMAE == "50-54" ~ 9,
        IDADEMAE == "55-59" ~ 10,
        IDADEMAE == "60-64" ~ 11,
        IDADEMAE == "65-69" ~ 12,
        IDADEMAE == "70-74" ~ 13,
        IDADEMAE == "75-79" ~ 14,
        IDADEMAE == "80-84" ~ 15,
        IDADEMAE == "85-89" ~ 16,
        IDADEMAE == "90+" ~ 17
      ),
      ESCMAE2010_COD = case_when(
        ESCMAE2010 == "Sem escolaridade" ~ 1,
        ESCMAE2010 == "Fundamental I (1ª a 4ª série)" ~ 2,
        ESCMAE2010 == "Fundamental II (5ª a 8ª série)" ~ 3,
        ESCMAE2010 == "Médio (antigo 2º Grau)" ~ 4,
        ESCMAE2010 == "Superior incompleto" ~ 5,
        ESCMAE2010 == "Superior completo" ~ 6,
        ESCMAE2010 == "Ignorado" ~ 7,
        ESCMAE2010 == "Sem Informação" ~ 8
      ),
      GESTACAO_COD = case_when(
        GESTACAO == "Menos de 22 semanas" ~ 1,
        GESTACAO == "22 a 27 semanas" ~ 2,
        GESTACAO == "28 a 31 semanas" ~ 3,
        GESTACAO == "32 a 36 semanas" ~ 4,
        GESTACAO == "37 a 41 semanas" ~ 5,
        GESTACAO == "42 e + semanas" ~ 6,
        GESTACAO == "Ignorado" ~ 7,
        GESTACAO == "Sem Informação" ~ 8
      ),
      PESO_COD = case_when(
        PESO == "Insuficiente" ~ 1,
        PESO == "Baixo" ~ 2,
        PESO == "Adequado" ~ 3,
        PESO == "Excesso" ~ 4,
        PESO == "Sem Informação" ~ 5
      ),
      GRAVIDEZ_COD = case_when(
        GRAVIDEZ == "Única" ~ 1,
        GRAVIDEZ == "Dupla" ~ 2,
        GRAVIDEZ == "Tripla e mais" ~ 3,
        GRAVIDEZ == "Ignorada" ~ 4,
        GRAVIDEZ == "Sem Informação" ~ 5
      )
    )
  
  # Define a lista de dataframes a serem retornados
  dataframes <- list(SIM = SIM, CBO = CBO, CID = CID, Municipio = Municipio, Descricao = Descricao, Razao_de_obito = Razao_de_obito)
  
  # Define o ambiente global
  env <- globalenv()
  
  # Atribui os dataframes ao ambiente global
  list2env(dataframes, envir = env)
  
  # Define o caminho do arquivo
  caminho_arquivo <- file.path("SIM", "SIM.RData")
  
  # Salva o arquivo RData
  save.image(file = caminho_arquivo)
  
  # Caminho completo do arquivo "[Modelo]Painel.pbix"
  caminho_pasta <- system.file("Arquivos_externos", package = "PaineisPublicos")
  caminho_completo <- file.path(caminho_pasta, "Painel_SIM.pbix")
  
  # Verifica se o arquivo existe
  if (file.exists(caminho_completo)) {
    # Move o arquivo para o diretório de destino
    novo_caminho_completo <- file.path(dir_destino, "Painel_SIM.pbix")
    file.rename(caminho_completo, novo_caminho_completo)
    cat("Arquivo movido com sucesso para:", novo_caminho_completo)
  } else {cat("O arquivo '[Modelo]Painel.pbix' não foi encontrado no diretório:", caminho_pasta)}
  
}
