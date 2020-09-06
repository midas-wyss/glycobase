library(shiny)
library(httr)
library(rjson)
library(DT)
library(plotly)
PYTHON_DEPENDENCIES = c('synapseclient', 'requests', 'pandas', 'numpy')

# profvis::profvis({ runApp() })
OFFLINE <- FALSE
REQUIRE_LOGIN <- FALSE

# TODO
# Add GBID to the tSNE tables for easier mapping and filtering by species, etc

# ----------------------------------- App UI --------------------------------- #

# Check whether user has auth'd
has_auth_code <- function(params) {
  # params is a list object containing the parsed URL parameters. Return TRUE if
  # based on these parameters, it looks like auth code is present that we can
  # use to get an access token. If not, it means we need to go through the OAuth
  # flow.
  return(!is.null(params$code))
}

# UI will change depending on whether the user has logged in
uiFunc <- function(req) {
  if (OFFLINE | !REQUIRE_LOGIN){
    AuthenticatedUI
  } else {
    if (!has_auth_code(parseQueryString(req$QUERY_STRING))) {
      # Login button
      AnonymousUI
    } else {
      # App UI
      AuthenticatedUI
    }
  }
}

# Import UI to be shown after user before and after auth'd
source('app_ui.R')
if (!dir.exists('data')){
  dir.create('data')
}

# ------------------ App virtualenv setup (Do not edit) ------------------- #

virtualenv_dir = Sys.getenv('VIRTUALENV_NAME')
python_path = Sys.getenv('PYTHON_PATH')

# Create virtual env and install dependencies
reticulate::virtualenv_create(envname = virtualenv_dir, python = python_path)
reticulate::virtualenv_install(virtualenv_dir, packages = PYTHON_DEPENDENCIES, ignore_installed = T)
reticulate::use_virtualenv(virtualenv_dir, required = T)


# ----------------------------------- Server --------------------------------- #

