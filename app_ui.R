library(shiny)
library(shinydashboard)
library(shinycssloaders)

# Add www subdirectory for images and stuff
addResourcePath(prefix = 'www', directoryPath = paste0(getwd(), '/www'))

# We'll do a dynamic redirect after authenticating
# https://stackoverflow.com/questions/57755830/how-to-redirect-to-a-dynamic-url-in-shiny
jscode <- "Shiny.addCustomMessageHandler('customredirect', function(message) { window.location = message;});"

source('plot_helpers.R')

# ------------------------------- Pre-login UI ------------------------------ #

AnonymousUI <- fluidPage(
  tags$head(tags$link(rel="stylesheet", type="text/css", href="bootstrap_rani.css"),
            HTML('<link rel="icon" href="www/favicon.ico" type="image/x-icon"/>')),
  title = 'GlycoBase',
  
  # Wyss logo
  div(img(src = paste0('www/wyss-logo-white.png'), width = '200px'),
      style='text-align: center; padding-top: 30px;'),
  
  h1('GlycoBase'),
  
  # Glycan logo
  div(img(src = paste0('www/glycobase_home.png'), width = '100px'),
      style='text-align: center; padding-top: 30px; padding-bottom: 60px;'),
  
  # Login button
  tags$head(tags$script(jscode)),
  div(actionButton("action", "Log in with Synapse"),
      style='text-align: center; padding-bottom: 100px;'),
  
  div(p("Don't have a Synapse account yet?", style='text-align: center; font-size: 10pt;'),
      p("Follow the ",
        a(href = 'https://midas-wyss.github.io/synapse_instructions_predictive_bioanalytics.html',
          target = '_blank', 'instructions for registering here', style='font-size: 10pt;'), 
        '.', style='text-align: center; font-size: 10pt;'))
)

# ------------------------------ Post-login UI ------------------------------ #

AuthenticatedUI <- dashboardPage(
  skin = 'blue',
  
  dashboardHeader(title = 'GlycoBase',
                  titleWidth = 250,
                  tags$li(class = "dropdown",
                          tags$li(class = "dropdown", 
                                  actionLink("user_account_modal", textOutput("logged_user")),
                                  style = "color: #fff;"))
  ),
  
  dashboardSidebar(
    width = 250,
    tags$head(tags$style(HTML('.logo {
                              background-color: #0f9971ff !important;
                              }
                              .navbar {
                              background-color: #00B07D !important;
                              }
                              .sidebar-toggle {
                              background-color: #00B07D !important;
                              }
                              .skin-blue .sidebar-menu > li.active > a,
                              .skin-blue .sidebar-menu > li:hover > a { border-left-color: #0f9971ff;}'
    ))),
    sidebarMenu(
      p(),
      menuItem("GlycoBase overview", tabName = "tab_overview", icon = icon("star")),
      menuItem("Structure characterization", tabName = "tab_env", icon = icon("chart-pie")),
      menuItem("SweetTalk", tabName = "tab_sweettalk", icon = icon("comment-dots")),
      menuItem("SweetOrigins", tabName = "tab_sweetorigins", icon = icon("project-diagram")),
      menuItem("Glycan alignment", tabName = "tab_alignment", icon = icon("stream")),
      menuItem("Biomining", tabName = "tab_biomining", icon = icon("microscope")),
      div(actionLink('citation_modal', 'Citing GlycoBase', 
                     style = 'color: #00B07D; padding-top: 30px;'), 
          style = 'font-size: 8pt; margin: 0px 5px 20px 0px;')
    ),
    br(),
    div(style = 'position: fixed; bottom: 20px; margin: 0px 20px 0 20px; width: 180px;',
        img(src = 'www/wyss-logo-white-square.png', width = '140px'),
        p('This tool was developed by the Predictive BioAnalytics group',
          style = 'font-size: 8pt; margin-top: 10px',),
        a('View our other apps', href = 'https://midas-wyss.github.io/', 
          target = '_blank', style = 'font-size: 8pt; color: #00B07D;')
    )
  ),
  
  dashboardBody(
    tags$head(includeHTML('www/analytics.html'),
              tags$style('.shiny-output-error{color: white;}'),
              HTML('<link rel="icon" href="www/favicon.ico" type="image/x-icon"/>')),
    tags$style(
      type = 'text/css',
      '.bg-aqua { background-color: #019DB0 !important; }
       .bg-fuchsia { background-color: #903C83 !important; }
       .bg-yellow { background-color: #B09001 !important; }
       .bg-green { background-color: #01B07D !important; }
       .bg-lime { background-color: #16D69E !important; }
       .bg-olive { background-color: #3BF1BC !important; }
       
       i.rkp.glycan
      '
    ),
    # green = darkest green
    # lime = medium green
    # olive = light green
    
    tabItems(
      tabItem(tabName = 'tab_overview',
              h2('GlycoBase overview'),
              fluidRow(
                # TODO make the whole box clickable
                box(title = 'Unique glycans',
                    height = 120, width = 4,
                    background = 'green', solidHeader = T,
                    div(style = 'float: left; padding-left: 20px;',
                        img(src = 'www/icon_glycan.png', width = '100px')),
                    div(style = 'float: left; padding-left: 30px; font-size: 28px;',
                        textOutput('num_glycans'))
                ),
                box(title = actionLink('modal_glycowords', 'Unique glycowords',
                                       style = 'color: white;'),
                    height = 120, width = 4,
                    background = 'aqua', solidHeader = T,
                    div(style = 'float: left; padding-left: 20px; padding-top: 10px;',
                        img(src = 'www/icon_glycoword.png', width = '75px')),
                    div(style = 'float: left; padding-left: 30px; font-size: 28px;',
                        textOutput('num_glycowords'))
                ),
                box(title = actionLink('modal_glycoletters', 'Unique glycoletters',
                                       style = 'color: white;'),
                    height = 120, width = 4,
                    background = 'fuchsia', solidHeader = T,
                    div(style = 'float: left; padding-left: 20px; padding-top: 3px;',
                        img(src = 'www/icon_glycoletters.png', width = '70px')),
                    div(style = 'float: left; padding-left: 30px; font-size: 28px;',
                        textOutput('num_glycoletters'))
                )
              ),
              fluidRow(
                box(title = 'Full GlycoBase dataset (v1.0)',
                    width = 12,
                    div(withSpinner(dataTableOutput('table_glycobase'), type = 4, color = '#00B07D')))
              )
        ),
        tabItem(tabName = 'tab_env',
                h2('Structural Environment'),
                p('Coming soon')
        ),
        tabItem(tabName = 'tab_sweettalk',
                h2('SweetTalk'),
                p('Coming soon')
        ),
        tabItem(tabName = 'tab_sweetorigins',
                h2('SweetOrigins'),
                p('Coming soon')
        ),
        tabItem(tabName = 'tab_alignment',
                h2('Glycan-based alignment'),
                p('Coming soon')
        ),
        tabItem(tabName = 'tab_biomining',
                h2('Biomining'),
                p('Coming soon')
        )
      ) # end tabItems
  ) # end dashboardBody
) # end dashboardPage