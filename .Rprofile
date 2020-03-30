# -------------------------------- Settings --------------------------------- #
if (!Sys.info()[['sysname']] == 'Darwin'){
  # If running on shinyapps.io, set the RETICULATE_PYTHON evironment variable
  Sys.setenv(RETICULATE_PYTHON = '/home/shiny/.virtualenvs/python35_gly_env/bin/python')
  # Set local debug to false
  Sys.setenv(DEBUG = FALSE)
} else{
  # Running locally, use the local virtualenv
  options(shiny.port = 7450)
  reticulate::use_virtualenv('python35_gly_env', required = T)
  Sys.setenv(DEBUG = TRUE)
}
# -------------------------------- Projects --------------------------------- #
# Note: these are Synapse accession numbers and are *not* secrets. 
# Don't put secrets here - store them as environment variables instead!
PROJECT_CONFIG <- list(
  DATASETS = list(
      V2 = list(
        glycobase = 'syn21568081',
        tsne_glycans = 'syn21664555',
        tsne_glycoletters = 'syn21632310',
        tsne_glycowords = 'syn21632311'
      )
    )
)