server <- function(input, output, session) {
  
  
   # Logout modal
    observeEvent(input$user_account_modal, {
      showModal(
        modalDialog(title = "We appreciate your interest in GlycoBase!",
                    HTML('<div><strong>Additional resources</strong></div>'),
                    br(),
                    HTML('<div style="float:left;margin-right: 15px;margin-top: 23px;">
                         <a href="https://www.synapse.org/#!Synapse:syn21568077/wiki/600880""><img src="synapse_logo.png" title="View the Synapse project" width="200" /></a><p><a href="https://www.synapse.org/#!Synapse:syn21568077/wiki/600880" style="color: #00B07D;">View and download GlycoBase data from Synapse</a></p></div>'),
                    br(),
                    HTML('<div style="float:left;padding-bottom: 15px;padding-left: 15px;">
                         <a href="https://github.com/midas-wyss/glycobase"><img src="github_logo.png" title="View the code" width="100" /></a><p><a href="https://github.com/midas-wyss/glycobase" style="color: #00B07D;">View the GlycoBase code on Github</a></p></div>'),
                    br(),
                    div('For additional questions or suggestions, please email daniel.bojar@wyss.harvard.edu.', style="clear:left;"),
                    easyClose = T,
                    footer = tagList(
                      modalButton("Back to Analysis")
                    )
        )
      )
    })
    
    output$logged_user <- renderText({
      paste0('Welcome, Guest!')
    })
  
  # Citation info modal
  observeEvent(input$citation_modal, {
    showModal(modalDialog(
      title = 'Citing GlycoBase',
      p('When using GlycoBase and our glycan alignment tool in your research, please cite the following:'),
      div(style = 'padding-left: 30px;',
        p('D. Bojar, R.K. Powers, D.M. Camacho, J.J. Collins. SweetOrigins: Extracting Evolutionary Information from Glycans.'),
        a('Read the preprint on bioRxiv (opens in a new window)', href = 'https://www.biorxiv.org/content/10.1101/2020.04.08.031948v1.full.pdf+html',
          target = '_blank',
          style = 'color: #00B07D;')
      ),
      easyClose = T,
      footer = NULL
    ))
  })

  
  # ----------------------------- TAB 1: OVERVIEW --------------------------- #
  
  glycobaseData <- reactiveValues(glycobase_df = NULL,
                                  monosaccharides = NULL,
                                  species = NULL,
                                  tsne_glycans_df = NULL,
                                  tsne_glycoletters_df = NULL,
                                  tsne_glycowords_df = NULL,
                                  num_glycans = 19299,
                                  num_glycoletters = 1027,
                                  num_glycowords = 19866)
  
  # Load the current version of GlycoBase to display
  DATASET = PROJECT_CONFIG$DATASETS$V2
  
  if (OFFLINE){
    glycobase_csv = 'data/v2_glycobase.csv'
    tsne_glycans_csv = 'data/v2_tsne_glycans_isomorph.csv'
    tsne_glycoletters_csv = 'data/v2_tsne_glycoletters.csv'
    tsne_glycowords_csv = 'data/v2_tsne_glycowords.csv'
    
  } else{
    glycobase_csv = fetch_synapse_filepath(DATASET$glycobase)
    tsne_glycans_csv = fetch_synapse_filepath(DATASET$tsne_glycans)
    tsne_glycoletters_csv = fetch_synapse_filepath(DATASET$tsne_glycoletters)
    tsne_glycowords_csv = fetch_synapse_filepath(DATASET$tsne_glycowords)
  }
  
  # Load glycobase
  glycobase_df <- read.csv(glycobase_csv, stringsAsFactors = F)
  glycobase_df$glycan_id = paste0('GBID', glycobase_df$glycan_id)
  glycobase_df$species = gsub("\\['|\\']|'", '', glycobase_df$species)
  glycobase_df$species = gsub("_", ' ', glycobase_df$species)
  humans = glycobase_df[grepl('Homo sapiens', glycobase_df$species), ]
  others = glycobase_df[!grepl('Homo sapiens', glycobase_df$species), ]
  glycobase_df = rbind(humans, others)
  glycobase_df$immunogenicity[glycobase_df$immunogenicity == 0] = 'No'
  glycobase_df$immunogenicity[glycobase_df$immunogenicity == 1] = 'Yes'
  glycobase_df$immunogenicity[is.na(glycobase_df$immunogenicity)] = 'Unknown'
  glycobase_df$link[glycobase_df$link == ''] = 'None'
  glycobase_df$link[glycobase_df$link == 'free'] = 'Free'
  names(glycobase_df)[c(1:4,6)] = c('GlycoBase_ID', 'Glycan', 'Species', 'Immunogenic', 'Link')
  glycobaseData$glycobase_df <- glycobase_df
  
  # Unique monosaccharides, bonds, species for filtering
  glycobaseData$monosaccharides <- readRDS('rdata/v2_monosaccharides.rds')
  glycobaseData$bonds <- readRDS('rdata/v2_bonds.rds')
  glycobaseData$species <- readRDS('rdata/v2_species.rds')
  glycobaseData$kingdoms <- readRDS('rdata/v2_kingdoms.rds')
  
  # All data loaded
  glyco_data <- reactive({ glycobaseData$glycobase_df })
  tsne_glycans_data <- reactive({ glycobaseData$tsne_glycans_df })
  tsne_glycowords_data <- reactive({ glycobaseData$tsne_glycowords_df })
  tsne_glycoletters_data <- reactive({ glycobaseData$tsne_glycoletters_df })
  n_glycans <- reactive({ glycobaseData$num_glycans })
  n_glycoletters <- reactive({ glycobaseData$num_glycoletters })
  n_glycowords <- reactive({ glycobaseData$num_glycowords })
  monos <- reactive({ glycobaseData$monosaccharides })
  bonds <- reactive({ glycobaseData$bonds })
  kingdoms <- reactive({ glycobaseData$kingdoms })
  specs <- reactive({ glycobaseData$species })
  
  # Three boxes on first row
  output$num_glycans <- renderText({ n_glycans() })
  output$num_glycowords <- renderText({ n_glycowords() })
  output$num_glycoletters <- renderText({ n_glycoletters() })
  
  # tSNE plot for glycans
  output$tsne_glycans <- renderPlotly({
    
    # Load glycans tSNE if needed
    if (is.null(glycobaseData$tsne_glycans_df)){
      tsne_glycans <- read.csv(tsne_glycans_csv,
                               stringsAsFactors = F)
      names(tsne_glycans) = c('Glycan', 'Dim1', 'Dim2')
      glycobaseData$tsne_glycans_df <- tsne_glycans
    }
    
    plot_df = tsne_glycans_data()
    p <- plot_ly(data = plot_df, x = ~Dim1, y = ~Dim2,
                 symbols = 21,
                 text = ~Glycan,
                 hovertemplate = '<b>Glycan:</b> %{text}<extra></extra>',
                 type = 'scatter', mode = 'markers',
                 showlegend = FALSE,
                 marker = list(size = 8,
                               # TODO color them by a meaningful grouping?
                               color = '#01B07D',
                               line = list(
                                 color = '#212D32',
                                 width = 1
                               )
                 )
    ) %>%
      layout(title = 'Glycans (tSNE plot)')
    
    # Display Plotly plot in UI
    return(p)
  })
  
  # tSNE plot for glycowords
  output$tsne_glycowords <- renderPlotly({
    
    # Load glycowords tSNE if needed
    if (is.null(glycobaseData$tsne_glycowords_df)){
      tsne_glycowords = read.csv(tsne_glycowords_csv,
                                 stringsAsFactors = F)
      tsne_glycowords = tsne_glycowords[,c(3,1,2)]
      names(tsne_glycowords) = c('Glycoword', 'Dim1', 'Dim2')
      tsne_glycowords$Glycoword = gsub("\\(|\\)|'|,", "", tsne_glycowords$Glycoword)
      glycobaseData$tsne_glycowords_df <- tsne_glycowords
    }
    
    # Load glycans tSNE if needed
    if (is.null(glycobaseData$tsne_glycocans_df)){
      tsne_glycans <- read.csv(tsne_glycans_csv,
                               stringsAsFactors = F)
      names(tsne_glycans) = c('Glycan', 'Dim1', 'Dim2')
      glycobaseData$tsne_glycocans_df <- tsne_glycans
    }
    
    plot_df = tsne_glycowords_data()
    p <- plot_ly(data = plot_df, x = ~Dim1, y = ~Dim2,
                 symbols = 21,
                 text = ~Glycoword,
                 hovertemplate = '<b>Glycoword:</b> %{text}<extra></extra>',
                 type = 'scatter', mode = 'markers',
                 showlegend = FALSE,
                 marker = list(size = 8,
                               # TODO color them by a meaningful grouping?
                               color = '#019DB0',
                               line = list(
                                 color = '#212D32',
                                 width = 1
                               )
                 )
    ) %>%
      layout(title = 'Glycowords (tSNE plot)')
    
    # Display Plotly plot in UI
    return(p)
  })
  
  # tSNE plot for glycowords
  output$tsne_glycowords <- renderPlotly({
    
    # Load glycowords tSNE if needed
    if (is.null(glycobaseData$tsne_glycowords_df)){
      tsne_glycowords = read.csv(tsne_glycowords_csv,
                                 stringsAsFactors = F)
      tsne_glycowords = tsne_glycowords[,c(3,1,2)]
      names(tsne_glycowords) = c('Glycoword', 'Dim1', 'Dim2')
      tsne_glycowords$Glycoword = gsub("\\(|\\)|'|,", "", tsne_glycowords$Glycoword)
      glycobaseData$tsne_glycowords_df <- tsne_glycowords
    }
    
    plot_df = tsne_glycowords_data()
    p <- plot_ly(data = plot_df, x = ~Dim1, y = ~Dim2,
                 symbols = 21,
                 text = ~Glycoword,
                 hovertemplate = '<b>Glycoword:</b> %{text}<extra></extra>',
                 type = 'scatter', mode = 'markers',
                 showlegend = FALSE,
                 marker = list(size = 8,
                               # TODO color them by a meaningful grouping?
                               color = '#019DB0',
                               line = list(
                                 color = '#212D32',
                                 width = 1
                               )
                 )
    ) %>%
      layout(title = 'Glycowords (tSNE plot)')
    
    # Display Plotly plot in UI
    return(p)
  })
  
  
  # tSNE plot for glycoletters
  output$tsne_glycoletters <- renderPlotly({
    
    # Load glycoletters tSNE if needed
    if (is.null(glycobaseData$tsne_glycoletters_df)){
      tsne_glycoletters <- read.csv(tsne_glycoletters_csv,
                                    stringsAsFactors = F)
      tsne_glycoletters = tsne_glycoletters[,c(3,1,2)]
      names(tsne_glycoletters) = c('Glycoletter', 'Dim1', 'Dim2')
      tsne_glycoletters = tsne_glycoletters[tsne_glycoletters$Glycoletter != '',]
      glycobaseData$tsne_glycoletters_df <- tsne_glycoletters
    }
    
    plot_df = tsne_glycoletters_data()
    p <- plot_ly(data = plot_df, x = ~Dim1, y = ~Dim2,
                 symbols = 21,
                 text = ~Glycoletter,
                 hovertemplate = '<b>Glycoletter:</b> %{text}<extra></extra>',
                 type = 'scatter', mode = 'markers',
                 showlegend = FALSE,
                 marker = list(size = 8,
                               # TODO color them by a meaningful grouping?
                               color = '#903C83',
                               line = list(
                                 color = '#212D32',
                                 width = 1
                               )
                 )
    ) %>%
      layout(title = 'Glycoletters (tSNE plot)')
    
    # Display Plotly plot in UI
    return(p)
  })
  
  # Glycans modal
  observeEvent(input$modal_glycans, {
    showModal(modalDialog(
      title = 'Unique glycans in GlycoBase',
      div(style='padding-left: 20px;',
          p(style='color: #D2D6DD;', 'Hover over a point to view glycan')
      ),
      div(withSpinner(plotlyOutput('tsne_glycans'), type = 4, color = '#00B07D'),
          style = "overflow-y: auto;"),
      #selectInput('select_tsne_glycans', 'Highlight glycans containing monosaccharide:', 
      #            choices = c('All', monos()), selected = 'All', selectize = T),
      easyClose = T,
      footer = NULL
    ))
  })
  
  # Glycowords modal
  observeEvent(input$modal_glycowords, {
    showModal(modalDialog(
      title = 'Unique glycowords in GlycoBase',
      div(style='padding-left: 20px;',
        p(style='color: #D2D6DD;', 'Hover over a point to view glycoword')
      ),
      div(withSpinner(plotlyOutput('tsne_glycowords'), type = 4, color = '#019DB0'),
          style = "overflow-y: auto;"),
      #selectInput('select_tsne_glycowords', 'Highlight glycowords containing monosaccharide:', 
      #            choices = c('All', monos()), selected = 'All', selectize = T),
      easyClose = T,
      footer = NULL
    ))
  })
  
  # Glycoletters modal
  observeEvent(input$modal_glycoletters, {
    showModal(modalDialog(
      title = 'Unique glycoletters in GlycoBase',
      div(style='padding-left: 20px;',
          p(style='color: #D2D6DD;', 'Hover over a point to view glycoletter')
      ),
      div(withSpinner(plotlyOutput('tsne_glycoletters'), type = 4, color = '#903C83'),
          style = "overflow-y: auto;"),
      #selectInput('select_tsne_glycoletters', 'Highlight monosaccharide:', 
      #            choices = c('All', monos()), selected = 'All', selectize = T),
      easyClose = T,
      footer = NULL
    ))
  })
  
  output$button_download_glycobase <- downloadHandler(
    filename = paste0("GlycoBase_v2_", gsub('-', '_', Sys.Date()), ".csv"),
    content = function(file) {
      if (file.exists('data/glycobase_df.csv')){
        file.copy('data/glycobase_df.csv', file)
      } else{
        NULL
      }
    }
  )
  
  # Show the whole glycobase table
  output$table_glycobase <- DT::renderDT({
    df = glyco_data()
    df = df[,c('GlycoBase_ID', 'Glycan', 'Link', 'Species', 'Immunogenic')]
    df$Link = factor(df$Link, c('N', 'O', 'Free', 'None'))
    df$Immunogenic = factor(df$Immunogenic, c('Yes', 'No', 'Unknown'))
    #df$Species = factor(df$Species, sort(unique(df$Species))) # TODO make this a dropdown but search _within_ column somehow
    
    write.table(df, 'data/glycobase_df.csv', sep = ',', row.names = F)
    
    if (!is.null(df)){
      
      # Display
      return(datatable(df, rownames = F, selection = 'none',
                       style = 'bootstrap', escape = F, 
                       filter = 'top',
                       options = list(
                         dom = 'tipr',
                         pageLength = 20,
                         autoWidth = TRUE,
                         columnDefs = list(list(width = '100px', targets = c(0,2,4)),
                                           list(width = '200px', targets = 3))
                       )))
    } else{
      return(NULL)
    }
  })
  
  # ---------------------- TAB 2: STRUCTURAL CONTEXT ------------------------ #
  reticulate::source_python('structural_context.py')
  
  context_query_criteria <- reactive({ input$select_context_criteria })
  selected_context_glycoletter <- reactive({ input$select_context_glycoletter })
  context_tax_level <- reactive({ input$select_context_taxonomy_level })
  selected_tax_value <- reactive({ input$select_context_taxonomy_value })
  
  observeEvent(input$info_environment_modal, {
    showModal(
      modalDialog(title = "Analyzing the local structural context of glycoletters",
                  p('This tab highlights the characteristic local structural context of a glycoletter (monosaccharide or bond). It also shows its frequency by position in the glycan structure (main versus side branch).'),
                  p('For all glycans in our database with species information, we constructed a library of disaccharide motifs that are present in any species to generate leads for glycosyltransferase biomining.'),
                  a('Read the full methods in our preprint (opens in a new window)', href='https://www.biorxiv.org/content/10.1101/2020.04.08.031948v1.full.pdf+html', 
                    style='color: #00B07D;', target='_blank'),
                  easyClose = T,
                  footer = NULL)
    )
  })
  
  observeEvent(context_query_criteria(), {
    criteria = context_query_criteria()
    if (criteria == 'Observed monosaccharides making bond:'){
      updateSelectInput(session, 'select_context_glycoletter', 
                        choices = bonds())
    } else{
      updateSelectInput(session, 'select_context_glycoletter', 
                        choices = monos(), selected = 'Rha')
    }
  })
  
  observeEvent(context_tax_level(), {
    tax_level = context_tax_level()
    if (tax_level == 'Kingdom'){
      updateSelectInput(session, 'select_context_taxonomy_value', 
                        label = 'Kingdom',
                        choices = c('All', kingdoms()))
    } else{
      updateSelectInput(session, 'select_context_taxonomy_value',
                        label = 'Species',
                        choices = c('All', specs()))
    }
  })
  
  output$context_observed_barplot <- renderPlotly({
    
    motif = selected_context_glycoletter()
    criteria = context_query_criteria()
    if (criteria == 'Observed monosaccharides making bond:'){
      mode = 'bond'
    } else if (criteria == 'Observed monosaccharides paired with:'){
      mode = 'sugar'
    } else{
      mode = 'sugarbond'
    }
    
    context_results = characterize_context(motif, mode = mode, 
                                           taxonomy_filter=context_tax_level(), taxonomy_value = selected_tax_value())
    
    plot_title = context_results[[1]]
    plot_x = factor(context_results[[2]], levels = context_results[[2]]) # keep the order that characterize_context() returns
    plot_y = context_results[[3]]
    plot_ly(x = plot_x, y = plot_y, type = 'bar', marker = list(color = '#00B07D')) %>%
      layout(title = plot_title,
             xaxis = list(title = 'Monosaccharide'),
             yaxis = list(title = 'Number of glycans'))
    
  })
  
  output$context_main_side_barplot <- renderPlotly({
    
    motif = selected_context_glycoletter()
    
    main_side = main_v_side_branch(motif, taxonomy_filter=context_tax_level(), taxonomy_value = selected_tax_value())
    
    plot_title = motif
    plot_x = c('Main branch', 'Side branch')
    plot_y = main_side
    plot_ly(x = plot_x, y = plot_y, type = 'bar', 
            marker = list(color = c('#019DB0', '#903C83'))) %>%
      layout(title = plot_title,
             xaxis = list(title = 'Position'),
             yaxis = list(title = 'Ocurrence'))
    
  })
  
  # ---------------------- TAB 3: GLYCAN ALIGNMENT ------------------------ #
  reticulate::source_python('glycan_alignment.py')
  alignmentData <- reactiveValues(alignment_message = NULL,
                                  input_valid = NULL,
                                  alignment_df = NULL)
  
  glycan_query_seq <- reactive({ input$glycan_query })
  validated_query_seq <- reactive({ alignmentData$input_valid })
  
  observeEvent(input$info_alignment_modal, {
    showModal(
      modalDialog(title = "Glycan alignment",
                  p('A common method of analyzing motifs in biological sequences that capitalizes on evolutionary information is the use
                     of alignments. This tab on GlycoBase performs gapped, pairwise alignments of glycan sequences, assisted
                     by a substitution matrix analogous to the BLOSUM matrices utilized in protein alignments (which we termed GLYcan SUbstitution Matrix, GLYSUM).'),
                  HTML('<p>Global sequence alignment of glycans was implemented according to the Needleman Wunsch algorithm by adapting 
                    the <a href="https://github.com/eseraygun/pythonalignment" style="color: #00B07D;">Python Alignment library</a>.</p>'),
                  br(),
                  HTML('<strong>Scoring with the GLYcan SUbstitution Matrix (GLYSUM)</strong>'),
                  HTML('<p>The exhaustive list of in silico modifications resulting in glycans with observed glycowords was generated (n
                        = 1,238,879). All thereby observed monosaccharide and/or bond substitutions were recorded in a
                        symmetric matrix and converted into substitution frequencies by dividing them by the total number of
                        retained modifications.</p>'),
                  HTML('<p>Substitutions never observed during this procedure received a final value of -5, lower than any of the observed substitution scores, 
                        while the diagonal values of the substitution matrix re set at 5, higher than any of the observed substitution scores. 
                        The penalty for gaps for alignments in this work was set at -5, to match the minimal substitution score. The penalty for mismatches was -10.</p>'),
                  a('Read the full methods in our preprint (opens in a new window)', href='https://www.biorxiv.org/content/10.1101/2020.04.08.031948v1.full.pdf+html', 
                    style='color: #00B07D;', target='_blank'),
                  easyClose = T,
                  footer = NULL)
    )
  })
  
  observeEvent(input$button_run_alignment, {
    alignmentData$alignment_df <- NULL
    query = glycan_query_seq()
    
    if (!is.null(query)){
      if (!grepl('\\(', query)){
        alignmentData$alignment_message <- 'Please use the IUPAC condensed nomenclature shown on GlycoBase.'
      } else{
        alignmentData$alignment_message <- ''
        alignmentData$input_valid <- query
      }
    }
  })
  
  output$message_run_alignment <- renderText({
    return(alignmentData$alignment_message)
  })
  
  observeEvent(input$button_show_alignment_example, {
    query = 'ManNAcA(b1-4)FucNAcOAc(a1-3)D-FucNAc(b1-4)ManNAcA'
    updateTextInput(session, 'glycan_query', value = query)
  })
  
  observeEvent(validated_query_seq(), {
    
    withProgress(message = 'Aligning...', value = 0, {
      
      incProgress(0.2, detail = '(1-2 minutes)')
      
      query = validated_query_seq()
      
      incProgress(0.3, detail = '(1-2 minutes)')
      
      if (!is.null(query)){
        alignment_df = pairwiseAlign(query, n=0) # n=0 returns all
        
        alignment_df$Species = unlist(lapply(alignment_df$Species, function(x){
          gsub("\\['|'\\]|'", "", x)
        }))
                          
        incProgress(0.4, detail = 'Finishing up')
        
        if (!is.null(alignment_df)){
          
          df = as.data.frame(alignment_df)
          df$Species = gsub("_", ' ', df$Species)
          df = unique(df)
          
          df = df[,c('Query_Sequence', 'Aligned_Sequence', 'Score',
                     'Species', 'Percent_Identity', 'Percent_Coverage', 'Glycobase_ID')]
          
          alignmentData$alignment_df <- df
          
          # Save csv
          write.table(df, 'data/alignment_df.csv', sep = ',',
                      row.names = F)
          
        } else{
          alignmentData$alignment_df <- NULL
        }
      } else{
        alignmentData$alignment_df <- NULL
      }
    })
  })
  
  alignment_table <- reactive({ alignmentData$alignment_df })
  
  output$button_download_alignments <- downloadHandler(
    filename = paste0("GlycoBase_glycan_pairwise_alignment_", gsub('-', '_', Sys.Date()), ".csv"),
    content = function(file) {
      if (file.exists('data/alignment_df.csv')){
        file.copy('data/alignment_df.csv', file)
      } else{
        NULL
      }
    }
  )
  
  USE_PRECOMPUTED_ALIGNMENT = FALSE
  
  output$alignments_ui <- renderUI({
    if (USE_PRECOMPUTED_ALIGNMENT){
      dat = readRDS('cache/dat.rds')
    } else{
      dat = alignment_table()
    }
    
    if (!is.null(dat)){
      n = nrow(dat)
      
      return(tagList(
        div(downloadButton('button_download_alignments', label = 'Download all (csv)', style = 'margin-right: 15px; float: right;', icon = icon('download')),
            HTML('<h2>Pairwise alignment results <span style="font-size: 10pt;">(Top 5 shown)</span></h2>'),
            style = 'padding-left: 15px;'),
        lapply(1:5, function(i) {
          a = sapply(strsplit(as.character(dat[i, 'Query_Sequence']), ' ')[[1]], function(s) {
            if (s != ''){
              paste0('<span class="alignment_item">', s, '</span>')
            }
          })
          b = sapply(strsplit(as.character(dat[i, 'Aligned_Sequence']), ' ')[[1]], function(s) {
            if (s != ''){
              paste0('<span class="alignment_item">', s, '</span>')
            }
          })
          gbid = as.character(dat[i, 'Glycobase_ID'])
          species = as.character(dat[i, 'Species'])
          score = as.character(dat[i, 'Score'])
          percent_id = as.character(round(dat[i, 'Percent_Identity'], 3))
          percent_coverage = as.character(round(dat[i, 'Percent_Coverage'], 3))
          
          box(title = paste0('Alignment #', i, ': ', gbid), 
              width = 12,
              div(style = 'padding-left: 15px; padding-bottom: 15px;',
                h4({ paste0('Score: ', score) }, style='color: #00B07D'),
                p({ paste0('Percent identity: ', percent_id) }),
                p({ paste0('Percent coverage: ', percent_coverage) }),
                p(HTML({ paste0('Species: <i>', species, '</i>') })),
                br(),
                strong('Alignment: '),
                div(HTML(a), class = 'alignment_row1'),
                div(HTML(b), class = 'alignment_row2')
              )
          )
        })
      ))
    }
  })
  
}

# uiFunc instead of ui
shinyApp(uiFunc, server)
