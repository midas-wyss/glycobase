# ---------------------------- OAuth setup ---------------------------------- #
# Synapse REST API docs:
# https://rest-docs.synapse.org/rest/#org.sagebionetworks.auth.OpenIDConnectController

DEBUG = Sys.getenv('DEBUG')

CLIENT_ID = NULL
CLIENT_SECRET = NULL
if (DEBUG){
  # Local testing
  APP_URL = Sys.getenv('APP_URL_LOCAL')
  CLIENT_ID = Sys.getenv('CLIENT_ID_LOCAL')
  CLIENT_SECRET = Sys.getenv('CLIENT_SECRET_LOCAL')
} else{
  # Deployed
  APP_URL = Sys.getenv('APP_URL')
  CLIENT_ID = Sys.getenv('CLIENT_ID')
  CLIENT_SECRET = Sys.getenv('CLIENT_SECRET')
}
if (is.null(CLIENT_ID)) stop('Missing CLIENT_ID. Did you forget to dencrypt .Renviron?')
if (is.null(CLIENT_SECRET)) stop('Missing CLIENT_SECRET. Did you forget to dencrypt .Renviron?')

# Create the OAuth app
APP <- oauth_app('Predictive BioAnalytics - Wyss',
                 key = CLIENT_ID,
                 secret = CLIENT_SECRET, 
                 redirect_uri = APP_URL)

# These are the user info details ('claims') requested from Synapse:
claims <- list(
  family_name = NULL, 
  given_name = NULL,
  email = NULL,
  email_verified = NULL,
  userid = NULL,
  orcid = NULL,
  is_certified = NULL,
  is_validated = NULL,
  validated_given_name = NULL,
  validated_family_name = NULL,
  validated_location = NULL,
  validated_email = NULL,
  validated_company = NULL,
  validated_at = NULL,
  validated_orcid = NULL,
  company = NULL
)

claimsParam <- toJSON(list(id_token = claims,
                           userinfo = claims))

# Synapse uses the OpenID Connect services to implement OAuth 2.0
API <- oauth_endpoint(authorize = paste0('https://signin.synapse.org?claims=', claimsParam), 
                      access = 'https://repo-prod.prod.sagebase.org/auth/v1/oauth2/token')

# The 'openid' scope is required by the protocol for retrieving user information
SCOPE <- 'openid'