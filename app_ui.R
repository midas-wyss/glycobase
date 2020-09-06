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
  title = 'SugarBase',
  
  # Wyss logo
  div(img(src = paste0('www/wyss-logo-white.png'), width = '200px'),
      style='text-align: center; padding-top: 30px;'),
  
  h1('SugarBase'),
  
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
  
  dashboardHeader(title = 'SugarBase',
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
                              .main-header .logo {
                                font-family: "GraphikMedium",Helvetica,Arial,sans-serif;
                              }
                              .navbar {
                              background-color: #00B07D !important;
                              }
                              .sidebar-toggle {
                              background-color: #00B07D !important;
                              }
                              .skin-blue .sidebar-menu > li.active > a,
                              .skin-blue .sidebar-menu > li:hover > a { border-left-color: #0f9971ff;}
                              .alignment_row1, .alignment_row2 {
                                border: 1px solid #e2e2e2;
                              }
                              .no-header-box .box-header {
                                display: none;
                              }
                              .alignment_row1 .alignment_item, .alignment_row2 .alignment_item {
                                display: inline-block;
                                width: 10%;
                                border-right: 1px solid #e2e2e2;
                                padding: 10px;
                                text-align: center;
                                min-width: 80px;
                                position: relative;
                              }
                              .alignment_row1 {
                                background-color: #f2f2f2;
                                margin-bottom: -1px;
                              }
                              .alignment_row1 .alignment_item {
                              }
                              .info-tip:hover {
                                text-decoration: underline;
                              }'
    ))),
    sidebarMenu(id='tabs',
      p(),
      menuItem("SugarBase overview", tabName = "home", icon = icon("star")),
      menuItem("Glycan alignment", tabName = "alignment", icon = icon("stream"),
               badgeLabel = 'New!', badgeColor = 'green'),
      menuItem("Characteristic environment", tabName = "structuralcontext", icon = icon("chart-bar")),
      menuItem("Submit a glycan", tabName = "submit", icon = icon("plus-square")),
      #menuItem("SweetTalk", tabName = "tab_sweettalk", icon = icon("comment-dots")),
      #menuItem("SweetOrigins", tabName = "tab_sweetorigins", icon = icon("project-diagram")),
      #menuItem("Biomining", tabName = "tab_biomining", icon = icon("microscope")),
      div(actionLink('citation_modal', 'Citing SugarBase',
                     style = 'color: #00B07D; padding-top: 30px;'), 
          style = 'font-size: 10pt; margin: 0px 5px 20px 0px;')
    ),
    br(),
    div(style = 'position: fixed; bottom: 20px; margin: 0px 20px 0 20px; width: 180px;',
        img(src = 'www/wyss-logo-white.png', width = '160px'),
        p('This app was built at the Wyss Institute for Biologically Inspired Engineering',
          style = 'font-size: 8pt; margin-top: 10px',),
        a('Visit our website to learn more', href = 'https://wyss.harvard.edu/',
          target = '_blank', style = 'font-size: 8pt; color: #00B07D;')
    )
  ),
  
  dashboardBody(
    tags$head(includeHTML('www/analytics.html'),
              tags$style('.shiny-output-error{color: white;}
                         .progress-bar { background-color: #00B07D; }
                          .shiny-notification {
                            position: fixed;
                            top: 40%;
                            left: 40%;
                            right: 40%;"'),
              HTML('<link rel="icon" href="www/favicon.ico" type="image/x-icon"/>')),
    tags$style(
      type = 'text/css',
      '.bg-aqua { background-color: #019DB0 !important; }
       .bg-fuchsia { background-color: #903C83 !important; }
       .bg-yellow { background-color: #B09001 !important; }
       .bg-green { background-color: #01B07D !important; }
       .bg-lime { background-color: #16D69E !important; }
       .bg-olive { background-color: #3BF1BC !important; }
       .hoverbox:hover { opacity: 0.85 !important; }
      '
    ),
    # green = darkest green
    # lime = medium green
    # olive = light green
    
    tabItems(
      tabItem(tabName = 'home',
              h2('SugarBase overview'),
              fluidRow(
                actionLink('modal_glycans', class='hoverbox',
                           box(title = 'Unique glycans',
                    height = 120, width = 4,
                    background = 'green', solidHeader = T,
                    div(style = 'float: left; padding-left: 20px;',
                        img(src = 'www/icon_glycan.png', width = '100px')),
                    div(style = 'float: left; padding-left: 30px; font-size: 28px;',
                        textOutput('num_glycans'))
                )),
                actionLink('modal_glycowords', class='hoverbox',
                           box(title = 'Unique glycowords',
                    height = 120, width = 4,
                    background = 'aqua', solidHeader = T,
                    div(style = 'float: left; padding-left: 20px; padding-top: 10px;',
                        img(src = 'www/icon_glycoword.png', width = '75px')),
                    div(style = 'float: left; padding-left: 30px; font-size: 28px;',
                        textOutput('num_glycowords'))
                )),
                actionLink('modal_glycoletters', class='hoverbox',
                           box(title = 'Unique glycoletters',
                    height = 120, width = 4,
                    background = 'fuchsia', solidHeader = T,
                    div(style = 'float: left; padding-left: 20px; padding-top: 3px;',
                        img(src = 'www/icon_glycoletters.png', width = '70px')),
                    div(style = 'float: left; padding-left: 30px; font-size: 28px;',
                        textOutput('num_glycoletters'))
                ))
              ),
              fluidRow(
                class = 'no-header-box',
                div(downloadButton('button_download_glycobase', label = 'Download full (csv)', style = 'margin-right: 15px; float: right;', icon = icon('download')),
                    HTML('<h2>Search SugarBase <span style="font-size: 10pt;">(v2.0)</span></h2>'),
                    style = 'padding-left: 15px;'),
                box(title = '',
                    width = 12,
                    div(withSpinner(dataTableOutput('table_glycobase'), type = 4, color = '#00B07D')))
              )
        ),
        tabItem(tabName = 'structuralcontext',
                h2('Characteristic environment'),
                fluidRow(
                  box(title = tagList("Query local structural context for a glycoletter",
                                      HTML('&nbsp;&nbsp;'),
                                      tags$i(
                                        class = "fa fa-info-circle", 
                                        style = "color: #00B07D; font-size: 8pt;"
                                      ),
                                      actionLink('info_environment_modal', 
                                                 label = 'What is this?',
                                                 class = 'info-tip',
                                                 style = 'font-size: 8pt; color: #00B07D;')),
                      width = 7, height = 320,
                      div(selectInput('select_context_criteria', label = 'Query type',
                                  choices = c('Observed monosaccharides paired with:',
                                              'Observed monosaccharides making bond:',
                                              'Observed bonds made by:')),
                          style = 'width: 53%; display: inline-block; max-width: 380px; min-width: 300px; padding-top: 20px; padding-left: 15px;'),
                      div(selectInput('select_context_glycoletter', label = 'Glycoletter',
                                  choices = 'Loading...'), 
                          style = 'width: 40%; display: inline-block; max-width: 175px;'),
                      hr(style = 'margin-top: 0'),
                      div(selectInput('select_context_taxonomy_level', label = 'Taxonomic filter',
                                  choices = c('Kingdom', 'Species')),
                          style = 'width: 49%; display: inline-block; max-width: 150px; padding-left: 15px;'),
                      div(selectInput('select_context_taxonomy_value', label = 'Kingdom',
                                  choices = 'Loading...'),
                          style = 'width: 49%; display: inline-block; max-width: 350px;')
                  ),
                  box(title='Frequency of glycoletter by position', 
                      width = 5, height = 320,
                      div(withSpinner(plotlyOutput('context_main_side_barplot', height = '240px'), 
                                      type = 4, color = '#00B07D')))
                ),
                fluidRow(
                  box(title = 'Structural context',
                      width = 12,
                      div(withSpinner(plotlyOutput('context_observed_barplot'), type = 4, color = '#00B07D'))
                  )
                )
        ),
        tabItem(tabName = 'alignment',
                h2('Glycan alignment'),
                fluidRow(
                  box(title = tagList("Input a glycan sequence to perform pairwise alignment",
                                      HTML('&nbsp;&nbsp;'),
                                      tags$i(
                                        class = "fa fa-info-circle", 
                                        style = "color: #00B07D; font-size: 8pt;"
                                      ),
                                      actionLink('info_alignment_modal', 
                                                 label = 'What is this?',
                                                 class = 'info-tip',
                                                 style = 'font-size: 8pt; color: #00B07D;')),
                      width = 12,
                      div(style='padding-left: 15px; padding-bottom: 15px;',
                        textInput('glycan_query', label = 'Query sequence', 
                                placeholder = 'Glycan sequence in IUPAC condensed format'),
                        actionButton('button_run_alignment', label = 'Align sequence',
                                   style = 'color: #ffffff; background-color: #00B07D; border-color: #0f9971ff; border-radius: 5px;'),
                        actionButton('button_show_alignment_example', label = 'Give me an example', style = 'margin-left: 10px;'),
                        textOutput('message_run_alignment')
                      )
                  )
                ),
                fluidRow(
                  uiOutput('alignments_ui')
                )
        ),
        tabItem(tabName = 'tab_sweettalk',
                h2('SweetTalk'),
                p('Coming soon')
        ),
        tabItem(tabName = 'tab_sweetorigins',
                h2('SweetOrigins'),
                p('Coming soon')
        ),
        tabItem(tabName = 'tab_biomining',
                h2('Biomining'),
                p('Coming soon')
        ),
        tabItem(tabName = 'submit',
                h2('Submit a new glycan'),
                HTML('<div class="typeform-widget" data-url="https://ranipowers.typeform.com/to/gmNmrW" style="width: 100%; height: 600px;"></div> <script> (function() { var qs,js,q,s,d=document, gi=d.getElementById, ce=d.createElement, gt=d.getElementsByTagName, id="typef_orm", b="https://embed.typeform.com/"; if(!gi.call(d,id)) { js=ce.call(d,"script"); js.id=id; js.src=b+"embed.js"; q=gt.call(d,"script")[0]; q.parentNode.insertBefore(js,q) } })() </script> <div style="font-family: Sans-Serif;font-size: 12px;color: #999;opacity: 0.5; padding-top: 5px;"> powered by <a href="https://admin.typeform.com/signup?utm_campaign=gmNmrW&utm_source=typeform.com-01E4M277GRYSX45RZ0PSMP63SW-free&utm_medium=typeform&utm_content=typeform-embedded-poweredbytypeform&utm_term=EN" style="color: #999" target="_blank">Typeform</a> </div>')
        )
      ) # end tabItems
  ) # end dashboardBody
) # end dashboardPage
