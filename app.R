library(shiny)
library(httr)
library(rjson)
library(DT)
library(plotly)

# profvis::profvis({ runApp() })
DEBUG <- Sys.getenv('DEBUG') == 'TRUE'
OFFLINE <- TRUE

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
  if (OFFLINE){
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

# ------------------------ Virtualenv setup -------------------------- #
if (Sys.info()[['sysname']] != 'Darwin'){
  # When running on shinyapps.io, create a virtualenv 
  reticulate::virtualenv_create(envname = 'python35_gly_env', 
                                python = '/usr/bin/python3')
  reticulate::virtualenv_install('python35_gly_env', 
                                 packages = c('synapseclient', 'requests'))
}
reticulate::use_virtualenv('python35_gly_env', required = T)

# ---------------------------- OAuth --------------------------------- #

if (!OFFLINE){
  reticulate::source_python('connect_to_synapse.py')
  # Initialize Synapse client
  login_to_synapse(username = Sys.getenv('SYN_USERNAME'),
                   api_key = Sys.getenv('SYN_API_KEY'))
  logged_in <- reactiveVal(FALSE)
  source('oauth.R')
}

# ----------------------------------- Server --------------------------------- #

server <- function(input, output, session) {
  
  if (!OFFLINE){
    # Click on the 'Log in' button to kick off the OAuth round trip
    observeEvent(input$action, {
      session$sendCustomMessage("customredirect", oauth2.0_authorize_url(API, APP, scope = SCOPE))
      return()
    })
    
    params <- parseQueryString(isolate(session$clientData$url_search))
    if (!has_auth_code(params)) {
      return()
    }
    
    url <- paste0(API$access, '?', 'redirect_uri=', APP_URL, '&grant_type=', 
                 'authorization_code', '&code=', params$code)
    
    # Get the access_token and userinfo token
    token_request <- POST(url,
                          encode = 'form',
                          body = '',
                          authenticate(APP$key, APP$secret, type = 'basic'),
                          config = list()
    )
    
    stop_for_status(token_request, task = 'Get an access token')
    token_response <- httr::content(token_request, type = NULL)
    
    access_token <- token_response$access_token
    id_token <- token_response$id_token
    if (token_request$status_code == 201){
      logged_in(T)
    }
    
    # ------------------------------ App --------------------------------- #
    
    # Get information about the user
    user_response = get_synapse_userinfo(access_token)
    user_id = user_response$userid
    user_content_formatted = paste(lapply(names(user_response), 
                                          function(n) paste(n, user_response[n])), collapse="\n")
    
    # Get user profile
    profile_response <- get_synapse_user_profile()
    
    # Get the user's teams
    teams_response <- get_synapse_teams(user_id)
    teams = unlist(lapply(teams_response$results, function(l) paste0(l$name, ' (', l$id, ')')))
    team_ids = unlist(lapply(teams_response$results, function(l) paste0('team_', l$id)))
    teams_content_formatted = paste(teams, collapse = '\n')
    
    # Select team(s) that have project(s) enabled for this app
    enabled_teams = team_ids[team_ids %in% names(PROJECT_CONFIG)]
    # TEMP just allow Predictive BioAnalytics members
    if ('team_3402260' %in% enabled_teams){
      TEAM_ID = 'team_3402260'
    }
    
    # Cache responses
    if (DEBUG){
      saveRDS(token_response, 'cache/token_response.rds')
      saveRDS(user_response, 'cache/user_response.rds')
      saveRDS(teams_response, 'cache/teams_response.rds')
      saveRDS(profile_response, 'cache/profile_response.rds')
    }
    
    output$userInfo <- renderText(user_content_formatted)
    output$teamInfo <- renderText(teams_content_formatted)
    # See in app_ui.R with verbatimTextOutput("userInfo")
  
    # ---------------------------- Menus --------------------------------- #
    
    # Logout modal
    observeEvent(input$user_account_modal, {
      showModal(
        modalDialog(title = "Synapse Account Information",
                    h4(paste0(profile_response$firstName, ' ', profile_response$lastName)),
                    p(profile_response$company),
                    p(user_response$email, style = 'color: #00B07D;'),
                    easyClose = T,
                    footer = tagList(
                      actionButton("button_view_syn_profile", "View Profile on Synapse",
                                   style = 'color: #ffffff; background-color:  #00B07D; border-color: #0f9971ff;',
                                   onclick = paste0("window.open('https://www.synapse.org/#!Profile:", profile_response$ownerId, "', '_blank')")),
                      modalButton("Back to Analysis")
                      #actionButton("button_logout", "Log Out")
                    )
        )
      )
    })
    
    output$logged_user <- renderText({
      if(logged_in()){
        return(paste0('Welcome, ', profile_response$firstName, '!'))
      }
    })
    
  } # end OFFLINE
  
  # Citation info modal
  observeEvent(input$citation_modal, {
    showModal(modalDialog(
      title = 'Citing GlycoBase',
      p('When using GlycoBase in your research, please cite the following:'),
      div(style = 'padding-left: 30px;',
        p('D. Bojar, D.M. Camacho, J.J. Collins. Using Natural Language Processing to Learn the Grammar of Glycans.'),
        a('Preprint available on bioRxiv', href = 'https://www.biorxiv.org/content/10.1101/2020.01.10.902114v1',
          target = '_blank',
          style = 'color: #00B07D;')
      ),
      easyClose = T,
      footer = NULL
    ))
  })

  
  # -------------------------- Tab 1: Overview ------------------------- #
  
  glycobaseData <- reactiveValues(glycobase_df = NULL,
                                  tsne_glycocans_df = NULL,
                                  tsne_glycoletters_df = NULL,
                                  tsne_glycowords_df = NULL,
                                  num_glycans = NULL,
                                  num_glycoletters = NULL,
                                  num_glycowords = NULL,
                                  data_loaded = F)
  
  if (OFFLINE){
    TEAM_ID = 'team_3402260'
  }
  
  # Load the projects the user has access to
  project_data = PROJECT_CONFIG[[TEAM_ID]]
  datasets = project_data$datasets
  DATASET = datasets[['v2']]
  
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
  glycobaseData$glycobase_df <- read.csv(glycobase_csv,
                                         stringsAsFactors = F)
  
  # Load glycans tSNE
  tsne_glycans <- read.csv(tsne_glycans_csv,
                           stringsAsFactors = F)
  names(tsne_glycans) = c('Glycan', 'Dim1', 'Dim2')
  glycobaseData$tsne_glycocans_df <- tsne_glycans
  
  # Load glycoletters tSNE (TODO - only do these loads if modal is opened)
  # TODO fix the files in Synapse to have correct index order
  tsne_glycoletters <- read.csv(tsne_glycoletters_csv,
                                stringsAsFactors = F)
  tsne_glycoletters = tsne_glycoletters[,c(3,1,2)]
  names(tsne_glycoletters) = c('Glycoletter', 'Dim1', 'Dim2')
  tsne_glycoletters = tsne_glycoletters[tsne_glycoletters$Glycoletter != '',]
  glycobaseData$tsne_glycoletters_df <- tsne_glycoletters
  
  # Load glycowords tSNE
  tsne_glycowords = read.csv(tsne_glycowords_csv,
                             stringsAsFactors = F)
  tsne_glycowords = tsne_glycowords[,c(3,1,2)]
  names(tsne_glycowords) = c('Glycoword', 'Dim1', 'Dim2')
  tsne_glycowords$Glycoword = gsub("\\(|\\)|'|,", "", tsne_glycowords$Glycoword)
  glycobaseData$tsne_glycowords_df <- tsne_glycowords
  
  # All data loaded
  glycobaseData$data_loaded <- T
  
  loaded <- reactive({ glycobaseData$data_loaded })
  glyco_data <- reactive({ glycobaseData$glycobase_df })
  tsne_glycoletters_data <- reactive({ glycobaseData$tsne_glycoletters_df })
  tsne_glycowords_data <- reactive({ glycobaseData$tsne_glycowords_df })
  n_glycans <- reactive({ glycobaseData$num_glycans })
  n_glycoletters <- reactive({ glycobaseData$num_glycoletters })
  n_glycowords <- reactive({ glycobaseData$num_glycowords })
  
  observeEvent(loaded(), {
    df1 = glyco_data()
    df2 = tsne_glycoletters_data()
    df3 = tsne_glycowords_data()
    glycobaseData$num_glycans <- nrow(df1)
    glycobaseData$num_glycoletters <- nrow(df2)
    glycobaseData$num_glycowords <- nrow(df3)
  })
  
  # Three boxes on first row
  output$num_glycans <- renderText({ n_glycans() })
  output$num_glycowords <- renderText({ n_glycowords() })
  output$num_glycoletters <- renderText({ n_glycoletters() })
  
  # tSNE plot for glycowords
  output$tsne_glycowords <- renderPlotly({
    
    if (loaded()){
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
      
    } else{
      return(NULL)
    } 
    
  })
  
  
  # tSNE plot for glycoletters
  output$tsne_glycoletters <- renderPlotly({
    
    if (loaded()){
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
      
    } else{
      return(NULL)
    } 
    
  })
  
  # Glycowords modal
  observeEvent(input$modal_glycowords, {
    showModal(modalDialog(
      title = 'Unique glycowords in GlycoBase',
      div(style='padding-left: 20px;',
        p(style='color: #D2D6DD;', 'Hover over a point to view glycoword')
      ),
      div(withSpinner(plotlyOutput('tsne_glycowords'), type = 4, color = '#00B07D'),
          style = "overflow-y: auto;"),
      selectInput('select_tsne_glycowords', 'Highlight glycowords containing monosaccharide:', 
                  choices = c('All', 'Hello'), selected = 'All', selectize = T),
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
      div(withSpinner(plotlyOutput('tsne_glycoletters'), type = 4, color = '#00B07D'),
          style = "overflow-y: auto;"),
      selectInput('select_tsne_glycoletters', 'Highlight monosaccharide:', 
                  choices = c('All', 'Hello'), selected = 'All', selectize = T),
      easyClose = T,
      footer = NULL
    ))
  })
  
  
  # Show the whole glycobase table
  output$table_glycobase <- DT::renderDT({
    df = glyco_data()
    
    if (!is.null(df)){
      
      # Display
      return(datatable(df, rownames = F, selection = 'none',
                       style = 'bootstrap', escape = F))
    } else{
      return(NULL)
    }
  })
  
}

# uiFunc instead of ui
shinyApp(uiFunc, server)
