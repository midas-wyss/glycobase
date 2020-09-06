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

# ------------------------- Settings (Do not edit) -------------------------- #

VIRTUALENV_NAME = 'glycobase_env'

if (Sys.info()[['user']] == 'rstudio-connect'){
  
  # Running on remote server
  Sys.setenv(ONLINE = TRUE)
  Sys.setenv(PYTHON_PATH = '/opt/python/3.7.7/bin/python3')
  Sys.setenv(VIRTUALENV_NAME = paste0(VIRTUALENV_NAME, '/')) # include '/' => installs into rstudio-connect/apps/
  Sys.setenv(RETICULATE_PYTHON = paste0(VIRTUALENV_NAME, '/bin/python'))
  
} else {
  
  # Running locally
  Sys.setenv(ONLINE = TRUE)
  options(shiny.autoreload = TRUE, shiny.port = 3107)
  Sys.setenv(PYTHON_PATH = 'python3')
  Sys.setenv(VIRTUALENV_NAME = VIRTUALENV_NAME) # exclude '/' => installs into ~/.virtualenvs/
  # RETICULATE_PYTHON is not required locally, RStudio infers it based on the ~/.virtualenvs path
}

